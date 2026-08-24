-- Rate-stat helper functions, applied via SQLMesh's `before_all` config
-- hook (see transform/config.py) so they're created/replaced on every
-- `sqlmesh plan`/`run`, same as any other project-managed object.
-- All divide-by-zero cases (e.g. zero AB) return NULL rather than erroring.

CREATE OR REPLACE FUNCTION public.batting_avg(h INTEGER, ab INTEGER)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND(h::NUMERIC / NULLIF(ab, 0), 3)
$$;

CREATE OR REPLACE FUNCTION public.on_base_pct(h INTEGER, bb INTEGER, hbp INTEGER, ab INTEGER, sf INTEGER)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND((h + bb + hbp)::NUMERIC / NULLIF(ab + bb + hbp + sf, 0), 3)
$$;

CREATE OR REPLACE FUNCTION public.slugging_pct(tb INTEGER, ab INTEGER)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND(tb::NUMERIC / NULLIF(ab, 0), 3)
$$;

CREATE OR REPLACE FUNCTION public.ops(h INTEGER, bb INTEGER, hbp INTEGER, ab INTEGER, sf INTEGER, tb INTEGER)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT public.on_base_pct(h, bb, hbp, ab, sf) + public.slugging_pct(tb, ab)
$$;
