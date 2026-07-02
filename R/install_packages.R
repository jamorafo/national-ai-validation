packages <- c("data.table", "yaml", "digest", "ggplot2", "scales", "svglite", "jsonlite", "MASS")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
message("Required R packages are installed.")
