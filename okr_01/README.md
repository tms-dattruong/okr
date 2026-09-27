# OKR 01 — Model Impact Automation

Claude workflow that audits impact when `ha-speaking-api` changes schema (Alembic migration) on consumer repos. Cuts the risk of missing files/layers that need sync.

**Run workspace:** monorepo root `Haji/` (all sibling repos visible).

---

## Goals

- Read a migration → infer model / fields / relationships
- Scan consumers via config maps
- Emit a report: risks, Must / Should / Maybe, checklist by repo & layer

Consumers: `ha-speaking-admin-web`, `ha-speaking-company-web`, `ha-speaking-haij-student-api` (direct MySQL — no shared ORM import).

---

## Layout

```
okr_01/.claude/
├── CLAUDE.md
├── commands/
│   ├── check-model-impact.md
│   ├── verify-model-impact.md
│   └── update-model-impact-config.md
├── skills/
│   ├── model-impact-audit/
│   ├── model-impact-verify/
│   └── model-impact-config-update/
├── config/
│   ├── repos.md
│   ├── repo-scan-profiles.md
│   ├── impact-map.md
│   └── report-writing-style.md
├── templates/
└── reports/
```

**Design rule:** thin commands → logic in skills → repo knowledge in config → layout in templates. Skills **do not** edit application code (except config-update, which only touches `.claude/config/`).

---

## Setup

1. Copy or symlink this OKR’s `.claude/` into `Haji/.claude/`.
2. Open Claude Code CLI from `Haji/`.
3. Ensure migration paths point at the right files under `ha-speaking-api`.

Requirements: Claude CLI logged in; sibling repos side by side under `Haji/`.

---

## How to use

### 1. `/check-model-impact` — audit after a new migration

Only `Migration` is required. Model + summary are **inferred from the file** — no prompts.

```text
/check-model-impact
Migration: ha-speaking-api/src/app/migrations/versions/<revision>_<name>.py
```

**Output:** `.claude/reports/YYYY-MM-DD-<model>-impact.html` + chat summary.

Skill: `skills/model-impact-audit/SKILL.md`

### 2. `/verify-model-impact` — confirm after applying the checklist

```text
/verify-model-impact
@.claude/reports/YYYY-MM-DD-<model>-impact.html
```

Legacy `*-impact.md` still works. You can override `Model` / `Migration` / `Change summary` if needed.

**Output:** `.claude/reports/YYYY-MM-DD-<model>-verify.html`

Skill: `skills/model-impact-verify/SKILL.md`

### 3. `/update-model-impact-config` — refresh maps when config is stale

From a verify report (also reads the linked impact report):

```text
/update-model-impact-config
@.claude/reports/YYYY-MM-DD-<model>-verify.html
```

Or rescan domain map / layers / `scan_order`:

```text
/update-model-impact-config
full-scan
```

**Output:** `.claude/reports/YYYY-MM-DD-config-update.md`

Skill: `skills/model-impact-config-update/SKILL.md`

---

## Recommended flow

```
new migration
    → /check-model-impact
    → (dev fixes Must / Should)
    → /verify-model-impact
    → (map drifted) /update-model-impact-config
```

Do not auto-run config-update after verify.

---

## Config & reports

| File | Role |
|------|------|
| `config/repos.md` | Repo purpose, scan order, deploy tier, breakage |
| `config/repo-scan-profiles.md` | Domain map, layer tags, change-type × action matrix |
| `config/impact-map.md` | Change types, scan priority, risk, confidence |
| `config/report-writing-style.md` | Report writing rules |

**Audit report sections:** Source change → Migration summary → Risks → Per-repo findings → Per-file checklist → Notes.

---

## More docs

- `CLAUDE.md` — full session guidance
- Skills under `skills/*/SKILL.md`
- Templates: `templates/impact-report.html` (and legacy `.md`)
