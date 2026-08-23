import argparse

from baseball_etl.pipeline import run_chadwick_register, run_retrosheet_pbp


def main():
    parser = argparse.ArgumentParser(description="Run a baseball-etl dlt pipeline.")
    subparsers = parser.add_subparsers(dest="source", required=True)

    subparsers.add_parser("chadwick-register", help="Load the Chadwick Bureau register.")

    pbp_parser = subparsers.add_parser(
        "retrosheet-pbp", help="Load Retrosheet play-by-play data for a year or range of years."
    )
    pbp_parser.add_argument("start_year", type=int, help="First (or only) season to load, e.g. 2019.")
    pbp_parser.add_argument(
        "end_year",
        type=int,
        nargs="?",
        default=None,
        help="Last season to load, inclusive. Defaults to start_year.",
    )

    args = parser.parse_args()

    if args.source == "chadwick-register":
        run_chadwick_register()
    elif args.source == "retrosheet-pbp":
        run_retrosheet_pbp(args.start_year, args.end_year)


if __name__ == "__main__":
    main()
