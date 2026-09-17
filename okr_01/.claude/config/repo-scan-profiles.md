# Repo Scan Profiles

Use with `.claude/config/repos.md` and `.claude/config/impact-map.md` during
`model-impact-audit`. This file defines domain mapping, shared patterns, and
per-repo action hints so findings include the correct layer and actionable
suggestion.

---

## Shared patterns (all repos)

- **Content tree:** topic → subject → scenario → log (+ log_details)
- **Lang mapping:** `{entity}_lang_mappings` or `{entity}_scenario_mappings`; `lang_code` + text; COALESCE fallback to `ja`
- **Visibility:** `VisibilityStatusEnum` — `PUBLIC` / `PRIVATE`
- **Timestamps:** `TimestampMixin` — `created_at`, `updated_at`
- **Scenario prompts:** `prompt_base`, `prompt_fixed`, `prompt_evaluation`, `prompt_reason`, `open_ai_model`
- **Table naming:** snake_case; prefixes `haij_`, `lets_talk_`, `situation_`, `master_`

---

## Layer tags for findings

Tag every finding with one layer:

| Layer | admin-web | company-web | student-api | api |
|-------|-----------|-------------|-------------|-----|
| entity | `db_models.py` | `domain/entities/` | `domain/entities/` | `db/db_models.py` |
| repo | `db/repositories/` | `infrastructure/persistence/` | `infrastructure/repositories/` | `db/repositories/` |
| service | `services/` | `application/services/` | `application/services/` | `services/` |
| dto | — (forms) | `application/dto/` | `application/dto/` | `models/` Pydantic |
| template | `templates/admin/` | `templates/pages/` | — | — |
| validation | `utils/check/` | `interfaces/schema/` | controller schema | — |
| raw-sql | bulk register, csv, learning_statistics | rare | rare | views |
| seed | — | — | `infrastructure/database/seeds/` | `db/seed/` |

---

## Domain feature map

Map model/table name → feature folders per repo. Use snake_case table name or
PascalCase class name to resolve.

| Model / table prefix | admin-web feature | company-web entity | student-api feature |
|--------------------|-------------------|--------------------|---------------------|
| `Branch`, `Department`, `Company`, `CompanyUser` | `company/`, `department/`, `company_user/` | `branch.py`, `department.py`, `company.py`, `company_user*.py` | usually no impact (student has `company_id` only) |
| `HaijStudent` | `haij_student/` | `haij_student.py` | `auth/`, `user/` |
| `SituationWord`, `SituationWordMapping`, `WordPractice` | `situation_word/` | none | none (Maybe — confirm PM for student delivery) |
| `SituationPractice`, `Situation` | `situation_practice/` | `situation_practice.py` | `situation/` |
| `HaijQuiz*` | `haij_quiz/` | `haij_quiz.py` | `haij_quiz/` |
| `HaijVocabulary*` | `haij_vocabulary/` | `haij_vocabulary.py` | `haij_vocabulary/` |
| `HaijGrammar*` | `haij_grammar_writing/` | `haij_grammar.py` | `haij_grammar_writing/` |
| `HaijAiExam*`, `HaijExam*` | `haij_exam_*`, `exam_management/` | `haij_ai_exam*.py`, `haij_exam_*.py` | `haij_ai_exam/`, `haij_exam_*` |
| `HaijFreeTalk*`, `HaijLetsTalk*` | `haij_talk_scenario/`, `lets_talk/` | `lets_talk.py`, `haij_talk.py` | `haij_free_talk/`, `haij_lets_talk/` |
| `Homework*` | `homework/` (if exists) | `homework.py` | `homework/` |
| `CulturalVideo*` | `cultural_video/` | `cultural_video.py` | `cultural_video/` |
| `MasterLearn*` | `master_learn_word/` etc. | `master_*.py` | related learned_word repos |
| `LearningStatistics`, `LearningRecordTime` | `learning_statistics/` | `learning_statistics.py`, `haij_learning_record_time.py` | `learning_record_time/` |

When model not in map: grep by table name and class name across entity/db_models
first, then infer feature folder from path.

---

## Change type × repo action matrix

Use to derive the `action:` line in findings. Be specific — include file path and
field name.

### field rename (`old` → `new`)

| Repo | Primary layers | Typical action |
|------|---------------|----------------|
| admin-web | entity, service, template, validation | Sync column in `db_models.py`; change `request.form.get("old")` → `"new"`; update template `{{ model.old }}` → `{{ model.new }}`; update `*_check.py` |
| company-web | entity, repo, dto, template | Update `Column("old")` → `"new"` in entity; fix repo `.filter()`/`.order_by()`; update Marshmallow field; fix template display |
| student-api | entity, repo, dto | Sync entity column; fix repo SELECT/JOIN; rename DTO field (API contract key change) |
| api | db_models, services, models | Update model + migration; update Pydantic if exposed; update service mapping |

### new field

