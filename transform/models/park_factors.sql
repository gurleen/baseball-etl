MODEL (
  name public.park_factors,
  kind FULL,
  grain (pk),
);

SELECT
  HASHTEXTEXTENDED(clubs_history.club_pk::TEXT || ':' || park_factors.season::TEXT, 0)
    & x'7fffffffffffffff'::BIGINT AS pk,
  clubs_history.club_pk AS club_pk,
  park_factors.season::SMALLINT AS season,
  NULLIF(park_factors.basic_5yrx, '')::NUMERIC AS basic_5yr,
  NULLIF(park_factors._3yr, '')::NUMERIC AS three_yr,
  NULLIF(park_factors._1yr, '')::NUMERIC AS one_yr,
  NULLIF(park_factors._1_b, '')::NUMERIC AS single,
  NULLIF(park_factors._2_b, '')::NUMERIC AS double,
  NULLIF(park_factors._3_b, '')::NUMERIC AS triple,
  NULLIF(park_factors.hr, '')::NUMERIC AS hr,
  NULLIF(park_factors.so, '')::NUMERIC AS so,
  NULLIF(park_factors.bb, '')::NUMERIC AS bb,
  NULLIF(park_factors.gb, '')::NUMERIC AS gb,
  NULLIF(park_factors.fb, '')::NUMERIC AS fb,
  NULLIF(park_factors.ld, '')::NUMERIC AS ld,
  NULLIF(park_factors.iffb, '')::NUMERIC AS iffb,
  NULLIF(park_factors.fip, '')::NUMERIC AS fip
FROM raw.fangraphs_park_factors AS park_factors
JOIN public.clubs_history AS clubs_history
  ON clubs_history.club_name = park_factors.team
  AND clubs_history.season = park_factors.season::SMALLINT
