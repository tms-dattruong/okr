---
description: Analyze cross-repo impact from ha-speaking-api model or migration changes
---

# /check-model-impact

Thin entrypoint. Logic lives in `.claude/skills/model-impact-audit/SKILL.md`.

## Usage

```text
/check-model-impact
Migration: ha-speaking-api/src/app/migrations/versions/20260728_add_level_id_to_course.py
```

## Required input

- `Migration`

If missing → ask and STOP.

Do **not** ask for `Model` or `Change summary`. Infer from the migration file. Optional hints OK; migration is source of truth.

## Output

- `.claude/reports/YYYY-MM-DD-<model>-impact.html` (from `.claude/templates/impact-report.html`; Vietnamese prose; identifiers as-is)
- Short Vietnamese chat summary + path

After checklist applied → `/verify-model-impact`. Do not auto-run `/update-model-impact-config`.

Invoke `.claude/skills/model-impact-audit/SKILL.md`.
