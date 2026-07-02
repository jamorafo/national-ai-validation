# Fixed-source ETC post-processing in R — version 3
#
# Additive post-processing only:
#   - reads results/summary/performance_summary_R.csv
#   - does not read replication-level data
#   - does not rerun or alter the Monte Carlo experiment
#   - produces three separate publication figures
#
# IMPORTANT:
# theta_S = 0.94 is an ASSUMED certified source sensitivity, not an estimate
# generated in this simulation. Source-side uncertainty is excluded.

required_packages <- c("data.table", "ggplot2", "scales", "svglite")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop(
    "Missing R packages: ", paste(missing_packages, collapse = ", "),
    "\nInstall them with:\n",
    "Rscript -e \"install.packages(c('data.table','ggplot2','scales','svglite'), ",
    "repos='https://cloud.r-project.org')\"",
    call. = FALSE
  )
}

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(scales)
})

# -----------------------------------------------------------------------------
# Command-line arguments
# -----------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
overwrite <- "--overwrite" %in% args
args <- args[args != "--overwrite"]

project <- if (length(args)) args[[1]] else "."
project <- normalizePath(project, winslash = "/", mustWork = TRUE)

# -----------------------------------------------------------------------------
# Fixed constants
# -----------------------------------------------------------------------------
theta_S <- 0.94
epsilon_T <- 0.04
tau <- 0.85
preservation_floor <- theta_S - epsilon_T
z_value <- 1.96
sample_sizes <- c(40L, 80L, 120L, 160L)
tolerance <- 1e-3

expected <- data.table(
  hospital_sample_size = sample_sizes,
  mean_estimate = c(0.8775750344, 0.8781872748, 0.8783508638, 0.8782993064),
  mean_estimated_se = c(0.0205323803, 0.0134648560, 0.0100372099, 0.0077843068),
  target_lo = c(0.8313306236, 0.8492422226, 0.8572688706, 0.8622000666),
  target_hi = c(0.9124753942, 0.9022148589, 0.8966941999, 0.8927516249),
  gap_hat = c(0.0624249656, 0.0618127252, 0.0616491362, 0.0617006936),
  gap_lo = c(0.0275246058, 0.0377851411, 0.0433058001, 0.0472483751),
  gap_hi = c(0.1086693764, 0.0907577774, 0.0827311294, 0.0777999334),
  tac = c("Inconclusive", "Inconclusive", "Adequate", "Adequate"),
  etc = c("Inconclusive", "Inconclusive", "Not transported", "Not transported")
)

# -----------------------------------------------------------------------------
# Read and validate the frozen summary output
# -----------------------------------------------------------------------------
summary_file <- file.path(
  project, "results", "summary", "performance_summary_R.csv"
)
if (!file.exists(summary_file)) {
  stop(
    "Missing R summary file: ", summary_file,
    ". Run R/run_all.R before generating fixed-source ETC figures.",
    call. = FALSE
  )
}

message("Fixed-source ETC input: ", summary_file)
summary_data <- fread(summary_file)

required_columns <- c(
  "hospital_sample_size", "strategy", "estimand",
  "mean_estimate", "mean_estimated_se", "mean_half_width"
)
missing_columns <- setdiff(required_columns, names(summary_data))
if (length(missing_columns)) {
  stop(
    basename(summary_file), " is missing required columns: ",
    paste(missing_columns, collapse = ", "),
    call. = FALSE
  )
}

plot_data <- summary_data[
  strategy == "N4" &
    estimand == "national" &
    hospital_sample_size %in% sample_sizes
]
setorder(plot_data, hospital_sample_size)

if (!identical(as.integer(plot_data$hospital_sample_size), sample_sizes)) {
  stop(
    "Expected exactly one N4 national row for each m in {40, 80, 120, 160}.",
    call. = FALSE
  )
}

if (anyNA(plot_data[, .(
  mean_estimate, mean_estimated_se, mean_half_width
)])) {
  stop("Required N4 national summary values contain missing data.", call. = FALSE)
}

