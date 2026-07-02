suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(scales)
})

save_plot_set <- function(plot, outdir, stem, width, height) {
  ggsave(file.path(outdir, paste0(stem, ".pdf")), plot, width = width, height = height)
  ggsave(file.path(outdir, paste0(stem, ".svg")), plot, width = width, height = height, device = svglite::svglite)
  ggsave(file.path(outdir, paste0(stem, ".png")), plot, width = width, height = height, dpi = 320)
}

make_figures_R <- function(project) {
  outdir <- file.path(project, "figures", "r_publication")
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

  estimand_label_map <- c(
    easy = "Easy",
    hard = "Hard",
    national = "National"
  )

  row_levels_nav <- unlist(lapply(
    paste0("N", 1:5),
    function(s) paste0(s, " - ", c("Easy", "Hard", "National"))
  ))

  tac_fill <- c(
    "Adequate" = "#8BC596",
    "Inconclusive" = "#E8BF63",
    "Not adequate" = "#E89A88",
    "Evidentially insufficient" = "#D9D9D9"
  )

  evidential_fill <- c(
    "Insufficient" = "#B9C3E6",
    "Pass" = "#8FD19E"
  )

  suffix <- if (file.exists(file.path(project, "results", "summary", "performance_summary_R.csv"))) "_R" else ""

  perf <- fread(file.path(project, "results", "summary", paste0("performance_summary", suffix, ".csv")))
  obs <- fread(file.path(project, "results", "summary", paste0("observation_parameters", suffix, ".csv")))
  tac <- fread(file.path(project, "results", "summary", paste0("tac_frequencies", suffix, ".csv")))
  rawfile <- file.path(project, "results", "raw", paste0("replications", ifelse(suffix == "_R", "_R", ""), ".csv.gz"))
  raw <- fread(rawfile)
  pop <- load_locked_population(project)
  counts <- fread(file.path(project, "results", "summary", paste0("hard_positive_count_quantiles", suffix, ".csv")))
  config <- load_config(project)

  labs <- c(
    N1 = "N1 Patient SRS",
    N2 = "N2 Proportional hospitals",
    N3 = "N3 Enriched, unweighted",
    N4 = "N4 Enriched, design-weighted",
    N5 = "N5 Enriched, naive variance"
  )

  sci_palette <- c(
    blue = "#0072B2",
    orange = "#E69F00",
    green = "#009E73",
    vermillion = "#D55E00",
    purple = "#CC79A7",
    skyblue = "#56B4E9",
    yellow = "#F0E442",
    black = "#000000"
  )

  strategy_palette_id <- setNames(
    sci_palette[c("blue", "orange", "green", "vermillion", "purple")],
    names(labs)
  )

  strategy_palette_label <- setNames(
    sci_palette[c("blue", "orange", "green", "vermillion", "purple")],
    labs
  )

  tac_palette <- c(
    Adequate = "#8FD19E",
    Inconclusive = "#F6C667",
    "Not adequate" = "#F29E9E",
    "Evidentially insufficient" = "#B9C3E6"
  )

  base_theme <- theme_minimal(base_size = 11.5) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "grey88", linewidth = 0.30),
      legend.position = "bottom",
      legend.title = element_text(face = "bold", size = 11.5),
      legend.text = element_text(face = "bold", size = 10.5),
      axis.title = element_text(colour = "grey15", face = "bold", size = 13),
      axis.text = element_text(colour = "grey20", face = "bold", size = 10.5),
      strip.text = element_text(face = "bold", colour = "grey15", size = 12), plot.margin = margin(12, 18, 16, 30),
      plot.title = element_blank(),
      plot.subtitle = element_blank()
    )

  structure <- rbindlist(list(
    pop[, .(quantity = "Hard-subgroup prevalence", value = mean(hard_subgroup)), by = hospital_stratum],
    pop[, .(quantity = "Event prevalence", value = mean(outcome)), by = hospital_stratum],
    pop[, .(quantity = "Sensitivity", value = sum(true_positive) / sum(outcome)), by = hospital_stratum]
  ))

  structure[, hospital_stratum_label := factor(
    hospital_stratum,
    levels = c(0, 1),
    labels = c("Standard hospitals", "Priority hospitals")
  )]

  p1 <- ggplot(structure, aes(quantity, value, fill = hospital_stratum_label)) +
    geom_col(position = position_dodge(width = .75), width = .68) +
    geom_text(
      aes(label = sprintf("%.3f", value)),
      position = position_dodge(width = .75),
      vjust = -.3,
      size = 3.8,
      fontface = "bold"
    ) +
    scale_fill_manual(values = c(
      "Standard hospitals" = "#0072B2",
      "Priority hospitals" = "#D55E00"
    )) +
    scale_y_continuous(limits = c(0, 1.03), expand = expansion(mult = c(0, .02))) +
    labs(x = NULL, y = "Finite-population proportion", fill = "Hospital stratum") +
    base_theme

  save_plot_set(p1, outdir, "nav_fig1_population_structure", 8.4, 4.8)

  d2 <- obs[strategy == "N3" & hospital_sample_size == max(hospital_sample_size)]
  d2[, estimand := factor(
    estimand,
    levels = c("hard", "easy", "national"),
    labels = c("Harder subgroup", "Easier subgroup", "National")
  )]

  p2 <- ggplot(d2, aes(y = estimand)) +
    geom_segment(
      aes(x = observation_parameter, xend = target_parameter, yend = estimand),
      linewidth = 1.3,
      colour = "grey65"
    ) +
    geom_point(
      aes(x = target_parameter, shape = "Target parameter"),
      size = 2.9,
      colour = sci_palette["blue"]
    ) +
    geom_point(
      aes(x = observation_parameter, shape = "Enriched observation parameter"),
      size = 2.9,
      colour = sci_palette["vermillion"]
    ) +
    geom_vline(xintercept = config$target$adequacy_threshold, linetype = 2) +
    geom_text(
      aes(
        x = pmin(target_parameter, observation_parameter) - .006,
        label = sprintf("RTD %+.3f", reference_target_discrepancy)
      ),
      hjust = 1,
      size = 3.6,
      fontface = "bold"
    ) +
    coord_cartesian(xlim = c(.66, .98)) +
    labs(x = "Sensitivity", y = NULL, shape = NULL) +
    base_theme

  save_plot_set(p2, outdir, "nav_fig2_target_observation_parameters", 8.2, 4.8)

  perf[, strategy_label := factor(labs[strategy], levels = labs)]
  perf[, estimand_label := factor(
    estimand,
    levels = c("national", "easy", "hard"),
    labels = c("National", "Easier subgroup", "Harder subgroup")
  )]

  p3 <- ggplot(
    perf,
    aes(
      hospital_sample_size,
      bias,
      colour = strategy_label,
      linetype = strategy_label,
      shape = strategy_label
    )
  ) +
    geom_hline(yintercept = c(-.03, .03), linetype = 3, colour = "grey55") +
    geom_hline(yintercept = 0) +
    geom_line(linewidth = .8) +
    geom_point(size = 2.3) +
    facet_wrap(~estimand_label, ncol = 1, scales = "free_y") +
    scale_colour_manual(values = strategy_palette_label) +
    labs(x = "Hospitals selected, m", y = "Bias in sensitivity", colour = NULL, linetype = NULL, shape = NULL) +
    base_theme

  save_plot_set(p3, outdir, "nav_fig3_bias", 7.2, 8.6)

  p4 <- ggplot(
    perf,
    aes(
      hospital_sample_size,
      rmse,
      colour = strategy_label,
      linetype = strategy_label,
      shape = strategy_label
    )
  ) +
    geom_line(linewidth = .8) +
    geom_point(size = 2.3) +
    facet_wrap(~estimand_label, nrow = 1, scales = "free_y") +
    scale_colour_manual(values = strategy_palette_label) +
    labs(x = "Hospitals selected, m", y = "RMSE of sensitivity", colour = NULL, linetype = NULL, shape = NULL) +
    base_theme

  save_plot_set(p4, outdir, "nav_fig4_rmse", 13.8, 4.6)

  p5 <- ggplot(
    perf[estimand == "national" & strategy %in% c("N4", "N5")],
    aes(
      hospital_sample_size,
      target_coverage,
      colour = strategy_label,
      linetype = strategy_label,
      shape = strategy_label
    )
  ) +
    annotate("rect", xmin = -Inf, xmax = Inf, ymin = .925, ymax = .975, alpha = .15) +
    geom_hline(yintercept = .95, linetype = 2) +
    geom_line(linewidth = .8) +
    geom_point(size = 2.3) +
    coord_cartesian(ylim = c(.78, .985)) +
    scale_colour_manual(values = strategy_palette_label) +
    labs(x = "Hospitals selected, m", y = "Empirical coverage of target sensitivity", colour = NULL, linetype = NULL, shape = NULL) +
    base_theme

  save_plot_set(p5, outdir, "nav_fig5_coverage_n4_n5", 8.3, 4.8)

  p6 <- ggplot(
    counts[strategy %in% c("N2", "N4")],
    aes(
      hospital_sample_size,
      median,
      colour = factor(strategy),
      shape = factor(strategy)
    )
  ) +
    geom_errorbar(aes(ymin = p05, ymax = p95), width = 3, linewidth = .8) +
    geom_point(size = 3) +
    scale_colour_manual(
      values = strategy_palette_id[c("N2", "N4")],
      labels = labs[c("N2", "N4")],
      name = NULL
    ) +
    scale_shape_discrete(labels = labs[c("N2", "N4")]) +
    labs(x = "Hospitals selected, m", y = "Hard-subgroup positive cases (median; P5-P95)", shape = NULL) +
    base_theme

  save_plot_set(p6, outdir, "nav_fig6_hard_positive_yield", 9.2, 5.2)

  # -------------------------------------------------------------------------
  # Figure 7. Evidential status heatmap
  # -------------------------------------------------------------------------

  heat <- perf[, .(
    hospital_sample_size,
    strategy,
    estimand,
    status = ifelse(full_evidential_pass, "Pass", "Insufficient")
  )]

  heat[, estimand_label := estimand_label_map[as.character(estimand)]]
  heat[, row := paste0(strategy, " - ", estimand_label)]
  heat[, row := factor(row, levels = rev(row_levels_nav))]
  heat[, status := factor(status, levels = c("Insufficient", "Pass"))]

  p7 <- ggplot(
    heat,
    aes(
      x = factor(hospital_sample_size),
      y = row,
      fill = status
    )
  ) +
    geom_tile(colour = "white", linewidth = 0.85, height = 0.96) +
    geom_text(
      aes(label = status),
      size = 4.15,
      fontface = "bold",
      colour = "grey8"
    ) +
    scale_fill_manual(
      values = evidential_fill,
      breaks = c("Insufficient", "Pass"),
      drop = FALSE
    ) +
    scale_x_discrete(expand = c(0, 0)) +
    labs(
      x = "Hospitals selected, m",
      y = NULL,
      fill = NULL
    ) +
    base_theme +
    theme(
      panel.grid = element_blank(),
      axis.text.x = element_text(size = 12, face = "bold"),
      axis.text.y = element_text(size = 11.5, face = "bold", margin = margin(r = 8)),
      axis.title.x = element_text(size = 15, face = "bold"),
      legend.position = "bottom",
      legend.text = element_text(size = 12, face = "bold"),
      legend.key.height = unit(0.75, "cm"),
      legend.key.width = unit(0.75, "cm"),
      plot.margin = margin(8, 12, 8, 8)
    )

  save_plot_set(p7, outdir, "nav_fig7_evidential_status", 8.4, 7.0)


  # -------------------------------------------------------------------------
  # Figure 8. Formal TAC decision frequencies
  # -------------------------------------------------------------------------

  d8 <- tac[
    hospital_sample_size == max(hospital_sample_size) &
      estimand %in% c("national", "hard")
  ]

  d8[, estimand := factor(
    estimand,
    levels = c("national", "hard"),
    labels = c("National sensitivity", "Hard-subgroup sensitivity")
  )]

  d8[, formal_tac := factor(
    formal_tac,
    levels = c("Adequate", "Inconclusive", "Not adequate", "Evidentially insufficient")
  )]

  d8[, label_value := ifelse(
    proportion >= 0.035,
    scales::percent(proportion, accuracy = 0.1),
    ""
  )]

  p8 <- ggplot(d8, aes(strategy, proportion, fill = formal_tac)) +
    geom_col(width = .72, colour = "white", linewidth = .35) +
    geom_text(
      aes(label = label_value),
      position = position_stack(vjust = 0.5),
      size = 3.4,
      fontface = "bold",
      colour = "grey8"
    ) +
    facet_wrap(~estimand, nrow = 1) +
    scale_y_continuous(
      labels = scales::percent_format(accuracy = 0.1),
      expand = expansion(mult = c(0, .025))
    ) +
    scale_fill_manual(values = tac_palette, drop = FALSE) +
    labs(
      x = NULL,
      y = "Decision frequency",
      fill = NULL
    ) +
    base_theme +
    theme(
      panel.grid.major.x = element_blank(),
      axis.text.x = element_text(size = 11.5, face = "bold"),
      axis.text.y = element_text(size = 10.5, face = "bold"),
      strip.text = element_text(size = 12.5, face = "bold"),
      legend.position = "bottom",
      legend.text = element_text(size = 10.8, face = "bold"),
      plot.margin = margin(10, 16, 12, 16)
    )

  save_plot_set(p8, outdir, "nav_fig8_tac", 11.5, 5.2)

  n3 <- raw[
    strategy == "N3" & estimand == "national",
    .(
      lower = quantile(estimate, .025),
      median = median(estimate),
      upper = quantile(estimate, .975)
    ),
    by = hospital_sample_size
  ]

  n4 <- raw[
    strategy == "N4" & estimand == "national",
    .(
      lower = quantile(estimate, .025),
      median = median(estimate),
      upper = quantile(estimate, .975)
    ),
    by = hospital_sample_size
  ]

  par <- obs[strategy == "N3" & estimand == "national"][1]

  ref_lines <- data.table(
    y = c(
      par$observation_parameter,
      par$target_parameter,
      config$target$adequacy_threshold
    ),
    reference = factor(
      c("Enriched observation parameter", "Target parameter", "Adequacy threshold"),
      levels = c("Enriched observation parameter", "Target parameter", "Adequacy threshold")
    )
  )

  y_rng <- range(c(n3$lower, n3$upper, n4$lower, n4$upper, ref_lines$y), na.rm = TRUE)
  y_pad <- diff(y_rng) * .10
  if (!is.finite(y_pad) || y_pad == 0) y_pad <- .02

  xmax <- max(c(n3$hospital_sample_size, n4$hospital_sample_size), na.rm = TRUE)

  p9 <- ggplot() +
    geom_ribbon(
      data = n3,
      aes(
        x = hospital_sample_size,
        ymin = lower,
        ymax = upper,
        fill = "Central 95% of N3 estimates"
      ),
      alpha = .24
    ) +
    geom_ribbon(
      data = n4,
      aes(
        x = hospital_sample_size,
        ymin = lower,
        ymax = upper,
        fill = "Central 95% of N4 estimates"
      ),
      alpha = .22
    ) +
    geom_line(
      data = n3,
      aes(
        x = hospital_sample_size,
        y = median,
        colour = "Median N3 estimate",
        linetype = "Median N3 estimate"
      ),
      linewidth = .95
    ) +
    geom_point(
      data = n3,
      aes(x = hospital_sample_size, y = median),
      colour = sci_palette["blue"],
      size = 2.6,
      show.legend = FALSE
    ) +
    geom_line(
      data = n4,
      aes(
        x = hospital_sample_size,
        y = median,
        colour = "Median N4 estimate",
        linetype = "Median N4 estimate"
      ),
      linewidth = .95
    ) +
    geom_point(
      data = n4,
      aes(x = hospital_sample_size, y = median),
      colour = sci_palette["vermillion"],
      size = 2.6,
      show.legend = FALSE
    ) +
    geom_hline(
      aes(
        yintercept = par$observation_parameter,
        colour = "Enriched reference parameter",
        linetype = "Enriched reference parameter"
      ),
      linewidth = .9
    ) +
    geom_hline(
      aes(
        yintercept = par$target_parameter,
        colour = "Target parameter",
        linetype = "Target parameter"
      ),
      linewidth = .9
    ) +
    geom_hline(
      aes(
        yintercept = config$target$adequacy_threshold,
        colour = "TAC threshold 0.85",
        linetype = "TAC threshold 0.85"
      ),
      linewidth = .9
    ) +
    annotate(
      "text",
      x = xmax,
      y = par$target_parameter - .006,
      label = sprintf("Target parameter = %.3f", par$target_parameter),
      hjust = 1,
      size = 3.9,
      fontface = "bold",
      colour = sci_palette["blue"]
    ) +
    annotate(
      "text",
      x = xmax,
      y = config$target$adequacy_threshold + .004,
      label = sprintf("TAC threshold = %.2f", config$target$adequacy_threshold),
      hjust = 1,
      size = 3.9,
      fontface = "bold",
      colour = "grey20"
    ) +
    annotate(
      "text",
      x = xmax,
      y = par$observation_parameter + .004,
      label = sprintf("Enriched reference parameter = %.3f", par$observation_parameter),
      hjust = 1,
      size = 3.9,
      fontface = "bold",
      colour = sci_palette["vermillion"]
    ) +
    annotate(
      "label",
      x = min(n3$hospital_sample_size, na.rm = TRUE),
      y = y_rng[2] + y_pad * .45,
      label = sprintf("RTD = %+.3f", par$reference_target_discrepancy),
      hjust = 0,
      size = 3.9,
      fontface = "bold",
      fill = "white"
    ) +
    coord_cartesian(ylim = c(y_rng[1] - y_pad, y_rng[2] + y_pad)) +
    scale_fill_manual(
      name = NULL,
      breaks = c("Central 95% of N3 estimates", "Central 95% of N4 estimates"),
      values = c(
        "Central 95% of N3 estimates" = "#CFE8F3",
        "Central 95% of N4 estimates" = "#F7D7C8"
      )
    ) +
    scale_colour_manual(
      name = NULL,
      breaks = c(
        "Median N3 estimate",
        "Median N4 estimate",
        "Enriched reference parameter",
        "Target parameter"
      ),
      values = c(
        "Median N3 estimate" = "#0072B2",
        "Median N4 estimate" = "#D55E00",
        "Enriched reference parameter" = "#D55E00",
        "Target parameter" = "#0072B2",
        "TAC threshold 0.85" = "grey20"
      )
    ) +
    scale_linetype_manual(
      name = NULL,
      breaks = c(
        "Median N3 estimate",
        "Median N4 estimate",
        "Enriched reference parameter",
        "Target parameter"
      ),
      values = c(
        "Median N3 estimate" = 1,
        "Median N4 estimate" = 1,
        "Enriched reference parameter" = 3,
        "Target parameter" = 2,
        "TAC threshold 0.85" = 1
      )
    ) +
    guides(
      fill = guide_legend(order = 1),
      colour = guide_legend(
        order = 2,
        override.aes = list(
          shape = c(16, 16, NA, NA),
          linetype = c(1, 1, 3, 2),
          linewidth = c(.95, .95, .9, .9)
        )
      ),
      linetype = "none"
    ) +
    labs(
      x = "Hospitals selected, m",
      y = "National sensitivity"
    ) +
    base_theme +
    theme(
      legend.position = "bottom",
      legend.box = "vertical",
      legend.text = element_text(size = 10.0, face = "bold"),
      legend.key.width = grid::unit(0.9, "cm"),
      legend.spacing.y = grid::unit(0.10, "cm"),
      plot.margin = margin(12, 22, 18, 24)
    )

  save_plot_set(p9, outdir, "nav_fig9_large_wrong_orp", 10.2, 6.3)
}
