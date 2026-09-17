# Claude Setup — ha-speaking-admin-web

This file orients new Claude sessions. Read it before starting any task.

---

## Project in One Line

Flask admin web (server-rendered Jinja2) for HAIJ language learning platform. Python/SQLAlchemy/MySQL, Gunicorn behind Nginx, auth via JWT cookie, Pytest in Docker.

Key facts:
- Container: `h-ad-flask-1` (Flask on port 7201), `h-ad-nginx-1` (port 7200)
- Test command: `docker exec "h-ad-flask-1" pytest /app/tests/ -v`
- Auth bypass in dev: `SKIP_AUTH=True` in `.env`
- Source of truth for structure: `CLAUDE.md` at repo root

---

## What's Been Set Up (and Why)

Everything in `.claude/` is **layered**: generic → project-specific. The `*` layer adds project context that the generic layer cannot know (container names, JWT cookie name, `restricted_routes` pattern, SQLAlchemy session rules).

```
.claude/
├── CLAUDE.md (repo root)     ← project structure, hard rules, naming conventions
├── skills/                   ← instruction sets auto-loaded when description matches
│   ├── <generic>/            ← generic skills (do not edit)
│   └── */                    ← project-specific skills (use these)
├── agents/                   ← specialist personas spawned as subagents
│   ├── <generic>.md          ← generic agents (do not edit)
│   └── *.md                  ← project-specific agents (use these)
├── commands/                 ← slash commands (/build, /ship, etc.)
│   ├── <generic>.md          ← generic commands
│   └── *.md                  ← project-specific commands (use these)
└── PROMPT.md                 ← this file

references/
├── <generic>.md              ← generic checklists (generic skills point here)
└── *.md                      ← project checklists (* skills point here)
```

---

## * Skills

Skills are auto-loaded when the task matches their description. Prefer `*` over generic equivalents.

### Core project skills (standalone — do not extend generic)

| Skill | Use when |
|-------|---------|
| `flask-patterns` | Adding routes, blueprints, repositories, templates |
| `sqlalchemy` | Writing or reviewing DB access code in `app/db/` |
| `security` | Implementing or auditing auth, JWT, input validation |
| `code-review` | Full structured review — Flask/SQLAlchemy/auth/security axes |
| `review-code` | Quick 8-question pass for small PRs (≤ 5 files) |
| `ai-review` | Full 4-step AI review workflow (git diff → read → checklist → output) |
| `generate-code` | Generating new features — 4-phase: understand → design → plan → code |
| `pull-issue` | Fetch Redmine issue → writes `tasks/<TICKET>/issue.md` + `analysis.md` |

### Project skills extending generic

| Skill | Extends | Use when |
|-------|---------|---------|
| `debugging-and-error-recovery` | debugging-and-error-recovery | Route 500, SQLAlchemy session error, JWT failure, container logs |
| `performance-optimization` | performance-optimization | Slow list views, N+1 queries, MySQL EXPLAIN |
| `test-driven-development` | test-driven-development | Writing Pytest tests, bug Prove-It pattern |
| `security-and-hardening` | security-and-hardening | Adding routes, reviewing auth/input/SQL |
| `git-workflow-and-versioning` | git-workflow-and-versioning | Branching, committing, PR prep |
| `pr-description` | pr-description | Writing PR descriptions |

### Generic skills (use if no project equivalent)

| Skill | Use when |
|-------|---------|
| `spec-driven-development` | Starting a new feature with no spec yet |
| `planning-and-task-breakdown` | Breaking a spec into ordered implementable tasks |
| `incremental-implementation` | Changes touching > 1 file; avoid landing too much at once |
| `idea-refine` | Stress-test or expand ideas before committing to a plan |
| `api-and-interface-design` | Designing REST endpoints or module boundaries |
| `ci-cd-and-automation` | CI pipeline setup or quality gate changes |
| `deprecation-and-migration` | Removing old systems or migrating users between implementations |
| `documentation-and-adrs` | Recording architectural decisions or public API changes |

### Caveman / meta skills

