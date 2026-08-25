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
  park_factors.basic_5yrx::NUMERIC AS basic_5yr,
  park_factors._3yr::NUMERIC AS three_yr,
  park_factors._1yr::NUMERIC AS one_yr,
  park_factors._1_b::NUMERIC AS single,
  park_factors._2_b::NUMERIC AS double,
  park_factors._3_b::NUMERIC AS triple,
  park_factors.hr::NUMERIC AS hr,
  park_factors.so::NUMERIC AS so,
  park_factors.bb::NUMERIC AS bb,
  park_factors.gb::NUMERIC AS gb,
  park_factors.fb::NUMERIC AS fb,
  park_factors.ld::NUMERIC AS ld,
  park_factors.iffb::NUMERIC AS iffb,
  park_factors.fip::NUMERIC AS fip
FROM raw.fangraphs_park_factors AS park_factors
JOIN public.clubs_history AS clubs_history
  ON clubs_history.club_name = park_factors.team
  AND clubs_history.season = park_factors.season::SMALLINT
