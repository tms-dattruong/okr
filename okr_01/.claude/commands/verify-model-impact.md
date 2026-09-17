---
description: Re-scan after model impact fixes and confirm baseline findings are resolved
---

# /verify-model-impact

Thin entrypoint. Logic lives in `.claude/skills/model-impact-verify/SKILL.md`.

## Usage

```text
/verify-model-impact
.claude/reports/2026-08-13-situationlistening-impact.html
```

Also valid: `@.claude/reports/...-impact.html` (or legacy `*-impact.md`), absolute path, or file URL. Do **not** require label `Baseline report:`.

## Required input

Path / `@` / URL → `*-impact.html` (legacy `*-impact.md` OK). Infer baseline; never ask user to type `Baseline report`.

If missing or file not found → ask (path or `@`) and STOP.

## Optional overrides

`Model:` / `Migration:` / `Change summary:` — only when baseline incomplete or override needed. Default: extract from baseline.

## Output

- `.claude/reports/YYYY-MM-DD-<model>-verify.html` (from `.claude/templates/impact-verify-report.html`; Vietnamese prose per `.claude/config/report-writing-style.md`; identifiers as-is)
- Short Vietnamese chat summary + path

If domain map / scan paths look stale → `/update-model-impact-config` with `*-verify.html` (do not auto-run).

Invoke `.claude/skills/model-impact-verify/SKILL.md`.
