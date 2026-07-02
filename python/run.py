"""Run the fixed-population Monte Carlo experiment."""
from __future__ import annotations

import argparse
from pathlib import Path
import time

import numpy as np
import pandas as pd

from dgp import deterministic_seed, generate_population, load_config, patient_srs_cells
from designs import draw_hospitals, expected_patient_srs_size
from estimators import estimate_hospital_sample, estimate_patient_srs


def run_experiment(project: Path, replications: int | None = None) -> pd.DataFrame:
    config = load_config(project / "config" / "config.yaml")
    population, hospitals = generate_population(config)
    population.to_csv(project / "results" / "raw" / "finite_population.csv.gz", index=False, compression="gzip")
    hospitals.to_csv(project / "results" / "raw" / "hospital_aggregates.csv", index=False)

    master = int(config["project"]["master_seed"])
    language = str(config["project"]["language_tag"])
    replications = int(replications or config["project"]["monte_carlo_replications"])
    h0 = int(config["population"]["hospitals_standard"])
    h1 = int(config["population"]["hospitals_priority"])
    total_hospitals = h0 + h1
    total_patients = len(population)

    arrays = {name: hospitals[name].to_numpy() for name in hospitals.columns if name not in {"hospital_id"}}
    indices0 = np.flatnonzero(arrays["hospital_stratum"] == 0)
    indices1 = np.flatnonzero(arrays["hospital_stratum"] == 1)
    cells = patient_srs_cells(population)

    rows: list[dict[str, float | int | str]] = []
    start = time.time()
    for hospital_sample_size in config["designs"]["hospital_sample_sizes"]:
        m = int(hospital_sample_size)
        proportional = tuple(int(x) for x in config["designs"]["proportional_allocations"][str(m)])
        enriched = tuple(int(x) for x in config["designs"]["enriched_allocations"][str(m)])
        n1 = expected_patient_srs_size(total_patients, total_hospitals, m)

        for replication in range(replications):
            # N1: ideal patient SRS benchmark.
            rng = np.random.default_rng(deterministic_seed(master, "N1", m, replication, language))
            draw = rng.multivariate_hypergeometric(cells.ravel(), n1).reshape(cells.shape)
            _append_results(
                rows,
                "N1",
                m,
                replication,
                estimate_patient_srs(draw, n1, total_patients),
                n1,
                int(draw[:, 1, 1:].sum()),
                draw[1, :, :].sum() / n1,
                draw[:, 1, :].sum() / n1,
            )

            # N2: proportional hospital stratification and design-aware ratio.
            rng = np.random.default_rng(deterministic_seed(master, "N2", m, replication, language))
            selected0, selected1 = draw_hospitals(rng, indices0, indices1, proportional)
            selected = np.r_[selected0, selected1]
            n_observed = int(arrays["N"][selected].sum())
            q_observed = int(arrays["Q"][selected].sum())
            _append_results(
                rows,
                "N2",
                m,
                replication,
                estimate_hospital_sample(arrays, selected0, selected1, h0, h1, "design"),
                n_observed,
                int(arrays["Y_q1"][selected].sum()),
                float(arrays["N"][selected1].sum() / n_observed),
                float(q_observed / n_observed),
            )

            # N3-N5: exactly the same enriched ORP in each replication.
            rng = np.random.default_rng(deterministic_seed(master, "ENRICHED", m, replication, language))
            selected0, selected1 = draw_hospitals(rng, indices0, indices1, enriched)
            selected = np.r_[selected0, selected1]
            n_observed = int(arrays["N"][selected].sum())
            q_observed = int(arrays["Q"][selected].sum())
            shared = {
                "N3": estimate_hospital_sample(arrays, selected0, selected1, h0, h1, "unweighted"),
                "N4": estimate_hospital_sample(arrays, selected0, selected1, h0, h1, "design"),
                "N5": estimate_hospital_sample(arrays, selected0, selected1, h0, h1, "naive"),
            }
            for strategy, estimates in shared.items():
                _append_results(
                    rows,
                    strategy,
                    m,
                    replication,
                    estimates,
                    n_observed,
                    int(arrays["Y_q1"][selected].sum()),
                    float(arrays["N"][selected1].sum() / n_observed),
                    float(q_observed / n_observed),
                )

        elapsed = time.time() - start
        print(f"Completed m={m}: {replications} replications ({elapsed:.1f} seconds elapsed).", flush=True)

    raw = pd.DataFrame(rows)
    raw.to_csv(project / "results" / "raw" / "replications.csv.gz", index=False, compression="gzip")
    return raw


def _append_results(
    rows: list[dict[str, float | int | str]],
    strategy: str,
    m: int,
    replication: int,
    estimates: dict[str, dict[str, float]],
    observed_patients: int,
    hard_positive_cases: int,
    observed_priority_share: float,
    observed_hard_share: float,
) -> None:
    for estimand, result in estimates.items():
        rows.append(
            {
                "strategy": strategy,
                "hospital_sample_size": m,
                "replication": replication,
                "estimand": estimand,
                **result,
                "observed_patients": observed_patients,
                "hard_positive_cases": hard_positive_cases,
                "observed_priority_share": observed_priority_share,
                "observed_hard_share": observed_hard_share,
            }
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--replications", type=int, default=None)
    args = parser.parse_args()
    run_experiment(args.project, args.replications)


if __name__ == "__main__":
    main()
