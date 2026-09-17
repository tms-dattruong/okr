---
description: Refresh .claude/config from impact/verify reports or a full-scan of sibling repos
---

# /update-model-impact-config

Thin entrypoint. Logic lives in `.claude/skills/model-impact-config-update/SKILL.md`.

## Usage

```text
/update-model-impact-config
.claude/reports/2026-08-14-basicsituationpracticecontent-verify.html
```

Also valid: `@...-verify.html` (legacy `*-verify.md` OK), absolute path, or file URL. Do **not** require `Mode:` / `Reports:`.

```text
/update-model-impact-config
full-scan
```

Both: `*-verify.html` (or `.md`) + `full-scan` (`full-scan` first, then reports).

## Required input

Path / `@` / URL → `*-verify.html` (legacy `*-verify.md` OK; infer reports mode), and/or `full-scan`.

If neither → ask for verify file (path or `@`) and STOP. Never ask user to type `Mode:` / `Reports:`.

## Output

- Surgical edits only under `.claude/config/*.md`
- `.claude/reports/YYYY-MM-DD-config-update.md` (Vietnamese; empty diff still saves “no change”)
- Short Vietnamese chat summary + path

Invoke `.claude/skills/model-impact-config-update/SKILL.md`.
