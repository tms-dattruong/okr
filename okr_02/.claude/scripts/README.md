# AI Commit Gate — Cấu trúc scripts

Pre-commit gọi `ai_commit_gate.sh`. Script này chỉ **xếp thứ tự**; logic nằm trong thư mục con + 2 helper Python.

Hướng dẫn vận hành (cài đặt, env, troubleshoot): [../docs/ai-commit-gate.md](../docs/ai-commit-gate.md)

## Cây file

```
.claude/
├── ai-commit-gate.env              ← config (DEMO, TIMEOUT, CACHE, REPORT…)
├── docs/
│   └── ai-commit-gate.md           ← hướng dẫn dùng
└── scripts/
    ├── ai_commit_gate.sh           ← entry / orchestrator
    ├── ai_commit_gate/             ← module bash (source bởi orchestrator)
    │   ├── common.sh               ← fail_open, fail_hard, redact_secrets()
    │   ├── env.sh                  ← load_gate_env, resolve_gate_runtime_config
    │   ├── timeout.sh              ← run_with_timeout (portable)
    │   └── prompt.sh               ← checklist_fingerprint, build_gate_prompt
    ├── redact_secrets.py           ← che secret trước khi gửi LLM
    └── print_ai_review.py          ← parse JSON finding → terminal + .md report

.pre-commit-config.yaml             ← hook id: ai-commit-gate → entry bash ở trên
```

Checklist luôn đọc:

- `.claude/commands/review.md`
- `.claude/skills/ai-review/SKILL.md`
- `.claude/skills/code-review/SKILL.md`

## Ai làm gì

| Thành phần | Việc |
|------------|------|
| `ai_commit_gate.sh` | Flow: load env → diff → redact → hash/cache → prompt → `claude` → print |
| `common.sh` | Thoát fail-open / fail-hard; wrapper gọi `redact_secrets.py` |
| `env.sh` | Đọc `ai-commit-gate.env`; set CACHE / REPORT / TIMEOUT / MODEL / EFFORT |
| `timeout.sh` | Chạy lệnh có timeout: GNU `timeout` / `gtimeout` / bash fallback |
| `prompt.sh` | Fingerprint + `build_gate_prompt` (review + ai-review + code-review) |
| `redact_secrets.py` | Load tên biến `.env`/`.env-sample` + prefix; che → `[REDACTED PRIVATE KEY]` |
| `print_ai_review.py` | In Nghiêm trọng/Quan trọng/Gợi ý (tiếng Việt); ghi report; exit (enforce) |

## Luồng ngắn

```
pre-commit (files: .py | templates/*.html)
        │
        ▼
ai_commit_gate.sh
        ├─ source ai_commit_gate/*.sh
        ├─ diff staged .py + templates (hoặc AI_GATE_DIFF_FILE)
        ├─ redact_secrets.py
        ├─ SHA-256(diff + checklist) → cache hit? → print cũ, dừng
        ├─ prompt.sh → PROMPT + diff
        ├─ claude -p --effort low --model haiku --tools ""  (± --bare)
        └─ print_ai_review.py → cache + report markdown
```

## Chạy tay

```bash
# Đã stage file src/**/*.py hoặc templates
.claude/scripts/ai_commit_gate.sh

# Warn-only một lần
AI_GATE_DEMO=1 .claude/scripts/ai_commit_gate.sh
```

## Runtime (không commit)

| Path | Ý nghĩa |
|------|---------|
| `.git/ai-commit-gate-cache/` | Cache kết quả theo hash |
| `.claude/reports/ai-commit-gate/` | `latest.md` + archive (gitignored trừ README) |
