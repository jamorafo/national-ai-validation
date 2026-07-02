"""Summarise point estimation, uncertainty, PR and TAC operating characteristics."""
from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np
import pandas as pd

from dgp import generate_population, load_config, observation_parameters, target_truths


def mechanical_tac(lower: pd.Series, upper: pd.Series, threshold: float) -> pd.Series:
    return pd.Series(
        np.select(
            [lower >= threshold, upper < threshold],
            ["Adequate", "Not adequate"],
            default="Inconclusive",
        ),
        index=lower.index,
    )


def analyse(project: Path) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    config = load_config(project / "config" / "config.yaml")
    raw = pd.read_csv(project / "results" / "raw" / "replications.csv.gz")
    population, _ = generate_population(config)
    truths = target_truths(population)
    observations = observation_parameters(population, config)
    truths.to_csv(project / "results" / "summary" / "target_truths.csv", index=False)
    observations.to_csv(project / "results" / "summary" / "observation_parameters.csv", index=False)

    truth_map = truths.set_index("estimand")["target_parameter"].to_dict()
    observation_map = observations.set_index(["hospital_sample_size", "strategy", "estimand"])[
        "observation_parameter"
    ].to_dict()
    raw["target_parameter"] = raw["estimand"].map(truth_map)
    raw["reference_parameter"] = [
        observation_map[(int(m), strategy, estimand)]
        for m, strategy, estimand in zip(
            raw["hospital_sample_size"], raw["strategy"], raw["estimand"], strict=True
        )
    ]
    raw["target_covered"] = (
        (raw["ci_lower"] <= raw["target_parameter"])
        & (raw["ci_upper"] >= raw["target_parameter"])
    )
    raw["reference_covered"] = (
        (raw["ci_lower"] <= raw["reference_parameter"])
        & (raw["ci_upper"] >= raw["reference_parameter"])
    )
    raw["interval_width"] = raw["ci_upper"] - raw["ci_lower"]
    raw["mechanical_tac"] = mechanical_tac(
        raw["ci_lower"], raw["ci_upper"], float(config["target"]["adequacy_threshold"])
    )

    summary_rows: list[dict[str, float | int | str | bool]] = []
    for (m, strategy, estimand), data in raw.groupby(
        ["hospital_sample_size", "strategy", "estimand"], sort=True
    ):
        target = float(truth_map[estimand])
        reference = float(observation_map[(int(m), strategy, estimand)])
        valid = data.loc[data["estimate"].notna()].copy()
        errors = valid["estimate"] - target
        squared_errors = errors**2
        r = len(valid)
        bias = float(errors.mean())
        esd = float(valid["estimate"].std(ddof=1))
        variance = esd**2
        rmse = float(np.sqrt(squared_errors.mean()))
        bias_mcse = esd / math.sqrt(r)
        rmse_mcse = float(squared_errors.std(ddof=1) / (2.0 * rmse * math.sqrt(r))) if rmse > 0 else 0.0
        coverage = float(valid["target_covered"].mean())
        reference_coverage = float(valid["reference_covered"].mean())
        coverage_mcse = math.sqrt(coverage * (1.0 - coverage) / r)
        nonestimable = float(data["non_estimable"].mean())
        nonestimable_mcse = math.sqrt(nonestimable * (1.0 - nonestimable) / len(data))
        summary_rows.append(
            {
                "hospital_sample_size": int(m),
                "strategy": strategy,
                "estimand": estimand,
                "target_parameter": target,
                "reference_parameter": reference,
                "reference_target_discrepancy": reference - target,
                "mean_estimate": float(valid["estimate"].mean()),
                "bias": bias,
                "bias_mcse": bias_mcse,
                "relative_bias_percent": 100.0 * bias / target,
                "empirical_sd": esd,
                "empirical_variance": variance,
                "rmse": rmse,
                "rmse_mcse": rmse_mcse,
                "mean_estimated_se": float(valid["estimated_se"].mean()),
                "se_to_esd_ratio": float(valid["estimated_se"].mean() / esd),
                "target_coverage": coverage,
                "target_coverage_mcse": coverage_mcse,
                "reference_coverage": reference_coverage,
                "mean_interval_width": float(valid["interval_width"].mean()),
                "mean_half_width": float(valid["interval_width"].mean() / 2.0),
                "mean_positive_cases": float(valid["positive_cases"].mean()),
                "mean_hard_positive_cases": float(valid["hard_positive_cases"].mean()),
                "mean_observed_patients": float(valid["observed_patients"].mean()),
                "mean_observed_priority_share": float(valid["observed_priority_share"].mean()),
                "mean_observed_hard_share": float(valid["observed_hard_share"].mean()),
                "non_estimable_rate": nonestimable,
                "non_estimable_mcse": nonestimable_mcse,
                "replications_estimable": r,
            }
        )
    summary = pd.DataFrame(summary_rows)

    eps_b = float(config["target"]["bias_tolerance"])
    eps_h = float(config["target"]["halfwidth_tolerance"])
    eps_v = (eps_h / 1.96) ** 2
    coverage_tolerance = float(config["target"]["coverage_tolerance"])
    summary["pr_bias_pass"] = summary["bias"].abs() <= eps_b
    summary["pr_precision_pass"] = summary["empirical_variance"] <= eps_v
    summary["pr_point_estimation_pass"] = summary["pr_bias_pass"] & summary["pr_precision_pass"]
    summary["interval_validity_pass"] = (
        (summary["target_coverage"] - 0.95).abs() <= coverage_tolerance
    )
    # N3 intervals correctly describe theta_O rather than theta_T; report this explicitly.
    summary["reference_interval_validity_pass"] = (
        (summary["reference_coverage"] - 0.95).abs() <= coverage_tolerance
    )
    # Structural compatibility is part of the declared strategy. N5 is
    # deliberately incompatible because it treats weighted patients as
    # independent and ignores hospital clustering. Accidental empirical
    # coverage in one cell does not make that procedure design-compatible.
    summary["variance_method_compatible"] = summary["strategy"] != "N5"
    summary["full_evidential_pass"] = (
        summary["pr_point_estimation_pass"]
        & summary["interval_validity_pass"]
        & summary["variance_method_compatible"]
    )
    summary.to_csv(project / "results" / "summary" / "performance_summary.csv", index=False)

    raw = raw.merge(
        summary[
            [
                "hospital_sample_size",
                "strategy",
                "estimand",
                "pr_point_estimation_pass",
                "interval_validity_pass",
                "full_evidential_pass",
            ]
        ],
        on=["hospital_sample_size", "strategy", "estimand"],
        how="left",
    )
    raw["formal_tac"] = np.where(
        raw["full_evidential_pass"], raw["mechanical_tac"], "Evidentially insufficient"
    )
    raw.to_csv(project / "results" / "raw" / "replications_classified.csv.gz", index=False, compression="gzip")

    tac = (
        raw.groupby(
            ["hospital_sample_size", "strategy", "estimand", "formal_tac"], sort=True
        )
        .size()
        .rename("count")
        .reset_index()
    )
    tac["proportion"] = tac["count"] / tac.groupby(
        ["hospital_sample_size", "strategy", "estimand"]
    )["count"].transform("sum")
    total_r = int(config["project"]["monte_carlo_replications"])
    tac["proportion_mcse"] = np.sqrt(tac["proportion"] * (1 - tac["proportion"]) / total_r)
    tac.to_csv(project / "results" / "summary" / "tac_frequencies.csv", index=False)

    count_quantiles = (
        raw.drop_duplicates(["hospital_sample_size", "strategy", "replication"])
        .groupby(["hospital_sample_size", "strategy"])["hard_positive_cases"]
        .quantile([0.05, 0.25, 0.50, 0.75, 0.95])
        .unstack()
        .reset_index()
        .rename(columns={0.05: "p05", 0.25: "p25", 0.50: "median", 0.75: "p75", 0.95: "p95"})
    )
    count_quantiles.to_csv(project / "results" / "summary" / "hard_positive_count_quantiles.csv", index=False)
    return summary, tac, raw


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    analyse(args.project)


if __name__ == "__main__":
    main()
