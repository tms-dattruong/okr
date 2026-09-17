# AI Commit Gate — ERD (sơ đồ thành phần & luồng chạy)

Xem hướng dẫn dùng đầy đủ tại [ai-commit-gate.md](ai-commit-gate.md). File này chỉ mô tả **thành phần** và **luồng chạy**.

## Sơ đồ thành phần

```
.pre-commit-config.yaml (hook: ai-commit-gate)
            │
            ▼
.claude/ai-commit-gate.env ──▶ ai_commit_gate.sh (orchestrator)
                                        │
                    ┌───────────────────┼────────────────────────────┐
                    ▼                   ▼                            ▼
        ai_commit_gate/common.sh   ai_commit_gate/env.sh   ai_commit_gate/timeout.sh
        (fail_open / fail_hard)    (load_gate_env /        (run_with_timeout)
                                     resolve_config)
                                        │
                                        ▼
                              ai_commit_gate/prompt.sh (build_gate_prompt)
                                        │
                    ┌───────────────────┼───────────────────────┐
                    ▼                   ▼                       ▼
        .claude/commands/      .claude/skills/          .claude/skills/
        review.md              ai-review/SKILL.md        code-review/SKILL.md
                    (checklist nguồn — đọc lại mỗi lần chạy)

        ai_commit_gate.sh
                    │
                    ▼
        redact_secrets.py  ──▶  (diff đã che secret)
                    │
                    ▼
        claude CLI (-p --output-format json)
                    │
                    ▼
        print_ai_review.py
                    │
        ┌───────────┴────────────┐
        ▼                        ▼
.git/ai-commit-gate-cache/   .claude/reports/ai-commit-gate/
(cache theo hash)             (latest.md + archive)
```

## Luồng chạy

```
Dev: git commit
  │
  ▼
pre-commit: chạy hook (files: src/**/*.py | templates/**/*.html)
  │
  ▼
ai_commit_gate.sh
  │
  ├─ 1. load .claude/ai-commit-gate.env
  │
  ├─ 2. git diff --cached -- 'src/**/*.py' 'src/app/templates/**/*.html'
  │       không có diff staged ──▶ exit 0 (không review)
  │
  ├─ 3. redact_secrets.py (che password/token/PEM/AI key/AWS/...)
  │       ▼
  │     diff đã redact
  │
  ├─ 4. SHA-256(diff đã redact + fingerprint checklist) → tra cache
  │       │
  │       ├─ cache HIT ──▶ lấy kết quả cũ ──▶ print_ai_review.py (không gọi LLM)
  │       │
  │       └─ cache MISS
  │             │
  │             ▼
  │           build_gate_prompt() = review.md + ai-review + code-review + diff
  │             │
  │             ▼
  │           claude CLI -p --output-format json (timeout AI_GATE_TIMEOUT)
  │             │
  │             ▼
  │           JSON {critical, major, suggestions}
  │             │
  │             ▼
  │           print_ai_review.py: parse + in kết quả + ghi cache (chỉ khi parse OK)
  │
  ├─ 5. print_ai_review.py ghi .claude/reports/ai-commit-gate/latest.md + archive
  │
  └─ 6. exit code
          0 = qua (không critical, hoặc AI_GATE_DEMO=1)
          1 = chặn (có critical VÀ AI_GATE_DEMO=0)
          │
          ▼
pre-commit: forward exit code
  │
  ▼
git commit: chặn hoặc cho phép commit
```

## Ghi chú

- Checklist review không cố định trong script — đọc lại từ `review.md` + 2 skill mỗi lần chạy, nên sửa checklist tự động bust cache (fingerprint đổi).
- `redact_secrets.py` chạy trước khi hash và trước khi bất kỳ nội dung nào rời máy.
