MODEL (
  name public.bullpen_availability,
  kind VIEW,
  grain (pk),
);

-- Recent workload per pitcher as of today (US Eastern), counting every game
-- type including the postseason. A view rather than a table so the
-- date-relative windows are evaluated at query time and never go stale.
-- Covers pitchers who have appeared in the latest loaded season; club is
-- the club of their most recent appearance. `*_last_N_days` windows cover
-- the previous N calendar days plus today.
WITH today AS (
  SELECT (NOW() AT TIME ZONE 'America/New_York')::DATE AS as_of_date
),
latest_season AS (
  SELECT MAX(season) AS season FROM public.pitcher_appearances
),
appearances AS (
  SELECT
    a.*,
    ROW_NUMBER() OVER (PARTITION BY a.pitcher_pk ORDER BY a.game_date DESC, a.game_pk DESC) AS recency_rank
  FROM public.pitcher_appearances AS a
  JOIN latest_season AS ls ON ls.season = a.season
),
-- Runs of consecutive calendar days with an appearance: dates in the same
-- run share the same (game_date - dense rank) anchor.
appearance_days AS (
  SELECT
    pitcher_pk,
    game_date,
    game_date - DENSE_RANK() OVER (PARTITION BY pitcher_pk ORDER BY game_date)::INTEGER AS run_anchor
  FROM (SELECT DISTINCT pitcher_pk, game_date FROM appearances) AS d
),
latest_runs AS (
  SELECT
    pitcher_pk,
    COUNT(*)::INTEGER AS consecutive_days,
    MAX(game_date) AS run_end_date
  FROM appearance_days
  GROUP BY pitcher_pk, run_anchor
),
windows AS (
  SELECT
    a.pitcher_pk,
    COALESCE(SUM(a.pitches) FILTER (WHERE a.game_date >= t.as_of_date - 1), 0)::INTEGER AS pitches_last_1_days,
    COALESCE(SUM(a.pitches) FILTER (WHERE a.game_date >= t.as_of_date - 3), 0)::INTEGER AS pitches_last_3_days,
    COALESCE(SUM(a.pitches) FILTER (WHERE a.game_date >= t.as_of_date - 7), 0)::INTEGER AS pitches_last_7_days,
    COUNT(*) FILTER (WHERE a.game_date >= t.as_of_date - 3)::INTEGER AS appearances_last_3_days,
    COUNT(*) FILTER (WHERE a.game_date >= t.as_of_date - 7)::INTEGER AS appearances_last_7_days,
    COUNT(*) FILTER (WHERE a.is_relief)::INTEGER AS season_relief_appearances,
    COUNT(*) FILTER (WHERE a.is_start)::INTEGER AS season_starts
  FROM appearances AS a
  CROSS JOIN today AS t
  GROUP BY a.pitcher_pk
)
SELECT
  last.pitcher_pk AS pk,
  last.club_pk,
  last.season,
  t.as_of_date,
  last.game_date AS last_appearance_date,
  last.game_pk AS last_appearance_game_pk,
  last.game_type AS last_appearance_game_type,
  last.is_start AS last_appearance_was_start,
  last.pitches AS last_appearance_pitches,
  last.outs AS last_appearance_outs,
  (t.as_of_date - last.game_date)::INTEGER AS days_since_last_appearance,
  CASE WHEN last.game_date >= t.as_of_date - 1 THEN lr.consecutive_days ELSE 0 END AS consecutive_days_pitched,
  w.pitches_last_1_days,
  w.pitches_last_3_days,
  w.pitches_last_7_days,
  w.appearances_last_3_days,
  w.appearances_last_7_days,
  w.season_relief_appearances,
  w.season_starts
FROM appearances AS last
CROSS JOIN today AS t
JOIN windows AS w ON w.pitcher_pk = last.pitcher_pk
LEFT JOIN latest_runs AS lr
  ON lr.pitcher_pk = last.pitcher_pk AND lr.run_end_date = last.game_date
WHERE last.recency_rank = 1
