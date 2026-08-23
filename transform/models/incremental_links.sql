MODEL (
  name raw_sqlmesh.incremental_links,
  kind FULL,
);

SELECT
  CAST(c.key_person AS TEXT) AS key_person,
  CAST(c.source AS TEXT) AS source,
  CAST(c.value AS TEXT) AS value,
  CAST(c._dlt_load_id AS TEXT) AS _dlt_load_id,
  CAST(c._dlt_id AS TEXT) AS _dlt_id,
  TO_TIMESTAMP(CAST(c._dlt_load_id AS DOUBLE PRECISION)) as _dlt_load_time
FROM
  raw.links as c
