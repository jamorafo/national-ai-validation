# Reporting Checklist

This checklist maps the repository contents to the ADEMP structure for simulation studies and to practical reproducibility requirements.

## 1. ADEMP mapping

| ADEMP item | What is reported | Repository location |
|---|---|---|
| Aims | Study purpose and validation questions | `README.md`, `docs/simulation_description.md` |
| Data-generating mechanisms | Finite target population, hospital heterogeneity, subgroup structure, locked threshold | `docs/simulation_description.md`, `R/dgp.R` |
| Estimands | National, easy-subgroup, and hard-subgroup target sensitivity; source-to-target degradation | `docs/simulation_description.md`, `R/analyse.R` |
| Methods | ORP strategies, estimators, variance procedures, Monte Carlo execution | `R/designs.R`, `R/estimators.R`, `R/variance.R`, `R/run.R` |
| Performance measures | Bias, RMSE, coverage, standard errors, decision frequencies | `docs/simulation_description.md`, `R/analyse.R`, `R/validate.R` |

## 2. Decision-rule reporting

| Item | Repository location |
|---|---|
| Target Adequacy Criterion | `docs/simulation_description.md`, dissertation chapter |
| External Transportability Criterion | `docs/simulation_description.md`, `R/tr_etc_fixed_source.R` |
| Predictive Representativity gate | `docs/simulation_description.md`, dissertation chapter |
| Interval-based decision rules | `docs/simulation_description.md`, `R/analyse.R`, `R/tr_etc_fixed_source.R` |
| Point-region versus interval-verdict distinction | `docs/simulation_description.md`, fixed-source ETC figure caption |

## 3. Reproducibility reporting

| Item | Repository location |
|---|---|
| Main workflow command | `README.md`, `docs/reproducibility.md` |
| Output-only workflow command | `README.md`, `docs/reproducibility.md` |
| Dependencies | `README.md`, `R/install_packages.R`, `requirements.txt` |
| Random seeds | `docs/reproducibility.md`, `config/seeds.csv` |
| Tracked outputs | `README.md`, `docs/reproducibility.md` |
| Excluded raw outputs | `.gitignore`, `README.md`, `docs/reproducibility.md` |
| Generated figures | `figures/r_publication/` |
| Generated tables | `tables/` |
| Summary outputs | `results/summary/` |

## 4. Scope statements

| Statement | Status |
|---|---|
| This is a methodological simulation | Reported |
| This is not a clinical trial | Reported |
| This is not a deployed clinical AI evaluation | Reported |
| R is the canonical workflow | Reported |
| Python is retained for historical cross-checking | Reported |
| Raw replication files are excluded but regenerable | Reported |

## 5. Repository hygiene

Before release, the repository should not contain:

```text
*.bak
*.bak*
*_patch*
*_backup*
*_restore*
checkpoints/
results/raw/
figures/python_validation/
```

The public repository should contain clean canonical scripts, generated manuscript outputs, and documentation sufficient to reproduce or inspect the study.
