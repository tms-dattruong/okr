# OKR 02 — AI Commit Quality Gate

LLM code review **before commit** on the developer machine (pre-commit). Catches Flask admin issues early: blueprints, `get_db()`, repository boundaries, auth (`restricted_routes` / `skip_paths`), IDOR, N+1, safe logging, and more.

**Typical target repo:** `ha-speaking-admin-web` (copy assets into that repo root).

---

## Goals

- Auto-review staged diffs
- Findings: **Critical** / **Major** / **Suggestions**
- Enforce: `AI_GATE_DEMO=0` → block commit when **critical** exists (major is warn-only)
- Demo: `AI_GATE_DEMO=1` → warn-only for everything

**No CI backstop.** `git commit --no-verify` skips AI review entirely.

---

## Layout

```
okr_02/
├── .pre-commit-config.yaml
├── .gitignore
└── .claude/
    ├── ai-commit-gate.env          ← DEMO, TIMEOUT, MODEL, …
    ├── docs/ai-commit-gate.md      ← detailed runbook
    ├── PROMPT.md                   ← project / skills context
    ├── scripts/
    │   ├── ai_commit_gate.sh       ← orchestrator (hook entry)
    │   ├── ai_commit_gate/         ← env, timeout, prompt, common
    │   ├── redact_secrets.py
    │   ├── print_ai_review.py
    │   └── README.md
    └── reports/ai-commit-gate/     ← latest.md (runtime; gitignored except README)
```

Runtime checklist (must exist in the target repo):

- `.claude/commands/review.md`
- `.claude/skills/ai-review/SKILL.md`
- `.claude/skills/code-review/SKILL.md`

Missing checklist sources → **exit 1**.

---

## Setup

1. Copy from `okr_02/` into the app repo root:
   - `.pre-commit-config.yaml`
   - `.claude/scripts/`
   - `.claude/ai-commit-gate.env`
   - checklist `review.md` + skills `ai-review` / `code-review` (if the repo does not already have them)
2. Install the hook:

```bash
pip install pre-commit
pre-commit install
```

3. Install the `claude` binary (Claude Code CLI) and log in (`claude` → `/login`).  
   Missing `claude` → **exit 1** (no silent skip).

---

## How to use

### Daily

```bash
git add src/app/...
git commit -m "..."
```

Hook runs when staged paths match:

- `src/**/*.py`
- `src/app/templates/**/*.html`

### Gate only

```bash
# Files already staged in scope
.claude/scripts/ai_commit_gate.sh

# One-shot warn-only
AI_GATE_DEMO=1 .claude/scripts/ai_commit_gate.sh

pre-commit run ai-commit-gate --all-files
```

### Enforce mode

| `AI_GATE_DEMO` | Behavior |
|----------------|----------|
| `0` | Critical present → block commit |
| `1` | Warn only |

File: `.claude/ai-commit-gate.env`. Shell env **wins** over the file.

---

## Runtime flow

```
git commit
    → pre-commit (files: .py | templates/*.html)
    → ai_commit_gate.sh
         ├─ load ai-commit-gate.env
         ├─ staged diff
         ├─ redact secrets
         ├─ cache hit? → reprint, no LLM call
         ├─ build prompt (review + ai-review + code-review)
         ├─ claude -p --effort low --model haiku
         └─ print_ai_review.py → terminal + latest.md
```

Timeout / parse failure → fail-open (`exit 0`) unless `AI_GATE_REQUIRE_LLM=1`.

---

## Skip review

| Method | When | Note |
|--------|------|------|
| `git commit --no-verify` | Urgent commit | Skips all pre-commit |
| Do not stage `.py` / templates under `src/` | Docs / other config | Hook does not run |
| Cache hit (same hash) | Diff + checklist unchanged | No LLM call |

---

## Main config

| Variable | Default (script) | Meaning |
|----------|------------------|---------|
| `AI_GATE_DEMO` | `1` (repos often set `0`) | `1` warn-only; `0` block on critical |
| `AI_GATE_TIMEOUT` | `90` | Seconds timeout for `claude` |
| `AI_GATE_MODEL` | `haiku` | CLI model |
| `AI_GATE_EFFORT` | `low` | LLM effort |
| `AI_GATE_BARE` | `0` | `1` = `--bare` (needs API key) |
| `AI_GATE_CACHE_DIR` | `.git/ai-commit-gate-cache` | Cache |
| `AI_GATE_REPORT_DIR` | `.claude/reports/ai-commit-gate` | Report; empty = off |
| `AI_GATE_REQUIRE_LLM` | `0` | `1` = fail on timeout / empty review |

Priority: script defaults < `ai-commit-gate.env` < shell env.

---

## Security & runtime

- Only sends redacted `.py` + HTML template diffs (`redact_secrets.py`).
- Cache: `.git/ai-commit-gate-cache/` — clear with `rm -rf .git/ai-commit-gate-cache`
- Report: `.claude/reports/ai-commit-gate/latest.md` (+ archives)

Redaction is not enough — do not hardcode credentials.

---

## Quick troubleshooting

| Symptom | Fix |
|---------|-----|
| `claude CLI not found` | Install `claude`, log in |
| Timeout / review unavailable | Raise `AI_GATE_TIMEOUT`; check login |
| Hook does not run | Stage matching paths or `pre-commit install` |
| Enforce but no block | Clear cache; look for block message in output |

---

## More docs

- Full runbook: [`.claude/docs/ai-commit-gate.md`](.claude/docs/ai-commit-gate.md)
- Scripts layout: [`.claude/scripts/README.md`](.claude/scripts/README.md)
- Admin skills/commands context: [`.claude/PROMPT.md`](.claude/PROMPT.md)
