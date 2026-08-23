MODEL (
  name raw_sqlmesh.incremental__dlt_loads,
  kind FULL,
);

SELECT
  CAST(c.load_id AS TEXT) AS load_id,
  CAST(c.schema_name AS TEXT) AS schema_name,
  CAST(c.status AS BIGINT) AS status,
  CAST(c.inserted_at AS TIMESTAMP) AS inserted_at,
  CAST(c.schema_version_hash AS TEXT) AS schema_version_hash,
  TO_TIMESTAMP(CAST(c.load_id AS DOUBLE PRECISION)) as _dlt_load_time
FROM
  raw._dlt_loads as c
