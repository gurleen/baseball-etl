MODEL (
  name public.sports,
  kind FULL,
  grain (pk),
);

SELECT
  id AS pk,
  code,
  name,
  abbreviation,
  sort_order,
  active_status AS active
FROM raw.sports
