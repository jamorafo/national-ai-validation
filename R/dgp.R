suppressPackageStartupMessages({
  library(data.table)
  library(yaml)
  library(digest)
})

load_config <- function(project) {
  yaml::read_yaml(file.path(project, "config", "config.yaml"))
}

stable_seed <- function(master, label, size, replication, language = "R") {
  text <- paste(master, label, size, replication, language, sep = "|")
  hex <- digest::digest(text, algo = "sha256", serialize = FALSE)
  hi <- strtoi(substr(hex, 1, 4), base = 16L)
  lo <- strtoi(substr(hex, 5, 8), base = 16L)
  as.integer((hi * 65536 + lo) %% 2147483646 + 1)
}

load_locked_population <- function(project) {
  fread(file.path(project, "results", "raw", "finite_population.csv.gz"))
}

generate_population_R <- function(config) {
  # Independent R implementation of the DGP. The default chapter run uses the
  # locked finite population created once and stored in results/raw so both
  # languages evaluate exactly the same target population.
  p <- config$population
  set.seed(config$project$master_seed)
  h0 <- p$hospitals_standard
  h1 <- p$hospitals_priority
  H <- h0 + h1
  Hstr <- c(rep(0L, h0), rep(1L, h1))
  sizes <- round(rlnorm(H, p$hospital_size_log_mean, p$hospital_size_log_sd))
  sizes <- pmax(p$hospital_size_min, pmin(p$hospital_size_max, sizes))

  sdv <- c(p$random_effect_sd_q, p$random_effect_sd_y, p$random_effect_sd_a)
  corr <- matrix(c(
    1, p$random_effect_corr_q_y, p$random_effect_corr_q_a,
    p$random_effect_corr_q_y, 1, p$random_effect_corr_y_a,
    p$random_effect_corr_q_a, p$random_effect_corr_y_a, 1
  ), 3, 3, byrow = TRUE)
  Sigma <- corr * outer(sdv, sdv)
  re <- MASS::mvrnorm(H, mu = c(0, 0, 0), Sigma = Sigma)

  out <- vector("list", H)
  for (h in seq_len(H)) {
    n <- sizes[h]
    hs <- Hstr[h]
    pq <- plogis(qlogis(p$q_baseline_probability) + p$q_priority_log_odds * hs + re[h, 1])
    q <- rbinom(n, 1, pq)
    py <- plogis(qlogis(p$y_baseline_probability) + p$y_priority_log_odds * hs + p$y_hard_log_odds * q + re[h, 2])
    y <- rbinom(n, 1, py)
    pa1 <- plogis(qlogis(p$sensitivity_baseline_probability) + p$sensitivity_hard_log_odds * q + p$sensitivity_priority_log_odds * hs + re[h, 3])
    pa0 <- plogis(qlogis(p$false_alert_baseline_probability) + p$false_alert_hard_log_odds * q + p$false_alert_priority_log_odds * hs + 0.20 * re[h, 2])
    a <- rbinom(n, 1, ifelse(y == 1, pa1, pa0))
    out[[h]] <- data.table(
      hospital_id = h - 1L,
      hospital_stratum = hs,
      hard_subgroup = q,
      outcome = y,
      alert = a,
      true_positive = y * a
    )
  }
  rbindlist(out)
}

aggregate_hospitals <- function(pop) {
  base <- pop[, .(
    N = .N,
    Q = sum(hard_subgroup),
    Y = sum(outcome),
    TP = sum(true_positive),
    N_q0 = sum(hard_subgroup == 0),
    Y_q0 = sum(outcome * (hard_subgroup == 0)),
    TP_q0 = sum(true_positive * (hard_subgroup == 0)),
    N_q1 = sum(hard_subgroup == 1),
    Y_q1 = sum(outcome * (hard_subgroup == 1)),
    TP_q1 = sum(true_positive * (hard_subgroup == 1))
  ), by = .(hospital_id, hospital_stratum)]
  setorder(base, hospital_id)
  base
}

target_truths_R <- function(pop) {
  rbindlist(list(
    pop[, .(estimand = "national", target_parameter = sum(true_positive) / sum(outcome), eligible_patients = .N, positive_cases = sum(outcome), event_prevalence = mean(outcome))],
    pop[hard_subgroup == 0, .(estimand = "easy", target_parameter = sum(true_positive) / sum(outcome), eligible_patients = .N, positive_cases = sum(outcome), event_prevalence = mean(outcome))],
    pop[hard_subgroup == 1, .(estimand = "hard", target_parameter = sum(true_positive) / sum(outcome), eligible_patients = .N, positive_cases = sum(outcome), event_prevalence = mean(outcome))]
  ))
}

observation_parameters_R <- function(pop, config) {
  truth <- target_truths_R(pop)
  h0 <- config$population$hospitals_standard
  h1 <- config$population$hospitals_priority
  ans <- list(); k <- 0L
  for (m in config$designs$hospital_sample_sizes) {
    allocations <- list(
      N1 = NULL,
      N2 = config$designs$proportional_allocations[[as.character(m)]],
      N3 = config$designs$enriched_allocations[[as.character(m)]],
      N4 = config$designs$enriched_allocations[[as.character(m)]],
      N5 = config$designs$enriched_allocations[[as.character(m)]]
    )
    for (strategy in names(allocations)) {
      if (strategy == "N1") {
        pi <- rep(1, nrow(pop))
      } else {
        a <- allocations[[strategy]]
        pi <- ifelse(pop$hospital_stratum == 0, a[[1]] / h0, a[[2]] / h1)
      }
      for (e in c("national", "easy", "hard")) {
        idx <- if (e == "national") rep(TRUE, nrow(pop)) else pop$hard_subgroup == ifelse(e == "easy", 0, 1)
        theta_o <- sum(pi[idx] * pop$true_positive[idx]) / sum(pi[idx] * pop$outcome[idx])
        theta_t <- truth[estimand == e, target_parameter]
        k <- k + 1L
        ans[[k]] <- data.table(
          hospital_sample_size = m,
          strategy = strategy,
          estimand = e,
          target_parameter = theta_t,
          observation_parameter = theta_o,
          reference_target_discrepancy = theta_o - theta_t
        )
      }
    }
  }
  rbindlist(ans)
}

patient_cells_R <- function(pop) {
  cells <- array(0L, dim = c(2, 2, 3))
  for (h in 0:1) for (q in 0:1) {
    d <- pop[hospital_stratum == h & hard_subgroup == q]
    cells[h + 1, q + 1, 1] <- sum(d$outcome == 0)
    cells[h + 1, q + 1, 2] <- sum(d$outcome == 1 & d$alert == 0)
    cells[h + 1, q + 1, 3] <- sum(d$outcome == 1 & d$alert == 1)
  }
  cells
}
