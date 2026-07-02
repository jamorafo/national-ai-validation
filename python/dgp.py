"""Fixed finite-population generator for the national AI validation study."""
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
import yaml
from scipy.special import expit, logit


def load_config(path: str | Path) -> dict[str, Any]:
    with open(path, "r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def deterministic_seed(master: int, label: str, size: int, replication: int, language: str) -> int:
    """Map identifiers to a stable 63-bit integer using SHA-256.

    The byte string is ``master|label|size|replication|language``.  The first
    eight digest bytes are interpreted as an unsigned little-endian integer
    and reduced modulo 2^63-1.  This avoids Python's session-dependent hash().
    """
    text = f"{master}|{label}|{size}|{replication}|{language}".encode("utf-8")
    return int.from_bytes(hashlib.sha256(text).digest()[:8], "little") % (2**63 - 1)


def generate_population(config: dict[str, Any]) -> tuple[pd.DataFrame, pd.DataFrame]:
    p = config["population"]
    master = int(config["project"]["master_seed"])
    rng = np.random.default_rng(master)

    h0 = int(p["hospitals_standard"])
    h1 = int(p["hospitals_priority"])
    hospital_stratum = np.r_[np.zeros(h0, dtype=int), np.ones(h1, dtype=int)]
    hospital_count = h0 + h1

    sizes = np.rint(
        rng.lognormal(
            mean=float(p["hospital_size_log_mean"]),
            sigma=float(p["hospital_size_log_sd"]),
            size=hospital_count,
        )
    ).astype(int)
    sizes = np.clip(sizes, int(p["hospital_size_min"]), int(p["hospital_size_max"]))

    sd = np.array(
        [
            float(p["random_effect_sd_q"]),
            float(p["random_effect_sd_y"]),
            float(p["random_effect_sd_a"]),
        ]
    )
    corr = np.array(
        [
            [1.0, float(p["random_effect_corr_q_y"]), float(p["random_effect_corr_q_a"])],
            [float(p["random_effect_corr_q_y"]), 1.0, float(p["random_effect_corr_y_a"])],
            [float(p["random_effect_corr_q_a"]), float(p["random_effect_corr_y_a"]), 1.0],
        ]
    )
    covariance = corr * np.outer(sd, sd)
    if np.min(np.linalg.eigvalsh(covariance)) < -1e-10:
        raise ValueError("The hospital random-effect covariance matrix is not positive semidefinite.")
    random_effects = rng.multivariate_normal(np.zeros(3), covariance, size=hospital_count)

    patient_frames: list[pd.DataFrame] = []
    for hospital_id in range(hospital_count):
        n_h = int(sizes[hospital_id])
        stratum = int(hospital_stratum[hospital_id])

        probability_q = expit(
            logit(float(p["q_baseline_probability"]))
            + float(p["q_priority_log_odds"]) * stratum
            + random_effects[hospital_id, 0]
        )
        q = rng.binomial(1, probability_q, size=n_h)

        probability_y = expit(
            logit(float(p["y_baseline_probability"]))
            + float(p["y_priority_log_odds"]) * stratum
            + float(p["y_hard_log_odds"]) * q
            + random_effects[hospital_id, 1]
        )
        y = rng.binomial(1, probability_y, size=n_h)

        probability_alert_event = expit(
            logit(float(p["sensitivity_baseline_probability"]))
            + float(p["sensitivity_hard_log_odds"]) * q
            + float(p["sensitivity_priority_log_odds"]) * stratum
            + random_effects[hospital_id, 2]
        )
        probability_alert_nonevent = expit(
            logit(float(p["false_alert_baseline_probability"]))
            + float(p["false_alert_hard_log_odds"]) * q
            + float(p["false_alert_priority_log_odds"]) * stratum
            + 0.20 * random_effects[hospital_id, 1]
        )
        alert_probability = np.where(y == 1, probability_alert_event, probability_alert_nonevent)
        a = rng.binomial(1, alert_probability)

        patient_frames.append(
            pd.DataFrame(
                {
                    "hospital_id": hospital_id,
                    "hospital_stratum": stratum,
                    "hard_subgroup": q.astype(int),
                    "outcome": y.astype(int),
                    "alert": a.astype(int),
                }
            )
        )

    population = pd.concat(patient_frames, ignore_index=True)
    population["true_positive"] = population["outcome"] * population["alert"]

    aggregate_rows: list[dict[str, int]] = []
    for hospital_id, data in population.groupby("hospital_id", sort=True):
        row: dict[str, int] = {
            "hospital_id": int(hospital_id),
            "hospital_stratum": int(data["hospital_stratum"].iloc[0]),
            "N": int(len(data)),
            "Q": int(data["hard_subgroup"].sum()),
            "Y": int(data["outcome"].sum()),
            "TP": int(data["true_positive"].sum()),
        }
        for q in (0, 1):
            subgroup = data.loc[data["hard_subgroup"] == q]
            row[f"N_q{q}"] = int(len(subgroup))
            row[f"Y_q{q}"] = int(subgroup["outcome"].sum())
            row[f"TP_q{q}"] = int(subgroup["true_positive"].sum())
        aggregate_rows.append(row)
    hospitals = pd.DataFrame(aggregate_rows).sort_values("hospital_id").reset_index(drop=True)
    return population, hospitals


def target_truths(population: pd.DataFrame) -> pd.DataFrame:
    rows = []
    masks = {
        "national": np.ones(len(population), dtype=bool),
        "easy": population["hard_subgroup"].eq(0).to_numpy(),
        "hard": population["hard_subgroup"].eq(1).to_numpy(),
    }
    for estimand, mask in masks.items():
        data = population.loc[mask]
        y_total = int(data["outcome"].sum())
        tp_total = int(data["true_positive"].sum())
        rows.append(
            {
                "estimand": estimand,
                "target_parameter": tp_total / y_total,
                "eligible_patients": int(len(data)),
                "positive_cases": y_total,
                "event_prevalence": y_total / len(data),
            }
        )
    return pd.DataFrame(rows)


def observation_parameters(population: pd.DataFrame, config: dict[str, Any]) -> pd.DataFrame:
    """Exact finite-population P_O parameters from first-order inclusion probabilities."""
    h0 = int(config["population"]["hospitals_standard"])
    h1 = int(config["population"]["hospitals_priority"])
    truths = target_truths(population).set_index("estimand")["target_parameter"].to_dict()
    rows: list[dict[str, float | str | int]] = []
    masks = {
        "national": np.ones(len(population), dtype=bool),
        "easy": population["hard_subgroup"].eq(0).to_numpy(),
        "hard": population["hard_subgroup"].eq(1).to_numpy(),
    }
    for m in config["designs"]["hospital_sample_sizes"]:
        m = int(m)
        allocations = {
            "N1": None,
            "N2": config["designs"]["proportional_allocations"][str(m)],
            "N3": config["designs"]["enriched_allocations"][str(m)],
            "N4": config["designs"]["enriched_allocations"][str(m)],
            "N5": config["designs"]["enriched_allocations"][str(m)],
        }
        for strategy, allocation in allocations.items():
            if strategy == "N1":
                pi = np.ones(len(population), dtype=float)
            else:
                m0, m1 = (int(allocation[0]), int(allocation[1]))
                pi = np.where(
                    population["hospital_stratum"].to_numpy() == 0,
                    m0 / h0,
                    m1 / h1,
                )
            for estimand, mask in masks.items():
                data = population.loc[mask]
                weights = pi[mask]
                theta_o = float(
                    np.sum(weights * data["true_positive"].to_numpy())
                    / np.sum(weights * data["outcome"].to_numpy())
                )
                rows.append(
                    {
                        "hospital_sample_size": m,
                        "strategy": strategy,
                        "estimand": estimand,
                        "target_parameter": float(truths[estimand]),
                        "observation_parameter": theta_o,
                        "reference_target_discrepancy": theta_o - float(truths[estimand]),
                    }
                )
    return pd.DataFrame(rows)


def patient_srs_cells(population: pd.DataFrame) -> np.ndarray:
    cells = np.zeros((2, 2, 3), dtype=np.int64)
    for h in (0, 1):
        for q in (0, 1):
            data = population.loc[
                (population["hospital_stratum"] == h)
                & (population["hard_subgroup"] == q)
            ]
            cells[h, q, 2] = int(((data["outcome"] == 1) & (data["alert"] == 1)).sum())
            cells[h, q, 1] = int(((data["outcome"] == 1) & (data["alert"] == 0)).sum())
            cells[h, q, 0] = int((data["outcome"] == 0).sum())
    return cells
