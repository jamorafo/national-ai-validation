"""Create Python validation figures. Final publication figures are regenerated in R."""
from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from dgp import generate_population, load_config

STRATEGY_LABELS = {
    "N1": "N1 Patient SRS",
    "N2": "N2 Proportional hospitals",
    "N3": "N3 Enriched, unweighted",
    "N4": "N4 Enriched, design-weighted",
    "N5": "N5 Enriched, naive variance",
}
MARKERS = {"N1": "o", "N2": "s", "N3": "D", "N4": "^", "N5": "P"}
LINESTYLES = {"N1": "-", "N2": "--", "N3": "-", "N4": "-.", "N5": ":"}


def save_figure(fig: plt.Figure, outdir: Path, stem: str) -> None:
    fig.tight_layout()
    for extension in ("pdf", "svg", "png"):
        kwargs = {"dpi": 320} if extension == "png" else {}
        fig.savefig(outdir / f"{stem}.{extension}", bbox_inches="tight", **kwargs)
    plt.close(fig)


def make_figures(project: Path) -> None:
    outdir = project / "figures" / "python_validation"
    outdir.mkdir(parents=True, exist_ok=True)
    config = load_config(project / "config" / "config.yaml")
    population, _ = generate_population(config)
    summary = pd.read_csv(project / "results" / "summary" / "performance_summary.csv")
    observations = pd.read_csv(project / "results" / "summary" / "observation_parameters.csv")
    tac = pd.read_csv(project / "results" / "summary" / "tac_frequencies.csv")
    counts = pd.read_csv(project / "results" / "summary" / "hard_positive_count_quantiles.csv")
    raw = pd.read_csv(project / "results" / "raw" / "replications.csv.gz")

    plt.rcParams.update(
        {
            "font.size": 10,
            "axes.titlesize": 12,
            "axes.labelsize": 10,
            "legend.fontsize": 8.5,
            "figure.titlesize": 14,
            "axes.spines.top": False,
            "axes.spines.right": False,
            "grid.alpha": 0.25,
        }
    )

    # 1. Finite-population structure.
    structure = []
    for h, data in population.groupby("hospital_stratum"):
        structure.extend(
            [
                (h, "Hard-subgroup prevalence", data["hard_subgroup"].mean()),
                (h, "Event prevalence", data["outcome"].mean()),
                (h, "Sensitivity", data["true_positive"].sum() / data["outcome"].sum()),
            ]
        )
    structure = pd.DataFrame(structure, columns=["H", "quantity", "value"])
    fig, ax = plt.subplots(figsize=(8.4, 4.8))
    x = np.arange(3)
    width = 0.34
    for offset, h in zip((-width / 2, width / 2), (0, 1), strict=True):
        data = structure.loc[structure["H"] == h]
        bars = ax.bar(x + offset, data["value"], width=width, label=f"Hospital stratum H={h}")
        ax.bar_label(bars, labels=[f"{v:.3f}" for v in data["value"]], padding=3, fontsize=8)
    ax.set_xticks(x, structure.loc[structure["H"] == 0, "quantity"])
    ax.set_ylim(0, 1.03)
    ax.set_ylabel("Finite-population proportion")
    ax.set_title("The priority hospital stratum is higher-yield and lower-performing")
    ax.legend(frameon=False, loc="upper left")
    ax.grid(axis="y")
    save_figure(fig, outdir, "nav_fig1_population_structure")

    # 2. P_T versus P_O parameters.
    data = observations.loc[
        (observations["strategy"] == "N3") & (observations["hospital_sample_size"] == 160)
    ].copy()
    order = ["national", "easy", "hard"]
    data["estimand"] = pd.Categorical(data["estimand"], order, ordered=True)
    data = data.sort_values("estimand")
    fig, ax = plt.subplots(figsize=(8.2, 4.8))
    y = np.arange(len(data))
    for i, row in enumerate(data.itertuples()):
        ax.plot([row.observation_parameter, row.target_parameter], [i, i], color="0.65", linewidth=3)
    ax.scatter(data["target_parameter"], y, marker="o", s=60, label=r"Target parameter $\theta_T$")
    ax.scatter(data["observation_parameter"], y, marker="D", s=55, label=r"Enriched $\theta_{\mathcal{O}}$")
    for i, row in enumerate(data.itertuples()):
        ax.text(
            min(row.target_parameter, row.observation_parameter) - 0.006,
            i,
            f"RTD {row.reference_target_discrepancy:+.3f}",
            ha="right",
            va="center",
            fontsize=8.5,
        )
    ax.axvline(float(config["target"]["adequacy_threshold"]), color="0.25", linestyle="--", linewidth=1.2, label="TAC threshold 0.85")
    ax.set_yticks(y, ["National", "Easier subgroup", "Harder subgroup"])
    ax.set_xlim(0.66, 0.98)
    ax.set_xlabel("Sensitivity")
    ax.set_title("Enrichment changes the unweighted observation parameter, not the target")
    ax.legend(frameon=False, ncol=3, loc="lower center", bbox_to_anchor=(0.5, -0.25))
    ax.grid(axis="x")
    save_figure(fig, outdir, "nav_fig2_target_observation_parameters")

    # 3. Bias by estimand.
    fig, axes = plt.subplots(1, 3, figsize=(13.8, 4.3), sharex=True)
    for ax, estimand in zip(axes, ["national", "easy", "hard"], strict=True):
        block = summary.loc[summary["estimand"] == estimand]
        for strategy in STRATEGY_LABELS:
            d = block.loc[block["strategy"] == strategy]
            ax.plot(
                d["hospital_sample_size"],
                d["bias"],
                marker=MARKERS[strategy],
                linestyle=LINESTYLES[strategy],
                label=STRATEGY_LABELS[strategy],
            )
        ax.axhline(0, color="0.25", linewidth=1)
        ax.axhline(0.03, color="0.55", linestyle=":", linewidth=1)
        ax.axhline(-0.03, color="0.55", linestyle=":", linewidth=1)
        ax.set_title(estimand.capitalize())
        ax.set_xlabel("Hospitals selected, m")
        ax.grid(axis="y")
    axes[0].set_ylabel("Bias in sensitivity")
    handles, labels = axes[0].get_legend_handles_labels()
    fig.suptitle("National bias depends on the design-estimator pairing")
    fig.legend(handles, labels, frameon=False, ncol=3, loc="lower center", bbox_to_anchor=(0.5, -0.04))
    fig.subplots_adjust(bottom=0.23)
    save_figure(fig, outdir, "nav_fig3_bias")

    # 4. RMSE by estimand.
    fig, axes = plt.subplots(1, 3, figsize=(13.8, 4.3), sharex=True)
    for ax, estimand in zip(axes, ["national", "easy", "hard"], strict=True):
        block = summary.loc[summary["estimand"] == estimand]
        for strategy in STRATEGY_LABELS:
            d = block.loc[block["strategy"] == strategy]
            ax.plot(
                d["hospital_sample_size"],
                d["rmse"],
                marker=MARKERS[strategy],
                linestyle=LINESTYLES[strategy],
                label=STRATEGY_LABELS[strategy],
            )
        ax.set_title(estimand.capitalize())
        ax.set_xlabel("Hospitals selected, m")
        ax.grid(axis="y")
    axes[0].set_ylabel("RMSE of sensitivity")
    handles, labels = axes[0].get_legend_handles_labels()
    fig.suptitle("Compatible weighting converts enrichment into usable evidence")
    fig.legend(handles, labels, frameon=False, ncol=3, loc="lower center", bbox_to_anchor=(0.5, -0.04))
    fig.subplots_adjust(bottom=0.23)
    save_figure(fig, outdir, "nav_fig4_rmse")

    # 5. N4 versus N5 coverage.
    fig, ax = plt.subplots(figsize=(8.3, 4.8))
    block = summary.loc[(summary["estimand"] == "national") & (summary["strategy"].isin(["N4", "N5"]))]
    for strategy in ("N4", "N5"):
        d = block.loc[block["strategy"] == strategy]
        ax.plot(d["hospital_sample_size"], d["target_coverage"], marker=MARKERS[strategy], linewidth=2, label=STRATEGY_LABELS[strategy])
    ax.axhline(0.95, color="0.25", linestyle="--", linewidth=1.2)
    ax.axhspan(0.925, 0.975, color="0.85", alpha=0.45, label="95% coverage diagnostic band")
    ax.set_ylim(0.78, 0.985)
    ax.set_xlabel("Hospitals selected, m")
    ax.set_ylabel("Empirical coverage of target sensitivity")
    ax.set_title("The same point estimator does not imply the same evidentiary reliability")
    ax.legend(frameon=False)
    ax.grid(axis="y")
    save_figure(fig, outdir, "nav_fig5_coverage_n4_n5")

    # 6. Hard-positive evidence yield.
    fig, ax = plt.subplots(figsize=(8.3, 4.8))
    for strategy, offset in (("N2", -2.0), ("N4", 2.0)):
        d = counts.loc[counts["strategy"] == strategy]
        x = d["hospital_sample_size"].to_numpy() + offset
        y = d["median"].to_numpy()
        lower = y - d["p05"].to_numpy()
        upper = d["p95"].to_numpy() - y
        ax.errorbar(x, y, yerr=np.vstack([lower, upper]), fmt=MARKERS[strategy], capsize=4, linewidth=1.4, label=STRATEGY_LABELS[strategy])
    ax.set_xlabel("Hospitals selected, m")
    ax.set_ylabel("Hard-subgroup positive cases (median; P5-P95)")
    ax.set_title("Prospective hospital enrichment increases evidence for the harder subgroup")
    ax.legend(frameon=False)
    ax.grid(axis="y")
    save_figure(fig, outdir, "nav_fig6_hard_positive_yield")

    # 7. Full evidential status heat map.
    strategies = list(STRATEGY_LABELS)
    estimands = ["national", "easy", "hard"]
    cells = []
    labels = []
    for strategy in strategies:
        for estimand in estimands:
            for m in sorted(summary["hospital_sample_size"].unique()):
                row = summary.loc[
                    (summary["strategy"] == strategy)
                    & (summary["estimand"] == estimand)
                    & (summary["hospital_sample_size"] == m)
                ].iloc[0]
                cells.append(bool(row["full_evidential_pass"]))
                labels.append((strategy, estimand, m))
    matrix = np.array(cells, dtype=int).reshape(len(strategies) * len(estimands), -1)
    fig, ax = plt.subplots(figsize=(8.4, 7.0))
    ax.imshow(matrix, aspect="auto", vmin=0, vmax=1, cmap="Greys")
    for i in range(matrix.shape[0]):
        for j in range(matrix.shape[1]):
            ax.text(j, i, "Pass" if matrix[i, j] else "Insufficient", ha="center", va="center", fontsize=7.5, color="white" if matrix[i, j] else "black")
    ax.set_xticks(range(matrix.shape[1]), sorted(summary["hospital_sample_size"].unique()))
    ax.set_xlabel("Hospitals selected, m")
    ax.set_yticks(
        range(matrix.shape[0]),
        [f"{s} - {e}" for s in strategies for e in ("National", "Easy", "Hard")],
    )
    ax.set_title("Evidential adequacy is strategy-, sample-size-, and estimand-specific")
    save_figure(fig, outdir, "nav_fig7_evidential_status")

    # 8. Formal TAC decisions at m=160.
    data = tac.loc[(tac["hospital_sample_size"] == 160) & (tac["estimand"].isin(["national", "hard"]))].copy()
    statuses = ["Adequate", "Inconclusive", "Not adequate", "Evidentially insufficient"]
    groups = [(s, e) for e in ("national", "hard") for s in STRATEGY_LABELS]
    bottom = np.zeros(len(groups))
    fig, ax = plt.subplots(figsize=(11.5, 5.2))
    for status in statuses:
        values = []
        for strategy, estimand in groups:
            match = data.loc[(data["strategy"] == strategy) & (data["estimand"] == estimand) & (data["formal_tac"] == status), "proportion"]
            values.append(float(match.iloc[0]) if len(match) else 0.0)
        ax.bar(range(len(groups)), values, bottom=bottom, label=status)
        bottom += np.array(values)
    ax.axvline(4.5, color="0.4", linewidth=1)
    ax.text(2, 1.05, "National sensitivity", ha="center", fontweight="bold")
    ax.text(7, 1.05, "Hard-subgroup sensitivity", ha="center", fontweight="bold")
    ax.set_xticks(range(len(groups)), [g[0] for g in groups])
    ax.set_ylim(0, 1.11)
    ax.set_ylabel("Decision frequency")
    ax.set_title("TAC is applied only after the evidential gate (m=160)")
    ax.legend(frameon=False, ncol=4, loc="lower center", bbox_to_anchor=(0.5, -0.25))
    ax.grid(axis="y")
    save_figure(fig, outdir, "nav_fig8_tac")

    # 9. More data reduce sampling error around the wrong N3 parameter.
    n3 = raw.loc[(raw["strategy"] == "N3") & (raw["estimand"] == "national")]
    q = n3.groupby("hospital_sample_size")["estimate"].quantile([0.025, 0.50, 0.975]).unstack()
    obs_n = observations.loc[(observations["strategy"] == "N3") & (observations["estimand"] == "national")].iloc[0]
    fig, ax = plt.subplots(figsize=(8.4, 4.9))
    x = q.index.to_numpy()
    ax.fill_between(x, q[0.025], q[0.975], alpha=0.22, label="Central 95% of N3 estimates")
    ax.plot(x, q[0.50], marker="o", linewidth=2, label="Median N3 estimate")
    ax.axhline(obs_n["observation_parameter"], linestyle=":", linewidth=1.8, label=r"Enriched reference parameter $\theta_{\mathcal{O},3}$")
    ax.axhline(obs_n["target_parameter"], linestyle="--", linewidth=1.8, label=r"Target parameter $\theta_T$")
    ax.axhline(float(config["target"]["adequacy_threshold"]), color="0.25", linewidth=1.1, label="TAC threshold 0.85")
    ax.annotate(
        f"RTD = {obs_n['reference_target_discrepancy']:+.3f}",
        xy=(158, (obs_n["target_parameter"] + obs_n["observation_parameter"]) / 2),
        xytext=(145, 0.865),
        arrowprops={"arrowstyle": "<->", "color": "0.25"},
        ha="right",
    )
    ax.set_xlabel("Hospitals selected, m")
    ax.set_ylabel("National sensitivity")
    ax.set_title("Precision increases around the observation parameter; validity does not")
    ax.legend(frameon=False, ncol=2, loc="lower center", bbox_to_anchor=(0.5, -0.30))
    ax.grid(axis="y")
    save_figure(fig, outdir, "nav_fig9_large_wrong_orp")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    make_figures(args.project)


if __name__ == "__main__":
    main()
