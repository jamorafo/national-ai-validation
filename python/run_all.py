"""Execute the complete Python validation workflow."""
from pathlib import Path
import argparse

from run import run_experiment
from analyse import analyse
from validate import validate
from make_tables import make_tables
from make_figures import make_figures


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--replications", type=int, default=None)
    args = parser.parse_args()
    run_experiment(args.project, args.replications)
    analyse(args.project)
    validate(args.project)
    make_tables(args.project)
    make_figures(args.project)


if __name__ == "__main__":
    main()
