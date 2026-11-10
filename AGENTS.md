# AGENTS.md — dbt fintech analytics

Guidance for AI coding agents working in this repository. All data is synthetic; this is a learning/portfolio project, never production work.

## Project overview

Analytics layer built with **dbt Core** (dbt-postgres) on a local **PostgreSQL 18** database, over synthetic fintech data. Domain: consumer lending (cash and POS loans, PHP, Philippines), period 2024-10-01 to 2026-09-30, as-of date 2026-09-30.

Architecture follows the classic ELT flow:

1. `scripts/generate_raw/` — pure-SQL generator that emulates a source system into the `raw` schema (not a dbt layer, no dbt involved).
2. dbt layers: **staging** (views, cleaning) → **intermediate** (views, business logic) → **marts** (tables, star schema `dim_*` / `fct_*`).
3. SCD2 history via dbt **snapshots** (`snapshots/customers_snapshot.yml`).
4. Tests: generic (unique, not_null, relationships, accepted_values), custom generic and singular reconciliation tests planned.
5. Planned extras: 2–3 macros, dbt docs, GitHub Actions CI, a small Python reconciliation report script.

Repository: `c:\git\dbt-fintech-analytics`, GitHub https://github.com/natshev/dbt-fintech-analytics (public), branch `main`.

## Tech stack and environment

- **dbt Core 1.12.6 + dbt-postgres 1.11.0**, installed in `.venv` (Python 3.14.3). Run as `.venv\Scripts\dbt.exe` or with the venv activated. Pin versions explicitly (`dbt-core~=1.12.0`, `dbt-postgres~=1.11.0`) — without pins, pip resolves dbt-core to a 1.13 beta.
- The new dbt v2 engine does not support Postgres, so the project stays on dbt Core v1; the project language is shared between v1 and v2.
- **PostgreSQL 18** local Windows install (EDB installer), service `postgresql-x64-18`, port 5432, database `analytics`, user `dbt_user`. SQL execution and data checks are done in DBeaver.
- No `requirements.txt` currently; environment details live in `CLAUDE.md` (see below).

## Repository layout

- `dbt_project.yml` — project name and profile `fintech_analytics`; per-layer config: `staging` and `intermediate` are views in same-named schemas, `marts` are tables in schema `marts`.
- `profiles.yml` — local dbt profile (target `dev`, host 127.0.0.1, db `analytics`, target schema `dbt_dev`, 4 threads). **Gitignored** (see Security).
- `macros/generate_schema_name.sql` — overrides dbt default `<target_schema>_<layer>`: layer schemas (`staging`, `intermediate`, `marts`) are used as-is.
- `models/staging/` — 9 `stg_*` models plus `_sources.yml` (source `raw`, 9 tables, key tests) and `_stg_models.yml` (model and column descriptions with tests). `models/intermediate/` and `models/marts/` do not exist yet — create them with the first model of each layer.
- `snapshots/customers_snapshot.yml` — SCD2 snapshot of `raw_customers` (timestamp strategy on `updated_at`, schema `snapshots`). Newly added, not yet committed.
- `scripts/generate_raw/` — synthetic data generator: `00_schema.sql` … `09_provider_statement.sql`, one file per table, plus `run_all.sql` (psql runner with `\ir` in dependency order and a control-totals query at the end). Re-runnable: each file drops and recreates its table; `setseed()` before every random insert makes output reproducible; files reading `raw_loans` after its `UPDATE` must order explicitly (physical row order changes).
- `target/`, `logs/` — dbt artifacts, gitignored.
- `CLAUDE.md` — local working journal in Russian (gitignored, not on GitHub). It is the authoritative, continuously updated record of progress, decisions, control totals, and environment quirks; consult it for current state before planning work.
- `PLAN.md` — plan from a previous session (local-only, listed in `.git/info/exclude`). Reference only; the repo intentionally deviates from it.

## Build and run commands

Regenerate the raw data (from the project root, PowerShell — psql is not on PATH):

```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h 127.0.0.1 -U dbt_user -d analytics -f scripts/generate_raw/run_all.sql
```

The `-h 127.0.0.1` matters: without it psql tries IPv6 `::1` first and fails with Permission denied. `run_all.sql` sets `ON_ERROR_STOP` and ends with a control-totals query; expected counts/sums are documented in its header comments — a correct run matches them exactly (e.g. raw_customers 2000 rows, raw_payments 11062 rows of which 73 planted duplicates).

dbt commands (Git Bash / PowerShell):

