MODEL (
  name public.clubs_history,
  kind FULL,
  grain (pk),
);

SELECT
  HASHTEXTEXTENDED(id::TEXT || ':' || season::TEXT, 0) & x'7fffffffffffffff'::BIGINT AS pk,
  id AS club_pk,
  season::SMALLINT AS season,
  name,
  team_name,
  club_name,
  franchise_name,
  short_name,
  location_name,
  abbreviation,
  team_code,
  file_code,
  NULLIF(first_year_of_play, '')::SMALLINT AS first_year_of_play,
  active,
  sport__id AS sport_pk,
  league__id AS league_pk,
  division__id AS division_pk,
  venue__id AS venue_pk
FROM raw.teams
