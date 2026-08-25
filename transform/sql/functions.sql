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

CREATE OR REPLACE FUNCTION public.iso(h INTEGER, tb INTEGER, ab INTEGER)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND((tb - h)::NUMERIC / NULLIF(ab, 0), 3)
$$;

CREATE OR REPLACE FUNCTION public.babip(h INTEGER, hr INTEGER, ab INTEGER, k INTEGER, sf INTEGER)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND((h - hr)::NUMERIC / NULLIF(ab - k - hr + sf, 0), 3)
$$;

CREATE OR REPLACE FUNCTION public.bb_pct(bb INTEGER, pa INTEGER)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND(bb::NUMERIC / NULLIF(pa, 0), 3)
$$;

CREATE OR REPLACE FUNCTION public.k_pct(k INTEGER, pa INTEGER)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND(k::NUMERIC / NULLIF(pa, 0), 3)
$$;

CREATE OR REPLACE FUNCTION public.bb_k_ratio(bb INTEGER, k INTEGER)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND(bb::NUMERIC / NULLIF(k, 0), 3)
$$;

CREATE OR REPLACE FUNCTION public.woba(
  ubb INTEGER, hbp INTEGER, singles INTEGER, doubles INTEGER, triples INTEGER, hr INTEGER, ab INTEGER, sf INTEGER,
  wbb NUMERIC, whbp NUMERIC, w1b NUMERIC, w2b NUMERIC, w3b NUMERIC, whr NUMERIC
)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND(
    (wbb * ubb + whbp * hbp + w1b * singles + w2b * doubles + w3b * triples + whr * hr)
      / NULLIF(ab + ubb + sf + hbp, 0), 3)
$$;

CREATE OR REPLACE FUNCTION public.era(er INTEGER, outs INTEGER)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND(27.0 * er / NULLIF(outs, 0), 2)
$$;

CREATE OR REPLACE FUNCTION public.whip(bb INTEGER, h INTEGER, outs INTEGER)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND(3.0 * (bb + h) / NULLIF(outs, 0), 2)
$$;

CREATE OR REPLACE FUNCTION public.k9(k INTEGER, outs INTEGER)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND(27.0 * k / NULLIF(outs, 0), 1)
$$;

CREATE OR REPLACE FUNCTION public.bb9(bb INTEGER, outs INTEGER)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND(27.0 * bb / NULLIF(outs, 0), 1)
$$;

CREATE OR REPLACE FUNCTION public.hr9(hr INTEGER, outs INTEGER)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND(27.0 * hr / NULLIF(outs, 0), 1)
$$;

CREATE OR REPLACE FUNCTION public.fip(hr INTEGER, bb INTEGER, hbp INTEGER, k INTEGER, outs INTEGER, cfip NUMERIC)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND((13.0 * hr + 3.0 * (bb + hbp) - 2.0 * k) / (NULLIF(outs, 0) / 3.0) + cfip, 2)
$$;

CREATE OR REPLACE FUNCTION public.lob_pct(h INTEGER, bb INTEGER, hbp INTEGER, r INTEGER, hr INTEGER)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND((h + bb + hbp - r)::NUMERIC / NULLIF(h + bb + hbp - 1.4 * hr, 0), 3)
$$;

-- https://library.fangraphs.com/offense/wrc/
-- wRC+ = ((wRAA/PA + lgR/PA + (lgR/PA - parkFactor * lgR/PA)) / lgR/PA) * 100
-- wRAA/PA simplifies to (woba - lgWoba) / wobaScale (the PA terms cancel).
-- lg_woba/lg_r_pa are expected to be the batter's own league's (AL/NL) rates
-- for that season (see batting_stats_season.sql), not MLB-wide; this does
-- not exclude pitchers from them since that split isn't tracked here.
CREATE OR REPLACE FUNCTION public.wrc_plus(
  woba NUMERIC, lg_woba NUMERIC, woba_scale NUMERIC, lg_r_pa NUMERIC, park_factor NUMERIC
)
RETURNS INTEGER
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT ROUND(
    (
      (
        (woba - lg_woba) / NULLIF(woba_scale, 0)
        + lg_r_pa
        + (lg_r_pa - (park_factor / 100.0) * lg_r_pa)
      ) / NULLIF(lg_r_pa, 0)
    ) * 100
  )::INTEGER
$$;
