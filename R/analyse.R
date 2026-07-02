mechanical_tac_R <- function(lo, hi, tau) {
  fifelse(lo >= tau, "Adequate", fifelse(hi < tau, "Not adequate", "Inconclusive"))
}

analyse_R <- function(project) {
  config <- load_config(project)
  raw_path <- file.path(project, "results", "raw", "replications_R.csv.gz")
  if (!file.exists(raw_path)) stop("Run R/run.R before R/analyse.R")
  raw <- fread(raw_path)
  pop <- load_locked_population(project)
  truth <- target_truths_R(pop)
  obs <- observation_parameters_R(pop, config)
  fwrite(truth, file.path(project, "results", "summary", "target_truths_R.csv"))
  fwrite(obs, file.path(project, "results", "summary", "observation_parameters_R.csv"))
  raw <- merge(raw, truth[, .(estimand, target_parameter)], by = "estimand")
  raw <- merge(raw, obs[, .(hospital_sample_size, strategy, estimand, reference_parameter = observation_parameter)], by = c("hospital_sample_size", "strategy", "estimand"))
  raw[, `:=`(
    target_covered = ci_lower <= target_parameter & ci_upper >= target_parameter,
    reference_covered = ci_lower <= reference_parameter & ci_upper >= reference_parameter,
    interval_width = ci_upper - ci_lower,
    mechanical_tac = mechanical_tac_R(ci_lower, ci_upper, config$target$adequacy_threshold)
  )]
  epsv <- (config$target$halfwidth_tolerance / 1.96)^2
  summary <- raw[!is.na(estimate), {
    err <- estimate - target_parameter[1]
    sq <- err^2
    esd <- sd(estimate); rmse <- sqrt(mean(sq)); nr <- .N
    .(
      target_parameter = target_parameter[1], reference_parameter = reference_parameter[1],
      reference_target_discrepancy = reference_parameter[1] - target_parameter[1],
      mean_estimate = mean(estimate), bias = mean(err), bias_mcse = esd / sqrt(nr),
      relative_bias_percent = 100 * mean(err) / target_parameter[1], empirical_sd = esd,
      empirical_variance = esd^2, rmse = rmse,
      rmse_mcse = ifelse(rmse > 0, sd(sq) / (2 * rmse * sqrt(nr)), 0),
      mean_estimated_se = mean(estimated_se), se_to_esd_ratio = mean(estimated_se) / esd,
      target_coverage = mean(target_covered), reference_coverage = mean(reference_covered),
      mean_interval_width = mean(interval_width), mean_half_width = mean(interval_width) / 2,
      mean_positive_cases = mean(positive_cases), mean_hard_positive_cases = mean(hard_positive_cases),
      mean_observed_patients = mean(observed_patients), mean_observed_priority_share = mean(observed_priority_share),
      mean_observed_hard_share = mean(observed_hard_share), replications_estimable = nr
    )
  }, by = .(hospital_sample_size, strategy, estimand)]
  summary[, `:=`(
    target_coverage_mcse = sqrt(target_coverage * (1 - target_coverage) / config$project$monte_carlo_replications),
    non_estimable_rate = 0,
    non_estimable_mcse = 0,
    pr_bias_pass = abs(bias) <= config$target$bias_tolerance,
    pr_precision_pass = empirical_variance <= epsv,
    interval_validity_pass = abs(target_coverage - 0.95) <= config$target$coverage_tolerance,
    reference_interval_validity_pass = abs(reference_coverage - 0.95) <= config$target$coverage_tolerance,
    variance_method_compatible = strategy != "N5"
  )]
  summary[, pr_point_estimation_pass := pr_bias_pass & pr_precision_pass]
  summary[, full_evidential_pass := pr_point_estimation_pass & interval_validity_pass & variance_method_compatible]
  fwrite(summary, file.path(project, "results", "summary", "performance_summary_R.csv"))
  raw <- merge(raw, summary[, .(hospital_sample_size, strategy, estimand, full_evidential_pass)], by = c("hospital_sample_size", "strategy", "estimand"))
  raw[, formal_tac := fifelse(full_evidential_pass, mechanical_tac, "Evidentially insufficient")]
  tac <- raw[, .(count = .N), by = .(hospital_sample_size, strategy, estimand, formal_tac)]
  tac[, proportion := count / sum(count), by = .(hospital_sample_size, strategy, estimand)]
  tac[, proportion_mcse := sqrt(proportion * (1 - proportion) / config$project$monte_carlo_replications)]
  fwrite(tac, file.path(project, "results", "summary", "tac_frequencies_R.csv"))
  count_quantiles <- raw[, .(
    mean = mean(hard_positive_cases),
    p05 = as.numeric(quantile(hard_positive_cases, 0.05)),
    p25 = as.numeric(quantile(hard_positive_cases, 0.25)),
    median = median(hard_positive_cases),
    p75 = as.numeric(quantile(hard_positive_cases, 0.75)),
    p95 = as.numeric(quantile(hard_positive_cases, 0.95))
  ), by = .(hospital_sample_size, strategy)]
  fwrite(count_quantiles, file.path(project, "results", "summary", "hard_positive_count_quantiles_R.csv"))
  fwrite(raw, file.path(project, "results", "raw", "replications_classified_R.csv.gz"))
  invisible(list(summary = summary, tac = tac, counts = count_quantiles, raw = raw))
}
