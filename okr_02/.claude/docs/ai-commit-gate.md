# AI Commit Gate (AI Commit Review)

Gate review code bằng LLM **trước khi commit trên máy dev** (pre-commit hook).  
**Chế độ enforce** điều khiển bởi `AI_GATE_DEMO` trong `.claude/ai-commit-gate.env`: `0` = chặn commit khi có **critical**; **major** chỉ cảnh báo; `1` = warn-only toàn bộ.

**Không có CI backstop.** `git commit --no-verify` bỏ qua toàn bộ AI commit review.

## Mục đích

- Bắt lỗi Flask admin sớm: blueprint, `get_db()`, repository boundary, `restricted_routes` / `skip_paths`, `AdminRole`, IDOR, logging an toàn, N+1, v.v.
- Checklist: `review.md` + skill `ai-review` + `code-review`. Thiếu file nguồn → **exit 1**.
- Cần binary `claude` (Claude Code CLI), đã `/login`. Gọi `--effort low --model haiku` (config được). `--bare` tắt mặc định (OAuth); chỉ bật `AI_GATE_BARE=1` khi có `ANTHROPIC_API_KEY`.
- Thiếu `claude` hoặc thiếu file checklist → **exit 1**. Timeout / parse lỗi → fail-open (`exit 0`) trừ khi `AI_GATE_REQUIRE_LLM=1`.

## Source chính

| File | Vai trò |
|------|---------|
| `.claude/ai-commit-gate.env` | Config (DEMO, TIMEOUT, CACHE_DIR, REPORT_DIR, REQUIRE_LLM) |
| `.claude/scripts/ai_commit_gate.sh` | Orchestrator: diff → redact → cache → LLM → print |
| `.claude/scripts/ai_commit_gate/common.sh` | `fail_open` / `fail_hard` / `redact_secrets` |
| `.claude/scripts/ai_commit_gate/env.sh` | Load env + resolve CACHE / REPORT / TIMEOUT |
| `.claude/scripts/ai_commit_gate/timeout.sh` | `run_with_timeout` (portable) |
| `.claude/scripts/ai_commit_gate/prompt.sh` | Fingerprint + `build_gate_prompt` |
| `.claude/scripts/redact_secrets.py` | Che secret trước khi gửi LLM |
| `.claude/scripts/print_ai_review.py` | Parse JSON, in terminal, ghi report `.md`, exit code |
| `.pre-commit-config.yaml` | Hook `ai-commit-gate` (cửa vào duy nhất) |

Checklist runtime: luôn `review.md` + `ai-review` + `code-review`.

## Cài đặt (local)

