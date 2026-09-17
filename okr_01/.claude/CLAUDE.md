# Haji Claude Assets

Shared Claude workflow for cross-repo work at `Haji/`.

## Purpose

This folder holds Claude commands, skills, config, and templates for workflows
that span multiple sibling repos.

Use this folder when a task crosses repo boundaries, especially:

- model changes in `ha-speaking-api`
- migration impact checks
- cross-repo compatibility review
- refreshing scan config after new models or impact reports

## CLI assumptions

- Run Claude CLI from `Haji/`
- Sibling repos should be visible from the current workspace
- Commands and skills here should avoid IDE-only assumptions

## Structure

- `commands/` — user entrypoints
- `skills/` — reusable workflows
- `config/` — repo map, scan profiles, and impact rules
- `templates/` — stable output formats
- `reports/` — generated markdown outputs from shared workflows

## Current workflows

### `/check-model-impact`

Full cross-repo impact audit from a migration change in `ha-speaking-api`.
Infers model/table/field changes from the migration file.

**Required input:** `Migration` only (`Model` and `Change summary` are inferred; do not ask for them)

**Output:** `.claude/reports/YYYY-MM-DD-<model>-impact.html`

**Skill:** `.claude/skills/model-impact-audit/SKILL.md`

### `/verify-model-impact`

Post-fix re-scan after developer applies audit checklist.

**Required input:** path, `@` mention, or URL of a prior `*-impact.html` (legacy `*-impact.md` OK; infer baseline; do not require the label `Baseline report:`)

**Optional overrides:** `Model`, `Migration`, `Change summary` (defaults extracted from baseline)

**Output:** `.claude/reports/YYYY-MM-DD-<model>-verify.html`

**Skill:** `.claude/skills/model-impact-verify/SKILL.md`

### `/update-model-impact-config`

Refresh `.claude/config/` when scan knowledge is stale (new model/table,
missing domain-map row, drifted layer/`scan_order` path, or learning from a
prior impact/verify report).

**Required input:** path, `@` mention, or URL of a `*-verify.html` (legacy `*-verify.md` OK; infer
`Mode: reports`; do not require `Mode:` / `Reports:`). Also reads linked
`*-impact.html` / `*-impact.md` from the verify file. Or `full-scan`.

**Output:** `.claude/reports/YYYY-MM-DD-config-update.md`

**Skill:** `.claude/skills/model-impact-config-update/SKILL.md`

`full-scan` only updates domain map, layer-tag paths, and `scan_order`.
Reports mode may also update the change-type matrix and `impact-map.md` when
the report has evidence. Does not modify application code.

## Shared config and audit notes

**Config files used:**

- `config/repos.md` — repo purpose, scan order, deploy tier, breakage patterns
- `config/repo-scan-profiles.md` — domain map, layer tags, change-type × repo action matrix
- `config/impact-map.md` — change types, scan priorities, typical risks, confidence rules
- `config/report-writing-style.md` — Vietnamese wording rules for report prose (what stays as-is vs must be translated), shared by all three skills

**Audit report sections:**

1. Source change
2. Migration summary (what the migration does — not a rollout/rollback plan)
3. Risks
4. Per-repo findings (Must / Should / Maybe, with layer tags)
5. Per-file checklist grouped by repo and layer
6. Notes

**Consumer repos scanned:**

- `ha-speaking-admin-web` — Flask admin, direct MySQL, copy `db_models.py`
- `ha-speaking-company-web` — Flask company portal, `domain/entities/` per-table
- `ha-speaking-haij-student-api` — FastAPI student API, entity + Pydantic DTO contract

All consumer repos read shared MySQL directly — no cross-repo ORM import. Schema
changes require manual sync in each repo after api migration.

## Design rule

Keep commands thin. Put reusable analysis logic in skills. Put repo knowledge in
config files. Put final output layout in templates.
