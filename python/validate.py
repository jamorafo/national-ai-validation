"""Fail-loud implementation checks requested in the simulation protocol."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import platform

import numpy as np
import pandas as pd
import scipy
import yaml

from dgp import generate_population, load_config, observation_parameters, target_truths


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate(project: Path) -> dict:
    config_path = project / "config" / "config.yaml"
    config = load_config(config_path)
    population, hospitals = generate_population(config)
    raw = pd.read_csv(project / "results" / "raw" / "replications.csv.gz")
    summary = pd.read_csv(project / "results" / "summary" / "performance_summary.csv")
    observations = observation_parameters(population, config)
    truths = target_truths(population)

    checks: dict[str, dict[str, object]] = {}
    def record(name: str, passed: bool, detail: str) -> None:
        checks[name] = {"passed": bool(passed), "detail": detail}
        if not passed:
            raise AssertionError(f"{name}: {detail}")

    h0 = int(config["population"]["hospitals_standard"])
    h1 = int(config["population"]["hospitals_priority"])
    probabilities = []
    for m in config["designs"]["hospital_sample_sizes"]:
        for allocation_name in ("proportional_allocations", "enriched_allocations"):
            m0, m1 = config["designs"][allocation_name][str(m)]
            probabilities.extend([m0 / h0, m1 / h1])
    record("inclusion_probabilities", all(0 < x <= 1 for x in probabilities), str(probabilities))

    columns_text = " ".join(raw.columns).lower()
    record("no_month_sampling", "month" not in columns_text, "No month variable appears in replication output.")
    record("fixed_period", config["project"]["audit_period"] == "fixed_common_period", config["project"]["audit_period"])

    enriched = raw.loc[raw["strategy"].isin(["N3", "N4", "N5"])]
    sample_identity = enriched.groupby(["hospital_sample_size", "replication", "estimand"])[
        ["observed_patients", "hard_positive_cases", "observed_priority_share", "observed_hard_share"]
    ].nunique().max().max()
    record("N3_N4_N5_same_orp", sample_identity == 1, f"Maximum within-replication unique count: {sample_identity}")

    pair = raw.loc[raw["strategy"].isin(["N4", "N5"])].pivot_table(
        index=["hospital_sample_size", "replication", "estimand"], columns="strategy", values="estimate"
    )
    difference = float(np.nanmax(np.abs(pair["N4"] - pair["N5"])))
    record("N4_N5_identical_points", difference < 1e-14, f"Maximum absolute difference: {difference}")

    truth_direct = {
        "national": population["true_positive"].sum() / population["outcome"].sum(),
        "easy": population.loc[population["hard_subgroup"] == 0, "true_positive"].sum()
        / population.loc[population["hard_subgroup"] == 0, "outcome"].sum(),
        "hard": population.loc[population["hard_subgroup"] == 1, "true_positive"].sum()
        / population.loc[population["hard_subgroup"] == 1, "outcome"].sum(),
    }
    truth_table = truths.set_index("estimand")["target_parameter"].to_dict()
    record("truths_match_enumeration", max(abs(truth_direct[k] - truth_table[k]) for k in truth_direct) < 1e-14, str(truth_direct))

    n1_bias = summary.loc[summary["strategy"] == "N1", "bias"].abs().max()
    record("N1_approximately_unbiased", n1_bias < 0.005, f"Maximum absolute bias: {n1_bias:.6f}")
    n4_bias = summary.loc[summary["strategy"] == "N4", "bias"].abs().max()
    record("N4_design_consistent", n4_bias < 0.0075, f"Maximum absolute bias: {n4_bias:.6f}")

    n3 = summary.loc[(summary["strategy"] == "N3") & (summary["estimand"] == "national")].copy()
    convergence_gap = (n3["mean_estimate"] - n3["reference_parameter"]).abs()
    record("N3_targets_observation_parameter", convergence_gap.iloc[-1] < convergence_gap.iloc[0], str(convergence_gap.tolist()))

    n4n5 = summary.loc[summary["strategy"].isin(["N4", "N5"])].pivot_table(
        index=["hospital_sample_size", "estimand"], columns="strategy", values="empirical_sd"
    )
    record("N4_N5_same_empirical_distribution", float((n4n5["N4"] - n4n5["N5"]).abs().max()) < 1e-14, "Empirical SDs are identical.")

    n5_national = summary.loc[(summary["strategy"] == "N5") & (summary["estimand"] == "national")]
    record("N5_naive_variance_detected", bool((n5_national["target_coverage"] < 0.925).any()), str(n5_national[["hospital_sample_size", "target_coverage"]].to_dict("records")))

    classified = pd.read_csv(project / "results" / "raw" / "replications_classified.csv.gz")
    invalid_valid_tac = classified.loc[(~classified["full_evidential_pass"]) & (classified["formal_tac"] != "Evidentially insufficient")]
    record("no_valid_TAC_after_gate_failure", len(invalid_valid_tac) == 0, f"Violating rows: {len(invalid_valid_tac)}")

    checks["metadata"] = {
        "python_version": platform.python_version(),
        "numpy_version": np.__version__,
        "pandas_version": pd.__version__,
        "scipy_version": scipy.__version__,
        "pyyaml_version": yaml.__version__,
        "config_sha256": sha256(config_path),
        "finite_population_csv_sha256": sha256(project / "results" / "raw" / "finite_population.csv.gz"),
        "replications_csv_sha256": sha256(project / "results" / "raw" / "replications.csv.gz"),
        "population_size": int(len(population)),
        "hospital_count": int(len(hospitals)),
    }
    output = project / "results" / "summary" / "validation_results.json"
    output.write_text(json.dumps(checks, indent=2), encoding="utf-8")
    return checks


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    validate(args.project)


if __name__ == "__main__":
    main()
