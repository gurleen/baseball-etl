MODEL (
  name public.game_data_completeness,
  kind FULL,
  grain (pk),
);

WITH mlb_playbyplay AS (
  SELECT
    game_pk::BIGINT AS game_pk,
    COUNT(*) AS play_count
  FROM raw.mlb_plays
  GROUP BY 1
),

statcast_pitches AS (
  SELECT
    game_pk::BIGINT AS game_pk,
    COUNT(*) AS pitch_count
  FROM raw.statcast_pitches
  GROUP BY 1
),

statcast_batted_balls AS (
  SELECT
    game_pk::BIGINT AS game_pk,
    COUNT(*) AS batted_ball_count
  FROM raw.statcast_batted_balls
  GROUP BY 1
)

SELECT
  g.pk AS pk,
  g.season,
  g.game_date,
  g.abstract_game_state,
  COALESCE(mp.play_count, 0) AS mlb_playbyplay_play_count,
  mp.game_pk IS NOT NULL AS has_mlb_playbyplay,
  COALESCE(sp.pitch_count, 0) AS statcast_pitch_count,
  sp.game_pk IS NOT NULL AS has_statcast_pitches,
  COALESCE(sb.batted_ball_count, 0) AS statcast_batted_ball_count,
  sb.game_pk IS NOT NULL AS has_statcast_batted_balls,
  g.abstract_game_state = 'Final' AND mp.game_pk IS NULL AS is_missing_mlb_playbyplay,
  g.abstract_game_state = 'Final' AND sp.game_pk IS NULL AS is_missing_statcast_pitches
FROM public.games AS g
LEFT JOIN mlb_playbyplay AS mp ON mp.game_pk = g.pk
LEFT JOIN statcast_pitches AS sp ON sp.game_pk = g.pk
LEFT JOIN statcast_batted_balls AS sb ON sb.game_pk = g.pk
