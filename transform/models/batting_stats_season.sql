MODEL (
  name public.batting_stats_season,
  kind FULL,
  grain (batter_pk, season),
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
batter_games_played AS (
  SELECT
    p.batter_pk,
    p.season,
    MAX(cgp.games_played) AS games_played
  FROM (SELECT DISTINCT batter_pk, season, batting_club_pk FROM public.plays WHERE batter_pk IS NOT NULL) AS p
  JOIN club_games_played AS cgp
    ON cgp.club_pk = p.batting_club_pk AND cgp.season = p.season
  GROUP BY p.batter_pk, p.season
),
counts AS (
  SELECT
    batter_pk,
    season,
    COUNT(*)::INTEGER AS pa,
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
  WHERE batter_pk IS NOT NULL
  GROUP BY batter_pk, season
),
totals AS (
  SELECT
    batter_pk,
    season,
    pa,
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
    (singles + 2 * doubles + 3 * triples + 4 * home_runs) AS tb,
    (pa - (bb + ibb + hbp + sf + sh + ci)) AS ab
  FROM counts
),
primary_club AS (
  -- The batter's club with the most plate appearances that season, used to
  -- pick which team's park factor applies to a traded-mid-season player, and
  -- which league (AL/NL) their league-average rates are drawn from.
  SELECT batter_pk, season, batting_club_pk
  FROM (
    SELECT
      batter_pk,
      season,
      batting_club_pk,
      ROW_NUMBER() OVER (PARTITION BY batter_pk, season ORDER BY COUNT(*) DESC) AS rn
    FROM public.plays
    WHERE batter_pk IS NOT NULL
    GROUP BY batter_pk, season, batting_club_pk
  ) AS ranked
  WHERE rn = 1
),
league_batting AS (
  -- Per-league (AL/NL) totals, inferred from plays via each play's batting
  -- club's league that season, to derive a league-specific wOBA and R/PA
  -- for wRC+ (FanGraphs' guts constants are MLB-wide, not split by league).
  SELECT
    ch.league_pk,
    pl.season,
    COUNT(*)::INTEGER AS pa,
    COUNT(*) FILTER (WHERE pl.is_walk)::INTEGER AS bb,
    COUNT(*) FILTER (WHERE pl.is_intentional_walk)::INTEGER AS ibb,
    COUNT(*) FILTER (WHERE pl.is_hit_by_pitch)::INTEGER AS hbp,
    COUNT(*) FILTER (WHERE pl.is_single)::INTEGER AS singles,
    COUNT(*) FILTER (WHERE pl.is_double)::INTEGER AS doubles,
    COUNT(*) FILTER (WHERE pl.is_triple)::INTEGER AS triples,
    COUNT(*) FILTER (WHERE pl.is_home_run)::INTEGER AS home_runs,
    COUNT(*) FILTER (WHERE pl.is_sacrifice_fly)::INTEGER AS sf,
    COUNT(*) FILTER (WHERE pl.is_sacrifice_bunt)::INTEGER AS sh,
    COUNT(*) FILTER (WHERE pl.is_catcher_interference)::INTEGER AS ci
  FROM public.plays AS pl
  JOIN public.clubs_history AS ch
    ON ch.club_pk = pl.batting_club_pk AND ch.season = pl.season
  WHERE pl.batter_pk IS NOT NULL
  GROUP BY ch.league_pk, pl.season
),
league_runs AS (
  -- Each team's runs scored count toward its own league's total, even in an
  -- interleague game against a team from the other league.
  SELECT league_pk, season, SUM(runs)::INTEGER AS runs
  FROM (
    SELECT ch.league_pk, g.season, g.home_score AS runs
    FROM public.games AS g
    JOIN public.clubs_history AS ch
      ON ch.club_pk = g.home_club_pk AND ch.season = g.season
    WHERE g.game_type = 'R' AND g.abstract_game_state = 'Final'
    UNION ALL
    SELECT ch.league_pk, g.season, g.away_score AS runs
    FROM public.games AS g
    JOIN public.clubs_history AS ch
      ON ch.club_pk = g.away_club_pk AND ch.season = g.season
    WHERE g.game_type = 'R' AND g.abstract_game_state = 'Final'
  ) AS runs_by_team_league
  GROUP BY league_pk, season
),
league_rates AS (
  SELECT
    lb.league_pk,
    lb.season,
    public.woba(
      lb.bb, lb.hbp, lb.singles, lb.doubles, lb.triples, lb.home_runs,
      (lb.pa - (lb.bb + lb.ibb + lb.hbp + lb.sf + lb.sh + lb.ci)), lb.sf,
      ww.wbb, ww.whbp, ww.w1b, ww.w2b, ww.w3b, ww.whr
    ) AS lg_woba,
    lr.runs::NUMERIC / NULLIF(lb.pa, 0) AS lg_r_pa
  FROM league_batting AS lb
  JOIN league_runs AS lr
    ON lr.league_pk = lb.league_pk AND lr.season = lb.season
  LEFT JOIN public.woba_weights AS ww
    ON ww.pk = lb.season
),
rates AS (
  SELECT
    totals.*,
    public.woba(
      totals.bb, totals.hbp, totals.singles, totals.doubles, totals.triples, totals.home_runs, totals.ab, totals.sf,
      ww.wbb, ww.whbp, ww.w1b, ww.w2b, ww.w3b, ww.whr
    ) AS woba,
    lgr.lg_woba,
    ww.woba_scale AS lg_woba_scale,
    lgr.lg_r_pa,
    pf.basic_5yr AS park_factor
  FROM totals
  LEFT JOIN public.woba_weights AS ww
    ON ww.pk = totals.season
  LEFT JOIN primary_club AS pc
    ON pc.batter_pk = totals.batter_pk AND pc.season = totals.season
  LEFT JOIN public.clubs_history AS bch
    ON bch.club_pk = pc.batting_club_pk AND bch.season = pc.season
  LEFT JOIN league_rates AS lgr
    ON lgr.league_pk = bch.league_pk AND lgr.season = totals.season
  -- Prior-season park factors: a batter's 2026 season uses 2025 park factors.
  LEFT JOIN public.park_factors AS pf
    ON pf.club_pk = pc.batting_club_pk AND pf.season = totals.season - 1
)
SELECT
  rates.batter_pk,
  rates.season,
  pa,
  ab,
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
  tb,
  public.batting_avg(h, ab) AS avg,
  public.on_base_pct(h, bb_total, hbp, ab, sf) AS obp,
  public.slugging_pct(tb, ab) AS slg,
  public.ops(h, bb_total, hbp, ab, sf, tb) AS ops,
  public.bb_pct(bb_total, pa) AS bb_pct,
  public.k_pct(so, pa) AS k_pct,
  public.bb_k_ratio(bb_total, so) AS bb_k,
  public.iso(h, tb, ab) AS iso,
  public.babip(h, home_runs, ab, so, sf) AS babip,
  rates.woba AS woba,
  public.wrc_plus(rates.woba, rates.lg_woba, rates.lg_woba_scale, rates.lg_r_pa, rates.park_factor) AS wrc_plus,
  pa >= ROUND(3.1 * bgp.games_played) AS qualified
FROM rates
LEFT JOIN batter_games_played AS bgp
  ON bgp.batter_pk = rates.batter_pk AND bgp.season = rates.season
