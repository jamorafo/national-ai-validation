"""Create dissertation-ready booktabs LaTeX tables."""
from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd


def status(value: bool) -> str:
    return "Pass" if bool(value) else "Fail"


def write_table(path: Path, caption: str, label: str, columns: str, header: str, rows: list[str], notes: str = "") -> None:
    text = [
        "\\begin{table}[h!]",
        "\\centering",
        "\\small",
        f"\\caption{{{caption}}}",
        f"\\label{{{label}}}",
        f"\\begin{{tabular}}{{{columns}}}",
        "\\toprule",
        header + " \\\\",
        "\\midrule",
        *[row + " \\\\" for row in rows],
        "\\bottomrule",
        "\\end{tabular}",
    ]
    if notes:
        text.extend(["\\par\\vspace{2pt}", f"\\begin{{minipage}}{{0.97\\linewidth}}\\footnotesize {notes}\\end{{minipage}}"])
    text.append("\\end{table}\n")
    path.write_text("\n".join(text), encoding="utf-8")


def _summary_csv(project: Path, stem: str, suffix: str) -> Path:
    """Return a summary CSV path by stem and optional suffix.

    suffix="_R" makes the table formatter read the R-generated files, e.g.
    performance_summary_R.csv. With no suffix, the formatter keeps the original
    Python behaviour. A small legacy fallback is kept for observation_parameters2.csv,
    because one project snapshot used that name for the Python output.
    """
    summary_dir = project / "results" / "summary"
    path = summary_dir / f"{stem}{suffix}.csv"
    if path.exists():
        return path
    if stem == "observation_parameters" and suffix == "":
        legacy = summary_dir / "observation_parameters2.csv"
        if legacy.exists():
            return legacy
    raise FileNotFoundError(f"Required summary file not found: {path}")


