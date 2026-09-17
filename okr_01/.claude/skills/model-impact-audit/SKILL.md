---
name: model-impact-audit
description: >
  Use when ha-speaking-api has a new or changed Alembic migration and sibling
  consumer repos may need schema sync, or when invoking /check-model-impact.
  Not for post-fix re-scan (use model-impact-verify).
---

# Model Impact Audit

Callable root skill for `Haji/`.

This skill exists so Claude CLI and Cursor can discover and run the workflow
entirely from root `.claude/`.

## Read first

Before scanning, read:

1. `.claude/config/repos.md`
2. `.claude/config/repo-scan-profiles.md`
3. `.claude/config/impact-map.md`
4. `.claude/config/report-writing-style.md` (Vietnamese wording rules)
5. `.claude/templates/impact-report.md` (section order + placeholders)
6. `.claude/templates/impact-report.html` (render layout)
7. the migration file from `Migration:`
8. matching ORM class(es) in `ha-speaking-api/src/app/db/db_models.py` after tables are inferred

## Inputs

Required:

- `Migration:`

Do **not** require `Model:` or `Change summary:`. Do **not** ask for them.

If `Migration:` is missing, ask for it and STOP.

If the user still supplies `Model:` or `Change summary:`, treat as optional hints.
The migration file is the source of truth for DB schema changes.

Post-fix verification → use `.claude/skills/model-impact-verify/SKILL.md` via `/verify-model-impact`.

---

## Audit workflow

Full cross-repo impact analysis with migration summary, risks, and per-file
checklist.

### Workflow

1. **Read the migration file first** (`upgrade` and `downgrade`):
   - tables: create / drop / rename
   - columns: add / drop / alter / rename
   - indexes, unique constraints, FKs
   - type, nullability, default changes
   - skip no-op merge revisions with no schema ops → STOP and ask

2. **Infer Model + change summary from that file:**
   - table name → model/class name (PascalCase); confirm in `db_models.py` when present
   - old fields vs new fields from column ops
   - relation changes from FKs
   - change types (map to impact-map sections)
   - fill report `Model` and `Tóm tắt` from this inference — never wait for user bullets

3. **Derive search terms** from the inferred change:
   - model/class name, table name
   - old and new field names
   - related enum names, FK column names
   - lang mapping table names if applicable

4. **Repo-aware scan** — for each repo in `repos.md` (consumers first, then api):
   - read repo profile: purpose, scan_order, breakage_patterns, depends_on
   - resolve feature folder via `repo-scan-profiles.md` domain map
   - walk scan_order paths in order
   - if model class missing at entity layer: flag Must (add ORM) or Maybe (out of scope) with reason
   - for each hit: record path, **layer tag** (entity/repo/service/dto/template/validation/raw-sql/seed), reason, action
   - derive action from `repo-scan-profiles.md` change-type × repo matrix — be specific (path + field name), not generic

5. **Adapt classification** using `impact-map.md` confidence guidance and repo-aware rules in `repo-scan-profiles.md`:
   - `Must update`
   - `Should verify`
   - `Maybe impacted`

6. **Summarize migration + risks** from migration file + change types + findings:
   - **Migration summary:** what upgrade/downgrade does (table/column/index/FK) — short, name model/fields
   - **Risks:** technical/ops risks tied to Must/Should findings; use `Typical risks` in `impact-map.md` as optional cues
   - **Do not** write backward-compat, rollout, rollback, or deployment-order plans

7. **Build per-file checklist** from Must and Should findings:
   - group by repo, then by layer
   - one checkbox per file with action summary
   - Maybe findings → separate `### Optional checks` subsection
   - add `rerun affected test suite` checkbox per repo with findings

8. **Render report** as HTML from `.claude/templates/impact-report.html`, following section order in `.claude/templates/impact-report.md` — **entire report body in Vietnamese, per `.claude/config/report-writing-style.md`** (clear, not mixed with English filler; identifiers stay as-is). Replace all placeholders; omit empty severity blocks / empty repo blocks. Fill Must/Should/Maybe counts in the hero pills (omit a pill when count is 0).

9. **Save** to `.claude/reports/YYYY-MM-DD-<model>-impact.html` (lowercase kebab-case for inferred model).
   Multi-table in one migration → primary/new table name, or join short kebabs (`branch`, `branch-company-user-branch`)
   Do **not** write a parallel `.md` report unless the user asks.

10. **Return** short Vietnamese chat summary + saved HTML report path

### Output rules

- Group findings by repo
- Each finding: path, layer, reason, action
- Include sections: Source change, Migration summary, Risks, per-repo findings, Checklist, Notes
- Do **not** include backward-compat / rollout / rollback / deployment-order sections
- Be concise and actionable
- **Language: Vietnamese**, following `.claude/config/report-writing-style.md`, for all prose (summary, risks, reason, action, checklist text, notes). Keep identifiers in original form: file paths, class/field/table names, repo names, layer tags, and severity labels (`Must update` / `Should verify` / `Maybe impacted`)
- Report only; do not modify application code

---

## Stop conditions

Stop and ask the user if:

- the migration path does not exist
- the migration has no schema ops (empty / merge-only)
- schema changes in the migration cannot be inferred
- **unrelated requests mixed** — more than one `Migration:` path, or multiple separate
  user asks bundled into one run

**Do not STOP** for multiple tables/columns/FKs inside **one** migration file — that is
normal. Infer all models, scan for all of them, one report.

---

## Common mistakes

- Asking for `Model:` or `Change summary:` when `Migration:` is present
- Stopping because one migration touches several tables
- Writing the report body in English, or in Vietnamese mixed with English filler words (see `.claude/config/report-writing-style.md`)
- Inventing consumer feature folders not in domain map / disk
- Including rollout / rollback / deploy-order plans
- Modifying application code
- Skipping `db_models.py` confirm after inferring table → class
