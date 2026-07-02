"""Point estimators and matched/mismatched uncertainty procedures."""
from __future__ import annotations

import math
import numpy as np

from variance import (
    logit_interval,
    naive_patient_variance,
    taylor_ratio_variance,
    unweighted_cluster_ratio_variance,
)

ESTIMANDS = {
    "national": ("TP", "Y"),
    "easy": ("TP_q0", "Y_q0"),
    "hard": ("TP_q1", "Y_q1"),
}


def estimate_patient_srs(draw: np.ndarray, n: int, population_n: int) -> dict[str, dict[str, float]]:
    output: dict[str, dict[str, float]] = {}
    for estimand in ESTIMANDS:
        if estimand == "national":
            cell = draw.sum(axis=(0, 1))
        elif estimand == "easy":
            cell = draw[:, 0, :].sum(axis=0)
        else:
            cell = draw[:, 1, :].sum(axis=0)
        true_positive = float(cell[2])
        positive = float(cell[1] + cell[2])
        if positive <= 0:
            output[estimand] = _missing_result()
            continue
        estimate = true_positive / positive
        sum_z2 = true_positive * (1.0 - estimate) ** 2 + (positive - true_positive) * estimate**2
        sample_variance_z = sum_z2 / (n - 1)
        mean_y = positive / n
        variance = (1.0 - n / population_n) * sample_variance_z / (n * mean_y**2)
        standard_error = math.sqrt(max(variance, 0.0))
        lower, upper = logit_interval(estimate, standard_error)
        output[estimand] = _result(estimate, standard_error, lower, upper, positive)
    return output


def estimate_hospital_sample(
    arrays: dict[str, np.ndarray],
    selected0: np.ndarray,
    selected1: np.ndarray,
    population_h0: int,
    population_h1: int,
    mode: str,
) -> dict[str, dict[str, float]]:
    """Estimate all three sensitivity parameters.

    mode is one of ``unweighted``, ``design`` or ``naive``.  ``design`` and
    ``naive`` use identical design-weighted point estimates; only variance
    differs.
    """
    output: dict[str, dict[str, float]] = {}
    m0, m1 = len(selected0), len(selected1)
    for estimand, (t_name, y_name) in ESTIMANDS.items():
        t0 = arrays[t_name][selected0].astype(float)
        y0 = arrays[y_name][selected0].astype(float)
        t1 = arrays[t_name][selected1].astype(float)
        y1 = arrays[y_name][selected1].astype(float)

        if mode == "unweighted":
            weight0 = weight1 = 1.0
        else:
            weight0 = population_h0 / m0
            weight1 = population_h1 / m1
        numerator = weight0 * t0.sum() + weight1 * t1.sum()
        denominator = weight0 * y0.sum() + weight1 * y1.sum()
        if denominator <= 0:
            output[estimand] = _missing_result()
            continue
        estimate = numerator / denominator

        if mode == "design":
            variance = taylor_ratio_variance(
                estimate,
                denominator,
                t0,
                y0,
                t1,
                y1,
                population_h0,
                population_h1,
            )
        elif mode == "naive":
            variance = naive_patient_variance(
                estimate,
                denominator,
                t0.sum(),
                y0.sum(),
                t1.sum(),
                y1.sum(),
                weight0,
                weight1,
            )
        elif mode == "unweighted":
            variance = unweighted_cluster_ratio_variance(
                estimate,
                denominator,
                t0,
                y0,
                t1,
                y1,
                population_h0,
                population_h1,
            )
        else:
            raise ValueError(f"Unknown estimation mode: {mode}")
        standard_error = math.sqrt(max(float(variance), 0.0))
        lower, upper = logit_interval(estimate, standard_error)
        output[estimand] = _result(
            estimate,
            standard_error,
            lower,
            upper,
            y0.sum() + y1.sum(),
        )
    return output


def _result(estimate: float, se: float, lower: float, upper: float, positive: float) -> dict[str, float]:
    return {
        "estimate": float(estimate),
        "estimated_se": float(se),
        "ci_lower": float(lower),
        "ci_upper": float(upper),
        "positive_cases": float(positive),
        "non_estimable": 0.0,
    }


def _missing_result() -> dict[str, float]:
    return {
        "estimate": math.nan,
        "estimated_se": math.nan,
        "ci_lower": math.nan,
        "ci_upper": math.nan,
        "positive_cases": 0.0,
        "non_estimable": 1.0,
    }
