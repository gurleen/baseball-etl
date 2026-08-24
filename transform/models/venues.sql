MODEL (
  name public.venues,
  kind FULL,
  grain (pk),
);

SELECT
  id AS pk,
  name,
  active,
  location__address1 AS address1,
  location__address2 AS address2,
  location__city AS city,
  location__state AS state,
  location__state_abbrev AS state_abbrev,
  location__postal_code AS postal_code,
  location__country AS country,
  location__phone AS phone,
  location__elevation AS elevation,
  location__azimuth_angle AS azimuth_angle,
  location__default_coordinates__latitude AS latitude,
  location__default_coordinates__longitude AS longitude,
  time_zone__id AS time_zone_id,
  time_zone__tz AS time_zone_abbreviation,
  time_zone__offset AS time_zone_offset,
  field_info__capacity AS capacity,
  field_info__turf_type AS turf_type,
  field_info__roof_type AS roof_type,
  field_info__left_line AS field_left_line,
  field_info__left AS field_left,
  field_info__left_center AS field_left_center,
  field_info__center AS field_center,
  field_info__right_center AS field_right_center,
  field_info__right AS field_right,
  field_info__right_line AS field_right_line
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY id ORDER BY season DESC) AS rn
  FROM raw.venues
)
WHERE rn = 1
