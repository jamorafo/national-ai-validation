# Reproducibility Guide

This document describes how to reproduce the simulation outputs for the dissertation chapter:

> **Objective Reference Points, Predictive Representativity, and External Transportability**

Author: **Andrés Morales-Forero**

## 1. Canonical workflow

The canonical workflow is implemented in R.

Full workflow:

```bash
Rscript R/run_all.R .
```

Windows example when `Rscript` is not available on the system path:

```bat
"C:\Users\morales-fo.j\AppData\Local\Programs\R\R-4.5.3\bin\Rscript.exe" R\run_all.R .
```

## 2. Output-only workflow

If the Monte Carlo summaries already exist, regenerate manuscript outputs with:

```bash
Rscript -e "source('R/make_tables.R'); make_tables_R(normalizePath(getwd(), winslash='/'))"

Rscript -e "source('R/dgp.R'); source('R/make_figures.R'); make_figures_R(normalizePath(getwd(), winslash='/'))"

Rscript R/tr_etc_fixed_source.R . --overwrite
```


## 3. Random seeds

Random seeds must be documented so that stochastic components can be reproduced.

Run these commands from the repository root to identify seed definitions:

```bat
findstr /S /N /I /C:"set.seed" R\*.R
findstr /S /N /I /C:"seed" R\*.R config\*.*
```

The seed record should be stored in:

```text
config/seeds.csv
```

Recommended format:

```csv
component,seed,script_or_file,purpose
main_simulation,,R/run.R,Monte Carlo replication stream
data_generating_process,,R/dgp.R,Synthetic finite population generation
audit_sampling,,R/designs.R,ORP and audit-sample construction
post_processing,not_stochastic,R/make_figures.R; R/make_tables.R; R/tr_etc_fixed_source.R,Deterministic table and figure generation
```

Do not leave empty seed fields in the final repository if the corresponding component is stochastic. If a component is deterministic, write `not_stochastic`.

## 4. Tracked and untracked outputs

Tracked:

```text
results/summary/
tables/
figures/r_publication/
docs/
R/
config/
```

Not tracked:

```text
results/raw/
checkpoints/
local backups
temporary patch files
figures/python_validation/
```

Reason: raw replication files and local backups can be regenerated or are not part of the canonical dissertation outputs.

## 5. Validation checks

The fixed-source ETC script performs deterministic validation before writing figures. It checks that reconstructed logit intervals match stored half-widths and that expected values and decisions match within tolerance.

The validation script is:

```text
R/validate.R
```

Additional fixed-source ETC validation is inside:

```text
R/tr_etc_fixed_source.R
```

## 6. Expected key outputs

After successful regeneration, the following files or file families should exist:

```text
results/summary/performance_summary_R.csv
results/summary/tac_frequencies_R.csv
tables/nav_table_variance_comparison.tex
tables/nav_table_mechanical_tac_m80.tex
figures/r_publication/nav_fig7_evidential_status.*
figures/r_publication/nav_fig8_tac.*
figures/r_publication/nav_fig9_large_wrong_orp.*
figures/r_publication/fixed_source_tac_etc_divergence.*
```

## 7. Repository hygiene

Before pushing to GitHub, check for unwanted backup or patch files:

```bat
dir /S /B *bak*
dir /S /B *backup*
dir /S /B *patch*
dir /S /B *restore*
```

The `.gitignore` file should exclude local backups and raw outputs.

## 8. Commit workflow

Recommended final check before commit:

```bat
git status --short
git add README.md docs config R tables figures/r_publication results/summary .gitignore
git status --short
git commit -m "Update reproducibility documentation and generated outputs"
git push
```
