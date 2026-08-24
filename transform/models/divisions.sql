MODEL (
  name public.divisions,
  kind FULL,
  grain (pk),
);

SELECT
  id AS pk,
  name,
  name_short,
  abbreviation,
  league__id AS league_pk,
  sport__id AS sport_pk,
  active
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY id ORDER BY season DESC) AS rn
  FROM raw.divisions
)
WHERE rn = 1
