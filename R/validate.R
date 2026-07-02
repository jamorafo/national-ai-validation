validate_R <- function(project) {
  raw <- fread(file.path(project, "results", "raw", "replications_R.csv.gz"))
  summary <- fread(file.path(project, "results", "summary", "performance_summary_R.csv"))
  stopifnot(!any(grepl("month", names(raw), ignore.case = TRUE)))
  shared <- raw[strategy %in% c("N3", "N4", "N5")]
  chk <- shared[, lapply(.SD, uniqueN), by = .(hospital_sample_size, replication, estimand), .SDcols = c("observed_patients", "hard_positive_cases", "observed_priority_share", "observed_hard_share")]
  stopifnot(max(as.matrix(chk[, -c(1:3)])) == 1)
  pts <- dcast(raw[strategy %in% c("N4", "N5")], hospital_sample_size + replication + estimand ~ strategy, value.var = "estimate")
  stopifnot(max(abs(pts$N4 - pts$N5), na.rm = TRUE) < 1e-14)
  stopifnot(max(abs(summary[strategy == "N1", bias])) < 0.005)
  stopifnot(max(abs(summary[strategy == "N4", bias])) < 0.008)
  result <- list(
    passed = TRUE,
    checks = c("no month sampling", "same enriched ORP", "N4/N5 identical point estimates", "N1 unbiased", "N4 design-consistent"),
    R_version = R.version.string,
    packages = sapply(c("data.table", "yaml", "digest", "ggplot2"), function(x) as.character(packageVersion(x)))
  )
  jsonlite::write_json(result, file.path(project, "results", "summary", "validation_results_R.json"), pretty = TRUE, auto_unbox = TRUE)
  invisible(result)
}
