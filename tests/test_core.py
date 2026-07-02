from pathlib import Path
import sys
import pandas as pd

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / "python"))


def test_shared_enriched_orp_and_point_estimates():
    raw = pd.read_csv(PROJECT / "results" / "raw" / "replications.csv.gz")
    shared = raw[raw.strategy.isin(["N3", "N4", "N5"])]
    uniqueness = shared.groupby(["hospital_sample_size", "replication", "estimand"])[
        ["observed_patients", "hard_positive_cases"]
    ].nunique()
    assert uniqueness.to_numpy().max() == 1
    points = raw[raw.strategy.isin(["N4", "N5"])].pivot_table(
        index=["hospital_sample_size", "replication", "estimand"], columns="strategy", values="estimate"
    )
    assert (points.N4 - points.N5).abs().max() < 1e-14


def test_primary_truths_and_bias_pattern():
    truth = pd.read_csv(PROJECT / "results" / "summary" / "target_truths.csv").set_index("estimand")
    assert 0.86 <= truth.loc["national", "target_parameter"] <= 0.88
    assert 0.93 <= truth.loc["easy", "target_parameter"] <= 0.97
    assert 0.71 <= truth.loc["hard", "target_parameter"] <= 0.77
    perf = pd.read_csv(PROJECT / "results" / "summary" / "performance_summary.csv")
    n3 = perf[(perf.strategy == "N3") & (perf.estimand == "national")]
    n4 = perf[(perf.strategy == "N4") & (perf.estimand == "national")]
    assert (n3.bias.abs() > 0.03).all()
    assert (n4.bias.abs() < 0.005).all()