```bash
.venv/Scripts/dbt.exe debug        # verify profile and DB connection
.venv/Scripts/dbt.exe build        # run models + tests
.venv/Scripts/dbt.exe test --select staging   # 50 PASS + 1 WARN expected (WARN = planted payment duplicates)
.venv/Scripts/dbt.exe docs generate
```

There is no CI yet; the intended pipeline is GitHub Actions with a Postgres service: run the generator via psql, then `dbt build`.

## Testing strategy

- Generic tests are declared in YAML property files using the dbt 1.12 key **`data_tests:`** (the old `tests:` key is renamed). Test arguments (`values`, `to`, `field`) must be nested under **`arguments:`** — the older flat syntax triggers a deprecation in dbt 1.11+/errors in 1.12.
- Source tests (`_sources.yml`): unique + not_null on primary keys of 8 raw tables; `raw_payments.payment_id` unique test has `severity: warn` because the generator plants ~0.5% duplicate loads.
- Model tests (`_stg_models.yml`): unique/not_null on keys, `relationships` between staging models, `accepted_values` on enumerations (channel, status, product_type, employment_type, risk_segment).
- Deliberately not tested: `raw_provider_statement.payment_reference → stg_payments` (the provider statement plants 46 extra transactions — catching those is the job of the future reconciliation model, not a test).
- Planned: custom generic tests (composite key on `stg_marketing_spend`, `non_negative`), singular reconciliation tests — roll-forward (opening balance + disbursements − principal repaid = closing balance) and provider statement vs `raw_payments`.
- Raw tables intentionally have no PK/FK constraints; integrity is enforced by dbt tests instead.

## Code style and conventions

- Naming: snake_case; model prefixes `stg_`, `int_`, `dim_`, `fct_` (`mart_` for aggregates if needed); schemas per layer (`staging`, `intermediate`, `marts`, `snapshots`).
- Model SQL: PostgreSQL dialect, dbt CTE style — import CTE (`source`/`ref`) → logical CTEs → final `select`. Each model file starts with a one-line header comment; non-obvious blocks (especially planted source defects being cleaned) get inline comments.
- Generator scripts: lowercase SQL, `varchar` rather than text, `int` for integers, English header comment describing grain, distributions, defects, and reproducibility notes (`setseed`, explicit `order by` where row order matters).
- Language: all project artifacts — README, YAML descriptions, SQL comments, commit messages — are in English. Working notes (`CLAUDE.md`) are in Russian.
- No emoji anywhere.

## Security and privacy

- `profiles.yml` contains the database password in plaintext and is gitignored — keep it that way; never commit it or copy the credential into committed files, issues, or docs.
- `CLAUDE.md`, `PLAN.md`, `.user.yml`, `target/`, `logs/`, `.venv/` are all excluded from version control; leave them excluded.
- All data is synthetic by design. Never present project results as real production or work experience; README and commits must keep the synthetic-data disclaimer.

## Current status and roadmap

Done: raw generator (all 10 steps + psql runner, verified against control totals), dbt profile and project config, all 9 staging models with tests (staging layer complete, 50 PASS + 1 expected WARN), per-layer schemas/materializations via `generate_schema_name`.

Immediate next steps (per `CLAUDE.md`):

1. Second load of `raw_customers` (~5% of customers change `region` or `risk_segment`, `updated_at` moves), then run the `customers_snapshot` to produce SCD2 history.
2. Intermediate models: `int_loan_schedule_payments` (plan vs actual per installment), `int_loan_balance_monthly` (balance and DPD at month end).
3. Marts (star schema): `dim_customer` (from snapshot), `dim_product`, `dim_date`, `fct_disbursements`, `fct_payments`, `fct_loan_month`; `mart_finance_kpi_monthly` as the single source of truth for Finance metrics; application funnel by channel for Growth (campaigns, CAC).
4. Macros (`dpd_bucket()`, `safe_divide()`, `month_end()`), custom generic and singular reconciliation tests.
5. Documentation (`dbt docs generate`), GitHub Actions CI, English README.

Do not expand project scope (no new marts for other roles/domains; no write-offs — the plan explicitly excludes them).
## AI Agent Behavior & Interaction Rules
- **Language:** Always communicate with the user in Russian.
- **Strict Manual Coding:** The user writes all code manually as part of their learning process. NEVER offer to create, edit, or write files using your tools. Output code blocks in Markdown chat only. The user will copy and paste them.
- **Permissions:** NEVER run terminal commands or make any changes to the project without explicit user approval.
- **Code Language:** All code, SQL models, YAML descriptions, and git commit messages must be written in English.