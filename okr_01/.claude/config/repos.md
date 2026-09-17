# Haji Repo Map

Use this file to understand sibling repos under `Haji/` when running shared
Claude workflows.

## Cross-repo data model

All four repos read the **same shared MySQL database** directly. No repo imports
ORM code from another repo — each mirrors schema locally and must be synced
manually after `ha-speaking-api` migrations.

```
ha-speaking-api (Alembic owner)
       ↓ migration runs on shared DB
ha-speaking-admin-web    → copy db_models.py
ha-speaking-company-web  → domain/entities/ per-table
ha-speaking-haij-student-api → domain/entities/ per-table + DTO contract
```

---

## Source of truth repo

### `ha-speaking-api`

- **Role:** owns core models, migrations, schema changes
- **Purpose:** canonical data structure, persistence, internal API
- **Technology:** FastAPI, SQLAlchemy, Alembic, Pydantic
- **Data access:** direct MySQL; migration owner
- **ORM location:** `src/app/db/db_models.py` (~87 tables, single file)
- **Contract layer:** `src/app/models/` Pydantic (separate from DB model)
- **depends_on:** none
- **deploy_notes:** Run `alembic upgrade head` first. Also check `src/app/db/views/views.py`, `src/app/db/seed/`, and `docs/db-erd.md` if schema changes.
- **Scan order:**
  1. `src/app/db/db_models.py` — column, enum, relationship, FK, index
  2. `src/app/migrations/versions/` — upgrade/downgrade matches model
  3. `src/app/db/repositories/` and `src/app/db/hai_j/` — query, join, eager load
  4. `src/app/services/` — field access, lang mapping, prompt columns
  5. `src/app/models/` — Pydantic request/response if API contract changes
  6. `src/app/db/views/views.py` — views referencing changed columns/tables
  7. `src/app/db/seed/` — seed JSON/Python for required fields
- **Typical impact sources:** model field changes, migration changes, relation changes, response contract changes
- **Breakage patterns:** migration/model drift, view breakage, seed missing required field, Pydantic contract not updated

---

## Consumer repos

### `ha-speaking-admin-web`

- **Role:** admin-facing web app — CRUD for all HAIJ content, company/user management
- **Purpose:** internal admin portal for content, students, companies, exams, homework, learning stats
- **Technology:** Flask, Jinja2, SQLAlchemy, Python
- **Data access:** direct MySQL via `DATABASE_URL`; **no Python API client** to ha-speaking-api
- **ORM location:** `src/app/db/db_models.py` — single-file copy (~1858 lines), sync manually with api
- **Contract layer:** Flask forms (`request.form`) + Jinja templates (no separate DTO layer)
- **Architecture:** Blueprint service → repository → db_models
- **depends_on:** `ha-speaking-api` (migration must run on shared DB first)
- **deploy_notes:** No own Alembic — depends on api migration already applied to shared DB. Deploy after api migration, before or parallel with company-web if no cross-dependency.
- **Scan order (mandatory, in order):**
  1. `src/app/db/db_models.py` — column, enum, relationship, CheckConstraint
  2. `src/app/db/repositories/<feature>/` — query filters, joinedload, insert/update kwargs
  3. `src/app/services/<feature>/` — `request.form.get(...)` field names
  4. `src/app/templates/admin/<feature>/` — form `name=`, `{{ model.field }}`
  5. `src/app/utils/check/<feature>_check.py` — validation rules
  6. **Raw SQL hotspots:** `*_bulk_register_repository.py`, `src/app/utils/csv.py`, `src/app/services/learning_statistics/learning_statistics_service.py`
  7. `src/app/utils/translate.py` — if model has lang mapping (`text_{lang}`, `*_lang_mappings`)
  8. `src/tests/<feature>/` — validation logic tests
- **Do not scan:** Python API client (does not exist); browser JS calling `MY_API_SERVER` unless scenario-test UI is in scope
- **Breakage patterns:** form field mismatch, template rendering old field names, validation rules stale, raw SQL column name drift, enum value mismatch, missing ORM class for new table

### `ha-speaking-company-web`

