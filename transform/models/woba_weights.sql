MODEL (
  name public.woba_weights,
  kind FULL,
  grain (pk),
);

SELECT
  season::SMALLINT AS pk,
  w_oba::NUMERIC AS woba,
  w_oba_scale::NUMERIC AS woba_scale,
  w_bb::NUMERIC AS wbb,
  w_hbp::NUMERIC AS whbp,
  w1_b::NUMERIC AS w1b,
  w2_b::NUMERIC AS w2b,
  w3_b::NUMERIC AS w3b,
  w_hr::NUMERIC AS whr,
  run_sb::NUMERIC AS run_sb,
  run_cs::NUMERIC AS run_cs,
  r_pa::NUMERIC AS r_pa,
  r_w::NUMERIC AS r_w,
  c_fip::NUMERIC AS c_fip
FROM raw.fangraphs_guts
