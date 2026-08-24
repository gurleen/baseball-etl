MODEL (
  name public.plays,
  kind INCREMENTAL_BY_UNIQUE_KEY (
    unique_key pk
  ),
  grain (pk),
);

WITH unioned AS (
  SELECT
    1 AS source_id,
    r.gid AS game_id,
    r.pn::INT AS play_seq,
    r.season::SMALLINT AS season,
    TO_DATE(r.date, 'YYYYMMDD') AS game_date,
    r.inning::SMALLINT AS inning,
    CASE r.top_bot WHEN '0' THEN 'top' WHEN '1' THEN 'bottom' END AS half_inning,
    bc.pk AS batting_club_pk,
    pc.pk AS pitching_club_pk,
    batter_p.pk AS batter_pk,
    pitcher_p.pk AS pitcher_pk,
    r.balls::SMALLINT AS balls,
    r.strikes::SMALLINT AS strikes,
    r.outs_post::SMALLINT AS outs_after,
    CASE
      WHEN r.hr = '1' THEN 'home_run'
      WHEN r.triple = '1' THEN 'triple'
      WHEN r.double = '1' THEN 'double'
      WHEN r.single = '1' THEN 'single'
      WHEN r.iw = '1' THEN 'intentional_walk'
      WHEN r.walk = '1' THEN 'walk'
      WHEN r.hbp = '1' THEN 'hit_by_pitch'
      WHEN r.k = '1' THEN 'strikeout'
      WHEN r.sf = '1' THEN 'sacrifice_fly'
      WHEN r.sh = '1' THEN 'sacrifice_bunt'
      WHEN r.roe = '1' THEN 'reached_on_error'
      WHEN r.fc = '1' THEN 'fielders_choice'
      WHEN r.xi = '1' THEN 'catcher_interference'
      WHEN r.tp = '1' THEN 'triple_play'
      WHEN r.gdp = '1' OR r.othdp = '1' THEN 'double_play'
      WHEN r.othout = '1' THEN 'other_out'
    END AS event_category,
    r.rbi::SMALLINT AS rbi,
    (r.runs::INT > 0) AS is_scoring_play
  FROM raw.plays AS r
  LEFT JOIN public.people AS batter_p ON batter_p.retro_id = r.batter
  LEFT JOIN public.people AS pitcher_p ON pitcher_p.retro_id = r.pitcher
  LEFT JOIN public.clubs AS bc ON bc.team_code = LOWER(r.batteam)
  LEFT JOIN public.clubs AS pc ON pc.team_code = LOWER(r.pitteam)
  WHERE r.pa = '1'

  UNION ALL

  SELECT
    2 AS source_id,
    m.game_pk::TEXT AS game_id,
    m.at_bat_index AS play_seq,
    g.season AS season,
    g.official_date AS game_date,
    m.about__inning::SMALLINT AS inning,
    m.about__half_inning AS half_inning,
    CASE WHEN m.about__is_top_inning THEN g.away_club_pk ELSE g.home_club_pk END AS batting_club_pk,
    CASE WHEN m.about__is_top_inning THEN g.home_club_pk ELSE g.away_club_pk END AS pitching_club_pk,
    m.matchup__batter__id AS batter_pk,
    m.matchup__pitcher__id AS pitcher_pk,
    m.count__balls::SMALLINT AS balls,
    m.count__strikes::SMALLINT AS strikes,
    m.count__outs::SMALLINT AS outs_after,
    CASE m.result__event_type
      WHEN 'single' THEN 'single'
      WHEN 'double' THEN 'double'
      WHEN 'triple' THEN 'triple'
      WHEN 'home_run' THEN 'home_run'
      WHEN 'walk' THEN 'walk'
      WHEN 'intent_walk' THEN 'intentional_walk'
      WHEN 'hit_by_pitch' THEN 'hit_by_pitch'
      WHEN 'strikeout' THEN 'strikeout'
      WHEN 'strikeout_double_play' THEN 'strikeout'
      WHEN 'sac_fly' THEN 'sacrifice_fly'
      WHEN 'sac_fly_double_play' THEN 'sacrifice_fly'
      WHEN 'sac_bunt' THEN 'sacrifice_bunt'
      WHEN 'field_error' THEN 'reached_on_error'
      WHEN 'fielders_choice' THEN 'fielders_choice'
      WHEN 'fielders_choice_out' THEN 'fielders_choice'
      WHEN 'catcher_interf' THEN 'catcher_interference'
      WHEN 'grounded_into_double_play' THEN 'double_play'
      WHEN 'double_play' THEN 'double_play'
      WHEN 'field_out' THEN 'other_out'
      WHEN 'force_out' THEN 'other_out'
      WHEN 'other_out' THEN 'other_out'
    END AS event_category,
    m.result__rbi::SMALLINT AS rbi,
    m.about__is_scoring_play AS is_scoring_play
  FROM raw.mlb_plays AS m
  LEFT JOIN public.games AS g ON g.pk = m.game_pk
  WHERE m.result__event_type IN (
    'single', 'double', 'triple', 'home_run', 'walk', 'intent_walk',
    'hit_by_pitch', 'strikeout', 'strikeout_double_play', 'sac_fly',
    'sac_fly_double_play', 'sac_bunt', 'field_error', 'fielders_choice',
    'fielders_choice_out', 'catcher_interf', 'grounded_into_double_play',
    'double_play', 'field_out', 'force_out', 'other_out'
  )
)
SELECT
  HASHTEXTEXTENDED(source_id::TEXT || ':' || game_id || ':' || play_seq::TEXT, 0)
    & x'7fffffffffffffff'::BIGINT AS pk,
  source_id,
  game_id,
  play_seq,
  season,
  game_date,
  inning,
  half_inning,
  batting_club_pk,
  pitching_club_pk,
  batter_pk,
  pitcher_pk,
  balls,
  strikes,
  outs_after,
  event_category = 'single' AS is_single,
  event_category = 'double' AS is_double,
  event_category = 'triple' AS is_triple,
  event_category = 'home_run' AS is_home_run,
  event_category = 'walk' AS is_walk,
  event_category = 'intentional_walk' AS is_intentional_walk,
  event_category = 'hit_by_pitch' AS is_hit_by_pitch,
  event_category = 'strikeout' AS is_strikeout,
  event_category = 'sacrifice_fly' AS is_sacrifice_fly,
  event_category = 'sacrifice_bunt' AS is_sacrifice_bunt,
  event_category = 'reached_on_error' AS is_reached_on_error,
  event_category = 'fielders_choice' AS is_fielders_choice,
  event_category = 'catcher_interference' AS is_catcher_interference,
  event_category = 'double_play' AS is_double_play,
  event_category = 'triple_play' AS is_triple_play,
  event_category = 'other_out' AS is_other_out,
  rbi,
  is_scoring_play
FROM unioned
WHERE season = EXTRACT(YEAR FROM CURRENT_DATE)::SMALLINT
