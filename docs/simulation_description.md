\# Simulation Description



This document describes the simulation study used in the dissertation chapter:



> \*\*Objective Reference Points, Predictive Representativity, and External Transportability\*\*



The chapter is part of the dissertation:



> \*\*Toward Safe AI\*\*



Author: \*\*Andrés Morales-Forero\*\*



\## 1. Purpose of the simulation



The simulation evaluates how different Objective Reference Point (ORP)

construction strategies support statistical claims about the target performance

and external transportability of a locked predictive system.



The study focuses on three connected evidential questions:



1\. whether target-country performance is adequate relative to a pre-specified

&#x20;  deployment threshold;

2\. whether performance degradation from a certified source claim to the target

&#x20;  condition remains within an admissible margin;

3\. whether the audit design, estimator, and uncertainty procedure are adequate

&#x20;  for the estimand invoked by the claim.



\## 2. Target estimands



The primary performance metric is sensitivity at a locked operating threshold.



The target estimands include:



\- national target sensitivity;

\- easier-subgroup target sensitivity;

\- harder-subgroup target sensitivity.



For a larger-is-better metric, the Target Adequacy Criterion (TAC) compares the

target performance interval with the adequacy threshold.



The External Transportability Criterion (ETC) compares the source-to-target

degradation interval with the admissible degradation margin.



\## 3. Decision criteria



\### Target Adequacy Criterion



Let \\(\\theta\_T\\) denote the target performance parameter and let \\(\\tau\\) denote

the adequacy threshold.



For larger-is-better metrics, the target system is classified as:



\- \*\*Adequate\*\* if the lower confidence bound for \\(\\theta\_T\\) is at least

&#x20; \\(\\tau\\);

\- \*\*Not adequate\*\* if the upper confidence bound for \\(\\theta\_T\\) is below

&#x20; \\(\\tau\\);

\- \*\*Inconclusive\*\* otherwise.



\### External Transportability Criterion



Let



\\\[

\\Delta\_{S \\to T} = \\theta\_S - \\theta\_T

\\]



denote the source-to-target degradation gap, and let \\(\\varepsilon\_T\\) denote

the maximum admissible degradation.



The target system is classified as:



\- \*\*Transported\*\* if the upper confidence bound for \\(\\Delta\_{S \\to T}\\) is no

&#x20; larger than \\(\\varepsilon\_T\\);

\- \*\*Not transported\*\* if the lower confidence bound for \\(\\Delta\_{S \\to T}\\) is

&#x20; larger than \\(\\varepsilon\_T\\);

\- \*\*Inconclusive\*\* otherwise.



\## 4. Audit strategies



The simulation compares several target-audit strategies, including simple and

enriched designs, with estimators designed to recover national and subgroup

performance under different ORP construction assumptions.



The canonical implementation is the R workflow contained in the `R/` directory.



\## 5. Random seeds



The simulation uses fixed random seeds to make the generated finite populations,

audit samples, and Monte Carlo summaries reproducible.



The seeds should be reported here as part of the simulation record.



| Component | Seed | Script / location | Purpose |

|---|---:|---|---|

| Main simulation seed | TODO | `R/run.R` or configuration file | Monte Carlo replication stream |

| Data-generating process seed | TODO | `R/dgp.R` or configuration file | Synthetic finite population generation |

| Sampling/design seed | TODO | `R/designs.R` or configuration file | Audit-sample construction |

| Analysis/post-processing seed | TODO | if applicable | Any stochastic post-processing |



If a single global seed is used, report it once and state that all stochastic

steps are derived from that seed. If multiple independent seeds are used, report

each seed separately.



\## 6. Reproducibility workflow



From the repository root, the full workflow can be run with:



```bash

Rscript R/run\_all.R .

