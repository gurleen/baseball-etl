import argparse

from baseball_etl.pipeline import run_chadwick_register, run_retrosheet_playbyplay


def parse_years(spec: str) -> list[int]:
    """Parse a year or comma-separated list of years/ranges, e.g. "2021",
    "2019-2023", or "2015-2017,2020,2022-2024"."""
    years: list[int] = []
    for chunk in spec.split(","):
        chunk = chunk.strip()
        if "-" in chunk:
            start, end = chunk.split("-", 1)
            years.extend(range(int(start), int(end) + 1))
        else:
            years.append(int(chunk))
    return years


def main() -> None:
    parser = argparse.ArgumentParser(description="Baseball ETL pipelines")
    subparsers = parser.add_subparsers(dest="pipeline", required=True)

    subparsers.add_parser(
        "chadwick-register", help="Load the Chadwick Bureau register"
    )

    retrosheet_parser = subparsers.add_parser(
        "retrosheet-playbyplay",
        help="Load Retrosheet's pre-parsed play-by-play CSVs",
    )
    retrosheet_parser.add_argument(
        "--years",
        required=True,
        help='Year or years to load, e.g. "2023", "2019-2023", or "2015-2017,2020"',
    )

    args = parser.parse_args()

    if args.pipeline == "chadwick-register":
        run_chadwick_register()
    elif args.pipeline == "retrosheet-playbyplay":
        run_retrosheet_playbyplay(parse_years(args.years))


if __name__ == "__main__":
    main()
