"""Variance and interval utilities."""
from __future__ import annotations

import math
import numpy as np
from scipy.special import expit, logit

Z_975 = 1.959963984540054


def logit_interval(estimate: float, standard_error: float) -> tuple[float, float]:
    if not np.isfinite(estimate) or not np.isfinite(standard_error):
        return math.nan, math.nan
    clipped = min(max(float(estimate), 1e-8), 1.0 - 1e-8)
    se_logit = standard_error / (clipped * (1.0 - clipped))
    return (
        float(expit(logit(clipped) - Z_975 * se_logit)),
        float(expit(logit(clipped) + Z_975 * se_logit)),
    )


def taylor_ratio_variance(
    estimate: float,
    denominator_total_estimate: float,
    t0: np.ndarray,
    y0: np.ndarray,
    t1: np.ndarray,
    y1: np.ndarray,
    population_h0: int,
    population_h1: int,
) -> float:
    m0, m1 = len(t0), len(t1)
    z0 = t0 - estimate * y0
    z1 = t1 - estimate * y1
    s20 = float(np.var(z0, ddof=1))
    s21 = float(np.var(z1, ddof=1))
    variance_z = (
        population_h0**2 * (1.0 - m0 / population_h0) * s20 / m0
        + population_h1**2 * (1.0 - m1 / population_h1) * s21 / m1
    )
    return variance_z / denominator_total_estimate**2


def unweighted_cluster_ratio_variance(
    estimate: float,
    denominator_sample_total: float,
    t0: np.ndarray,
    y0: np.ndarray,
    t1: np.ndarray,
    y1: np.ndarray,
    population_h0: int,
    population_h1: int,
) -> float:
    m0, m1 = len(t0), len(t1)
    z0 = t0 - estimate * y0
    z1 = t1 - estimate * y1
    variance_z = (
        m0 * (1.0 - m0 / population_h0) * float(np.var(z0, ddof=1))
        + m1 * (1.0 - m1 / population_h1) * float(np.var(z1, ddof=1))
    )
    return variance_z / denominator_sample_total**2


def naive_patient_variance(
    estimate: float,
    denominator_weighted: float,
    t0_sum: float,
    y0_sum: float,
    t1_sum: float,
    y1_sum: float,
    weight0: float,
    weight1: float,
) -> float:
    residual_ss = (
        weight0**2 * (t0_sum * (1.0 - estimate) ** 2 + (y0_sum - t0_sum) * estimate**2)
        + weight1**2 * (t1_sum * (1.0 - estimate) ** 2 + (y1_sum - t1_sum) * estimate**2)
    )
    return residual_ss / denominator_weighted**2
