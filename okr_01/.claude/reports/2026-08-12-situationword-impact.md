# SituationWord Impact Report

## Source change

- Model: `SituationWord`, `SituationWordMapping`
- Migration: `ha-speaking-api/src/app/migrations/versions/26b8715af222_add_table_words.py`
- Summary:
  - New table `situation_words` (id, scene, text, status, display_order, timestamps) — word entries tied to situation scene (int, no FK, same pattern as `SituationPracticeContent.scene`)
  - New table `situation_word_mappings` (id, situation_word_id FK, lang_code, text, timestamps) — per-language translations, unique on `(situation_word_id, lang_code)`
  - Index `idx_situation_words_scene` on `situation_words.scene`
- Change type: **new model / new table**

Note: each service keeps its own ORM copy mapped to shared MySQL (no cross-repo import). Migration alone does not propagate model classes — each consumer must add `SituationWord`/`SituationWordMapping` locally.

---

## Migration strategy

### Backward compatibility

- New tables only — no existing code reads `situation_words` until consumers add ORM classes; zero impact on running apps until deploy.
- `scene` column has no FK constraint — existing `situation_practice_contents` rows unaffected.
- `status` uses existing `VisibilityStatusEnum` (`PUBLIC`/`PRIVATE`) — same enum as other content domains.

### Rollout

1. Run migration `26b8715af222` on shared DB (`alembic upgrade head` in `ha-speaking-api`).
2. Deploy `ha-speaking-admin-web` — already has full CRUD; confirm ORM matches migration before deploy.
3. Skip `ha-speaking-company-web` — no reads/writes to these tables.
4. Deploy `ha-speaking-haij-student-api` after admin-web when student-facing word list is in scope — add entity/repo/DTO/endpoint (see student-api section below).
5. Optional: update `ha-speaking-api/docs/db-erd.md` §14 if not already synced.

### Rollback

- Drop tables via migration downgrade (`downgrade()` drops `situation_word_mappings` then `situation_words`).
- Remove admin-web routes/ORM only if rollback before any production data written.
- No rollback needed in company-web or student-api (no code references).

---

## Deployment order

1. **`ha-speaking-api`** — run migration `26b8715af222` on shared MySQL first; tables must exist before admin-web CRUD.
2. **`ha-speaking-admin-web`** — deploy after migration; sole consumer with full implementation (service, repo, templates, validation).
3. **`ha-speaking-company-web`** — skip (no findings).
4. **`ha-speaking-haij-student-api`** — after admin-web, when student word list endpoint needed; entity + repo + DTO + controller chưa tồn tại — xem section chi tiết bên dưới.

---

## `ha-speaking-api`

### Should verify

- `src/app/db/db_models.py:738-778` `[layer: entity]`
  - reason: `SituationWord`/`SituationWordMapping` classes present; columns match migration (`scene`, `text`, `status`, `display_order` / `situation_word_id`, `lang_code`, `text`, unique constraint)
  - action: confirm no drift vs migration before merge — no code change expected

- `src/app/migrations/versions/26b8715af222_add_table_words.py` `[layer: entity]`
  - reason: canonical migration for this change
  - action: verify `upgrade()`/`downgrade()` tested on dev DB

### Maybe impacted

- `src/app/routers/`, `src/app/services/`, `src/app/db/repositories/` — no `SituationWord` HTTP surface `[layer: dto]`
  - reason: same pattern as `ListeningPractice` — schema exists, no API endpoint; admin-web reads DB directly
  - action: confirm intentional before building student-facing API in `ha-speaking-api`; no action if direct-DB pattern stands

---

## `ha-speaking-admin-web`

### Should verify

- `src/app/db/db_models.py:744-784` `[layer: entity]`
  - reason: `SituationWord`/`SituationWordMapping` mirror api migration exactly
  - action: diff against api `db_models.py` before deploy — expect match

- `src/app/db/repositories/situation_word/situation_word_repository.py` `[layer: repo]`
  - reason: full CRUD — query by `scene`, `display_order`, mapping upsert, joinedload mappings
  - action: smoke-test create/update/delete/reorder after migration applied

- `src/app/services/situation_word/situation_word_service.py` `[layer: service]`
  - reason: Blueprint `situation_word_bp` registered in `__init__.py`; routes `/admin/situation-word/*`; form fields `scene`, `text`, `status`, `text_{lang}`; auto-translate via `translate_text_to_mappings()`
  - action: verify ACL entry exists for `/admin/situation-word` routes in auth config

- `src/app/utils/check/situation_word_check.py` `[layer: validation]`
  - reason: validates `scene`, `text`, `status` (PUBLIC/PRIVATE)
  - action: no change expected — confirm enum values match migration

