"""Probability sampling designs."""
from __future__ import annotations

import numpy as np


def draw_hospitals(
    rng: np.random.Generator,
    indices0: np.ndarray,
    indices1: np.ndarray,
    allocation: tuple[int, int],
) -> tuple[np.ndarray, np.ndarray]:
    m0, m1 = allocation
    return (
        rng.choice(indices0, size=m0, replace=False),
        rng.choice(indices1, size=m1, replace=False),
    )


def expected_patient_srs_size(total_patients: int, total_hospitals: int, sampled_hospitals: int) -> int:
    return int(round(total_patients * sampled_hospitals / total_hospitals))
