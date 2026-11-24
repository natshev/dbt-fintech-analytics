# dbt fintech analytics

Learning project: an analytics layer built with dbt (dbt-postgres, PostgreSQL 18) on synthetic fintech data — staging → intermediate → marts, dimensional modeling, tests, documentation and macros.

All data is synthetic. This is a portfolio project, not production work.

Status: work in progress.

## Local dbt setup

Install the pinned dependencies inside `.venv`:

```bash
pip install -r requirements.txt
```

The local `profiles.yml` reads the database password from `DBT_POSTGRES_PASSWORD`. Set it in the current terminal before running dbt.

PowerShell:

```powershell
$env:DBT_POSTGRES_PASSWORD = "your_database_password"
```

Git Bash:

```bash
export DBT_POSTGRES_PASSWORD="your_database_password"
```

Verify the connection and run the project from the repository root:

```bash
.venv/Scripts/dbt.exe debug
.venv/Scripts/dbt.exe build
```

`profiles.yml` is local machine configuration and is excluded from version control. Do not commit real credentials.
