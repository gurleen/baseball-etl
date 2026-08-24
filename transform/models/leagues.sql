MODEL (
  name public.leagues,
  kind FULL,
  grain (pk),
);

SELECT
  id AS pk,
  name,
  abbreviation,
  name_short,
  sport__id AS sport_pk,
  active
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY id ORDER BY season DESC) AS rn
  FROM raw.leagues
)
WHERE rn = 1
