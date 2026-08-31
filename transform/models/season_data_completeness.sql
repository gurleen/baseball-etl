MODEL (
  name public.season_data_completeness,
  kind FULL,
  grain (season),
);

WITH game_coverage AS (
  SELECT
    season,
    COUNT(*) AS total_games,
    SUM((abstract_game_state = 'Final')::INT) AS final_games,
    SUM((abstract_game_state = 'Final' AND has_mlb_playbyplay)::INT) AS games_with_mlb_playbyplay,
    SUM((abstract_game_state = 'Final' AND has_statcast_pitches)::INT) AS games_with_statcast_pitches,
    SUM(CASE WHEN abstract_game_state = 'Final' THEN statcast_pitch_count END) AS total_statcast_pitches,
    SUM((abstract_game_state = 'Final' AND has_statcast_batted_balls)::INT) AS games_with_statcast_batted_balls
  FROM public.game_data_completeness
  GROUP BY 1
),

retrosheet_coverage AS (
  SELECT
    season::SMALLINT AS season,
    COUNT(DISTINCT gid) AS retrosheet_games,
    COUNT(*) AS retrosheet_plate_appearances
  FROM raw.plays
  GROUP BY 1
),

retrosheet_resolution AS (
  SELECT
    season,
    COUNT(*) AS total_plays,
    SUM((batter_pk IS NOT NULL)::INT) AS batter_resolved,
    SUM((pitcher_pk IS NOT NULL)::INT) AS pitcher_resolved,
    SUM((batting_club_pk IS NOT NULL)::INT) AS batting_club_resolved,
    SUM((pitching_club_pk IS NOT NULL)::INT) AS pitching_club_resolved
  FROM public.plays
  WHERE source_id = 1
  GROUP BY 1
)

SELECT
  COALESCE(gc.season, rc.season, rr.season) AS season,
  gc.total_games,
  gc.final_games,
  gc.games_with_mlb_playbyplay,
  gc.games_with_mlb_playbyplay::DOUBLE PRECISION / NULLIF(gc.final_games, 0) AS pct_mlb_playbyplay,
  gc.games_with_statcast_pitches,
  gc.games_with_statcast_pitches::DOUBLE PRECISION / NULLIF(gc.final_games, 0) AS pct_statcast_pitches,
  gc.total_statcast_pitches::DOUBLE PRECISION / NULLIF(gc.games_with_statcast_pitches, 0) AS avg_statcast_pitches_per_game,
  gc.games_with_statcast_batted_balls,
  gc.games_with_statcast_batted_balls::DOUBLE PRECISION / NULLIF(gc.final_games, 0) AS pct_statcast_batted_balls,
  rc.retrosheet_games,
  rc.retrosheet_plate_appearances,
  rr.batter_resolved::DOUBLE PRECISION / NULLIF(rr.total_plays, 0) AS retrosheet_batter_resolved_pct,
  rr.pitcher_resolved::DOUBLE PRECISION / NULLIF(rr.total_plays, 0) AS retrosheet_pitcher_resolved_pct,
  rr.batting_club_resolved::DOUBLE PRECISION / NULLIF(rr.total_plays, 0) AS retrosheet_batting_club_resolved_pct,
  rr.pitching_club_resolved::DOUBLE PRECISION / NULLIF(rr.total_plays, 0) AS retrosheet_pitching_club_resolved_pct
FROM game_coverage AS gc
FULL OUTER JOIN retrosheet_coverage AS rc ON rc.season = gc.season
FULL OUTER JOIN retrosheet_resolution AS rr ON rr.season = COALESCE(gc.season, rc.season)
