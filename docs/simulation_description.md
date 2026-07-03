# Simulation Description

This document describes the simulation study used in the dissertation chapter:

> **Objective Reference Points, Predictive Representativity, and External Transportability**

The chapter is part of the dissertation:

> **Toward Safe AI**

Author: **Andrés Morales-Forero**

## 1. Documentation structure

The simulation is documented using the ADEMP structure:

```text
A  Aims
D  Data-generating mechanisms
E  Estimands
M  Methods
P  Performance measures
```

This structure is appropriate because the study evaluates statistical procedures under a controlled data-generating process.

## 2. Aims

The simulation evaluates how different Objective Reference Point (ORP) construction strategies support evidence for target performance and external transportability of a locked predictive system.

The specific aims are:

1. To estimate national and subgroup target sensitivity under competing audit strategies.
2. To evaluate whether a target-country audit supports the Target Adequacy Criterion (TAC).
3. To evaluate whether target evidence supports an External Transportability Criterion (ETC) when compared with a certified source claim.
4. To show how the Predictive Representativity gate changes the interpretation of point estimates and intervals.
5. To compare bias, precision, coverage, and decision frequencies across strategy-estimator combinations.
6. To demonstrate how a national-only audit may hide subgroup-specific failures.

## 3. Data-generating mechanisms

The simulation represents a target-country validation setting for a locked predictive system evaluated at a fixed operating threshold.

The finite population contains:

```text
Hospitals
Patients or admissions nested within hospitals
True deterioration status
Model alert status
Subgroup membership: easier versus harder cases
```

The data-generating mechanism is designed to include:

```text
Hospital-level heterogeneity
Different case composition across hospitals
Different positive-case yield by subgroup
Different model sensitivity by subgroup
A target population that may differ from the source claim
```

The primary setting is intentionally constructed so that average national performance can appear acceptable while subgroup performance and source-to-target preservation can fail.

The data-generating mechanism is implemented in:

```text
R/dgp.R
```

## 4. Target estimands

The primary performance metric is sensitivity at a locked operating threshold.

The main estimands are:

```text
National target sensitivity
Easy-subgroup target sensitivity
Hard-subgroup target sensitivity
```

Plain-text notation used in this repository:

```text
theta_T       = target performance parameter
theta_T,easy  = target performance in the easier subgroup
theta_T,hard  = target performance in the harder subgroup
theta_S       = certified source performance
Delta_S_to_T  = source-to-target degradation gap
tau           = target adequacy threshold
epsilon_T     = maximum admissible source-to-target degradation
```

For larger-is-better metrics such as sensitivity:

```text
Delta_S_to_T = theta_S - theta_T
```

A positive degradation gap means that the target performance is lower than the certified source performance.

## 5. Audit strategies and estimators

The simulation compares multiple target-audit strategies. The strategy labels used in the generated outputs include:

```text
N1
N2
N3
N4
N5
```

The strategies differ in how the ORP is constructed and how the target performance estimand is estimated.

The main implementation files are:

```text
R/designs.R       Audit design definitions
R/estimators.R    Estimator definitions
R/variance.R      Standard errors and interval calculations
R/run.R           Monte Carlo execution
R/analyse.R       Summary analysis
R/validate.R      Validation checks
```

## 6. Decision criteria

### 6.1 Target Adequacy Criterion

Plain-text notation:

```text
theta_T = target performance
tau     = adequacy threshold
L_T     = lower confidence bound for theta_T
U_T     = upper confidence bound for theta_T
```

For a larger-is-better metric:

```text
Adequate:
  L_T >= tau

Not adequate:
  U_T < tau

Inconclusive:
  otherwise
```

### 6.2 External Transportability Criterion

Plain-text notation:

```text
Delta_S_to_T = theta_S - theta_T
epsilon_T    = maximum admissible degradation
L_Delta      = lower confidence bound for Delta_S_to_T
U_Delta      = upper confidence bound for Delta_S_to_T
```

For a larger-is-better metric:

```text
Transported:
  U_Delta <= epsilon_T

Not transported:
  L_Delta > epsilon_T

Inconclusive:
  otherwise
```