- `src/app/templates/admin/situation-word/{list,detail,edit,register}.html` `[layer: template]`
  - reason: renders `word.text`, `word.status`, `word.mappings`, display order AJAX
  - action: manual UI test after migration — list/register/edit/delete/reorder

- `src/app/templates/admin/situation-practice/content/scene.html` `[layer: template]`
  - reason: entry link `url_for('situation_word.situation_word_list', scene=...)` from scene detail
  - action: verify navigation from situation practice scene → word list works

---

## `ha-speaking-company-web`

### Maybe impacted

- No `SituationWord` / `situation_word` references found — company staff portal does not manage situation words.

- `src/app/domain/entities/master_learn_word_expression.py` (`master_learn_words` table) `[layer: entity]`
  - reason: older lesson-based vocab feature (`japanese`/`english` columns); naming similar to SituationWord but different schema (no `situation_word_mappings`, no `scene` index pattern)
  - action: no functional change — FYI naming-collision risk for future maintainers only

---

## `ha-speaking-haij-student-api`

**Scan result:** `SituationWord` / `situation_words` / `situation_word` — **0 matches** trong codebase hiện tại. Entity, repo, DTO, controller **chưa tồn tại**. Cần implement mới khi student app hiển thị word list theo scene.

### Should verify (impact gián tiếp — code hiện có)

- `src/app/domain/entities/situation_practice.py:41` — `SituationPracticeContent.words` `[layer: entity]`
  - reason: cột `words` là **số tĩnh** seed từ JSON (`situation_practice_contents.json`), không đọc từ bảng `situation_words` mới
  - action: khi admin thêm word động qua admin-web, cột `words` có thể lệch số thực tế — verify có cần sync/count từ `situation_words` WHERE `scene = ?` không

- `src/app/infrastructure/repositories/practice_log/statistics.py:35,66` `[layer: repo]`
  - reason: `func.sum(SituationPracticeContent.words)` dùng cho `total_words_completed` / `total_words` trong dashboard thống kê
  - action: nếu word count chuyển sang dynamic từ `situation_words`, cần đổi query sang COUNT bảng mới hoặc cập nhật cột `words` khi admin save

- `src/app/application/services/statistic_service.py:146-151` `[layer: service]`
  - reason: expose `total_words_completed` từ statistics repo ở trên
  - action: verify số liệu thống kê vẫn đúng sau khi admin populate `situation_words`

- `src/app/infrastructure/database/seeds/situation.py:43` + `seeds/json/situation_practice_contents.json` `[layer: seed]`
  - reason: seed gán `exists.words = content.get("words", 0)` — giá trị hardcode per scene
  - action: không cần seed `situation_words` ngay (admin CRUD qua admin-web), nhưng có thể cần script backfill `words` count nếu dashboard dùng cột này

- `src/app/presentation/controllers/lesson/controller.py` — `GET /v1/scenes/{scene}` `[layer: dto]`
  - reason: `SceneDetailDTO` trả scene metadata + cando, **không có word list** — đây là integration point tự nhiên nếu student app cần words trên scene detail
  - action: mở rộng DTO hoặc thêm endpoint riêng (xem Must update bên dưới)

### Must update (implement mới — chưa có file nào)

Theo pattern `haij_vocabulary` (lang mapping + PUBLIC filter) và mirror admin-web ORM. **Tất cả file dưới đây cần tạo mới:**

| Layer | File cần tạo | Action |
|-------|-------------|--------|
| entity | `src/app/domain/entities/situation_word.py` | Copy `SituationWord` + `SituationWordMapping` từ api `db_models.py:738-778`; export trong `domain/entities/__init__.py` |
| repo interface | `src/app/application/interfaces/situation/situation_word_repository.py` | ABC: `get_words_by_scene(scene, lang_code)`, filter `status == PUBLIC` |
| repo impl | `src/app/infrastructure/repositories/situation/situation_word_repository.py` | Query JOIN `situation_word_mappings`, COALESCE fallback `ja` (pattern giống `haij_quiz` lang mapping) |
| dto | `src/app/application/dto/situation_word_dto.py` | `SituationWordDto(id, text, display_order, translations[])` — subset field, không expose `status` nếu đã filter PUBLIC |
| service | mở rộng `conversation_service.py` hoặc tạo `situation_word_service.py` | Map entity → DTO; gọi repo theo `scene` |
| controller | `src/app/presentation/controllers/situation_word/controller.py` + `schema.py` | Route đề xuất: `GET /v1/scenes/{scene}/words` với `Depends(verify_jwt)` |
| router | `src/app/presentation/routers/router.py` | Register controller mới |
| repo barrel | `src/app/infrastructure/repositories/__init__.py`, `situation/__init__.py` | Export `SituationWordRepository` |
| tests | `tests/unit/service/test_situation_word_service.py` | Mock repo, test PUBLIC filter + lang fallback |