if (any(plot_data$mean_estimate <= 0 | plot_data$mean_estimate >= 1)) {
  stop("Sensitivity estimates must lie strictly between zero and one.", call. = FALSE)
}
if (any(plot_data$mean_estimated_se <= 0)) {
  stop("Estimated standard errors must be positive.", call. = FALSE)
}

# Reconstruct the study's logit-transformed 95% target intervals.
plot_data[, logit_se :=
  mean_estimated_se / (mean_estimate * (1 - mean_estimate))]
plot_data[, target_lo :=
  plogis(qlogis(mean_estimate) - z_value * logit_se)]
plot_data[, target_hi :=
  plogis(qlogis(mean_estimate) + z_value * logit_se)]
plot_data[, reproduced_half_width := (target_hi - target_lo) / 2]

if (any(
  round(plot_data$reproduced_half_width, 4) !=
    round(plot_data$mean_half_width, 4)
)) {
  failed <- plot_data[
    round(reproduced_half_width, 4) != round(mean_half_width, 4),
    .(hospital_sample_size, reproduced_half_width, mean_half_width)
  ]
  stop(
    "Reconstructed intervals do not match stored half-widths:\n",
    paste(capture.output(print(failed)), collapse = "\n"),
    call. = FALSE
  )
}

# Fixed-source gap and decisions.
plot_data[, gap_hat := theta_S - mean_estimate]
plot_data[, gap_lo := theta_S - target_hi]
plot_data[, gap_hi := theta_S - target_lo]

plot_data[, tac := fifelse(
  target_lo >= tau,
  "Adequate",
  fifelse(target_hi < tau, "Not adequate", "Inconclusive")
)]
plot_data[, etc := fifelse(
  gap_hi <= epsilon_T,
  "Transported",
  fifelse(gap_lo > epsilon_T, "Not transported", "Inconclusive")
)]

# Coordinates for the decision plane.
plot_data[, adequacy_margin := mean_estimate - tau]
plot_data[, transportability_margin :=
  mean_estimate - preservation_floor]
plot_data[, adequacy_lo := target_lo - tau]
plot_data[, adequacy_hi := target_hi - tau]
plot_data[, transportability_lo := target_lo - preservation_floor]
plot_data[, transportability_hi := target_hi - preservation_floor]

plot_data[, m_factor := factor(
  hospital_sample_size,
  levels = sample_sizes
)]
plot_data[, point_label := paste0("m = ", hospital_sample_size)]

# Validate against the expected deterministic values.
numeric_checks <- c(
  "mean_estimate", "mean_estimated_se", "target_lo", "target_hi",
  "gap_hat", "gap_lo", "gap_hi"
)
for (column_name in numeric_checks) {
  discrepancy <- max(
    abs(plot_data[[column_name]] - expected[[column_name]])
  )
  if (discrepancy > tolerance) {
    stop(
      sprintf(
        "Expected-value validation failed for %s; max discrepancy = %.6f.",
        column_name, discrepancy
      ),
      call. = FALSE
    )
  }
}
if (
  !identical(plot_data$tac, expected$tac) ||
    !identical(plot_data$etc, expected$etc)
) {
  stop("TAC/ETC decision validation failed.", call. = FALSE)
}

# -----------------------------------------------------------------------------
# Publication styling
# -----------------------------------------------------------------------------
palette_values <- c(
  "40" = "#0072B2",
  "80" = "#E69F00",
  "120" = "#009E73",
  "160" = "#D55E00"
)
shape_values <- c("40" = 21, "80" = 22, "120" = 24, "160" = 23)
linetype_values <- c(
  "40" = "solid",
  "80" = "dashed",
  "120" = "dotdash",
  "160" = "twodash"
)

publication_theme <- theme_minimal(base_size = 10.5, base_family = "sans") +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = "grey88", linewidth = 0.35),
    axis.title = element_text(colour = "grey10"),
    axis.text = element_text(colour = "grey15"),
    plot.title = element_text(
      face = "bold", hjust = 0, size = 12.5, colour = "grey8"
    ),
    plot.subtitle = element_text(
      hjust = 0, size = 9.5, colour = "grey25",
      margin = margin(b = 8)
    ),
    plot.caption = element_text(
      hjust = 0, size = 8.2, colour = "grey30",
      margin = margin(t = 8)
    ),
    plot.margin = margin(8, 12, 8, 8),
    legend.position = "none"
  )

