MODEL (
  name public.bullpen_usage_pitcher,
  kind FULL,
  grain (pk),
);

-- Regular-season relief usage per pitcher per club stint. Only pitchers with
-- at least one relief appearance for the club are included; every metric
-- except `starts` counts relief appearances only.
WITH relief AS (
  SELECT *
  FROM public.pitcher_appearances
  WHERE game_type = 'R' AND is_relief
),
starts AS (
  SELECT pitcher_pk, club_pk, season, COUNT(*)::INTEGER AS starts
  FROM public.pitcher_appearances
  WHERE game_type = 'R' AND is_start
  GROUP BY 1, 2, 3
),
totals AS (
  SELECT
    pitcher_pk,
    club_pk,
    season,
    COUNT(*)::INTEGER AS relief_appearances,
    SUM(pitches)::INTEGER AS pitches,
    SUM(batters_faced)::INTEGER AS batters_faced,
    SUM(outs)::INTEGER AS outs,
    COUNT(*) FILTER (WHERE outs > 3)::INTEGER AS multi_inning_appearances,
    COUNT(*) FILTER (WHERE days_since_previous_appearance <= 1)::INTEGER AS consecutive_day_appearances,
    ROUND(AVG(LEAST(days_since_previous_appearance, 10)), 2) AS avg_days_since_previous_appearance,
    ROUND(AVG(entry_inning), 2) AS avg_entry_inning,
    ROUND(AVG(entry_leverage_index), 2) AS avg_entry_leverage_index,
    COUNT(*) FILTER (WHERE entry_leverage_index >= 1.5)::INTEGER AS high_leverage_appearances,
    COUNT(*) FILTER (WHERE entry_leverage_index < 0.85)::INTEGER AS low_leverage_appearances,
    COUNT(*) FILTER (WHERE is_save_situation_entry)::INTEGER AS save_situation_appearances,
    COUNT(*) FILTER (WHERE finished_game)::INTEGER AS games_finished,
    SUM(inherited_runners)::INTEGER AS inherited_runners,
    SUM(inherited_runners_scored)::INTEGER AS inherited_runners_scored,
    SUM(h)::INTEGER AS h,
    SUM(home_runs)::INTEGER AS home_runs,
    SUM(bb + ibb)::INTEGER AS bb_total,
    SUM(hbp)::INTEGER AS hbp,
    SUM(so)::INTEGER AS so,
    SUM(runs)::INTEGER AS runs,
    SUM(earned_runs)::INTEGER AS earned_runs,
    MAX(game_date) AS last_relief_appearance_date
  FROM relief
  GROUP BY pitcher_pk, club_pk, season
)
SELECT
  HASHTEXTEXTENDED(t.pitcher_pk::TEXT || ':' || t.club_pk::TEXT || ':' || t.season::TEXT, 0)
    & x'7fffffffffffffff'::BIGINT AS pk,
  t.pitcher_pk,
  t.club_pk,
  t.season,
  COALESCE(s.starts, 0) AS starts,
  t.relief_appearances,
  t.outs,
  ROUND((t.outs / 3) + (t.outs % 3) / 10.0, 1) AS ip,
  t.pitches,
  t.batters_faced,
  ROUND(t.pitches::NUMERIC / t.relief_appearances, 1) AS pitches_per_appearance,
  ROUND(t.outs::NUMERIC / t.relief_appearances, 2) AS outs_per_appearance,
  t.multi_inning_appearances,
  t.consecutive_day_appearances,
  t.avg_days_since_previous_appearance,
  t.avg_entry_inning,
  t.avg_entry_leverage_index,
  t.high_leverage_appearances,
  t.low_leverage_appearances,
  t.save_situation_appearances,
  t.games_finished,
  t.inherited_runners,
  t.inherited_runners_scored,
  ROUND(t.inherited_runners_scored::NUMERIC / NULLIF(t.inherited_runners, 0), 3) AS inherited_runners_scored_pct,
  t.runs,
  t.earned_runs,
  public.era(t.earned_runs, t.outs) AS era,
  public.fip(t.home_runs, t.bb_total, t.hbp, t.so, t.outs, ww.c_fip) AS fip,
  public.whip(t.bb_total, t.h, t.outs) AS whip,
  public.k_pct(t.so, t.batters_faced) AS k_pct,
  public.bb_pct(t.bb_total, t.batters_faced) AS bb_pct,
  t.last_relief_appearance_date
FROM totals AS t
LEFT JOIN starts AS s
  ON s.pitcher_pk = t.pitcher_pk AND s.club_pk = t.club_pk AND s.season = t.season
LEFT JOIN public.woba_weights AS ww
  ON ww.pk = t.season
