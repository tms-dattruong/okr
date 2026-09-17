---
name: model-impact-config-update
description: >
  Use when `.claude/config` looks stale (new model/table, missing domain-map
  row, drifted layer or scan_order path), after a *-verify.html (or legacy *-verify.md), or when
  invoking /update-model-impact-config or full-scan / "cập nhật repo-scan-profiles".
---

# Model Impact Config Update

Callable skill for `Haji/`. Refreshes `.claude/config/` from prior reports
and/or a codebase full-scan. Surgical config edits only.

## Read first

1. `.claude/config/repos.md`
2. `.claude/config/repo-scan-profiles.md`
3. `.claude/config/impact-map.md`
4. `.claude/config/report-writing-style.md` (Vietnamese wording rules, for the changelog prose)
5. `.claude/templates/config-update-report.md`
6. In `reports` mode: inferred `*-verify.html` (legacy `.md` OK) plus linked `*-impact.html` / `*-impact.md`
7. In `full-scan` mode: `ha-speaking-api/src/app/db/db_models.py` plus consumer
   directories from `repos.md` `scan_order`

## Inputs

Exactly one mode must be active. Combined run is allowed (see below).

Required (one of):

- a path, `@` mention, or URL that resolves to `*-verify.html` (legacy `*-verify.md` OK) → infer `Mode: reports`
- `full-scan` / `Mode: full-scan`

Do **not** require the labels `Mode:` or `Reports:`. Infer reports mode from the
first `*-verify.html` or `*-verify.md` token in the user message.

Normalization:

- strip leading `@`
- strip `file://`
- strip query string and line anchors (`#L12`, `:12-20`)
- accept labeled `Mode: reports` / `Reports: <path>` if present

From the verify file, also read `Baseline report` (`*-impact.html` / `*-impact.md`) when that path
exists. Extra `*-impact.html` / `*-impact.md` tokens in the user message are optional extra evidence.

If no `*-verify.html`/`*-verify.md` and no `full-scan` can be inferred → ask for the verify file
(path or `@` mention) and STOP. Never ask the user to type `Mode:` or `Reports:`.

If the verify path is missing → ask and STOP.
If `ha-speaking-api/src/app/db/db_models.py` missing during full-scan → ask and STOP.

**Combined run:** `*-verify.html` (or `.md`) plus `full-scan` → apply full-scan rules first,
then reports-mode rules, one changelog.

---

## Workflow

1. **Resolve report path** from the user token (path / `@` / URL / optional labeled field); load linked `*-impact.html` / `*-impact.md` from verify `Baseline report`
2. **Read current config** — keep section structure; do not rewrite files
3. **Gather evidence** — reports and/or full-scan (below)
4. **Diff** — proposed adds/updates/removes vs current text
5. **Patch** — only rows/bullets with evidence; follow mode write tables
6. **Render changelog** using `.claude/templates/config-update-report.md`
7. **Save** `.claude/reports/YYYY-MM-DD-config-update.md`
8. **Return** Vietnamese chat summary + saved path

Empty diff still gets a changelog that says no config change, plus Skipped/Notes.

---

## Reports mode — extract

From each impact/verify report, collect:

- Model / table / class names (`Thay đổi nguồn` / `Nguồn`)
- Feature folders and file paths in findings
- Layer tags used
- Change types implied by the change summary
- Gaps: missing ORM class, “no entity in this repo”, folder not in domain map
- Verify `Resolved` findings that confirm a mapping is now known

### Allowed writes (`reports`)

| File | May update |
|------|------------|
| `repo-scan-profiles.md` | Domain feature map rows; layer-tag path cells if a finding proves a new canonical path; shared patterns if a repeated cross-repo pattern appears; change-type × repo matrix if a used change type is missing; classification rules if a new signal type appeared |
| `repos.md` | `scan_order` if a finding used a path not listed; breakage patterns from repeated findings; purpose/ORM notes only if a report proves structure drift |
| `impact-map.md` | Change-type sections, repo-specific scan-priority rows, typical risks, confidence examples — only when the report introduces a type or risk not already covered |

Do not invent a feature folder. If a consumer has no matching entity/folder,
write an explicit “none” / “usually no impact” cell in the same tone as
existing domain-map rows.

---

## Full-scan mode — extract

1. Parse `ha-speaking-api/src/app/db/db_models.py` for PascalCase class names
   and `__tablename__` / table names.
2. List consumer feature folders:
   - admin-web: `src/app/services/`, `src/app/templates/admin/`, `src/app/db/repositories/`
   - company-web: `src/app/domain/entities/*.py`
   - student-api: `src/app/domain/entities/*.py` plus controller/service feature dirs from `scan_order`
3. Match model → folder with name heuristics **and** grep. High-confidence
   only: class name or table prefix in folder/file name, or entity file exists.
   Unmatched models → changelog Skipped/Notes. **Do not** invent a folder.
4. Check layer-tag table paths and `repos.md` `scan_order` paths exist on disk.
   Add missing live paths. Drop a listed path only if it is gone from the repo.

### Allowed writes (`full-scan`)

| File | May update |
|------|------------|
| `repo-scan-profiles.md` | Domain feature map (add/fix rows). Layer tags table (path cells if dirs drifted). |
| `repos.md` | `scan_order` only (add missing live paths; drop paths that no longer exist). |
| `impact-map.md` | **No writes.** |
| `repo-scan-profiles.md` change-type matrix / classification / shared patterns | **No writes.** |

---

## Shared patch rules

- Surgical edits. Preserve section headings and existing valid rows.
- Config prose stays **English** (match current files).
- Do not modify application code.
- Do not rewrite a whole config file.
- Do not delete a domain-map row unless evidence shows the model was renamed
  or removed (report change summary, or class gone from `db_models.py`).
- New domain-map row must include all three consumer columns.
- Keep identifiers (paths, class/table names, layer tags) as-is.

---

## Output rules

- Entire changelog body in **Vietnamese**, following `.claude/config/report-writing-style.md`
- Identifiers unchanged
- Group changes by config file
- Be concise and reviewable (quote enough of the new/old row)
- Chat summary in Vietnamese: changed files + what changed + report path

---

## Stop conditions

Stop and ask if:

- no `*-verify.html`/`*-verify.md` and no `full-scan` can be inferred
- inferred verify path does not exist
- a target config file is missing
- full-scan cannot find `ha-speaking-api/src/app/db/db_models.py`
- user mixed application-code fixes into the same request — config-update
  only, or ask to split

After a non-empty config patch, suggest re-running `/check-model-impact` on the next
migration if scan paths changed — do not auto-run.

---

## Common mistakes

- Asking the user to type `Mode:` or `Reports:`
- Inventing domain-map folders without high-confidence evidence
- Rewriting a whole config file instead of surgical row edits
- Writing config prose in Vietnamese (config stays English)
- `full-scan` writing `impact-map.md` or the change-type matrix
- Deleting domain-map rows without rename/remove evidence
- Modifying application code
- Accepting only `*-impact.html`/`*-impact.md` as reports mode without `*-verify.html`/`*-verify.md` or `full-scan`
  (unless user also passes `full-scan`)
