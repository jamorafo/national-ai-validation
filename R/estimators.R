estimand_columns <- list(
  national = c("TP", "Y"),
  easy = c("TP_q0", "Y_q0"),
  hard = c("TP_q1", "Y_q1")
)

missing_result_R <- function() {
  list(estimate = NA_real_, estimated_se = NA_real_, ci_lower = NA_real_, ci_upper = NA_real_, positive_cases = 0, non_estimable = 1)
}

estimate_patient_srs_R <- function(draw, n, N) {
  out <- list()
  for (e in names(estimand_columns)) {
    cell <- if (e == "national") apply(draw, 3, sum) else apply(draw[, ifelse(e == "easy", 1, 2), , drop = FALSE], 3, sum)
    tp <- cell[3]; y <- cell[2] + cell[3]
    if (y <= 0) { out[[e]] <- missing_result_R(); next }
    est <- tp / y
    sumz2 <- tp * (1 - est)^2 + (y - tp) * est^2
    sz2 <- sumz2 / (n - 1)
    var_est <- (1 - n / N) * sz2 / (n * (y / n)^2)
    se <- sqrt(max(var_est, 0))
    ci <- logit_interval_R(est, se)
    out[[e]] <- list(estimate = est, estimated_se = se, ci_lower = ci[1], ci_upper = ci[2], positive_cases = y, non_estimable = 0)
  }
  out
}

estimate_hospital_sample_R <- function(hosp, s0, s1, H0, H1, mode) {
  out <- list(); m0 <- length(s0); m1 <- length(s1)
  for (e in names(estimand_columns)) {
    cols <- estimand_columns[[e]]
    t0 <- hosp[[cols[1]]][s0]; y0 <- hosp[[cols[2]]][s0]
    t1 <- hosp[[cols[1]]][s1]; y1 <- hosp[[cols[2]]][s1]
    if (mode == "unweighted") { w0 <- 1; w1 <- 1 } else { w0 <- H0 / m0; w1 <- H1 / m1 }
    num <- w0 * sum(t0) + w1 * sum(t1)
    den <- w0 * sum(y0) + w1 * sum(y1)
    if (den <= 0) { out[[e]] <- missing_result_R(); next }
    est <- num / den
    var_est <- switch(mode,
      design = taylor_ratio_variance_R(est, den, t0, y0, t1, y1, H0, H1),
      naive = naive_patient_variance_R(est, den, t0, y0, t1, y1, w0, w1),
      unweighted = unweighted_cluster_variance_R(est, den, t0, y0, t1, y1, H0, H1),
      stop("Unknown mode")
    )
    se <- sqrt(max(var_est, 0)); ci <- logit_interval_R(est, se)
    out[[e]] <- list(estimate = est, estimated_se = se, ci_lower = ci[1], ci_upper = ci[2], positive_cases = sum(y0) + sum(y1), non_estimable = 0)
  }
  out
}
