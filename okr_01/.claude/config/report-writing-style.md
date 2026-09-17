# Report Writing Style (Vietnamese)

Shared language rule for all generated reports: `impact-report.md`/`.html`,
`impact-verify-report.md`/`.html`, `config-update-report.md`, and the chat summary
returned by `/check-model-impact`, `/verify-model-impact`,
`/update-model-impact-config`.

Goal: prose that a Vietnamese-speaking developer reads as one language, not a
sentence stitched half-English half-Vietnamese. Keep only what genuinely has
no natural Vietnamese equivalent in this codebase.

---

## Always keep as-is (never translate)

- File paths, code identifiers: class / field / table / column / function names
- Repo names (`ha-speaking-api`, `ha-speaking-admin-web`, ...)
- Layer tags: `entity`, `repo`, `service`, `dto`, `template`, `validation`, `raw-sql`, `seed`
- Severity labels: `Must update`, `Should verify`, `Maybe impacted`
- Verify status labels: `Resolved`, `Still pending`, `Not found`
- Standard tech proper nouns / acronyms already used verbatim in
  `repos.md` / `repo-scan-profiles.md`: SQLAlchemy, Alembic, Pydantic,
  FastAPI, Flask, Marshmallow, JWT, CSV, API, DB, ORM, FK, DTO, PM

Everything else — the sentence around these identifiers — is Vietnamese.

## Translate, do not leave in English

Common report words and their Vietnamese equivalent. Use the Vietnamese word
in prose; the English word may still appear as a code identifier if that is
literally the field/function name.

| English | Vietnamese |
|---|---|
| sync / out of sync | đồng bộ / chưa đồng bộ |
| expose (a field via API/DTO) | cung cấp qua API, lộ ra ở DTO |
| confirm | xác nhận |
| verify / re-verify | xác minh, kiểm tra lại |
| set (a value) | thiết lập, nhập |
| update | cập nhật |
| add | thêm |
| remove / drop | xóa, bỏ |
| rename | đổi tên |
| backfill | điền dữ liệu bù cho dữ liệu cũ |
| breaking change | thay đổi gây vỡ |
| feature | tính năng |
| scope | phạm vi |
| skip | bỏ qua |
| fallback | phương án dự phòng |
| deploy / rollout | triển khai |
| evidence | bằng chứng, dẫn chứng |
| pending | đang chờ, chưa xong |
| stale | cũ, lỗi thời, chưa cập nhật |
| flag as Must/Should | đánh dấu, gắn nhãn |

Extend this table instead of duplicating it elsewhere when a new recurring
English word shows up in a report draft.

## Style rules

1. Write full Vietnamese sentences. Don't code-switch mid-sentence when a
   natural Vietnamese verb/noun exists — write "cần đồng bộ", not "cần sync".
2. Don't translate word-by-word into something awkward — rewrite the whole
   sentence the way a Vietnamese technical writer would say it.
3. One idea per bullet; short sentences over long compound ones.
4. Never use English filler/connector words (so, then, actually, basically) —
   use their Vietnamese counterparts (vì vậy, sau đó, thực ra, v.v.) or drop
   the filler entirely.
5. When genuinely unsure whether a term counts as a "keep as-is" identifier
   (section above) or should be translated, translate it — identifiers are a
   short, closed list; everything else defaults to Vietnamese.

## Self-check before saving a report

Scan the drafted prose for English verbs/adjectives that aren't in the
keep-as-is list (sync, expose, confirm, set, update-as-verb, etc.) and rewrite
those sentences before saving the file.