publication_theme <- publication_theme + theme(plot.title = element_blank(), plot.subtitle = element_blank())
signed_2 <- function(x) {
  ifelse(abs(x) < 5e-12, "0.00", sprintf("%+.2f", x))
}

# -----------------------------------------------------------------------------
# Figure 1: decision plane
# -----------------------------------------------------------------------------
x_min <- min(-0.025, min(plot_data$adequacy_lo) - 0.006)
x_max <- max(0.070, max(plot_data$adequacy_hi) + 0.006)
y_min <- min(-0.075, min(plot_data$transportability_lo) - 0.006)
y_max <- max(0.030, max(plot_data$transportability_hi) + 0.006)

quadrants <- data.table(
  xmin = c(x_min, 0, x_min, 0),
  xmax = c(0, x_max, 0, x_max),
  ymin = c(0, 0, y_min, y_min),
  ymax = c(y_max, y_max, 0, 0),
  region = factor(
    c(
      "Transportable, not adequate",
      "Adequate + transportable",
      "Neither",
      "Adequate, not transportable"
    ),
    levels = c(
      "Transportable, not adequate",
      "Adequate + transportable",
      "Neither",
      "Adequate, not transportable"
    )
  )
)
quadrant_fill <- c(
  "Transportable, not adequate" = "#E8F1FA",
  "Adequate + transportable" = "#EAF4EA",
  "Neither" = "#F8EAEA",
  "Adequate, not transportable" = "#FBF3DF"
)

# Label offsets are visual only; the points themselves remain at exact values.
label_offsets <- data.table(
  hospital_sample_size = sample_sizes,
  dx = c(-0.011, 0.004, 0.004, 0.004),
  dy = c(0.006, -0.004, 0.004, 0.009)
)
decision_data <- merge(
  plot_data, label_offsets,
  by = "hospital_sample_size", sort = FALSE
)
setorder(decision_data, hospital_sample_size)

decision_plot <- ggplot() +
  geom_rect(
    data = quadrants,
    aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = region),
    alpha = 0.50,
    colour = NA,
    inherit.aes = FALSE
  ) +
  geom_hline(yintercept = 0, linewidth = 0.55, colour = "grey10") +
  geom_vline(xintercept = 0, linewidth = 0.55, colour = "grey10") +
  geom_segment(
    data = decision_data,
    aes(
      x = adequacy_lo,
      y = transportability_lo,
      xend = adequacy_hi,
      yend = transportability_hi,
      colour = m_factor,
      linetype = m_factor
    ),
    linewidth = 1.05,
    lineend = "round"
  ) +
  geom_point(
    data = decision_data,
    aes(
      x = adequacy_margin,
      y = transportability_margin,
      colour = m_factor,
      shape = m_factor
    ),
    size = 3.2,
    stroke = 1.1,
    fill = "white"
  ) +
  geom_text(
    data = decision_data,
    aes(
      x = adequacy_margin + dx,
      y = transportability_margin + dy,
      label = point_label
    ),
    size = 3.1,
    colour = "grey12"
  ) +
  annotate(
    "text",
    x = x_min + 0.30 * (0 - x_min),
    y = y_max - 0.010,
    label = "Transportable,\nnot adequate",
    fontface = "bold", size = 3.7
  ) +
  annotate(
    "text",
    x = 0.58 * x_max,
    y = y_max - 0.010,
    label = "Adequate +\ntransportable",
    fontface = "bold", size = 3.7
  ) +
  annotate(
    "text",
    x = x_min + 0.27 * (0 - x_min),
    y = y_min + 0.010,
    label = "Neither",
    fontface = "bold", size = 3.7
  ) +
  annotate(
    "text",
    x = 0.58 * x_max,
    y = y_min + 0.010,
    label = "Adequate,\nnot transportable",
    fontface = "bold", size = 3.7
  ) +
  scale_fill_manual(values = quadrant_fill, guide = "none") +
  scale_colour_manual(values = palette_values, guide = "none") +
  scale_shape_manual(values = shape_values, guide = "none") +
  scale_linetype_manual(values = linetype_values, guide = "none") +
  scale_x_continuous(
    limits = c(x_min, x_max),
    breaks = seq(-0.02, 0.06, by = 0.02),
    labels = signed_2,
    expand = expansion(mult = 0)
  ) +
  scale_y_continuous(
    limits = c(y_min, y_max),
    breaks = seq(-0.06, 0.02, by = 0.02),
    labels = signed_2,
    expand = expansion(mult = 0)
  ) +
  coord_fixed(ratio = 1, clip = "off") +
  labs(
    title = "Target adequacy and preservation of certified source performance",
    subtitle = paste0(
      "Fixed source sensitivity theta_S = 0.94; epsilon_T = 0.04; ",
      "tau = 0.85. Diagonal segments are transformed 95% target intervals."
    ),
    x = expression("Target-adequacy margin: " * hat(theta)[T] - tau),
    y = expression(
      "Transportability margin: " *
        hat(theta)[T] - (theta[S] - epsilon[T])
    ),
    caption = paste0(
      "Each symbol is an N4 national point estimate. Because theta_S is fixed, ",
      "both margins are functions of the same target estimate, so each ",
      "confidence interval maps to a diagonal segment. Formal TAC and ETC ",
      "decisions use interval bounds, not quadrant position alone."
    )
  ) +
  publication_theme

