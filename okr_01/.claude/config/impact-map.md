# Model Impact Rules

Decide what to scan when `ha-speaking-api` changes a model, migration, or
schema contract.

For repo-specific scan paths and action wording, also read
`.claude/config/repo-scan-profiles.md`.

Do **not** use this file to invent rollout, rollback, or deployment-order plans.
Risks in the audit report come from findings + the notes below.

---

## Change type: field rename

Example: `title` -> `name`

Prioritize scanning:

- DTOs, serializers, Pydantic schemas
- response mappers and payload builders
- service code reading the old field
- templates rendering the old field
- tests and fixtures asserting the old field

Likely actions:

- replace old field access
- update payload mapping
- update rendered labels or table columns
- update tests and fixtures

Typical risks:

- consumer ORM still maps the old column name
- API/DTO still exposes the old key
- templates or forms still read the old name

---

## Change type: new field

Example: add `level_id`

Prioritize scanning:

- create and update payload builders
- forms and validation
- DTOs and schemas
- detail and list response rendering
- tests and fixtures
- seed helpers if the field is required

Likely actions:

- add input handling
- add validation
- add serialization or mapping
- update fixtures or seed data

Typical risks:

- NOT NULL column without default breaks old inserts
- seed/fixtures omit a required field
- UI/DTO never exposes the field while DB expects it

---

## Change type: removed field

Prioritize scanning:

- templates or UI tables rendering the removed field
- service code reading the removed field
- DTOs or schemas still declaring it
- filters, sorters, export helpers
- tests still expecting the removed field
- raw SQL SELECT lists

Likely actions:

- remove legacy access
- update contracts
- clean up tests and fixtures

Typical risks:

- DROP COLUMN while a consumer still SELECTs it
- leftover DTO/template references cause runtime errors
- raw SQL still lists the old column

---

## Change type: relation or foreign key added

Example: add `course.level_id`

Prioritize scanning:

- joins and repository query helpers
- forms with select options
- detail pages rendering related objects
- validation rules
- seed data and fixtures

Likely actions:

- add query joins or eager loading
- add UI input and display
- update fixture setup

Typical risks:

- missing ORM relationship / FK sync across repos
- existing rows invalid if FK is NOT NULL without backfill
- UI missing select options for the new relation

---

## Change type: relation removed or reworked

Prioritize scanning:

- repository joins
- serializer flattening logic
- templates showing related data
- tests expecting nested relation payloads
- derived properties (e.g. `Company.departments` via Branch)

Likely actions:

- remove invalid joins
- update renderers and contracts
- update query paths (e.g. `dept.company` → `dept.branch.company`)
- update tests

Typical risks:

- queries still use the old join path
- derived properties return empty or wrong data
- nested payload shape breaks clients

---

## Change type: schema / response contract change

Example: API response now returns `name` instead of `title`

Prioritize scanning:

- API client code
- response mappers
- DTOs or response schemas
- UI rendering logic
- contract tests

Likely actions:

- update client parsing
- update mapper field names
- update contract tests

Typical risks:

- student-api or JS clients still parse the old key
- contract tests assert the old shape
- partial deploy leaves mixed response keys

---

## Change type: new model / new table

Example: add `word_practices` and `word_practice_mappings`

Prioritize scanning:

- api `db_models` and migration
- admin-web `db_models` copy (primary consumer for admin CRUD)
- company-web entities (only if company staff reads the table)
- student-api entities + DTO + controllers (only if student-facing)

Likely actions:

- add ORM class to each repo that reads/writes the table
- add repository + service + UI for admin features
- confirm PM scope for student-facing delivery

Typical risks:

- admin CRUD ships without ORM copy → runtime fail
- student/company scope unclear → false Must or missed Must
- seed/FK dependencies missing for related tables

---

## Repo-specific scan priorities

See `.claude/config/repo-scan-profiles.md` for the full domain map and action matrix.

| Change type | admin-web first | company-web first | student-api first |
|-------------|-----------------|-------------------|-------------------|
| field rename | db_models, form, template | entity, dto | entity, dto |
| new field | db_models, form, validation | entity, dto | entity, dto (if expose) |
| removed field | template, raw SQL | dto, template | dto |
| relation change | db_models, repo joins | entity, repo | entity, repo, dto |
| new model | db_models (Must if admin CRUD) | entity (if needed) | entity+dto (Maybe until PM confirms) |
| lang mapping | db_models, translate.py, form text_{lang} | entity, repo | entity, repo COALESCE, dto |

---

## Confidence guidance

### `Must update`

Use when:

- exact old field name appears in active code
- exact removed contract key appears in active code
- required new field is missing in create or update flows
- ORM class missing for a table the repo must read/write
- raw SQL references the old column name

### `Should verify`

Use when:

- file clearly belongs to the affected model flow
- relation or payload shape may depend on the changed model
- tests likely need sync even if the exact field is not obvious
- new model exists in admin-web but student feature scope is unclear

### `Maybe impacted`

Use when:

- match is indirect
- usage is uncertain
- file is adjacent to the impacted flow but evidence is weak
- repo has no entity for the model and the feature is admin-only — explain why no impact is expected
