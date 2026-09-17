---
name: model-impact-verify
description: >
  Use when a prior *-impact.html or *-impact.md checklist was applied and Must/Should items
  need confirmation, or when invoking /verify-model-impact.
---

# Model Impact Verify

Callable skill for `Haji/` — run after the developer has applied the audit checklist.

## Read first

1. inferred baseline report (required)
2. `.claude/config/repos.md`
3. `.claude/config/repo-scan-profiles.md`
4. `.claude/config/report-writing-style.md` (Vietnamese wording rules)
5. `.claude/templates/impact-verify-report.md` (section order + placeholders)
6. `.claude/templates/impact-verify-report.html` (render layout)
7. migration file — from baseline or `Migration:` override

## Inputs

Required:

- a path, `@` mention, or URL that resolves to a prior audit report (`*-impact.html` preferred; `*-impact.md` still accepted)

Do **not** require the label `Baseline report:`. Infer the baseline from the first
`*-impact.html` or `*-impact.md` token in the user message.

Normalization:

- strip leading `@`
- strip `file://`
- strip query string and line anchors (`#L12`, `:12-20`)
- accept labeled `Baseline report: <path>` if present

Optional overrides (only when baseline is incomplete or the user wants to override):

- `Model:`
- `Migration:`
- `Change summary:`

If no report path/URL can be inferred, or the file is not found → ask for the
report file (path or `@` mention) and STOP. Never ask the user to type `Baseline report`.

## Derive context from baseline

From baseline report, extract:

- **Model** — from `Source change` / `Thay đổi nguồn`
- **Migration** — migration path in the baseline
- **Change summary** — bullet list in the baseline
- **File list** — every `Must update` and `Should verify` finding (path + layer + action)
- **Search terms** — old field names, removed keys, renamed identifiers from the change summary

If baseline is missing Model or Migration and the user did not override → ask and STOP.

Do **not** re-run a full cross-repo audit. Primary work = verify baseline Must/Should files.
Add a **bounded** New findings pass (below) — not a second audit.

---

## Workflow

1. **Resolve baseline path** from the user token (path / `@` / URL / optional labeled field)
2. **Read baseline** — extract model, migration, change summary, Must/Should file list, search terms
3. **Read migration** — confirm schema context (old vs new fields, dropped columns)
4. **Re-scan baseline files** — for each Must/Should finding:
   - re-read file content (or note if missing)
   - search for old field names / removed keys / stale patterns from baseline action
   - classify:
     - **Resolved** — old ref gone or updated correctly
     - **Still pending** — old ref remains or expected change not done
     - **Not found** — file deleted or path moved
5. **New findings (bounded)** — catch false-green / missed paths:
   - grep baseline **search terms** (and dropped/renamed identifiers from migration) under
     `scan_order` paths for repos that had Must/Should in the baseline
   - skip paths already listed as Must/Should (and baseline Maybe if present)
   - high-confidence stale hits only (old field/key still present, or new path clearly tied
     to the same model/change) → list under **New findings**
   - do **not** invent Must/Should; do **not** expand into unrelated features
   - empty New findings → omit section or write “không có”
6. **Render report** as HTML from `.claude/templates/impact-verify-report.html`, following section order in `.claude/templates/impact-verify-report.md` — **entire report body in Vietnamese, per `.claude/config/report-writing-style.md`**. Replace all placeholders; omit empty status sections (except keep Summary). Fill hero pills from Summary counts (omit Still pending / Not found / New findings pills when count is 0; always show Resolved `N/TOTAL`).
7. **Save** to `.claude/reports/YYYY-MM-DD-<model>-verify.html` (lowercase kebab-case for model). Do **not** write a parallel `.md` report unless the user asks.
8. **Return** Vietnamese summary: resolved / total Must+Should + New findings count + saved HTML path

Verify scan uses same repo profiles — check raw SQL and DTO layers, not just entity.

Prose (evidence, suggested action, notes) in Vietnamese per `.claude/config/report-writing-style.md`; keep paths, field names, and status labels (`Resolved` / `Still pending` / `Not found`) unchanged.

If domain map / scan paths look stale after verify → suggest `/update-model-impact-config` with this `*-verify.html`; **do not auto-run**.

## Output rules

- Include sections: Source, Summary, Resolved, Still pending, Not found, New findings (if any), Notes
- New findings do **not** count toward Resolved totals
- Group by repo when helpful
- Be concise and actionable
- Report only; do not modify application code

---

## Stop conditions

Stop and ask the user if:

- no report path/URL can be inferred
- inferred report path does not exist
- baseline is missing Model or Migration and there is no override
- multiple unrelated baselines mixed into one request

If baseline has **no** Must/Should findings → do **not** STOP. Save a verify report with
Resolved `0/0`, note that only Maybe (or empty) existed, still run New findings if search
terms exist, then return.

---

## Common mistakes

- Asking the user to type `Baseline report:` — infer from path / `@` / URL
- Treating all Must/Should as Resolved without grepping old refs
- Skipping New findings → false green when fixes moved code to a new path
- Re-running a full `/check-model-impact` audit inside verify
- Writing the report body in English, or in Vietnamese mixed with English filler words
- Modifying application code
- Auto-running `/update-model-impact-config`
