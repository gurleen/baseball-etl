# Add a combined `public.plays` SQLMesh model

> Drafted, reviewed, and refined in conversation but not implemented —
> shelved in favor of building `mlb_games` first (see
> `baseball_etl/sources/mlb_games.py`), since `public.games` needs to
> exist before this table is fully useful. Saved here verbatim so the
> design work isn't lost. Re-verify the raw row counts/coverage numbers
> below against current data before implementing, since they'll have
> grown.

## Context

`raw.plays` (Retrosheet's pre-parsed play-by-play, loaded by
`retrosheet_playbyplay`) and `raw.mlb_plays` (current-season MLB GUMBO
play-by-play, loaded by `mlb_playbyplay`) are two structurally very
different sources — Retrosheet is a ~180-column flat file with binary
event-type flags, MLB is nested JSON dlt-flattened into `snake_case`/
`double_underscore` columns — that both describe the same real-world
thing: one row per plate appearance. This adds `public.plays`, a wide,
unioned, stats-ready fact table over both, following the same raw→typed
pattern as `public.people` and reusing it: player columns point at
`public.people.pk` (the MLBAM id) instead of raw per-source ids.

Both raw tables already have real data loaded (`raw.plays`: 193,767 rows,
season 2025; `raw.mlb_plays`: 147,805 rows), confirmed by querying them
directly, so this plan is grounded in actual column names/values.

## Design decisions

