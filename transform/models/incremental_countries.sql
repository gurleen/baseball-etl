MODEL (
  name raw_sqlmesh.incremental_countries,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column _dlt_load_time,
  ),
);

SELECT
  CAST(c.key_iso_alpha2 AS TEXT) AS key_iso_alpha2,
  CAST(c.key_iso_alpha3 AS TEXT) AS key_iso_alpha3,
  CAST(c.key_ioc AS TEXT) AS key_ioc,
  CAST(c.key_fifa AS TEXT) AS key_fifa,
  CAST(c.name_full_en AS TEXT) AS name_full_en,
  CAST(c._dlt_load_id AS TEXT) AS _dlt_load_id,
  CAST(c._dlt_id AS TEXT) AS _dlt_id,
  TO_TIMESTAMP(CAST(c._dlt_load_id AS DOUBLE PRECISION)) as _dlt_load_time
FROM
  raw.countries as c
WHERE
  TO_TIMESTAMP(CAST(c._dlt_load_id AS DOUBLE PRECISION)) BETWEEN @start_ts AND @end_ts
