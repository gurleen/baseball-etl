MODEL (
  name public.leverage_index,
  kind SEED (
    path '../seeds/leverage_index.csv'
  ),
  columns (
    pk INTEGER,
    inning SMALLINT,
    half_inning TEXT,
    outs SMALLINT,
    runner_on_first BOOLEAN,
    runner_on_second BOOLEAN,
    runner_on_third BOOLEAN,
    home_score_margin SMALLINT,
    leverage_index NUMERIC
  ),
  grain (pk),
);
