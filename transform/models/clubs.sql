MODEL (
  name public.clubs,
  kind FULL,
  grain (pk),
);

SELECT
  club_pk AS pk,
  name,
  team_name,
  club_name,
  franchise_name,
  short_name,
  location_name,
  abbreviation,
  team_code,
  file_code,
  first_year_of_play,
  active,
  sport_pk,
  league_pk,
  division_pk,
  venue_pk
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY club_pk ORDER BY season DESC) AS rn
  FROM public.clubs_history
)
WHERE rn = 1