1. Cài [pre-commit](https://pre-commit.com/):
   ```bash
   pip install pre-commit
   pre-commit install
   ```
2. Cài binary `claude` (Claude Code CLI) và login.
3. Thử thủ công:
   ```bash
   # Stage vài file .py dưới src/, rồi:
   .claude/scripts/ai_commit_gate.sh
   ```

## Luồng hoạt động

```
git commit
    │
    ▼
pre-commit (files: ^src/.*\.py$ | src/app/templates/.*\.html$)
    │
    ▼
ai_commit_gate.sh
    ├─ Load .claude/ai-commit-gate.env (env đã set thắng)
    ├─ Diff staged src/**/*.py + src/app/templates/**/*.html
    ├─ Redact secret (password, api_key, PEM, sk-*, AKIA, AI/AWS tokens…)
    ├─ Cache hit theo hash diff? → in lại, không gọi LLM
    ├─ build_gate_prompt() ← review.md + ai-review + code-review
    ├─ Gọi claude -p --effort low --model haiku (timeout; optional --bare) — thiếu claude → exit 1
    └─ print_ai_review.py → Nghiêm trọng / Quan trọng / Gợi ý + latest.md
       (summary finding bằng tiếng Việt)
```

## Dùng hàng ngày

```bash
git add src/app/...
git commit -m "..."
```

Hook chạy tự động. `AI_GATE_DEMO=0` → chặn chỉ khi có critical (major/suggestions chỉ warn). `AI_GATE_DEMO=1` → chỉ warn.

### Chỉ chạy hook này

```bash
pre-commit run ai-commit-gate --all-files
# hoặc khi đã stage:
.claude/scripts/ai_commit_gate.sh
```

## Bỏ qua review

| Cách | Khi nào dùng | Ghi chú |
|------|----------------|---------|
| `git commit --no-verify -m "..."` | Commit gấp, bỏ **mọi** pre-commit | Bỏ qua hoàn toàn AI review |
| Không stage `.py` / template HTML dưới `src/` | Commit docs / config khác | Hook không kích hoạt |
| Cache hit (cùng hash) | Diff giống lần trước | Không gọi LLM; vẫn in finding cũ |

Thiếu `claude` **không** skip — `exit 1`.

## Cấu hình

File: **`.claude/ai-commit-gate.env`** (commit được).

```
default trong script  <  ai-commit-gate.env  <  env đã set (pre-commit / shell)
```

| Biến | Mặc định | Ý nghĩa |
|------|----------|---------|
| `AI_GATE_DEMO` | `1` (repo: `0`) | `1` = warn-only; `0` = chặn chỉ critical |
| `AI_GATE_TIMEOUT` | `90` | Timeout giây cho `claude` |
| `AI_GATE_MODEL` | `haiku` | Model Claude CLI (nhanh) |
| `AI_GATE_EFFORT` | `low` | Effort LLM (`low` nhanh hơn) |
| `AI_GATE_BARE` | `0` | `1` = `--bare` (cần API key; bỏ OAuth) |
| `AI_GATE_CACHE_DIR` | `.git/ai-commit-gate-cache` | Thư mục cache |
| `AI_GATE_REPORT_DIR` | `.claude/reports/ai-commit-gate` | `latest.md` + archive; trống = tắt |
| `AI_GATE_REQUIRE_LLM` | `0` | `1` = fail khi timeout / review rỗng |

Warn-only tạm: `AI_GATE_DEMO=1 .claude/scripts/ai_commit_gate.sh`

## Bảo mật

- Chỉ gửi diff `src/**/*.py` + `src/app/templates/**/*.html`.
- Redact trước gửi (`redact_secrets.py`): tên biến từ `.env` + `.env-sample` **và** prefix secret sẵn có (`password`/`token`/…); value → `[REDACTED PRIVATE KEY]`. Thêm shape token (PEM, `sk-`, `AKIA`, …).
- **Không** coi redact là đủ — đừng hardcode credential.

## Cache & báo cáo

- Hash SHA-256(**diff đã redact + fingerprint checklist**) → `.git/ai-commit-gate-cache/`.
- Đổi skill checklist → cache miss tự động.
- Xóa cache: `rm -rf .git/ai-commit-gate-cache`
- Report: `.claude/reports/ai-commit-gate/latest.md` (+ archive). Runtime gitignored.

## Schema JSON finding

```json
{
  "critical": [{"file": "", "line": 0, "summary": ""}],
  "major": [{"file": "", "line": 0, "summary": ""}],
  "suggestions": [{"file": "", "line": 0, "summary": ""}]
}
```

## Troubleshooting

| Hiện tượng | Xử lý |
|------------|--------|
| `claude CLI not found` | Cài `claude`, login |
| `review unavailable or timed out` | Tăng `AI_GATE_TIMEOUT`; kiểm tra `claude` login; **đừng** bật `AI_GATE_BARE` nếu dùng OAuth |
| `Not logged in` | `claude` rồi `/login`, hoặc set `ANTHROPIC_API_KEY` + `AI_GATE_BARE=1` |
| Hook ~đủ timeout dù diff nhỏ | Đã fix: macOS thiếu `gtimeout` từng treo `claude &` trong `$()`. Cập nhật `timeout.sh` (Python foreground). Optional: `brew install coreutils` |
| Hook không chạy | Stage `.py` dưới `src/` hoặc `pre-commit install` |
| Enforce nhưng không chặn | Xóa cache; kiểm tra output `Commit bị chặn` |

## Prompt

`build_gate_prompt()` trong `ai_commit_gate/prompt.sh`: ghép `review.md` + `ai-review` + `code-review`. Thiếu file nguồn → gate báo lỗi và exit 1.
