# <MODEL> — Báo cáo impact

Content outline for audit mode from `model-impact-audit`.

**Render target:** fill `.claude/templates/impact-report.html` and save as `.html` (not this `.md`). This file = section order + placeholder names only.

**Language:** follow `.claude/config/report-writing-style.md` — all prose in clear, non-mixed Vietnamese; keep only the identifiers listed there (paths, class/field/table names, repo names, layer tags, severity labels) as-is.

## Thay đổi nguồn (Source change)

- Model: `<MODEL>`
- Migration: `<MIGRATION>`
- Tóm tắt:
  - `<CHANGE_1_VI>`
  - `<CHANGE_2_VI>`

## Tóm tắt migration

- `<MIGRATION_SUMMARY_VI>` — what upgrade/downgrade does (table/column/index/FK), short 3–6 bullets
- Do not write rollout / rollback / deploy-order plans

## Rủi ro

- `<RISK_1_VI>` — specific technical or ops risk (e.g. consumer ORM out of sync, stale DTO key, raw SQL)
- `<RISK_2_VI>`
- Prefer risks tied to Must/Should findings; drop generic bullets

## `<REPO_NAME>`

### Must update

- `<FILE_PATH>` `[layer: entity|repo|service|dto|template|validation|raw-sql|seed]`
  - reason: `<WHY_DIRECT_IMPACT_VI>`
  - action: `<SPECIFIC_UPDATE_PATH_AND_FIELD_VI>`

### Should verify

- `<FILE_PATH>` `[layer: ...]`
  - reason: `<WHY_MAY_DEPEND_VI>`
  - action: `<WHAT_TO_CHECK_VI>`

### Maybe impacted

- `<FILE_PATH>` `[layer: ...]`
  - reason: `<WEAK_OR_INDIRECT_SIGNAL_VI>`
  - action: `<OPTIONAL_MANUAL_CHECK_VI>`

*(Omit empty severity subsections. Omit the repo section entirely if there are no findings.)*

## Checklist

### `<REPO_NAME>`

#### `<LAYER>` (e.g. entity / service / template)

- [ ] `<FILE_PATH>` — `<ACTION_SUMMARY_VI>`

#### Tests

- [ ] chạy lại test suite liên quan trong `<REPO_NAME>`

### Optional checks

- [ ] `<FILE_PATH>` — `<MAYBE_ACTION_VI>` *(Maybe impacted only)*

## Ghi chú (Notes)

- Group findings by repo
- Keep reasons short; do not dump raw search hits
- Do not mark Must without evidence
- Explain why a repo was skipped when it has no impact
- Save: `.claude/reports/YYYY-MM-DD-<model>-impact.html`
