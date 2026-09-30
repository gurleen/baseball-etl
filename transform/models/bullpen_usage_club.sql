MODEL (
  name public.bullpen_usage_club,
  kind FULL,
  grain (pk),
);

-- Regular-season bullpen usage per club. Starter workload is included for
-- context, since bullpen load is largely set by how deep starters go.
WITH totals AS (
  SELECT
    club_pk,
    season,
    COUNT(DISTINCT game_pk)::INTEGER AS games,
    SUM(outs)::INTEGER AS team_outs,
    SUM(outs) FILTER (WHERE is_start)::INTEGER AS starter_outs,
    SUM(pitches) FILTER (WHERE is_start)::INTEGER AS starter_pitches,
    COUNT(*) FILTER (WHERE is_relief)::INTEGER AS relief_appearances,
    COUNT(DISTINCT pitcher_pk) FILTER (WHERE is_relief)::INTEGER AS relievers_used,
    COALESCE(SUM(outs) FILTER (WHERE is_relief), 0)::INTEGER AS outs,
    COALESCE(SUM(pitches) FILTER (WHERE is_relief), 0)::INTEGER AS pitches,
    COALESCE(SUM(batters_faced) FILTER (WHERE is_relief), 0)::INTEGER AS batters_faced,
    COUNT(*) FILTER (WHERE is_relief AND outs > 3)::INTEGER AS multi_inning_appearances,
    COUNT(*) FILTER (WHERE is_relief AND days_since_previous_appearance <= 1)::INTEGER AS consecutive_day_appearances,
    ROUND(AVG(entry_inning) FILTER (WHERE is_relief), 2) AS avg_entry_inning,
    ROUND(AVG(entry_leverage_index) FILTER (WHERE is_relief), 2) AS avg_entry_leverage_index,
    COUNT(*) FILTER (WHERE is_relief AND entry_leverage_index >= 1.5)::INTEGER AS high_leverage_appearances,
    COUNT(*) FILTER (WHERE is_save_situation_entry)::INTEGER AS save_situation_appearances,
    COALESCE(SUM(inherited_runners) FILTER (WHERE is_relief), 0)::INTEGER AS inherited_runners,
    COALESCE(SUM(inherited_runners_scored) FILTER (WHERE is_relief), 0)::INTEGER AS inherited_runners_scored,
    COALESCE(SUM(h) FILTER (WHERE is_relief), 0)::INTEGER AS h,
    COALESCE(SUM(home_runs) FILTER (WHERE is_relief), 0)::INTEGER AS home_runs,
    COALESCE(SUM(bb + ibb) FILTER (WHERE is_relief), 0)::INTEGER AS bb_total,
    COALESCE(SUM(hbp) FILTER (WHERE is_relief), 0)::INTEGER AS hbp,
    COALESCE(SUM(so) FILTER (WHERE is_relief), 0)::INTEGER AS so,
    COALESCE(SUM(runs) FILTER (WHERE is_relief), 0)::INTEGER AS runs,
    COALESCE(SUM(earned_runs) FILTER (WHERE is_relief), 0)::INTEGER AS earned_runs
  FROM public.pitcher_appearances
  WHERE game_type = 'R'
  GROUP BY club_pk, season
)
SELECT
  HASHTEXTEXTENDED(t.club_pk::TEXT || ':' || t.season::TEXT, 0)
    & x'7fffffffffffffff'::BIGINT AS pk,
  t.club_pk,
  t.season,
  t.games,
  ROUND(t.starter_outs::NUMERIC / t.games, 2) AS starter_outs_per_game,
  ROUND(t.starter_pitches::NUMERIC / t.games, 1) AS starter_pitches_per_game,
  t.relief_appearances,
  t.relievers_used,
  ROUND(t.relief_appearances::NUMERIC / t.games, 2) AS relief_appearances_per_game,
  t.outs,
  ROUND((t.outs / 3) + (t.outs % 3) / 10.0, 1) AS ip,
  ROUND(t.outs::NUMERIC / NULLIF(t.team_outs, 0), 3) AS share_of_team_outs,
  t.pitches,
  ROUND(t.pitches::NUMERIC / t.games, 1) AS pitches_per_game,
  t.batters_faced,
  t.multi_inning_appearances,
  t.consecutive_day_appearances,
  t.avg_entry_inning,
  t.avg_entry_leverage_index,
  t.high_leverage_appearances,
  t.save_situation_appearances,
  t.inherited_runners,
  t.inherited_runners_scored,
  ROUND(t.inherited_runners_scored::NUMERIC / NULLIF(t.inherited_runners, 0), 3) AS inherited_runners_scored_pct,
  t.runs,
  t.earned_runs,
  public.era(t.earned_runs, t.outs) AS era,
  public.fip(t.home_runs, t.bb_total, t.hbp, t.so, t.outs, ww.c_fip) AS fip,
  public.whip(t.bb_total, t.h, t.outs) AS whip,
  public.k_pct(t.so, t.batters_faced) AS k_pct,
  public.bb_pct(t.bb_total, t.batters_faced) AS bb_pct
FROM totals AS t
LEFT JOIN public.woba_weights AS ww
  ON ww.pk = t.season