| Repo | Primary layers | Typical action |
|------|---------------|----------------|
| admin-web | entity, service, template, validation | Add column to `db_models.py`; add form input + `request.form.get()`; add validation rule; render in template |
| company-web | entity, dto | Add column to entity; add to DTO if displayed; update repo if filtered/sorted |
| student-api | entity, dto, service | Add entity column; add to DTO if API exposes; update service computed logic if needed |
| api | db_models, migration, models, seed | Add column (nullable first if backfill needed); update Pydantic; update seed if required |

### removed field

| Repo | Primary layers | Typical action |
|------|---------------|----------------|
| admin-web | entity, service, template, raw-sql | Remove column from model; remove form field and validation; remove template refs; check raw SQL SELECT lists |
| company-web | entity, dto, repo, template | Remove column; remove DTO field; remove repo filter/sort; remove template display |
| student-api | entity, dto, repo | Remove from entity; remove from DTO; remove from repo SELECT |
| api | db_models, migration, models | Drop column in migration (after consumer deploy); remove Pydantic field |

### relation / FK added

| Repo | Primary layers | Typical action |
|------|---------------|----------------|
| admin-web | entity, repo, service, template | Add FK column + relationship in `db_models.py`; add joinedload in repo; add form select for FK; display related object in template |
| company-web | entity, repo | Add relationship; update repo joins and eager load |
| student-api | entity, repo, dto | Add FK + relationship; update repo join; add nested DTO if API exposes relation |
| api | db_models, migration | Add FK column; backfill before NOT NULL; update relationship `back_populates` |

### relation removed / reworked

| Repo | Primary layers | Typical action |
|------|---------------|----------------|
| admin-web | entity, repo, service, template | Remove old relationship; update queries using old path (e.g. `dept.company` → `dept.branch.company`) |
| company-web | entity, repo | Remove invalid join; update derived property if kept for backward compat |
| student-api | entity, repo | Remove join; verify DTO flattening logic |
| api | db_models, migration | Migration drop FK; update model relationships |

### new model / new table

| Repo | Primary layers | Typical action |
|------|---------------|----------------|
| admin-web | entity | Add full ORM class to `db_models.py` (copy from api); add repository + service + templates if admin CRUD needed |
| company-web | entity | Add entity file only if company staff needs to read/write table |
| student-api | entity, dto, controller | Add entity + DTO + endpoint only if student-facing feature in scope — otherwise flag Maybe and ask PM |
| api | db_models, migration, seed | Canonical model + migration; seed if master data needed |

### schema / API contract change

| Repo | Primary layers | Typical action |
|------|---------------|----------------|
| admin-web | template, service | Usually N/A unless browser JS calls API with changed contract |
| company-web | dto, template | Update Marshmallow output; update template field access |
| student-api | dto, schema, service | Update Pydantic DTO fields; update service mapping; verify OpenAPI |
| api | models, services, routers | Update Pydantic + service mapping + `response_model` |

### lang mapping change

| Repo | Primary layers | Typical action |
|------|---------------|----------------|
| admin-web | entity, repo, service, translate | Add/update mapping table class; handle `text_{lang}` form fields; update `translate.py` constants |
| company-web | entity, repo | Add mapping entity; update repo if displaying translated content |
| student-api | entity, repo, dto | Add mapping entity; update repo COALESCE query; expose translated field in DTO |
| api | db_models, migration | Add mapping table migration |

---

## Classification rules (repo-aware)

| Signal | Classification | Example action |
|--------|---------------|----------------|
| Old field in entity/db_models | **Must update** | "Change `Department.company_id` → `branch_id` in admin-web/db_models.py" |
| Old field only in template | **Must update** | "Change `{{ dept.company.name }}` → `{{ dept.branch.company.name }}` in edit.html" |
| New model, admin repo missing class | **Must update** (admin) / **Should verify** (others) | admin: "Add `WordPractice` class to db_models.py"; student: "Confirm PM — no student endpoint yet" |
| Field in entity but not in DTO | **Maybe impacted** | "Entity needs sync but API contract does not expose field — verify intentional" |
| Raw SQL references old column | **Must update** | "Fix column name in learning_statistics_service.py query" |
| File in feature flow, no exact field match | **Should verify** | "Repository for department flow — verify joins after FK change" |
| Adjacent feature, weak evidence | **Maybe impacted** | "master_learn_word naming similarity — unrelated to WordPractice migration" |
| Repo has no entity/class for model | **Maybe impacted** or skip | Explain WHY: "student-api has no Department entity — no direct impact" |

---

## Scan workflow per repo

For each consumer repo:

1. Read repo block from `repos.md` (purpose, scan_order, breakage_patterns)
2. Resolve feature folder from domain map above
3. Walk `scan_order` paths in order
4. If model class missing at entity layer → flag Must (add model) or Maybe (out of scope)
5. For each hit: record path, layer tag, reason, action from matrix above
6. Skip repo entirely only when no class, no grep hits, and feature is admin-only
