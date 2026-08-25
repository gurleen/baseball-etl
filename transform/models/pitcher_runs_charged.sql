MODEL (
  name public.pitcher_runs_charged,
  kind FULL,
  grain (pk),
);

WITH unioned AS (
  SELECT
    1 AS source_id,
    r.gid AS game_id,
    r.pn::INT AS play_seq,
    'b' AS slot,
    r.season::SMALLINT AS season,
    p.pk AS pitcher_pk,
    (r.ur_b <> '1') AS is_earned
  FROM raw.plays AS r
  LEFT JOIN public.people AS p ON p.retro_id = r.prun_b
  WHERE NULLIF(r.run_b, '') IS NOT NULL

  UNION ALL

  SELECT
    1 AS source_id,
    r.gid AS game_id,
    r.pn::INT AS play_seq,
    '1' AS slot,
    r.season::SMALLINT AS season,
    p.pk AS pitcher_pk,
    (r.ur1 <> '1') AS is_earned
  FROM raw.plays AS r
  LEFT JOIN public.people AS p ON p.retro_id = r.prun1
  WHERE NULLIF(r.run1, '') IS NOT NULL

  UNION ALL

  SELECT
    1 AS source_id,
    r.gid AS game_id,
    r.pn::INT AS play_seq,
    '2' AS slot,
    r.season::SMALLINT AS season,
    p.pk AS pitcher_pk,
    (r.ur2 <> '1') AS is_earned
  FROM raw.plays AS r
  LEFT JOIN public.people AS p ON p.retro_id = r.prun2
  WHERE NULLIF(r.run2, '') IS NOT NULL

  UNION ALL

  SELECT
    1 AS source_id,
    r.gid AS game_id,
    r.pn::INT AS play_seq,
    '3' AS slot,
    r.season::SMALLINT AS season,
    p.pk AS pitcher_pk,
    (r.ur3 <> '1') AS is_earned
  FROM raw.plays AS r
  LEFT JOIN public.people AS p ON p.retro_id = r.prun3
  WHERE NULLIF(r.run3, '') IS NOT NULL

  UNION ALL

  SELECT
    2 AS source_id,
    m.game_pk::TEXT AS game_id,
    m.at_bat_index AS play_seq,
    rn._dlt_list_idx::TEXT AS slot,
    g.season AS season,
    rn.details__responsible_pitcher__id AS pitcher_pk,
    rn.details__earned AS is_earned
  FROM raw.mlb_plays__runners AS rn
  JOIN raw.mlb_plays AS m ON m._dlt_id = rn._dlt_parent_id
  LEFT JOIN public.games AS g ON g.pk = m.game_pk
  WHERE rn.details__is_scoring_event
)
SELECT
  HASHTEXTEXTENDED(source_id::TEXT || ':' || game_id || ':' || play_seq::TEXT || ':' || slot, 0)
    & x'7fffffffffffffff'::BIGINT AS pk,
  source_id,
  game_id,
  play_seq,
  season,
  pitcher_pk,
  is_earned
FROM unioned
WHERE pitcher_pk IS NOT NULL
