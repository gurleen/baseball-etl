MODEL (
  name public.play_sources,
  kind SEED (
    path '../seeds/play_sources.csv'
  ),
  columns (
    source_id SMALLINT,
    source_name TEXT
  ),
  grain (source_id),
);