| Skill | Use when |
|-------|---------|
| `caveman` | Token-compressed communication mode (drop articles/filler) |
| `cavecrew` | Delegate to caveman specialist subagents |
| `caveman-commit` | Write git commit messages in caveman style |
| `caveman-compress` | Compress existing text to caveman style |
| `caveman-review` | Code review output in caveman style |
| `caveman-stats` | Show session token usage and estimated savings |

---

## * Agents (3 total — spawned by /ship)

| Agent | Role |
|-------|------|
| `code-reviewer` | Blueprint, `get_db()`, repository boundary, N+1, auth gaps |
| `security-auditor` | JWT, `restricted_routes`/`skip_paths`, IDOR, Jinja2 XSS, SQL injection |
| `test-engineer` | Coverage: write paths, role gates, validators, conftest patterns |

Spawned in parallel by `/ship`. Do not invoke one from another.

---

## * Commands (8 total — use instead of generic)

| Command | What it does |
|---------|-------------|
| `/pull-issue` | Fetch Redmine issue → analyse against Flask arch → write `tasks/<TICKET>/issue.md` + `analysis.md` |
| `/spec` | Write spec (Objective, Flask Structure, Routes, Auth, DB, DoD) → `spec/<Name>.md` |
| `/plan` | Break spec into vertical tasks with auth checkpoint → `tasks/plan.md` |
| `/build` | Implement one task: test (RED) → code (GREEN) → Docker test → commit |
| `/test` | TDD / Prove-It for bugs — Pytest in Docker, Flask test client |
| `/review` | Full review via `ai-review` (4-step workflow) |
| `/code-simplify` | Simplify Flask code without behavior change |
| `/ship` | **Fan-out**: spawn 3 haij agents in parallel → merge → GO/NO-GO + rollback |

### Full feature lifecycle

```
/pull-issue → /spec → /plan → /build (repeat) → /review → /ship
```

Human approval required between each phase. Do not automate phase transitions.

---

## * Reference Files

Quick-lookup checklists. Skills link here for detailed patterns.

| File | Linked from |
|------|------------|
| `references/security-checklist.md` | `security-and-hardening` skill |
| `references/performance-checklist.md` | `performance-optimization` skill |
| `references/testing-patterns.md` | `test-driven-development` skill |
| `references/orchestration-patterns.md` | `ship` command |

---

## /ship — Key Rules

Fan-out to 3 agents. **9 NO-GO conditions** (any = block merge):

| Condition | Reason |
|-----------|--------|
| New `/admin/...` path NOT in `restricted_routes` or `skip_paths` | Silent auth bypass |
| JWT manually decoded in view (not via `verify_jwt`) | Auth vulnerability |
| `SKIP_AUTH=True` in production `.env` | Full auth bypass |
| `SessionLocal()` used in view instead of `get_db()` | Session leak risk |
| Stack trace / SQL text in `flash()` or rendered HTML | Internal detail exposure |
| Secrets hardcoded (not from `get_env_variable()`) | Secret leak |
| DB schema change with no migration file | Data integrity risk |
| Full test suite fails | Broken main |
| `IntegrityError` not caught in repository write paths | Uncaught DB crash |

**Rollback:** `git revert` → `docker compose up --build -d` → restore DB if migration ran. RTO < 15 min.

---

## Hard Rules (from CLAUDE.md)

- Session: `with get_db() as db:` only — never `SessionLocal()` in services
- Repositories: pure persistence — no `request`, `flash`, HTTP logic inside
- Templates: no SQL or heavy logic in Jinja2 — compute in Python, pass to template
- Errors: catch in view, call `log_error`, show safe message — never expose stack traces
- Auth: new `/admin/...` paths must appear in `restricted_routes` or `skip_paths`
- `url_for`: always `url_for("blueprint_name.view_function_name")`
- Blueprints: variable `*_bp`; name = first arg to `Blueprint(...)` — used in `url_for`
- Validators: named `is_*` or `check_*`, return `{"is_valid": bool, "message": str}`
