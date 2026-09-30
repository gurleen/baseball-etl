MODEL (
  name public.pitcher_appearances,
  kind FULL,
  grain (pk),
);

-- One row per pitcher per game, built from the MLB Stats API play-by-play
-- (raw.mlb_plays), so it covers every game type that source loads,
-- including the postseason. Retrosheet seasons are not included: they carry
-- no pitch counts.
WITH plate_appearances AS (
  SELECT
    m._dlt_id,
    m.game_pk,
    m.at_bat_index,
    m.about__inning::SMALLINT AS inning,
    m.about__half_inning AS half_inning,
    m.matchup__pitcher__id AS pitcher_pk,
    CASE WHEN m.about__is_top_inning THEN g.home_club_pk ELSE g.away_club_pk END AS club_pk,
    m.count__outs::SMALLINT AS outs_after,
    m.result__home_score AS home_score_after,
    m.result__away_score AS away_score_after,
    m.matchup__post_on_first__id IS NOT NULL AS runner_on_first_after,
    m.matchup__post_on_second__id IS NOT NULL AS runner_on_second_after,
    m.matchup__post_on_third__id IS NOT NULL AS runner_on_third_after,
    g.game_type,
    g.season,
    g.official_date AS game_date,
    m.about__is_top_inning AS is_top_inning
  FROM raw.mlb_plays AS m
  JOIN public.games AS g ON g.pk = m.game_pk
  WHERE m.matchup__pitcher__id IS NOT NULL
),
-- Game state before each plate appearance: the previous plate appearance's
-- ending state within the same half-inning. Extra-inning halves start with
-- the automatic runner on second.
plate_appearance_states AS (
  SELECT
    pa.*,
    COALESCE(
      LAG(outs_after) OVER half_inning_window,
      0
    ) AS outs_before,
    COALESCE(
      LAG(runner_on_first_after) OVER half_inning_window,
      FALSE
    ) AS runner_on_first_before,
    COALESCE(
      LAG(runner_on_second_after) OVER half_inning_window,
      inning >= 10
    ) AS runner_on_second_before,
    COALESCE(
      LAG(runner_on_third_after) OVER half_inning_window,
      FALSE
    ) AS runner_on_third_before,
    COALESCE(LAG(home_score_after) OVER game_window, 0) AS home_score_before,
    COALESCE(LAG(away_score_after) OVER game_window, 0) AS away_score_before,
    LAG(pitcher_pk) OVER pitching_club_window AS previous_pitcher_pk
  FROM plate_appearances AS pa
  WINDOW
    half_inning_window AS (PARTITION BY game_pk, inning, half_inning ORDER BY at_bat_index),
    game_window AS (PARTITION BY game_pk ORDER BY at_bat_index),
    pitching_club_window AS (PARTITION BY game_pk, is_top_inning ORDER BY at_bat_index)
),
plate_appearance_details AS (
  SELECT
    s.*,
    outs_after - outs_before AS outs_recorded,
    CASE WHEN is_top_inning THEN home_score_before - away_score_before
      ELSE away_score_before - home_score_before
    END AS pitching_score_margin_before,
    home_score_before - away_score_before AS home_score_margin_before,
    runner_on_first_before::INT + runner_on_second_before::INT + runner_on_third_before::INT
      AS runners_on_before
  FROM plate_appearance_states AS s
),
plate_appearance_leverage AS (
  SELECT
    d.*,
    li.leverage_index
  FROM plate_appearance_details AS d
  LEFT JOIN public.leverage_index AS li
    ON li.inning = LEAST(d.inning, 9)
    AND li.half_inning = d.half_inning
    AND li.outs = d.outs_before
    AND li.runner_on_first = d.runner_on_first_before
    AND li.runner_on_second = d.runner_on_second_before
    AND li.runner_on_third = d.runner_on_third_before
    AND li.home_score_margin = GREATEST(LEAST(d.home_score_margin_before, 4), -4)
),
-- A pitching change occasionally happens mid-plate-appearance; pitches
-- thrown before it belong to the outgoing pitcher, not the one credited with
-- the plate appearance's result.
mid_plate_appearance_changes AS (
  SELECT _dlt_parent_id, MAX(index) AS change_index
  FROM raw.mlb_plays__play_events
  WHERE details__event_type = 'pitching_substitution'
  GROUP BY _dlt_parent_id
),
pitch_attribution AS (
  SELECT
    CASE
      WHEN e.index < c.change_index AND pa.previous_pitcher_pk IS NOT NULL THEN pa.previous_pitcher_pk
      ELSE pa.pitcher_pk
    END AS pitcher_pk,
    pa.game_pk,
    COUNT(*)::INTEGER AS pitches
  FROM raw.mlb_plays__play_events AS e
  JOIN plate_appearance_details AS pa ON pa._dlt_id = e._dlt_parent_id
  LEFT JOIN mid_plate_appearance_changes AS c ON c._dlt_parent_id = e._dlt_parent_id
  WHERE e.is_pitch
  GROUP BY 1, 2
),
-- Runs that scored while this pitcher was on the mound but were charged to
-- a teammate: inherited runners who scored.
inherited_runners_scored AS (
  SELECT
    pa.game_pk,
    pa.pitcher_pk,
    COUNT(*)::INTEGER AS inherited_runners_scored
  FROM raw.mlb_plays__runners AS rn
  JOIN plate_appearance_details AS pa ON pa._dlt_id = rn._dlt_parent_id
  WHERE rn.details__is_scoring_event
    AND rn.details__responsible_pitcher__id <> pa.pitcher_pk
  GROUP BY 1, 2
),
outcomes AS (
  SELECT
    p.game_id::BIGINT AS game_pk,
    p.pitcher_pk,
    COUNT(*)::INTEGER AS batters_faced,
    COUNT(*) FILTER (WHERE p.is_single OR p.is_double OR p.is_triple OR p.is_home_run)::INTEGER AS h,
    COUNT(*) FILTER (WHERE p.is_home_run)::INTEGER AS home_runs,
    COUNT(*) FILTER (WHERE p.is_walk)::INTEGER AS bb,
    COUNT(*) FILTER (WHERE p.is_intentional_walk)::INTEGER AS ibb,
    COUNT(*) FILTER (WHERE p.is_hit_by_pitch)::INTEGER AS hbp,
    COUNT(*) FILTER (WHERE p.is_strikeout)::INTEGER AS so
  FROM public.plays AS p
  WHERE p.source_id = 2 AND p.pitcher_pk IS NOT NULL
  GROUP BY 1, 2
),
runs_charged AS (
  SELECT
    game_id::BIGINT AS game_pk,
    pitcher_pk,
    COUNT(*)::INTEGER AS runs,
    COUNT(*) FILTER (WHERE is_earned)::INTEGER AS earned_runs
  FROM public.pitcher_runs_charged
  WHERE source_id = 2
  GROUP BY 1, 2
),
appearances AS (
  SELECT
    game_pk,
    pitcher_pk,
    MIN(club_pk) AS club_pk,
    MIN(game_type) AS game_type,
    MIN(season) AS season,
    MIN(game_date) AS game_date,
    MIN(at_bat_index) AS first_at_bat_index,
    MAX(at_bat_index) AS last_at_bat_index,
    SUM(outs_recorded)::INTEGER AS outs,
    AVG(leverage_index) AS avg_leverage_index
  FROM plate_appearance_leverage
  GROUP BY game_pk, pitcher_pk
),
appearance_entries AS (
  SELECT
    a.*,
    e.inning AS entry_inning,
    e.outs_before AS entry_outs,
    e.runners_on_before AS entry_runners_on,
    e.pitching_score_margin_before AS entry_score_margin,
    e.leverage_index AS entry_leverage_index,
    ROW_NUMBER() OVER (PARTITION BY a.game_pk, a.club_pk ORDER BY a.first_at_bat_index) AS appearance_seq,
    ROW_NUMBER() OVER (PARTITION BY a.game_pk, a.club_pk ORDER BY a.first_at_bat_index DESC) = 1 AS finished_game
  FROM appearances AS a
  JOIN plate_appearance_leverage AS e
    ON e.game_pk = a.game_pk AND e.at_bat_index = a.first_at_bat_index
)
SELECT
  HASHTEXTEXTENDED(ae.game_pk::TEXT || ':' || ae.pitcher_pk::TEXT, 0)
    & x'7fffffffffffffff'::BIGINT AS pk,
  ae.game_pk,
  ae.game_type,
  ae.season,
  ae.game_date,
  ae.club_pk,
  ae.pitcher_pk,
  ae.appearance_seq::SMALLINT AS appearance_seq,
  ae.appearance_seq = 1 AS is_start,
  ae.appearance_seq > 1 AS is_relief,
  ae.finished_game,
  ae.entry_inning,
  ae.entry_outs,
  ae.entry_runners_on::SMALLINT AS entry_runners_on,
  ae.entry_score_margin,
  ae.entry_leverage_index,
  ROUND(ae.avg_leverage_index, 2) AS avg_leverage_index,
  -- Official save situation on entry: leading by 3 or fewer, or the tying
  -- run is on base, at bat, or on deck.
  (
    ae.appearance_seq > 1
    AND ae.entry_score_margin > 0
    AND (ae.entry_score_margin <= 3 OR ae.entry_score_margin <= ae.entry_runners_on + 2)
  ) AS is_save_situation_entry,
  CASE WHEN ae.appearance_seq > 1 THEN ae.entry_runners_on ELSE 0 END::INTEGER AS inherited_runners,
  COALESCE(irs.inherited_runners_scored, 0) AS inherited_runners_scored,
  COALESCE(pt.pitches, 0) AS pitches,
  COALESCE(o.batters_faced, 0) AS batters_faced,
  ae.outs,
  COALESCE(o.h, 0) AS h,
  COALESCE(o.home_runs, 0) AS home_runs,
  COALESCE(o.bb, 0) AS bb,
  COALESCE(o.ibb, 0) AS ibb,
  COALESCE(o.hbp, 0) AS hbp,
  COALESCE(o.so, 0) AS so,
  COALESCE(rc.runs, 0) AS runs,
  COALESCE(rc.earned_runs, 0) AS earned_runs,
  (ae.game_date - LAG(ae.game_date) OVER (
    PARTITION BY ae.pitcher_pk ORDER BY ae.game_date, ae.game_pk
  ))::INTEGER AS days_since_previous_appearance
FROM appearance_entries AS ae
LEFT JOIN pitch_attribution AS pt
  ON pt.game_pk = ae.game_pk AND pt.pitcher_pk = ae.pitcher_pk
LEFT JOIN inherited_runners_scored AS irs
  ON irs.game_pk = ae.game_pk AND irs.pitcher_pk = ae.pitcher_pk
LEFT JOIN outcomes AS o
  ON o.game_pk = ae.game_pk AND o.pitcher_pk = ae.pitcher_pk
LEFT JOIN runs_charged AS rc
  ON rc.game_pk = ae.game_pk AND rc.pitcher_pk = ae.pitcher_pk
