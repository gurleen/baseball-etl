MODEL (
  name raw_sqlmesh.incremental_names,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column _dlt_load_time,
  ),
);

SELECT
  CAST(c.key_person AS TEXT) AS key_person,
  CAST(c.name_last AS TEXT) AS name_last,
  CAST(c.name_first AS TEXT) AS name_first,
  CAST(c.name_given AS TEXT) AS name_given,
  CAST(c.birth_year AS TEXT) AS birth_year,
  CAST(c.birth_month AS TEXT) AS birth_month,
  CAST(c.birth_day AS TEXT) AS birth_day,
  CAST(c.altname_type AS TEXT) AS altname_type,
  CAST(c.altname_lang AS TEXT) AS altname_lang,
  CAST(c.altname_last AS TEXT) AS altname_last,
  CAST(c.altname_first AS TEXT) AS altname_first,
  CAST(c.altname_given AS TEXT) AS altname_given,
  CAST(c.altname_matrilineal AS TEXT) AS altname_matrilineal,
  CAST(c.altname_nick AS TEXT) AS altname_nick,
  CAST(c.altname_date_start AS TEXT) AS altname_date_start,
  CAST(c.altname_date_end AS TEXT) AS altname_date_end,
  CAST(c._dlt_load_id AS TEXT) AS _dlt_load_id,
  CAST(c._dlt_id AS TEXT) AS _dlt_id,
  TO_TIMESTAMP(CAST(c._dlt_load_id AS DOUBLE PRECISION)) as _dlt_load_time
FROM
  raw.names as c
WHERE
  TO_TIMESTAMP(CAST(c._dlt_load_id AS DOUBLE PRECISION)) BETWEEN @start_ts AND @end_ts