def make_tables(project: Path, suffix: str = "") -> None:
    out = project / "tables"
    out.mkdir(exist_ok=True)
    truth = pd.read_csv(_summary_csv(project, "target_truths", suffix))
    obs = pd.read_csv(_summary_csv(project, "observation_parameters", suffix))
    perf = pd.read_csv(_summary_csv(project, "performance_summary", suffix))
    tac = pd.read_csv(_summary_csv(project, "tac_frequencies", suffix))
    counts = pd.read_csv(_summary_csv(project, "hard_positive_count_quantiles", suffix))

    rows = [
        f"{r.estimand.capitalize()} & {int(r.eligible_patients):,} & {int(r.positive_cases):,} & {r.event_prevalence:.3f} & {r.target_parameter:.4f}"
        for r in truth.itertuples()
    ]
    write_table(
        out / "nav_table_population_truths.tex",
        "Fixed finite-population target quantities.",
        "tab:nav-population-truths",
        "lrrrr",
        "Estimand & Eligible patients & Positive cases & Event prevalence & Sensitivity",
        rows,
        "The harder subgroup is defined at the patient level and occurs in both hospital design strata.",
    )

    strategy_rows = [
        "N1 & Patient SRSWOR & Ordinary sensitivity ratio & Patient-SRS ratio linearisation & Ideal self-weighting benchmark",
        "N2 & Proportional stratified hospital SRS & Design-weighted combined ratio & Stratified cluster Taylor linearisation & Realistic target-aligned design",
        "N3 & Enriched stratified hospital SRS & Unweighted pooled ratio & Cluster-aware variance around $\\theta_{\\mathcal O,3}$ & Deliberate estimator mismatch",
        "N4 & Same enriched ORP as N3 & Design-weighted combined ratio & Stratified cluster Taylor linearisation & Compatible enrichment",
        "N5 & Same enriched ORP and point estimate as N4 & Design-weighted combined ratio & Naive patient-level variance & Deliberate uncertainty mismatch",
    ]
    write_table(
        out / "nav_table_strategies.tex",
        "Probability construction, estimator, and uncertainty procedure for the five strategies.",
        "tab:nav-strategies",
        "lp{0.19\\linewidth}p{0.20\\linewidth}p{0.23\\linewidth}p{0.18\\linewidth}",
        "Strategy & Construction process & Point estimator & Variance procedure & Role",
        strategy_rows,
    )

    enriched_obs = obs.loc[(obs["strategy"] == "N3") & (obs["hospital_sample_size"] == 160)]
    rows = [
        f"{r.estimand.capitalize()} & {r.target_parameter:.4f} & {r.observation_parameter:.4f} & {r.reference_target_discrepancy:+.4f}"
        for r in enriched_obs.itertuples()
    ]
    write_table(
        out / "nav_table_observation_parameters.tex",
        "Target and design-induced unweighted observation parameters for the enriched ORP.",
        "tab:nav-observation-parameters",
        "lrrr",
        "Estimand & $\\theta_T$ & $\\theta_{\\mathcal O,3}$ & RTD",
        rows,
        "The inclusion-probability ratio between priority and standard hospitals is three for every enriched sample-size condition, so the observation parameters do not depend on $m$.",
    )

    national = perf.loc[perf["estimand"] == "national"].sort_values(["hospital_sample_size", "strategy"])
    rows = []
    for r in national.itertuples():
        rows.append(
            f"{int(r.hospital_sample_size)} & {r.strategy} & {r.bias:+.4f} & {r.empirical_sd:.4f} & {r.rmse:.4f} & {r.mean_estimated_se:.4f} & {r.target_coverage:.3f} & {status(r.full_evidential_pass)}"
        )
    write_table(
        out / "nav_table_national_performance.tex",
        "Monte Carlo performance for national sensitivity.",
        "tab:nav-national-performance",
        "rrlrrrrr",
        "$m$ & Strategy & Bias & ESD & RMSE & Mean SE & Coverage & Evidence",
        rows,
        "Evidence is marked Pass only when the bias and precision tolerances are met, target interval coverage is acceptable, and the declared variance procedure is design-compatible.",
    )

    variance = perf.loc[(perf["estimand"] == "national") & (perf["strategy"].isin(["N4", "N5"]))].sort_values(["hospital_sample_size", "strategy"])
    rows = [
        f"{int(r.hospital_sample_size)} & {r.strategy} & {r.empirical_sd:.4f} & {r.mean_estimated_se:.4f} & {r.se_to_esd_ratio:.3f} & {r.target_coverage:.3f} & {r.mean_interval_width:.4f}"
        for r in variance.itertuples()
    ]
    write_table(
        out / "nav_table_variance_comparison.tex",
        "Same enriched samples and point estimates, different uncertainty procedures.",
        "tab:nav-variance-comparison",
        "rrlrrrr",
        "$m$ & Strategy & ESD & Mean SE & SE/ESD & Coverage & Mean width",
        rows,
        "N4 and N5 have numerically identical point estimates in every replication. Differences arise only from the uncertainty procedure.",
    )

    hard = perf.loc[(perf["estimand"] == "hard") & (perf["strategy"].isin(["N2", "N4"]))].sort_values(["hospital_sample_size", "strategy"])
    rows = [
        f"{int(r.hospital_sample_size)} & {r.strategy} & {r.mean_hard_positive_cases:.1f} & {r.empirical_sd:.4f} & {r.rmse:.4f} & {status(r.pr_precision_pass)} & {status(r.full_evidential_pass)}"
        for r in hard.itertuples()
    ]
    write_table(
        out / "nav_table_hard_evidence.tex",
        "Effect of enrichment on harder-subgroup evidence.",
        "tab:nav-hard-evidence",
        "rrlrrrr",
        "$m$ & Strategy & Mean hard positives & ESD & RMSE & Precision & Evidence",
        rows,
        "At $m=160$, N4 passes the pre-specified precision criterion for harder-subgroup sensitivity, whereas N2 remains evidentially insufficient.",
    )

    pr160 = perf.loc[perf["hospital_sample_size"] == 160].sort_values(["strategy", "estimand"])
    rows = [
        f"{r.strategy} & {r.estimand.capitalize()} & {status(r.pr_bias_pass)} & {status(r.pr_precision_pass)} & {status(r.interval_validity_pass)} & {status(r.variance_method_compatible)} & {status(r.full_evidential_pass)}"
        for r in pr160.itertuples()
    ]
    write_table(
        out / "nav_table_pr_status.tex",
        "Predictive Representativity and uncertainty diagnostics at $m=160$.",
        "tab:nav-pr-status",
        "llrrrrr",
        "Strategy & Estimand & Bias & Precision & Coverage & $V_k$ compatible & Full evidence",
        rows,
    )

    tac160 = tac.loc[tac["hospital_sample_size"] == 160].copy()
    pivot = tac160.pivot_table(
        index=["strategy", "estimand"],
        columns="formal_tac",
        values="proportion",
        fill_value=0,
    ).reset_index()
    for col in ["Adequate", "Inconclusive", "Not adequate", "Evidentially insufficient"]:
        if col not in pivot:
            pivot[col] = 0.0
    rows = []
    for _, r in pivot.iterrows():
        rows.append(
            f"{r['strategy']} & {r['estimand'].capitalize()} & {r['Adequate']:.3f} & {r['Inconclusive']:.3f} & {r['Not adequate']:.3f} & {r['Evidentially insufficient']:.3f}"
        )
    write_table(
        out / "nav_table_tac.tex",
        "Formal TAC decision frequencies at $m=160$.",
        "tab:nav-tac",
        "llrrrr",
        "Strategy & Estimand & Adequate & Inconclusive & Not adequate & Evidentially insufficient",
        rows,
        "Mechanical threshold results are suppressed whenever the full evidential gate fails.",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument(
        "--suffix",
        default="",
        choices=["", "_R"],
        help="Read suffixed summary files. Use --suffix _R for the R simulation outputs.",
    )
    args = parser.parse_args()
    make_tables(args.project, suffix=args.suffix)


if __name__ == "__main__":
    main()
