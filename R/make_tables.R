make_tables_R <- function(project) {
  suppressPackageStartupMessages(library(data.table))

  summary_dir <- file.path(project, "results", "summary")
  out <- file.path(project, "tables")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)

  summary_csv <- function(stem) {
    path <- file.path(summary_dir, paste0(stem, "_R.csv"))
    if (!file.exists(path)) {
      stop("Required R summary file not found: ", path, call. = FALSE)
    }
    path
  }

  status <- function(x) ifelse(as.logical(x), "Pass", "Fail")

  write_table <- function(path, caption, label, columns, header, rows, notes = "") {
    text <- c(
      "\\begin{table}[h!]",
      "\\centering",
      "\\small",
      sprintf("\\caption{%s}", caption),
      sprintf("\\label{%s}", label),
      sprintf("\\begin{tabular}{%s}", columns),
      "\\toprule",
      paste0(header, " \\\\"),
      "\\midrule",
      paste0(rows, " \\\\"),
      "\\bottomrule",
      "\\end{tabular}"
    )
    if (nzchar(notes)) {
      text <- c(
        text,
        "\\par\\vspace{2pt}",
        sprintf("\\begin{minipage}{0.97\\linewidth}\\footnotesize %s\\end{minipage}", notes)
      )
    }
    text <- c(text, "\\end{table}", "")
    writeLines(text, path, useBytes = TRUE)
  }

  truth <- fread(summary_csv("target_truths"))
  obs <- fread(summary_csv("observation_parameters"))
  perf <- fread(summary_csv("performance_summary"))
  tac <- fread(summary_csv("tac_frequencies"))
  counts <- fread(summary_csv("hard_positive_count_quantiles"))

  rows <- truth[, sprintf(
    "%s & %s & %s & %.3f & %.4f",
    tools::toTitleCase(estimand),
    format(as.integer(eligible_patients), big.mark = ",", scientific = FALSE),
    format(as.integer(positive_cases), big.mark = ",", scientific = FALSE),
    event_prevalence,
    target_parameter
  )]
  write_table(
    file.path(out, "nav_table_population_truths.tex"),
    "Fixed finite-population target quantities.",
    "tab:nav-population-truths",
    "lrrrr",
    "Estimand & Eligible patients & Positive cases & Event prevalence & Sensitivity",
    rows,
    "The harder subgroup is defined at the patient level and occurs in both hospital design strata."
  )

  strategy_rows <- c(
    "N1 & Patient SRSWOR & Ordinary sensitivity ratio & Patient-SRS ratio linearisation & Ideal self-weighting benchmark",
    "N2 & Proportional stratified hospital SRS & Design-weighted combined ratio & Stratified cluster Taylor linearisation & Realistic target-aligned design",
    "N3 & Enriched stratified hospital SRS & Unweighted pooled ratio & Cluster-aware variance around $\\theta_{\\mathcal O,3}$ & Deliberate estimator mismatch",
    "N4 & Same enriched ORP as N3 & Design-weighted combined ratio & Stratified cluster Taylor linearisation & Compatible enrichment",
    "N5 & Same enriched ORP and point estimate as N4 & Design-weighted combined ratio & Naive patient-level variance & Deliberate uncertainty mismatch"
  )
  write_table(
    file.path(out, "nav_table_strategies.tex"),
    "Probability construction, estimator, and uncertainty procedure for the five strategies.",
    "tab:nav-strategies",
    "lp{0.19\\linewidth}p{0.20\\linewidth}p{0.23\\linewidth}p{0.18\\linewidth}",
    "Strategy & Construction process & Point estimator & Variance procedure & Role",
    strategy_rows
  )

  enriched_obs <- obs[strategy == "N3" & hospital_sample_size == 160]
  rows <- enriched_obs[, sprintf(
    "%s & %.4f & %.4f & %+.4f",
    tools::toTitleCase(estimand),
    target_parameter,
    observation_parameter,
    reference_target_discrepancy
  )]
  write_table(
    file.path(out, "nav_table_observation_parameters.tex"),
    "Target and design-induced unweighted observation parameters for the enriched ORP.",
    "tab:nav-observation-parameters",
    "lrrr",
    "Estimand & $\\theta_T$ & $\\theta_{\\mathcal O,3}$ & RTD",
    rows,
    "The inclusion-probability ratio between priority and standard hospitals is three for every enriched sample-size condition, so the observation parameters do not depend on $m$."
  )

  national <- perf[estimand == "national"]
  setorder(national, hospital_sample_size, strategy)
  rows <- national[, sprintf(
    "%d & %s & %+.4f & %.4f & %.4f & %.4f & %.3f & %s",
    as.integer(hospital_sample_size),
    strategy,
    bias,
    empirical_sd,
    rmse,
    mean_estimated_se,
    target_coverage,
    status(full_evidential_pass)
  )]
  write_table(
    file.path(out, "nav_table_national_performance.tex"),
    "Monte Carlo performance for national sensitivity.",
    "tab:nav-national-performance",
    "rrlrrrrr",
    "$m$ & Strategy & Bias & ESD & RMSE & Mean SE & Coverage & Evidence",
    rows,
    "Evidence is marked Pass only when the bias and precision tolerances are met, target interval coverage is acceptable, and the declared variance procedure is design-compatible."
  )

  variance <- perf[estimand == "national" & strategy %chin% c("N4", "N5")]
  setorder(variance, hospital_sample_size, strategy)
  rows <- variance[, sprintf(
    "%d & %s & %.4f & %.4f & %.3f & %.3f & %.4f",
    as.integer(hospital_sample_size),
    strategy,
    empirical_sd,
    mean_estimated_se,
    se_to_esd_ratio,
    target_coverage,
    mean_interval_width
  )]
  write_table(
    file.path(out, "nav_table_variance_comparison.tex"),
    "National sensitivity: same enriched samples and point estimates, different uncertainty procedures.",
    "tab:nav-variance-comparison",
    "rrlrrrr",
    "$m$ & Strategy & ESD & Mean SE & SE/ESD & Coverage & Mean width",
    rows,
    "N4 and N5 have numerically identical point estimates in every replication. Differences arise only from the uncertainty procedure."
  )

  hard <- perf[estimand == "hard" & strategy %chin% c("N2", "N4")]
  setorder(hard, hospital_sample_size, strategy)
  rows <- hard[, sprintf(
    "%d & %s & %.1f & %.4f & %.4f & %s & %s",
    as.integer(hospital_sample_size),
    strategy,
    mean_hard_positive_cases,
    empirical_sd,
    rmse,
    status(pr_precision_pass),
    status(full_evidential_pass)
  )]
  write_table(
    file.path(out, "nav_table_hard_evidence.tex"),
    "Effect of enrichment on harder-subgroup evidence.",
    "tab:nav-hard-evidence",
    "rrlrrrr",
    "$m$ & Strategy & Mean hard positives & ESD & RMSE & Precision & Evidence",
    rows,
    "At $m=160$, N4 passes the pre-specified precision criterion for harder-subgroup sensitivity, whereas N2 remains evidentially insufficient."
  )

  pr160 <- perf[hospital_sample_size == 160]
  setorder(pr160, strategy, estimand)
  rows <- pr160[, sprintf(
    "%s & %s & %s & %s & %s & %s & %s",
    strategy,
    tools::toTitleCase(estimand),
    status(pr_bias_pass),
    status(pr_precision_pass),
    status(interval_validity_pass),
    status(variance_method_compatible),
    status(full_evidential_pass)
  )]
  write_table(
    file.path(out, "nav_table_pr_status.tex"),
    "Predictive Representativity and uncertainty diagnostics at $m=160$.",
    "tab:nav-pr-status",
    "llrrrrr",
    "Strategy & Estimand & Bias & Precision & Coverage & $V_k$ compatible & Full evidence",
    rows
  )

  tac160 <- tac[hospital_sample_size == 160]
  pivot <- dcast(
    tac160,
    strategy + estimand ~ formal_tac,
    value.var = "proportion",
    fill = 0
  )
  for (col in c("Adequate", "Inconclusive", "Not adequate", "Evidentially insufficient")) {
    if (!col %chin% names(pivot)) pivot[, (col) := 0]
  }
  setorder(pivot, strategy, estimand)
  rows <- pivot[, sprintf(
    "%s & %s & %.3f & %.3f & %.3f & %.3f",
    strategy,
    tools::toTitleCase(estimand),
    Adequate,
    Inconclusive,
    `Not adequate`,
    `Evidentially insufficient`
  )]
  write_table(
    file.path(out, "nav_table_tac.tex"),
    "Formal TAC decision frequencies at $m=160$.",
    "tab:nav-tac",
    "llrrrr",
    "Strategy & Estimand & Adequate & Inconclusive & Not adequate & Evidentially insufficient",
    rows,
    "Mechanical threshold results are suppressed whenever the full evidential gate fails."
  )


  raw_classified_path <- file.path(project, "results", "raw", "replications_classified_R.csv.gz")
  if (file.exists(raw_classified_path)) {
    raw_classified <- fread(raw_classified_path)
    required_raw_columns <- c(
      "hospital_sample_size", "strategy", "estimand",
      "mechanical_tac", "formal_tac", "full_evidential_pass"
    )
    missing_raw_columns <- setdiff(required_raw_columns, names(raw_classified))
    if (length(missing_raw_columns)) {
      stop(
        basename(raw_classified_path), " is missing required columns: ",
        paste(missing_raw_columns, collapse = ", "),
        call. = FALSE
      )
    }

    mechanical_m80 <- raw_classified[
      hospital_sample_size == 80 &
        estimand == "national" &
        strategy %chin% c("N4", "N5"),
      .(
        mechanical_adequate = mean(mechanical_tac == "Adequate"),
        mechanical_inconclusive = mean(mechanical_tac == "Inconclusive"),
        mechanical_not_adequate = mean(mechanical_tac == "Not adequate"),
        formal_adequate = mean(formal_tac == "Adequate"),
        evidential_gate = ifelse(all(full_evidential_pass), "Pass", "Fail")
      ),
      by = strategy
    ]
    setorder(mechanical_m80, strategy)

    if (nrow(mechanical_m80) > 0L) {
      rows <- mechanical_m80[, sprintf(
        "%s & %.3f & %.3f & %.3f & %.3f & %s",
        strategy,
        mechanical_adequate,
        mechanical_inconclusive,
        mechanical_not_adequate,
        formal_adequate,
        evidential_gate
      )]
      write_table(
        file.path(out, "nav_table_mechanical_tac_m80.tex"),
        "Ungated mechanical TAC diagnostics for national sensitivity at $m=80$.",
        "tab:nav-mechanical-tac-m80",
        "lrrrrl",
        "Strategy & Mechanical adequate & Mechanical inconclusive & Mechanical not adequate & Formal adequate & Evidential gate",
        rows,
        "Mechanical TAC compares each interval with the adequacy threshold before applying the evidential gate. Formal TAC suppresses mechanical conclusions when point estimation, interval validity, or variance compatibility fails."
      )
    } else {
      warning("No N4/N5 national rows at m=80 were found in ", raw_classified_path)
    }
  } else {
    warning("Skipping nav_table_mechanical_tac_m80.tex because classified replications were not found: ", raw_classified_path)
  }

  invisible(TRUE)
}
