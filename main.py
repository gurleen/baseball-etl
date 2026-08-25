import argparse
from pathlib import Path

from baseball_etl.pipeline import (
    run_chadwick_register,
    run_fangraphs_guts,
    run_fangraphs_park_factors,
    run_mlb_divisions,
    run_mlb_games,
    run_mlb_leagues,
    run_mlb_playbyplay,
    run_mlb_sports,
    run_mlb_teams,
    run_mlb_venues,
    run_retrosheet_playbyplay,
    run_statcast,
)


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

    fangraphs_guts_parser = subparsers.add_parser(
        "fangraphs-guts",
        help="Load FanGraphs' guts constants (wOBA weights, run values, etc.) "
        "from the manually-downloaded CSV committed at data/fangraphs_guts.csv",
    )
    fangraphs_guts_parser.add_argument(
        "--path",
        type=Path,
        default=None,
        help="Path to the guts CSV. Defaults to data/fangraphs_guts.csv.",
    )

    fangraphs_park_factors_parser = subparsers.add_parser(
        "fangraphs-park-factors",
        help="Load FanGraphs' park factors by team/season from the "
        "manually-downloaded CSV committed at data/fangraphs_park_factors.csv",
    )
    fangraphs_park_factors_parser.add_argument(
        "--path",
        type=Path,
        default=None,
        help="Path to the park factors CSV. Defaults to data/fangraphs_park_factors.csv.",
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

    mlb_parser = subparsers.add_parser(
        "mlb-playbyplay",
        help="Load current-season MLB play-by-play data from the MLBAM/GUMBO live feed API",
    )
    mlb_parser.add_argument(
        "--season",
        type=int,
        default=None,
        help="Season to load, e.g. 2026. Defaults to the current calendar year.",
    )
    mlb_parser.add_argument(
        "--game-types",
        default="R",
        help='MLB game type code(s), e.g. "R" for regular season or "F,D,L,W" '
        'for postseason rounds. Defaults to "R".',
    )
    mlb_parser.add_argument(
        "--start-date",
        default=None,
        help="Only load games on/after this date (YYYY-MM-DD).",
    )
    mlb_parser.add_argument(
        "--end-date",
        default=None,
        help="Only load games on/before this date (YYYY-MM-DD).",
    )

    mlb_games_parser = subparsers.add_parser(
        "mlb-games",
        help="Load MLB schedule/game data (teams, score, venue, status) from the MLB Stats API",
    )
    mlb_games_parser.add_argument(
        "--season",
        type=int,
        default=None,
        help="Season to load, e.g. 2026. Defaults to the current calendar year.",
    )
    mlb_games_parser.add_argument(
        "--game-types",
        default="R",
        help='MLB game type code(s), e.g. "R" for regular season or "F,D,L,W" '
        'for postseason rounds. Defaults to "R".',
    )
    mlb_games_parser.add_argument(
        "--start-date",
        default=None,
        help="Only load games on/after this date (YYYY-MM-DD).",
    )
    mlb_games_parser.add_argument(
        "--end-date",
        default=None,
        help="Only load games on/before this date (YYYY-MM-DD).",
    )

    mlb_teams_parser = subparsers.add_parser(
        "mlb-teams",
        help="Load MLB team reference data (name, venue, division) from the MLB Stats API",
    )
    mlb_teams_parser.add_argument(
        "--seasons",
        default=None,
        help='Season or seasons to load, e.g. "2025", "1901-2025", or '
        '"2015-2017,2020". Defaults to the current calendar year.',
    )

    subparsers.add_parser(
        "mlb-sports", help="Load MLB Stats API's sports reference list (MLB, AAA, AA, etc.)"
    )

    mlb_leagues_parser = subparsers.add_parser(
        "mlb-leagues",
        help="Load MLB league reference data (American League, National League) from the MLB Stats API",
    )
    mlb_leagues_parser.add_argument(
        "--seasons",
        default=None,
        help='Season or seasons to load, e.g. "2025", "1901-2025", or '
        '"2015-2017,2020". Defaults to the current calendar year.',
    )

    mlb_divisions_parser = subparsers.add_parser(
        "mlb-divisions",
        help="Load MLB division reference data (AL West, NL East, etc.) from the MLB Stats API",
    )
    mlb_divisions_parser.add_argument(
        "--seasons",
        default=None,
        help='Season or seasons to load, e.g. "2025", "1901-2025", or '
        '"2015-2017,2020". Defaults to the current calendar year.',
    )

    mlb_venues_parser = subparsers.add_parser(
        "mlb-venues",
        help="Load MLB venue reference data (ballparks) from the MLB Stats API",
    )
    mlb_venues_parser.add_argument(
        "--seasons",
        default=None,
        help='Season or seasons to load, e.g. "2025", "1901-2025", or '
        '"2015-2017,2020". Defaults to the current calendar year.',
    )

    statcast_parser = subparsers.add_parser(
        "statcast",
        help="Load Statcast pitch-tracking and batted-ball data from Baseball "
        "Savant's per-game gamefeed API",
    )
    statcast_parser.add_argument(
        "--season",
        type=int,
        default=None,
        help="Season to load, e.g. 2026. Defaults to the current calendar year.",
    )
    statcast_parser.add_argument(
        "--game-types",
        default="R",
        help='MLB game type code(s), e.g. "R" for regular season or "F,D,L,W" '
        'for postseason rounds. Defaults to "R".',
    )
    statcast_parser.add_argument(
        "--start-date",
        default=None,
        help="Only load games on/after this date (YYYY-MM-DD).",
    )
    statcast_parser.add_argument(
        "--end-date",
        default=None,
        help="Only load games on/before this date (YYYY-MM-DD).",
    )

    args = parser.parse_args()

    if args.pipeline == "chadwick-register":
        run_chadwick_register()
    elif args.pipeline == "fangraphs-guts":
        if args.path:
            run_fangraphs_guts(args.path)
        else:
            run_fangraphs_guts()
    elif args.pipeline == "fangraphs-park-factors":
        if args.path:
            run_fangraphs_park_factors(args.path)
        else:
            run_fangraphs_park_factors()
    elif args.pipeline == "retrosheet-playbyplay":
        run_retrosheet_playbyplay(parse_years(args.years))
    elif args.pipeline == "mlb-playbyplay":
        run_mlb_playbyplay(
            season=args.season,
            game_types=args.game_types,
            start_date=args.start_date,
            end_date=args.end_date,
        )
    elif args.pipeline == "mlb-games":
        run_mlb_games(
            season=args.season,
            game_types=args.game_types,
            start_date=args.start_date,
            end_date=args.end_date,
        )
    elif args.pipeline == "mlb-teams":
        run_mlb_teams(parse_years(args.seasons) if args.seasons else None)
    elif args.pipeline == "mlb-sports":
        run_mlb_sports()
    elif args.pipeline == "mlb-leagues":
        run_mlb_leagues(parse_years(args.seasons) if args.seasons else None)
    elif args.pipeline == "mlb-divisions":
        run_mlb_divisions(parse_years(args.seasons) if args.seasons else None)
    elif args.pipeline == "mlb-venues":
        run_mlb_venues(parse_years(args.seasons) if args.seasons else None)
    elif args.pipeline == "statcast":
        run_statcast(
            season=args.season,
            game_types=args.game_types,
            start_date=args.start_date,
            end_date=args.end_date,
        )


if __name__ == "__main__":
    main()