# -----------------------------------------------------------------------------
# Figure 2: direct target estimates against both thresholds
# -----------------------------------------------------------------------------
threshold_data <- data.table(
  y = c(tau, preservation_floor),
  threshold = factor(
    c("Target adequacy threshold", "Source-preservation floor"),
    levels = c("Target adequacy threshold", "Source-preservation floor")
  )
)

target_plot <- ggplot(
  plot_data,
  aes(x = hospital_sample_size, y = mean_estimate)
) +
  geom_hline(
    data = threshold_data,
    aes(yintercept = y, linetype = threshold),
    colour = "grey25",
    linewidth = 0.75
  ) +
  geom_errorbar(
    aes(ymin = target_lo, ymax = target_hi, colour = m_factor),
    width = 4.5,
    linewidth = 0.85
  ) +
  geom_point(
    aes(colour = m_factor, shape = m_factor),
    size = 3.2,
    stroke = 1.1,
    fill = "white"
  ) +
  geom_text(
    aes(
      y = target_hi + c(0.006, 0.006, 0.006, 0.006),
      label = paste0("m = ", hospital_sample_size)
    ),
    size = 3.0,
    colour = "grey15"
  ) +
  scale_colour_manual(values = palette_values, guide = "none") +
  scale_shape_manual(values = shape_values, guide = "none") +
  scale_linetype_manual(
    values = c(
      "Target adequacy threshold" = "solid",
      "Source-preservation floor" = "dashed"
    ),
    name = NULL
  ) +
  scale_x_continuous(
    breaks = sample_sizes,
    limits = c(30, 170)
  ) +
  scale_y_continuous(
    limits = c(0.82, 0.92),
    breaks = seq(0.82, 0.92, by = 0.02),
    labels = label_number(accuracy = 0.01)
  ) +
  labs(
    title = "National target sensitivity under the compatible enriched strategy",
    subtitle = paste0(
      "Points are N4 estimates with reconstructed logit 95% intervals. ",
      "The fixed source value theta_S = 0.94 implies a preservation floor of 0.90."
    ),
    x = "Hospitals selected, m",
    y = expression("National target sensitivity, " * hat(theta)[T]),
    caption = paste0(
      "At m = 120 and m = 160, the target interval lies above tau = 0.85 ",
      "but below the source-preservation floor theta_S - epsilon_T = 0.90: ",
      "adequate, but not transported under the fixed-source illustration."
    )
  ) +
  publication_theme +
  theme(
    legend.position = "bottom",
    legend.justification = "left",
    legend.box = "horizontal"
  )