**Reference pattern (copy từ):**
- Entity mirror: `ha-speaking-api/src/app/db/db_models.py:738-778`
- Lang mapping query: `infrastructure/repositories/haij_quiz/haij_quiz_scenario_repository.py` (COALESCE + `get_language()`)
- Controller wiring: `presentation/controllers/haij_vocabulary/controller.py`
- Admin CRUD logic: `ha-speaking-admin-web/.../situation_word_repository.py` (query by scene, display_order)

### Maybe impacted

- `src/app/domain/entities/master_learn_word.py`, `learned_word_repository.py` `[layer: entity]`
  - reason: feature `master_learn_words` cũ — unrelated schema, không đụng `situation_words`
  - action: không sửa; tránh nhầm với SituationWord

- `src/app/presentation/controllers/conversation/controller.py` + `conversation_practice/controller.py` `[layer: service]`
  - reason: situation practice flow (conversation logs) cùng domain `scene` — có thể cần link word list trước khi student bắt đầu practice
  - action: confirm UX flow với PM — words hiển thị ở scene detail hay inline trong conversation UI

---

## Checklist

### `ha-speaking-api`

#### entity

- [ ] `src/app/migrations/versions/26b8715af222_add_table_words.py` — run `alembic upgrade head` on shared DB
- [ ] `src/app/db/db_models.py` — confirm SituationWord/SituationWordMapping matches migration (no drift)

#### Tests

- [ ] rerun affected test suite in `ha-speaking-api` (if any migration-related tests exist)

### `ha-speaking-admin-web`

#### entity

- [ ] `src/app/db/db_models.py` — confirm sync with api (already present)

#### repo

- [ ] `src/app/db/repositories/situation_word/situation_word_repository.py` — smoke-test CRUD after migration

#### service

- [ ] `src/app/services/situation_word/situation_word_service.py` — verify routes + ACL after deploy

#### template

- [ ] `src/app/templates/admin/situation-word/list.html` — UI smoke test
- [ ] `src/app/templates/admin/situation-word/register.html` — create flow + auto-translate
- [ ] `src/app/templates/admin/situation-word/edit.html` — update mappings `text_{lang}`
- [ ] `src/app/templates/admin/situation-practice/content/scene.html` — entry link to word list

#### validation

- [ ] `src/app/utils/check/situation_word_check.py` — no change expected

#### Tests

- [ ] rerun affected test suite in `ha-speaking-admin-web`

### `ha-speaking-haij-student-api`

#### entity (tạo mới)

- [ ] `src/app/domain/entities/situation_word.py` — add SituationWord + SituationWordMapping; export in `__init__.py`

#### repo (tạo mới)

- [ ] `src/app/application/interfaces/situation/situation_word_repository.py` — ABC interface
- [ ] `src/app/infrastructure/repositories/situation/situation_word_repository.py` — query by scene + lang mapping COALESCE

#### dto / service / controller (tạo mới)

- [ ] `src/app/application/dto/situation_word_dto.py` — API contract
- [ ] `src/app/application/services/situation_word_service.py` (hoặc mở rộng conversation_service) — entity → DTO
- [ ] `src/app/presentation/controllers/situation_word/controller.py` — `GET /v1/scenes/{scene}/words`
- [ ] `src/app/presentation/routers/router.py` — register route

#### Should verify (code hiện có)

- [ ] `src/app/infrastructure/repositories/practice_log/statistics.py` — `sum(SituationPracticeContent.words)` còn đúng sau khi admin thêm words?
- [ ] `src/app/presentation/controllers/lesson/controller.py` — SceneDetailDTO có cần embed word count/list?

#### Tests

- [ ] `tests/unit/service/test_situation_word_service.py` — mock repo, PUBLIC filter, lang fallback
- [ ] rerun affected test suite in `ha-speaking-haij-student-api`

### Optional checks

- [ ] Confirm UX: word list ở scene detail (`/v1/scenes/{scene}`) hay endpoint riêng?
- [ ] `ha-speaking-company-web` — no action (naming FYI only)

---

## Notes

- **New model, not modification** — company-web unaffected; student-api **chưa có code SituationWord** nhưng có impact gián tiếp qua `SituationPracticeContent.words` statistics.
- admin-web implementation **already on main** (`situation_word/`) — primary risk is **deploy order** (migration before app).
- student-api cần **implement mới 7–9 file** (entity → repo → dto → service → controller) — pattern copy từ `haij_vocabulary` + ORM mirror từ api.
- Endpoint đề xuất: `GET /api/v1/scenes/{scene}/words` — filter `status=PUBLIC`, lang mapping COALESCE `ja`.
- `ha-speaking-api` has no HTTP surface for SituationWord — consistent with direct-DB admin pattern.
- Old report (`2026-08-12-wordpractice-impact.md`) used outdated name `WordPractice` — canonical names are `SituationWord` / `situation_words`.
