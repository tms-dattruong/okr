# <MODEL> — Báo cáo verify

Content outline for `/verify-model-impact` (skill `model-impact-verify`).

**Render target:** fill `.claude/templates/impact-verify-report.html` and save as `.html` (not this `.md`). This file = section order + placeholder names only.

**Language:** follow `.claude/config/report-writing-style.md` — all prose in clear, non-mixed Vietnamese; keep paths, field names, and status labels (`Resolved` / `Still pending` / `Not found`) as-is.

## Nguồn (Source)

- Model: `<MODEL>`
- Migration: `<MIGRATION>`
- Baseline report: `<BASELINE_REPORT_PATH>`
- Verified at: `<DATE>`

## Tóm tắt (Summary)

- Resolved: `<N>` / `<TOTAL>`
- Still pending: `<P>`
- Not found: `<F>`
- New findings: `<K>`

## Resolved

- `<FILE_PATH>`
  - evidence: `<WHAT_CHANGED_OR_OLD_REF_GONE_VI>`

## Still pending

- `<FILE_PATH>`
  - old ref found: `<FIELD_OR_PATTERN>`
  - suggested action: `<WHAT_TO_FIX_VI>`

## Not found

- `<FILE_PATH>`
  - note: `<FILE_DELETED_OR_PATH_CHANGED_VI>`

## New findings

*(Omit section if none. Bounded grep outside baseline Must/Should — not a full re-audit.)*

- `<FILE_PATH>` `[layer: ...]`
  - old ref / pattern: `<TERM>`
  - suggested action: `<WHAT_TO_CHECK_OR_FIX_VI>`

## Ghi chú (Notes)

- Re-scan using the same search terms from the baseline report
- Save: `.claude/reports/YYYY-MM-DD-<model>-verify.html`