# -----------------------------------------------------------------------------
# Figure 3: four-region decision plane for TAC and ETC non-equivalence
# -----------------------------------------------------------------------------
# This figure uses the N4 target evidence at m = 160 and two hypothetical
# certified-source certificates. It is an illustrative addendum: it does not
# rerun the simulation and does not change the main Monte Carlo evidence.
#
# Horizontal axis: target performance, theta_T, compared with tau.
# Vertical axis: source-to-target degradation gap, Delta_{S->T}, compared with
# epsilon_T. Error bars show marginal 95% intervals, not a joint confidence
# region.

div_target <- summary_data[
  strategy == "N4" &
    hospital_sample_size == 160L &
    estimand %in% c("national", "hard")
]

if (nrow(div_target) != 2L) {
  stop(
    "Expected exactly two N4 rows at m = 160 for national and hard estimands.",
    call. = FALSE
  )
}

div_target[, target_logit_se :=
  mean_estimated_se / (mean_estimate * (1 - mean_estimate))]
div_target[, target_lcl :=
  plogis(qlogis(mean_estimate) - z_value * target_logit_se)]
div_target[, target_ucl :=
  plogis(qlogis(mean_estimate) + z_value * target_logit_se)]

hyp_source <- data.table(
  estimand = c("national", "hard"),
  source_est = c(0.9400, 0.7800),
  source_se = c(0.0102, 0.0102),
  source_certificate = c(
    "Hypothetical national source certificate",
    "Hypothetical hard-subgroup source certificate"
  )
)

div_data <- merge(
  div_target,
  hyp_source,
  by = "estimand",
  all = FALSE,
  sort = FALSE
)

epsilon_div <- 0.05

div_data[, delta := source_est - mean_estimate]
div_data[, delta_se := sqrt(source_se^2 + mean_estimated_se^2)]
div_data[, delta_lcl := delta - z_value * delta_se]
div_data[, delta_ucl := delta + z_value * delta_se]

div_data[, tac_decision := fifelse(
  target_lcl >= tau,
  "Adequate",
  fifelse(target_ucl < tau, "Not adequate", "Inconclusive")
)]

div_data[, etc_decision := fifelse(
  delta_ucl <= epsilon_div,
  "Transported",
  fifelse(delta_lcl > epsilon_div, "Not transported", "Inconclusive")
)]

div_data[, point_label := fifelse(
  estimand == "national",
  "National\nTAC adequate\nETC inconclusive",
  "Hard subgroup\nTAC not adequate\nETC inconclusive"
)]

div_data[, label_x := fifelse(
  estimand == "national",
  mean_estimate + 0.009,
  mean_estimate + 0.010
)]
div_data[, label_y := fifelse(
  estimand == "national",
  delta + 0.012,
  delta - 0.017
)]

div_data[, point_colour := fifelse(
  estimand == "national",
  "National",
  "Hard subgroup"
)]

x_min_div <- min(0.68, min(div_data$target_lcl, na.rm = TRUE) - 0.010)
x_max_div <- max(0.94, max(div_data$target_ucl, na.rm = TRUE) + 0.014)
y_min_div <- min(-0.005, min(div_data$delta_lcl, na.rm = TRUE) - 0.008)
y_max_div <- max(0.105, max(div_data$delta_ucl, na.rm = TRUE) + 0.010)

decision_regions <- data.table(
  xmin = c(x_min_div, tau, x_min_div, tau),
  xmax = c(tau, x_max_div, tau, x_max_div),
  ymin = c(y_min_div, y_min_div, epsilon_div, epsilon_div),
  ymax = c(epsilon_div, epsilon_div, y_max_div, y_max_div),
  region = factor(
    c(
      "Not adequate + transported",
      "Adequate + transported",
      "Not adequate + not transported",
      "Adequate + not transported"
    ),
    levels = c(
      "Not adequate + transported",
      "Adequate + transported",
      "Not adequate + not transported",
      "Adequate + not transported"
    )
  ),
  label = c(
    "Not adequate\n+ transported",
    "Adequate\n+ transported",
    "Not adequate\n+ not transported",
    "Adequate\n+ not transported"
  )
)

decision_regions[, `:=`(
  label_x = c(0.775, tau + 0.03, x_min_div + 0.062, tau + 0.03),
  label_y = c(0.01, 0.01, 0.09, 0.09),
  label_hjust = c(0, 0, 0, 0),
  label_colour = c("#567FA6", "#6FA06D", "#B26B6B", "#B08D3B")
)]

