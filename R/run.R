run_experiment_R <- function(project, replications = NULL, use_locked_population = TRUE) {
  config <- load_config(project)
  Rn <- if (is.null(replications)) config$project$monte_carlo_replications else replications
  pop <- if (use_locked_population) load_locked_population(project) else generate_population_R(config)
  hosp <- aggregate_hospitals(pop)
  cells <- patient_cells_R(pop)
  H0 <- config$population$hospitals_standard; H1 <- config$population$hospitals_priority
  idx0 <- which(hosp$hospital_stratum == 0); idx1 <- which(hosp$hospital_stratum == 1)
  N <- nrow(pop); H <- H0 + H1
  total_rows <- length(config$designs$hospital_sample_sizes) * Rn * 5L * 3L
  rows <- vector("list", total_rows); k <- 0L

  add_rows <- function(strategy, m, rep, ests, nobs, hard_pos, priority_share, hard_share) {
    for (e in names(ests)) {
      k <<- k + 1L
      z <- ests[[e]]
      rows[[k]] <<- data.table(
        strategy = strategy, hospital_sample_size = m, replication = rep - 1L, estimand = e,
        estimate = z$estimate, estimated_se = z$estimated_se, ci_lower = z$ci_lower, ci_upper = z$ci_upper,
        positive_cases = z$positive_cases, non_estimable = z$non_estimable,
        observed_patients = nobs, hard_positive_cases = hard_pos,
        observed_priority_share = priority_share, observed_hard_share = hard_share
      )
    }
  }

  for (m in config$designs$hospital_sample_sizes) {
    prop <- config$designs$proportional_allocations[[as.character(m)]]
    enrich <- config$designs$enriched_allocations[[as.character(m)]]
    n1 <- round(N * m / H)
    for (rep in seq_len(Rn)) {
      set.seed(stable_seed(config$project$master_seed, "N1", m, rep - 1L, "R"))
      draw <- array(rmvhyper_seq(as.vector(cells), n1), dim = dim(cells))
      n1_hard_positive <- sum(draw[, 2, 2:3])
      n1_priority_share <- sum(draw[2, , ]) / n1
      n1_hard_share <- sum(draw[, 2, ]) / n1
      add_rows("N1", m, rep, estimate_patient_srs_R(draw, n1, N), n1, n1_hard_positive, n1_priority_share, n1_hard_share)

      set.seed(stable_seed(config$project$master_seed, "N2", m, rep - 1L, "R"))
      ss <- draw_hospitals_R(idx0, idx1, prop); selected <- c(ss$s0, ss$s1)
      nobs <- sum(hosp$N[selected])
      add_rows("N2", m, rep, estimate_hospital_sample_R(hosp, ss$s0, ss$s1, H0, H1, "design"), nobs, sum(hosp$Y_q1[selected]), sum(hosp$N[ss$s1]) / nobs, sum(hosp$Q[selected]) / nobs)

      set.seed(stable_seed(config$project$master_seed, "ENRICHED", m, rep - 1L, "R"))
      ss <- draw_hospitals_R(idx0, idx1, enrich); selected <- c(ss$s0, ss$s1)
      nobs <- sum(hosp$N[selected]); hp <- sum(hosp$Y_q1[selected]); ps <- sum(hosp$N[ss$s1]) / nobs; qs <- sum(hosp$Q[selected]) / nobs
      add_rows("N3", m, rep, estimate_hospital_sample_R(hosp, ss$s0, ss$s1, H0, H1, "unweighted"), nobs, hp, ps, qs)
      add_rows("N4", m, rep, estimate_hospital_sample_R(hosp, ss$s0, ss$s1, H0, H1, "design"), nobs, hp, ps, qs)
      add_rows("N5", m, rep, estimate_hospital_sample_R(hosp, ss$s0, ss$s1, H0, H1, "naive"), nobs, hp, ps, qs)
    }
    message(sprintf("R simulation completed m=%s", m))
  }
  raw <- rbindlist(rows[seq_len(k)])
  fwrite(raw, file.path(project, "results", "raw", "replications_R.csv.gz"))
  invisible(raw)
}
