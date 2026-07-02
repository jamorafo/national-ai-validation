# Reproducibility record

## Fixed design decisions

- Project: `national-AI-validation`
- Master seed: `141421`
- Monte Carlo replications: 5,000 per primary design/sample-size condition
- Hospital sample sizes: 40, 80, 120, and 160
- Common fixed audit period: all selected hospitals contribute a census of eligible admissions in the same pre-specified period
- No month identifiers, month selection, collection-window selection, or month-level inclusion probabilities are used
- Target adequacy threshold: 0.85
- PR bias tolerance: 0.03
- PR variance tolerance: `(0.03 / 1.96)^2`

## Python sub-seed algorithm

For master seed `M`, design label `L`, hospital sample size `m`, replication `r`, and language tag `python`, form the UTF-8 string:

```text
M|L|m|r|python
```

Compute its SHA-256 digest, interpret the first eight bytes as an unsigned little-endian integer, and reduce it modulo `2^63 - 1`. Labels are `N1`, `N2`, and `ENRICHED`. The same `ENRICHED` seed and selected hospitals are reused by N3, N4, and N5 within each replication.

## R sub-seed algorithm

R forms the analogous string with language tag `R`, computes SHA-256, converts the first eight hexadecimal digits through two four-digit blocks, reduces the value modulo `2,147,483,646`, and adds one. The R streams are deterministic and independent of the Python streams.

## Locked population and software

The executed Python run used:

- Python 3.13.5
- NumPy 2.3.5
- pandas 2.2.3
- SciPy 1.17.0
- PyYAML 6.0.3

Checksums from the executed run are stored in `results/summary/validation_results.json`. They include the configuration file, compressed finite population, and compressed replication results.

## Validation checks

The executable validation script verifies that:

1. all hospital inclusion probabilities lie in `(0,1]`;
2. no calendar-month sampling variable exists;
3. the audit period is common and fixed;
4. N3, N4, and N5 use the same realised ORP in every replication;
5. N4 and N5 point estimates are identical to numerical precision;
6. target truths match direct finite-population enumeration;
7. N1 is approximately unbiased;
8. N4 is design-consistent for national and subgroup parameters;
9. N3 approaches the exact design-induced observation parameter;
10. N4 and N5 have the same point-estimator distribution;
11. the naive N5 variance failure is detected through national undercoverage;
12. no formal TAC result is issued after an evidential-gate failure.

## Separation of evidence concepts

The summary files report four separate quantities:

- PR bias pass;
- PR precision pass;
- empirical target-interval coverage;
- structural compatibility of the declared variance procedure.

The first two define the point-estimation component of PR under the pre-specified tolerances. Coverage remains a separate uncertainty diagnostic, as required. Formal TAC is reported only when point-estimation PR, target interval validity, and variance-procedure compatibility are all satisfied. This preserves the distinction between the chapter's PR definition and the reliability of the interval subsequently used by TAC.