region_fill <- c(
  "Not adequate + transported" = "#E8F1FA",
  "Adequate + transported" = "#EAF4EA",
  "Not adequate + not transported" = "#F8EAEA",
  "Adequate + not transported" = "#FBF3DF"
)

case_colours <- c(
  "National" = "#0072B2",
  "Hard subgroup" = "#D55E00"
)

divergence_plot <- ggplot() +
  geom_rect(
    data = decision_regions,
    aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = region),
    alpha = 0.42,
    colour = NA,
    inherit.aes = FALSE
  ) +
  geom_text(
    data = decision_regions,
    aes(
      x = label_x,
      y = label_y,
      label = label,
      hjust = label_hjust,
      colour = I(label_colour)
    ),
    size = 4.35,
    fontface = "bold",
    lineheight = 0.92,
    inherit.aes = FALSE,
    show.legend = FALSE
  ) +
  geom_vline(
    xintercept = tau,
    linewidth = 0.70,
    linetype = "dashed",
    colour = "grey15"
  ) +
  geom_hline(
    yintercept = epsilon_div,
    linewidth = 0.70,
    linetype = "dashed",
    colour = "grey15"
  ) +
  geom_segment(
    data = div_data,
    aes(
      x = target_lcl,
      xend = target_ucl,
      y = delta,
      yend = delta,
      colour = point_colour
    ),
    linewidth = 1.0,
    lineend = "round",
    inherit.aes = FALSE
  ) +
  geom_segment(
    data = div_data,
    aes(
      x = mean_estimate,
      xend = mean_estimate,
      y = delta_lcl,
      yend = delta_ucl,
      colour = point_colour
    ),
    linewidth = 1.0,
    lineend = "round",
    inherit.aes = FALSE
  ) +
  geom_point(
    data = div_data,
    aes(x = mean_estimate, y = delta, colour = point_colour),
    size = 3.5,
    stroke = 1.0,
    inherit.aes = FALSE
  ) +
  geom_label(
    data = div_data,
    aes(x = label_x, y = label_y, label = point_label, colour = point_colour),
    hjust = 0,
    size = 2.75,
    fontface = "bold",
    fill = "white",
    linewidth = 0.18,
    label.padding = grid::unit(0.14, "lines"),
    lineheight = 0.88,
    inherit.aes = FALSE,
    show.legend = FALSE
  ) +
  annotate(
    "text",
    x = tau + 0.004,
    y = y_min_div + 0.003,
    label = expression(tau == 0.85),
    hjust = 0,
    vjust = 0,
    size = 3.1,
    fontface = "bold",
    colour = "grey15"
  ) +
  annotate(
    "text",
    x = x_min_div + 0.005,
    y = epsilon_div + 0.004,
    label = expression(epsilon[T] == 0.05),
    hjust = 0,
    vjust = 0,
    size = 3.1,
    fontface = "bold",
    colour = "grey15"
  ) +
  scale_fill_manual(values = region_fill, guide = "none") +
  scale_colour_manual(values = case_colours, guide = "none") +
  scale_x_continuous(
    limits = c(x_min_div, x_max_div),
    breaks = seq(0.70, 0.92, by = 0.05),
    labels = label_number(accuracy = 0.01),
    expand = expansion(mult = 0)
  ) +
  scale_y_continuous(
    limits = c(y_min_div, y_max_div),
    breaks = seq(0.00, 0.10, by = 0.02),
    labels = label_number(accuracy = 0.01),
    expand = expansion(mult = 0)
  ) +
  coord_cartesian(clip = "off") +
  labs(
    x = expression("Target performance, " * hat(theta)[T]),
    y = expression("Source-to-target degradation gap, " * hat(Delta)[S %->% T])
    ) +
  publication_theme +
  theme(
    legend.position = "none",
    axis.title = element_text(face = "bold", colour = "grey10", size = 11.6),
    axis.text = element_text(face = "bold", colour = "grey18", size = 9.8),
    plot.caption = element_text(
      hjust = 0,
      size = 8.2,
      colour = "grey25",
      margin = margin(t = 8)
    ),
    plot.margin = margin(8, 26, 10, 8)
  )

