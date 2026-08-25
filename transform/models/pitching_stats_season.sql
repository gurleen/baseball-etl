MODEL (
  name public.pitching_stats_season,
  kind FULL,
  grain (pitcher_pk, season),
);

WITH club_games_played AS (
  SELECT club_pk, season, COUNT(*)::INTEGER AS games_played
  FROM (
    SELECT home_club_pk AS club_pk, season FROM public.games WHERE game_type = 'R' AND abstract_game_state = 'Final'
    UNION ALL
    SELECT away_club_pk AS club_pk, season FROM public.games WHERE game_type = 'R' AND abstract_game_state = 'Final'
  ) AS played
  GROUP BY club_pk, season
),
pitcher_games_played AS (
  SELECT
    p.pitcher_pk,
    p.season,
    MAX(cgp.games_played) AS games_played
  FROM (SELECT DISTINCT pitcher_pk, season, pitching_club_pk FROM public.plays WHERE pitcher_pk IS NOT NULL) AS p
  JOIN club_games_played AS cgp
    ON cgp.club_pk = p.pitching_club_pk AND cgp.season = p.season
  GROUP BY p.pitcher_pk, p.season
),
counts AS (
  SELECT
    pitcher_pk,
    season,
    COUNT(*)::INTEGER AS pa,
    SUM(outs_recorded)::INTEGER AS outs,
    COUNT(*) FILTER (WHERE is_single)::INTEGER AS singles,
    COUNT(*) FILTER (WHERE is_double)::INTEGER AS doubles,
    COUNT(*) FILTER (WHERE is_triple)::INTEGER AS triples,
    COUNT(*) FILTER (WHERE is_home_run)::INTEGER AS home_runs,
    COUNT(*) FILTER (WHERE is_walk)::INTEGER AS bb,
    COUNT(*) FILTER (WHERE is_intentional_walk)::INTEGER AS ibb,
    COUNT(*) FILTER (WHERE is_hit_by_pitch)::INTEGER AS hbp,
    COUNT(*) FILTER (WHERE is_strikeout)::INTEGER AS so,
    COUNT(*) FILTER (WHERE is_sacrifice_fly)::INTEGER AS sf,
    COUNT(*) FILTER (WHERE is_sacrifice_bunt)::INTEGER AS sh,
    COUNT(*) FILTER (WHERE is_catcher_interference)::INTEGER AS ci
  FROM public.plays
  WHERE pitcher_pk IS NOT NULL
  GROUP BY pitcher_pk, season
),
runs_charged AS (
  SELECT
    pitcher_pk,
    season,
    COUNT(*)::INTEGER AS runs,
    COUNT(*) FILTER (WHERE is_earned)::INTEGER AS earned_runs
  FROM public.pitcher_runs_charged
  GROUP BY pitcher_pk, season
),
totals AS (
  SELECT
    counts.pitcher_pk,
    counts.season,
    pa,
    outs,
    ROUND((outs / 3) + (outs % 3) / 10.0, 1) AS ip,
    (singles + doubles + triples + home_runs) AS h,
    singles,
    doubles,
    triples,
    home_runs,
    bb,
    ibb,
    (bb + ibb) AS bb_total,
    hbp,
    so,
    sf,
    sh,
    (pa - (bb + ibb + hbp + sf + sh + ci)) AS ab,
    COALESCE(rc.runs, 0) AS runs,
    COALESCE(rc.earned_runs, 0) AS earned_runs
  FROM counts
  LEFT JOIN runs_charged AS rc
    ON rc.pitcher_pk = counts.pitcher_pk AND rc.season = counts.season
)
SELECT
  totals.pitcher_pk,
  totals.season,
  pa,
  ip,
  outs,
  h,
  singles,
  doubles,
  triples,
  home_runs,
  bb,
  ibb,
  hbp,
  so,
  sf,
  sh,
  runs,
  earned_runs,
  public.era(earned_runs, outs) AS era,
  public.whip(bb_total, h, outs) AS whip,
  public.k9(so, outs) AS k9,
  public.bb9(bb_total, outs) AS bb9,
  public.hr9(home_runs, outs) AS hr9,
  public.babip(h, home_runs, ab, so, sf) AS babip,
  public.fip(home_runs, bb_total, hbp, so, outs, ww.c_fip) AS fip,
  public.lob_pct(h, bb_total, hbp, runs, home_runs) AS lob_pct,
  outs >= (pgp.games_played * 3) AS qualified
FROM totals
LEFT JOIN pitcher_games_played AS pgp
  ON pgp.pitcher_pk = totals.pitcher_pk AND pgp.season = totals.season
LEFT JOIN public.woba_weights AS ww
  ON ww.pk = totals.season