- **Role:** company-facing web app — staff dashboard for students, homework, talk history
- **Purpose:** company staff portal — student list, talk history, homework, messages, company detail
- **Technology:** Flask, Jinja2, Flask-SQLAlchemy, Marshmallow, Python
- **Data access:** direct MySQL via `DATABASE_URL`; one internal JSON endpoint only (`/api/practice-history`)
- **ORM location:** `src/app/domain/entities/<model>.py` — per-table SQLAlchemy entities (~70 tables)
- **Contract layer:** Marshmallow DTO in `src/app/application/dto/` + request schemas in `src/app/interfaces/schema/`
- **Architecture:** route → schema → service → repository impl → entity (Clean Architecture)
- **depends_on:** `ha-speaking-api`
- **deploy_notes:** Sync entity files after api migration. Can deploy parallel with admin-web if changes are independent.
- **Scan order (mandatory, in order):**
  1. `src/app/domain/entities/<model>.py` — column, FK, relationship, constraint
  2. `src/app/infrastructure/persistence/*_repository_impl.py` — select, filter, joins, CTE, subqueries
  3. `src/app/infrastructure/persistence/strategy/practice_log_strategy.py` — if model is a practice log type
  4. `src/app/infrastructure/persistence/department_scope.py` — multi-tenant filter (company_id + department_ids)
  5. `src/app/application/dto/*_dto.py` — Marshmallow output fields
  6. `src/app/interfaces/schema/` — request validation fields
  7. `src/app/templates/pages/` — field display in Jinja
  8. `src/app/common/constant/constant.py` — CSV column names (`STUDENT_COLUMN_NAMES`, `TALK_HISTORY_COLUMN_NAMES`)
  9. `src/app/interfaces/routes/homework_*_loader.py` — direct ORM queries by homework item type
- **Breakage patterns:** entity column drift, invalid repo joins, DTO field stale, department scope break, CSV export column mismatch, practice log strategy not updated for new log type

### `ha-speaking-haij-student-api`

- **Role:** student-facing REST API
- **Purpose:** student mobile/web app backend — quiz, vocabulary, exam, homework, situation, auth
- **Technology:** FastAPI async, SQLAlchemy 2.0 async, Pydantic v2, Python
- **Data access:** direct MySQL async; **no Alembic in practice** — schema managed externally via api
- **ORM location:** `src/app/domain/entities/<model>.py` — per-table, mirrors shared schema
- **Contract layer:** Pydantic DTO in `src/app/application/dto/` — **subset of entity fields** exposed to API
- **Architecture:** controller → service → repository interface → repository impl → entity
- **depends_on:** `ha-speaking-api`, optionally `ha-speaking-admin-web` if admin feature lands first
- **deploy_notes:** Entity sync can deploy after admin-web if no student-facing endpoint yet. Only required in deploy order when DTO/controller findings exist.
- **Scan order (mandatory, in order):**
  1. `src/app/domain/entities/<model>.py` — column, relationship, `__tablename__`
  2. `src/app/infrastructure/repositories/` — SELECT, JOIN, COALESCE lang mapping fallback `ja`
  3. `src/app/application/dto/<model>_dto.py` — API contract fields (may differ from entity)
  4. `src/app/application/services/<model>_service.py` — computed fields (`passed`, `is_recommend`)
  5. `src/app/presentation/controllers/<feature>/schema.py` — re-export DTO as response_model
  6. `src/app/infrastructure/database/seeds/` — seed JSON/Python if new model or required field
  7. `tests/unit/service/test_*` — mock fixtures referencing old fields
- **Special patterns:**
  - Lang mapping: `*_lang_mappings` table + COALESCE fallback to `ja`
  - Field filtering: detail DTO hides `is_correct`; submit DTO returns `explanation` conditionally
  - Entity may exist without DTO exposure — flag as Maybe and confirm with PM
- **Breakage patterns:** entity out of sync with shared DB, repo join broken, DTO contract drift, seed missing required field, lang mapping table missing for i18n feature

---

## Default deployment order

When multiple repos have `Must update` findings:

1. `ha-speaking-api` — run Alembic migration (+ views/seed if needed)
2. `ha-speaking-admin-web` — sync `db_models.py` + services/templates (primary admin consumer)
3. `ha-speaking-company-web` — sync entity + repos + DTOs (parallel with admin if independent)
4. `ha-speaking-haij-student-api` — sync entity + DTO + controllers (only if student API in scope)

Skip repos with no findings or only `Maybe impacted` in the required deploy path.

---

## Path assumptions

- Run Claude CLI from `Haji/`
- Repo paths are sibling folders directly under `Haji/`
- Emphasize downstream consumer findings first; scan source repo for completeness
