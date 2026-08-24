# baseball-etl

Two-stage pipeline: [dlt](https://dlthub.com/) loaders fetch source data into
a `raw` schema in Postgres, then [SQLMesh](https://sqlmesh.readthedocs.io/)
models transform it into typed, business-ready tables in `public`. Uses `uv`
for Python/deps.

## Adding a new dlt loader (raw data source)

1. **Write the source** in `baseball_etl/sources/<name>.py`. Look at
   `mlb_games.py` (simple REST API → flat rows) or `mlb_playbyplay.py`
   (REST API → nested JSON, dlt auto-flattens it) or
   `retrosheet_playbyplay.py` (zipped CSV) for the pattern to copy:
   a `@dlt.source` function returning one or more `@dlt.resource`
   generators.
   - `write_disposition="merge"` + `primary_key=...` for anything that gets
     re-fetched and can change (most things: games update status/score
     during the day, register data gets corrected). Only use `"replace"`
     for genuinely static reference data.
   - dlt's default naming convention converts `camelCase`/nested JSON keys
     to `snake_case` and flattens nested objects into `parent__child`
     columns automatically (or separate `table__child_table` tables for
     arrays) — don't hand-roll that flattening.
   - If the source needs a field that isn't natively present on each raw
     record (e.g. an id known only from the API call context, not in the
     payload itself), inject it before yielding, like
     `mlb_playbyplay.py` does with `game_pk`.
2. **Wire it into `baseball_etl/pipeline.py`**: import the source, add a
   `run_<name>()` function using the existing `_pipeline(pipeline_name)`
   helper (always `dataset_name="raw"`, credentials from `DATABASE_URL`).
3. **Wire it into `main.py`**: add a subparser mirroring an existing one
   (same flag names/help text style if the params overlap, e.g.
   `--season`/`--game-types`/`--start-date`/`--end-date` for anything keyed
   off the MLB schedule), dispatch to the new `run_<name>()`.
4. **Add a GitHub Actions workflow** in `.github/workflows/`, copying an
   existing one (e.g. `mlb-games.yml`) almost verbatim — same
   `workflow_dispatch` inputs, `DATABASE_URL` secret handling, and a cron
   schedule appropriate to how often the source changes. Every pipeline
   gets its own workflow in this repo.
5. **Verify before considering it done**: actually run
   `uv run main.py <subcommand> ...` against a small window/date range (not
   just import-check the code), then confirm the resulting `raw.<table>`
   looks right — column names/types, row count — via
   `uv run sqlmesh --paths transform fetchdf "SELECT * FROM raw.<table>
   LIMIT 5"` or similar.

## Adding a new SQLMesh model

Project lives in `transform/`. Config is `transform/config.py` (a Python
config, not YAML) — it parses `DATABASE_URL` from the environment so no
credentials are duplicated or committed. **Never write real credentials
into a `.yaml`/`.sql` file** — `sqlmesh init -t dlt` scaffolding does this
by default (writes the resolved password straight into `config.yaml`); if
you ever run that scaffolder again, immediately replace the generated
config with the `config.py` pattern before anything gets committed.

- **Layering**: `raw.*` (dlt-loaded) → optionally `raw_sqlmesh.*` staging
  models (only add this layer if the raw table actually needs cleanup,
  e.g. an all-`TEXT` CSV load like `raw.people`/`raw.plays` — skip it when
  the raw table is already well-typed, like dlt's JSON-inferred
  `raw.mlb_plays`/`raw.games`, since an identity passthrough adds nothing)
  → `public.*` mart models (typed, filtered, business-ready — this is what
  gets queried).
- **Primary keys are always named `pk`.** Prefer a real, meaningful,
  already-unique id when one exists across all rows (e.g. `public.people.pk`
  is the MLBAM id, not a hash) — small positive integers people recognize
  beat opaque values. Only fall back to a hash when no natural scalar id
  spans the whole table (e.g. combining two sources with unrelated native
  ids): `HASHTEXTEXTENDED(<key text>, 0) & x'7fffffffffffffff'::BIGINT` —
  the mask clears the sign bit so `pk` is always positive (plain
  `hashtextextended` returns a signed bigint, so roughly half the values
  would otherwise be negative; prefer this over `ABS()`, which throws on
  Postgres bigint's most-negative value).
- **Prefer `kind FULL`** for anything that isn't genuinely append-only
  event data — dimension/reference tables loaded via dlt `merge`
  (register data, schedules) don't have a meaningful "time column" to
  partition on. `INCREMENTAL_BY_TIME_RANGE` on a daily cron will silently
  stay empty for an entire day if all the source data lands within that
  still-open interval — bit us once on the `raw_sqlmesh.incremental_*`
  staging models, fixed by switching them to `FULL`.
- **Static lookup/dimension data** (e.g. a small source-id → source-name
  table) goes in `transform/seeds/*.csv` with a `kind SEED (path
  '../seeds/<file>.csv')` model in `transform/models/`, not hardcoded as
  literals inline.
- When combining multiple raw sources with different natural keys for the
  same real-world entity (e.g. a player's Retrosheet id vs MLBAM id),
  resolve to one canonical id space rather than carrying both — join
  through whichever table already established the canonical id (e.g.
  `public.people.retro_id` to resolve a Retrosheet id to `pk`/MLBAM id) so
  downstream tables have one clean FK, not per-source ids to reconcile
  every time.
- **Before applying**: `uv run sqlmesh --paths transform render
  <model_name>` renders/validates the SQL against the real schema without
  touching data — always do this first. `uv run sqlmesh --paths transform
  plan --auto-apply` actually creates/updates tables in the shared Postgres
  database — confirm with the user before running it (same bar as any
  other write to shared infrastructure).
- Verify with `fetchdf` after applying: row counts against expectations,
  spot-check a few rows, and check that any FK-ish column (e.g.
  `batter_pk`) actually resolves against the table it's supposed to point
  to.
- Clean up `transform/logs/` and `transform/.cache/` after running sqlmesh
  commands (already gitignored, but avoid leaving them around locally).

## Reference

- `docs/plans/` holds fully-designed-but-not-yet-implemented model plans
  (e.g. `public-plays-model.md`) — check there before redesigning
  something from scratch.
- `README.md` has the basic run commands for both stages.