- **Grain**: one row per plate appearance (PA), not every raw event.
  - Retrosheet: `WHERE pa = '1'` (Retrosheet's own real-PA flag) — drops
    ~7.1k standalone baserunning events out of 193.8k rows.
  - MLB: `result__type` is unconditionally `'atBat'` for every row (not
    a useful filter), but `result__event_type` includes ~384 rows that
    are really baserunning events sharing a batter's `at_bat_index`
    (`caught_stealing_*`, `pickoff_*`, `wild_pitch`, `stolen_base_3b`).
    These are excluded by construction: only recognized
    `result__event_type` values are kept (positive filter).
- **Player ids point at `public.people`**:
  - Retrosheet's `batter`/`pitcher` columns are Retrosheet person ids
    (e.g. `reynb001`) — joined through `public.people.retro_id` to get
    `pk` (the MLBAM id). Verified against the currently-loaded 2025 data:
    186,640/186,640 batters and pitchers both match 100%.
  - MLB's `matchup__batter__id`/`matchup__pitcher__id` are *already*
    MLBAM ids — the same id space as `public.people.pk` — so they're
    used directly as `batter_pk`/`pitcher_pk`, no join needed. (147,368
    of 147,805 — 99.7% — currently resolve to a row in `public.people`;
    the gap is expected register lag for brand-new callups, not a data
    problem.)
  - Neither side enforces the join with an inner join / not-null
    constraint, so play data stays complete even when the register
    hasn't caught up yet — `batter_pk`/`pitcher_pk` can be non-matching
    ids in that case, same as any other id column.
- **Wide boolean event columns instead of a text `event_type`**: one
  `BOOLEAN` (1 byte, smallest fixed-width type available) column per
  event category, mutually exclusive, mirroring Retrosheet's own flag-
  column style: `is_single`, `is_double`, `is_triple`, `is_home_run`,
  `is_walk`, `is_intentional_walk`, `is_hit_by_pitch`, `is_strikeout`,
  `is_sacrifice_fly`, `is_sacrifice_bunt`, `is_reached_on_error`,
  `is_fielders_choice`, `is_catcher_interference`, `is_double_play`,
  `is_triple_play`, `is_other_out`. Each source's raw event vocabulary
  is mapped to this set in a `CASE` (kept internal to a CTE, not
  exposed as a column), then pivoted into the 16 booleans.
- **`description` dropped** per explicit ask.
- **`source` becomes a lookup table**: new `public.play_sources` seed
  model (`transform/seeds/play_sources.csv`: `source_id,source_name` →
  `1,retrosheet` / `2,mlb`), and `plays.source_id SMALLINT` replaces the
  text `source` column. Chose a lookup table over a native Postgres
  `ENUM` type because SQLMesh models/seeds are version-tracked and
  plan-diffed the same way as everything else in this project; a raw
  `CREATE TYPE ... ENUM` would need to live outside that flow (SQLMesh
  has no first-class enum-type model kind) and `ALTER TYPE ... ADD
  VALUE` to extend it later is its own migration headache.
- **Team columns**: `batting_team`/`pitching_team` populated from
  Retrosheet (`batteam`/`pitteam`), left `NULL` for MLB — the MLB
  per-play payload doesn't carry team codes. This is exactly the gap
  `mlb_games` fixes at the game level; once `public.games` exists, this
  table could join through `game_id` to backfill MLB team columns
  instead of leaving them `NULL`.
- **Kind**: `FULL`, consistent with `public.people`.
- **`pk`**: `BIGINT`, deterministic hash (sign bit masked off, same fix
  as `public.people`) of `source_id`, `game_id`, `play_seq` — there's no
  single natural scalar id shared across both sources at this grain.
- `game_date` for MLB is derived from `about__start_time::DATE` (UTC),
  which can be off by one day from the local game date for very late
  games — a known simplification.
- `top_bot = '0'` is assumed to mean the top half (visitors batting) per
  standard Retrosheet convention — flag if that's backwards.

## Resulting `public.plays` schema

| Column | Type | Notes |
|---|---|---|
| `pk` | BIGINT | hash(`source_id`, `game_id`, `play_seq`) |
| `source_id` | SMALLINT | FK → `public.play_sources.source_id` |
| `game_id` | TEXT | Retrosheet `gid` / MLB `game_pk` |
| `play_seq` | INT | Retrosheet `pn` / MLB `at_bat_index` |
| `season` | SMALLINT | |
| `game_date` | DATE | |
| `inning` | SMALLINT | |
| `half_inning` | TEXT | `top` / `bottom` |
| `batting_team` | TEXT | Retrosheet only |
| `pitching_team` | TEXT | Retrosheet only |
| `batter_pk` | BIGINT | FK → `public.people.pk` |
| `pitcher_pk` | BIGINT | FK → `public.people.pk` |
| `balls` | SMALLINT | |
| `strikes` | SMALLINT | |
| `outs_after` | SMALLINT | |
| `is_single` | BOOLEAN | |
| `is_double` | BOOLEAN | |
| `is_triple` | BOOLEAN | |
| `is_home_run` | BOOLEAN | |
| `is_walk` | BOOLEAN | |
| `is_intentional_walk` | BOOLEAN | |
| `is_hit_by_pitch` | BOOLEAN | |
| `is_strikeout` | BOOLEAN | |
| `is_sacrifice_fly` | BOOLEAN | |
| `is_sacrifice_bunt` | BOOLEAN | |
| `is_reached_on_error` | BOOLEAN | |
| `is_fielders_choice` | BOOLEAN | |
| `is_catcher_interference` | BOOLEAN | |
| `is_double_play` | BOOLEAN | |
| `is_triple_play` | BOOLEAN | |
| `is_other_out` | BOOLEAN | |
| `rbi` | SMALLINT | |
| `is_scoring_play` | BOOLEAN | |

## Implementation

- New file: `transform/seeds/play_sources.csv`
  ```csv
  source_id,source_name
  1,retrosheet
  2,mlb
  ```
- New file: `transform/models/play_sources.sql`
  ```sql
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
  ```
- New file: `transform/models/plays.sql` — a `mapped` CTE per source
  (event-category `CASE`, id-resolution join for Retrosheet), `UNION
  ALL`'d, then an outer `SELECT` that pivots the mapped category into
  the 16 booleans and computes `pk` once:

  ```sql
  MODEL (
    name public.plays,
    kind FULL,
    grain (pk),
  );

  WITH unioned AS (
    SELECT
      1 AS source_id,
      r.gid AS game_id,
      r.pn::INT AS play_seq,
      r.season::SMALLINT AS season,
      TO_DATE(r.date, 'YYYYMMDD') AS game_date,
      r.inning::SMALLINT AS inning,
      CASE r.top_bot WHEN '0' THEN 'top' WHEN '1' THEN 'bottom' END AS half_inning,
      r.batteam AS batting_team,
      r.pitteam AS pitching_team,
      batter_p.pk AS batter_pk,
      pitcher_p.pk AS pitcher_pk,
      r.balls::SMALLINT AS balls,
      r.strikes::SMALLINT AS strikes,
      r.outs_post::SMALLINT AS outs_after,
      CASE
        WHEN r.hr = '1' THEN 'home_run'
        WHEN r.triple = '1' THEN 'triple'
        WHEN r.double = '1' THEN 'double'
        WHEN r.single = '1' THEN 'single'
        WHEN r.iw = '1' THEN 'intentional_walk'
        WHEN r.walk = '1' THEN 'walk'
        WHEN r.hbp = '1' THEN 'hit_by_pitch'
        WHEN r.k = '1' THEN 'strikeout'
        WHEN r.sf = '1' THEN 'sacrifice_fly'
        WHEN r.sh = '1' THEN 'sacrifice_bunt'
        WHEN r.roe = '1' THEN 'reached_on_error'
        WHEN r.fc = '1' THEN 'fielders_choice'
        WHEN r.xi = '1' THEN 'catcher_interference'
        WHEN r.tp = '1' THEN 'triple_play'
        WHEN r.gdp = '1' OR r.othdp = '1' THEN 'double_play'
        WHEN r.othout = '1' THEN 'other_out'
      END AS event_category,
      r.rbi::SMALLINT AS rbi,
      (r.runs::INT > 0) AS is_scoring_play
    FROM raw.plays AS r
    LEFT JOIN public.people AS batter_p ON batter_p.retro_id = r.batter
    LEFT JOIN public.people AS pitcher_p ON pitcher_p.retro_id = r.pitcher
    WHERE r.pa = '1'

    UNION ALL

    SELECT
      2 AS source_id,
      m.game_pk::TEXT AS game_id,
      m.at_bat_index AS play_seq,
      EXTRACT(YEAR FROM m.about__start_time)::SMALLINT AS season,
      m.about__start_time::DATE AS game_date,
      m.about__inning::SMALLINT AS inning,
      m.about__half_inning AS half_inning,
      NULL AS batting_team,
      NULL AS pitching_team,
      m.matchup__batter__id AS batter_pk,
      m.matchup__pitcher__id AS pitcher_pk,
      m.count__balls::SMALLINT AS balls,
      m.count__strikes::SMALLINT AS strikes,
      m.count__outs::SMALLINT AS outs_after,
      CASE m.result__event_type
        WHEN 'single' THEN 'single'
        WHEN 'double' THEN 'double'
        WHEN 'triple' THEN 'triple'
        WHEN 'home_run' THEN 'home_run'
        WHEN 'walk' THEN 'walk'
        WHEN 'intent_walk' THEN 'intentional_walk'
        WHEN 'hit_by_pitch' THEN 'hit_by_pitch'
        WHEN 'strikeout' THEN 'strikeout'
        WHEN 'strikeout_double_play' THEN 'strikeout'
        WHEN 'sac_fly' THEN 'sacrifice_fly'
        WHEN 'sac_fly_double_play' THEN 'sacrifice_fly'
        WHEN 'sac_bunt' THEN 'sacrifice_bunt'
        WHEN 'field_error' THEN 'reached_on_error'
        WHEN 'fielders_choice' THEN 'fielders_choice'
        WHEN 'fielders_choice_out' THEN 'fielders_choice'
        WHEN 'catcher_interf' THEN 'catcher_interference'
        WHEN 'grounded_into_double_play' THEN 'double_play'
        WHEN 'double_play' THEN 'double_play'
        WHEN 'field_out' THEN 'other_out'
        WHEN 'force_out' THEN 'other_out'
        WHEN 'other_out' THEN 'other_out'
      END AS event_category,
      m.result__rbi::SMALLINT AS rbi,
      m.about__is_scoring_play AS is_scoring_play
    FROM raw.mlb_plays AS m
    WHERE m.result__event_type IN (
      'single', 'double', 'triple', 'home_run', 'walk', 'intent_walk',
      'hit_by_pitch', 'strikeout', 'strikeout_double_play', 'sac_fly',
      'sac_fly_double_play', 'sac_bunt', 'field_error', 'fielders_choice',
      'fielders_choice_out', 'catcher_interf', 'grounded_into_double_play',
      'double_play', 'field_out', 'force_out', 'other_out'
    )
  )
  SELECT
    HASHTEXTEXTENDED(source_id::TEXT || ':' || game_id || ':' || play_seq::TEXT, 0)
      & x'7fffffffffffffff'::BIGINT AS pk,
    source_id,
    game_id,
    play_seq,
    season,
    game_date,
    inning,
    half_inning,
    batting_team,
    pitching_team,
    batter_pk,
    pitcher_pk,
    balls,
    strikes,
    outs_after,
    event_category = 'single' AS is_single,
    event_category = 'double' AS is_double,
    event_category = 'triple' AS is_triple,
    event_category = 'home_run' AS is_home_run,
    event_category = 'walk' AS is_walk,
    event_category = 'intentional_walk' AS is_intentional_walk,
    event_category = 'hit_by_pitch' AS is_hit_by_pitch,
    event_category = 'strikeout' AS is_strikeout,
    event_category = 'sacrifice_fly' AS is_sacrifice_fly,
    event_category = 'sacrifice_bunt' AS is_sacrifice_bunt,
    event_category = 'reached_on_error' AS is_reached_on_error,
    event_category = 'fielders_choice' AS is_fielders_choice,
    event_category = 'catcher_interference' AS is_catcher_interference,
    event_category = 'double_play' AS is_double_play,
    event_category = 'triple_play' AS is_triple_play,
    event_category = 'other_out' AS is_other_out,
    rbi,
    is_scoring_play
  FROM unioned
  ```

## Verification

- `uv run sqlmesh --paths transform render public.play_sources` and
  `render public.plays` to confirm both compile without touching the
  database.
- After approving applying (a write to the shared Postgres instance):
  `uv run sqlmesh --paths transform plan --auto-apply`, then spot-check
  with `fetchdf` — row count (~186.6k retrosheet + ~144k mlb after the
  event-type filter), that exactly one `is_*` boolean is true per row,
  and a join from `plays.batter_pk` to `public.people.pk` to confirm
  names resolve.