The ETC rule is interval-based. In the four-region decision-plane figure, the shaded quadrants classify the location of the point estimate only. The formal ETC decision depends on the interval. Therefore, a point estimate can lie in a region labelled "not transported" while the formal decision remains "Inconclusive" because the degradation interval crosses the admissible margin.

## 7. Predictive Representativity gate

The Predictive Representativity gate asks whether the evidence is adequate for the validation claim being made.

In this simulation, a claim is interpreted through the tuple:

```text
Target condition
Performance estimand
ORP construction strategy
Estimator
Uncertainty procedure
Decision threshold or margin
```

The gate separates two questions:

```text
1. What is the target estimand?
2. Is the design-estimator-uncertainty procedure adequate for that estimand?
```

This prevents treating an arbitrary sample or unweighted subgroup composition as automatically representative of the target performance claim.

## 8. Performance measures

The simulation reports both estimation performance and decision performance.

Estimation performance:

```text
Bias
Root mean squared error
Empirical standard deviation
Estimated standard error
Coverage
```

Decision performance:

```text
TAC decision frequencies
ETC decision frequencies
Predictive-Representativity evidential status
Evidential-insufficiency frequencies
```

The decision frequencies are central because the framework is intended to support validation decisions, not only point estimation.

## 9. Random seed system

The simulation uses a master seed and deterministic derived seeds. This is part of the reproducibility record because the finite population and the audit-sampling streams are stochastic.

The master seed is:

```text
141421
```

It is defined in:

```text
config/config.yaml:3
```

and used directly in:

```text
R/dgp.R:28
```

to initialize the finite-population data-generating mechanism.

Monte Carlo audit-sampling streams are then derived deterministically with `stable_seed()`. The derived seed depends on:

```text
master seed
strategy label
hospital sample size m
replication index rep - 1
language tag "R"
```

The seed derivation is used in:

```text
R/run.R:32  N1 sampling stream
R/run.R:39  N2 sampling stream
R/run.R:44  enriched-strategy sampling stream
```

The complete seed record is stored in:

```text
config/seeds.csv
```

The seed system has two purposes. First, it makes the finite population and Monte Carlo audit samples reproducible. Second, it avoids overlap between strategy-specific sampling streams by deriving distinct deterministic seeds for each strategy, sample size, and replication. Table and figure generation scripts are deterministic post-processing steps and do not introduce additional random variation.

## 10. Fixed-source ETC addendum

The fixed-source ETC addendum is generated by:

```text
R/tr_etc_fixed_source.R
```

This script reads:

```text
results/summary/performance_summary_R.csv
```

It does not rerun the Monte Carlo experiment. It reconstructs relevant target intervals and produces fixed-source ETC figures.

The main outputs are:

```text
decision_plane_target_adequacy_transportability.*
fixed_source_target_estimates.*
fixed_source_tac_etc_divergence.*
```

The four-region TAC/ETC decision-plane figure has two interpretations:

```text
Point-estimate regions:
  Determined by the location of (theta_T_hat, Delta_S_to_T_hat)

Formal TAC/ETC decisions:
  Determined by confidence-interval bounds
```

This distinction is important because a point estimate can fall in an off-diagonal or non-transported region while the interval-based ETC decision remains inconclusive.

## 11. Generated manuscript outputs

Main generated tables:

```text
tables/*.tex
```

Main generated figures:

```text
figures/r_publication/*.pdf
figures/r_publication/*.png
figures/r_publication/*.svg
```

Main summary files:

```text
results/summary/performance_summary_R.csv
results/summary/tac_frequencies_R.csv
```

## 12. Scope and limitations

This is a methodological simulation. It is not a clinical trial, not a clinical deployment study, and not a complete clinical prediction-model reporting document.

The simulation is designed to illustrate the evidential logic of ORP construction, Predictive Representativity, TAC, and ETC. The fixed-source ETC addendum is illustrative and should be interpreted as post-processing of the simulation summaries, not as additional Monte Carlo evidence.

## 13. Repository

```text
https://github.com/jamorafo/national-ai-validation
```