# -----------------------------------------------------------------------------
# Robust graphics output
# -----------------------------------------------------------------------------
output_dir <- file.path(project, "figures", "r_publication")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

prepare_file <- function(path) {
  if (!file.exists(path)) return(invisible(TRUE))

  if (!overwrite) {
    stop(
      "Output already exists. Rerun with --overwrite or remove it:\n",
      path,
      call. = FALSE
    )
  }

  removed <- suppressWarnings(file.remove(path))
  if (!isTRUE(removed) || file.exists(path)) {
    stop(
      "Cannot replace output file:\n", path, "\n",
      "Close the file in Adobe Reader, Edge, or another viewer and rerun.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

save_pdf_base <- function(plot, path, width, height) {
  prepare_file(path)
  grDevices::pdf(
    file = path,
    width = width,
    height = height,
    paper = "special",
    useDingbats = FALSE,
    bg = "white"
  )
  device_open <- TRUE
  tryCatch(
    {
      print(plot)
      grDevices::dev.off()
      device_open <- FALSE
    },
    error = function(e) {
      if (device_open && grDevices::dev.cur() > 1) {
        try(grDevices::dev.off(), silent = TRUE)
      }
      stop(
        "PDF creation failed for:\n", path, "\n",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )
}

save_png_base <- function(plot, path, width, height, dpi = 320) {
  prepare_file(path)
  grDevices::png(
    filename = path,
    width = width,
    height = height,
    units = "in",
    res = dpi,
    bg = "white"
  )
  device_open <- TRUE
  tryCatch(
    {
      print(plot)
      grDevices::dev.off()
      device_open <- FALSE
    },
    error = function(e) {
      if (device_open && grDevices::dev.cur() > 1) {
        try(grDevices::dev.off(), silent = TRUE)
      }
      stop(
        "PNG creation failed for:\n", path, "\n",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )
}

save_svg <- function(plot, path, width, height) {
  prepare_file(path)
  svglite::svglite(
    file = path,
    width = width,
    height = height,
    bg = "white"
  )
  device_open <- TRUE
  tryCatch(
    {
      print(plot)
      grDevices::dev.off()
      device_open <- FALSE
    },
    error = function(e) {
      if (device_open && grDevices::dev.cur() > 1) {
        try(grDevices::dev.off(), silent = TRUE)
      }
      stop(
        "SVG creation failed for:\n", path, "\n",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )
}

save_bundle <- function(plot, stem, width, height) {
  paths <- c(
    pdf = file.path(output_dir, paste0(stem, ".pdf")),
    png = file.path(output_dir, paste0(stem, ".png")),
    svg = file.path(output_dir, paste0(stem, ".svg"))
  )

  # Deliberately use the standard grDevices::pdf device, not cairo_pdf().
  save_pdf_base(plot, paths[["pdf"]], width, height)
  save_png_base(plot, paths[["png"]], width, height, dpi = 320)
  save_svg(plot, paths[["svg"]], width, height)

  invisible(paths)
}

decision_paths <- save_bundle(
  decision_plot,
  "decision_plane_target_adequacy_transportability",
  width = 7.6,
  height = 6.4
)

target_paths <- save_bundle(
  target_plot,
  "fixed_source_target_estimates",
  width = 7.6,
  height = 5.2
)

divergence_paths <- save_bundle(
  divergence_plot,
  "fixed_source_tac_etc_divergence",
  width = 8.8,
  height = 5.6
)

message(
  "Fixed-source ETC R validation passed: reconstructed logit intervals matched ",
  "pipeline half-widths to 4 decimals and all expected values/decisions within 1e-3."
)
message("Three publication figures were written to: ", output_dir)
message("  1. decision_plane_target_adequacy_transportability.{pdf,png,svg}")
message("  2. fixed_source_target_estimates.{pdf,png,svg}")
message("  3. fixed_source_tac_etc_divergence.{pdf,png,svg}  [four-region TAC/ETC decision plane]")
