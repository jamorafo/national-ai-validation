logit_interval_R <- function(est, se) {
  if (!is.finite(est) || !is.finite(se)) return(c(NA_real_, NA_real_))
  p <- min(max(est, 1e-8), 1 - 1e-8)
  se_logit <- se / (p * (1 - p))
  plogis(qlogis(p) + c(-1, 1) * qnorm(0.975) * se_logit)
}

taylor_ratio_variance_R <- function(est, den, t0, y0, t1, y1, H0, H1) {
  m0 <- length(t0); m1 <- length(t1)
  z0 <- t0 - est * y0; z1 <- t1 - est * y1
  vz <- H0^2 * (1 - m0 / H0) * var(z0) / m0 + H1^2 * (1 - m1 / H1) * var(z1) / m1
  vz / den^2
}

unweighted_cluster_variance_R <- function(est, den, t0, y0, t1, y1, H0, H1) {
  m0 <- length(t0); m1 <- length(t1)
  z0 <- t0 - est * y0; z1 <- t1 - est * y1
  vz <- m0 * (1 - m0 / H0) * var(z0) + m1 * (1 - m1 / H1) * var(z1)
  vz / den^2
}

naive_patient_variance_R <- function(est, den, t0, y0, t1, y1, w0, w1) {
  rss <- w0^2 * (sum(t0) * (1 - est)^2 + (sum(y0) - sum(t0)) * est^2) +
    w1^2 * (sum(t1) * (1 - est)^2 + (sum(y1) - sum(t1)) * est^2)
  rss / den^2
}
