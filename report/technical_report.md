# Technical report: national probability-based validation simulation

## Purpose

The simulation evaluates the chapter's central proposition that a realised Objective Reference Point is not representative in the abstract. Its evidentiary value depends on the complete strategy

\[
\eta_k=(d_k,\widehat\theta_k,V_k),
\]

relative to a pre-specified target performance parameter. The experiment isolates the construction process, point estimator, and uncertainty procedure through comparisons that reuse the same realised enriched ORP.

## Fixed target population

The simulator generated one finite target population of 25,585 eligible admissions in 400 hospitals: 300 standard hospitals and 100 priority hospitals. Hospital size ranged from 35 to 105 admissions. The priority stratum contained a higher prevalence of harder patients and deterioration events and had lower sensitivity. The patient difficulty subgroup was not identical to the hospital stratum: both easier and harder patients occurred in both strata.

The fixed target truths were:

| Estimand | Sensitivity | Positive cases |
|---|---:|---:|
| National | 0.8784 | 4,819 |
| Easier subgroup | 0.9480 | 3,231 |
| Harder subgroup | 0.7368 | 1,588 |

Thus, national performance exceeded the TAC threshold of 0.85 while harder-subgroup performance was clearly below it.

## Exact observation-distribution discrepancy

Under equal allocation of sampled hospitals to the two hospital strata, the priority-stratum hospital inclusion probability is three times the standard-stratum probability. The exact unweighted observation parameters of that enriched design were:

| Estimand | Target | Enriched observation parameter | RTD |
|---|---:|---:|---:|
| National | 0.8784 | 0.8419 | -0.0365 |
| Easier subgroup | 0.9480 | 0.9424 | -0.0056 |
| Harder subgroup | 0.7368 | 0.7110 | -0.0258 |

These quantities were computed directly from the fixed population and first-order inclusion probabilities before Monte Carlo sampling.

## Monte Carlo design

Five strategies were evaluated at 40, 80, 120, and 160 selected hospitals, using 5,000 replications per cell. N2 sampled hospitals proportionally to the frame strata. N3-N5 allocated one half of selected hospitals to the priority stratum. N3, N4, and N5 used exactly the same selected hospitals in every replication. N4 and N5 also used exactly the same design-weighted point estimate; they differed only in uncertainty estimation.

## Main findings

### Same enriched ORP, different estimator

N3's national bias remained approximately -0.0365 at every sample size, almost exactly the analytically calculated RTD. Its empirical SD decreased from 0.0259 at 40 hospitals to 0.0073 at 160 hospitals. The estimator therefore became increasingly precise around 0.8419 rather than around the national target 0.8784.

N4 used the same observed admissions but expanded hospital totals by inverse inclusion probabilities before forming the sensitivity ratio. Its absolute national bias was below 0.0003 in every condition. Weighting did not change the realised ORP; it changed the estimator and restored the national inferential target.

### Same sample and point estimator, different uncertainty

N4 and N5 were numerically identical point by point. At 80 hospitals, both had empirical SD 0.0135, but N4's mean estimated SE was 0.0135 and its coverage was 0.947. N5's mean estimated SE was 0.0102 and coverage fell to 0.861. At 120 hospitals, coverage was 0.942 for N4 and 0.890 for N5. N5 also generated more mechanically decisive TAC results because its intervals were too narrow. These results show that uncertainty is an inferential component of the strategy, not a presentation choice added after estimation.

### Enrichment improved difficult-subgroup evidence

Compared with N2, N4 increased the number of observed harder-subgroup positive cases by about 49% at every sample size. At 160 hospitals, the mean count increased from 635 to 947 and the empirical SD of harder-subgroup sensitivity decreased from 0.0222 to 0.0147, a reduction of approximately 34%. N4 then passed the declared hard-subgroup precision criterion; N2 did not.

### PR was parameter-specific

N4 supported national sensitivity from 80 hospitals onward and supported harder-subgroup sensitivity only at 160 hospitals. N2 supported national sensitivity at 120 and 160 hospitals but remained insufficient for the harder-subgroup claim. N3 failed the national bias criterion at all sample sizes even when its variance became small. These patterns show why a single statement that an ORP is "representative" is methodologically incomplete.

### TAC followed the evidential gate

At 160 hospitals, N4 produced a valid national TAC result of Adequate in 92.3% of replications and Inconclusive in 7.7%. For harder-subgroup sensitivity, N4 produced Not adequate in 100% of replications. N2 remained evidentially insufficient for the hard-subgroup TAC because it failed the precision requirement. N3 and N5 were not assigned formal TAC conclusions when their target alignment or uncertainty procedure failed, even though their mechanical interval-threshold results were retained for diagnostics.

## Conclusion

The experiment supports the chapter's intended closing claims:

1. probability designs with different operational structures can support the same target parameter when paired with compatible estimators;
2. an enriched ORP can improve difficult-subgroup evidence without sacrificing national inference when inclusion probabilities are known and used correctly;
3. the same realised ORP can be valid or invalid for a national claim depending on the estimator;
4. the same point estimator can provide reliable or unreliable decisions depending on the variance procedure;
5. increasing sample size reduces sampling error but does not remove reference-target discrepancy;
6. PR is the evidential gatekeeper and TAC is the subsequent decision rule.

The simulation concerns sensitivity at one locked operating threshold. It does not establish global model safety and does not evaluate source-to-target ETC.
