MODEL (
  name public.people,
  kind FULL,
  grain (pk),
);

SELECT
  -- pk is the MLBAM id itself (int-typed); rows without one are filtered out below
  NULLIF(key_mlbam, '')::BIGINT AS pk,
  key_person AS person_id,
  key_uuid::UUID AS uuid,
  key_retro AS retro_id,
  key_bbref AS bbref_id,
  key_bbref_minors AS bbref_minors_id,
  key_fangraphs AS fangraphs_id,
  name_last AS last_name,
  name_first AS first_name,
  name_given AS given_name,
  name_suffix AS suffix,
  name_nick AS nickname,
  CASE WHEN NULLIF(birth_year, '') IS NOT NULL THEN
    MAKE_DATE(
      NULLIF(birth_year, '')::INT,
      COALESCE(NULLIF(birth_month, '')::INT, 1),
      COALESCE(NULLIF(birth_day, '')::INT, 1)
    )
  END AS birth_date,
  CASE WHEN NULLIF(death_year, '') IS NOT NULL THEN
    MAKE_DATE(
      NULLIF(death_year, '')::INT,
      COALESCE(NULLIF(death_month, '')::INT, 1),
      COALESCE(NULLIF(death_day, '')::INT, 1)
    )
  END AS death_date,
  NULLIF(mlb_played_first, '')::SMALLINT AS mlb_debut_year,
  NULLIF(mlb_played_last, '')::SMALLINT AS mlb_last_season
FROM raw_sqlmesh.incremental_people
WHERE NULLIF(mlb_played_first, '') IS NOT NULL
  AND NULLIF(key_mlbam, '') IS NOT NULL
