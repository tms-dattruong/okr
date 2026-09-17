#!/usr/bin/env bash
# AI Commit Quality Gate — ha-speaking-admin-web
#
# Orchestrator mỏng: xếp thứ tự bước. Logic chi tiết nằm trong ai_commit_gate/*.sh
# và Python helper (redact_secrets.py, print_ai_review.py).
#
# Flow:
#   1. Load .claude/ai-commit-gate.env (env đã set sẵn thắng: hook / shell)
#   2. Lấy diff src/**/*.py + templates HTML (file inject test > git diff --cached)
#   3. Redact secret (redact_secrets.py) trước khi dữ liệu rời máy
#   4. Cache key = SHA-256(diff đã redact + checklist) — sửa checklist → bust cache
#   5. Dựng prompt: review.md + ai-review + code-review + JSON + diff
#   6. claude -p --effort low --model haiku --tools "" (optional --bare nếu AI_GATE_BARE=1)
#   7. print_ai_review.py → CRITICAL / MAJOR / SUGGESTIONS + báo cáo markdown;
#      DEMO=0 thì chặn chỉ khi có critical (major chỉ cảnh báo)
#
# Cần `claude` CLI local. Không fallback ANTHROPIC_API_KEY.
# Fail-open: timeout / helper lỗi → skip exit 0 (trừ AI_GATE_REQUIRE_LLM=1).
# Thiếu `claude` → exit 1 (hard error).
#
# Module:
#   ai_commit_gate/common.sh   — fail_open / fail_hard / redact_secrets
#   ai_commit_gate/env.sh      — load env + resolve CACHE/REPORT/TIMEOUT
#   ai_commit_gate/timeout.sh  — run_with_timeout (portable)
#   ai_commit_gate/prompt.sh   — fingerprint + build_gate_prompt
set -euo pipefail

# ---------------------------------------------------------------------------
# Bootstrap: repo root + nạp thư viện
# ---------------------------------------------------------------------------
# Script nằm .claude/scripts/ → root repo = ../..
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

GATE_LIB="$REPO_ROOT/.claude/scripts/ai_commit_gate"
# shellcheck source=/dev/null
source "$GATE_LIB/common.sh"
# shellcheck source=/dev/null
source "$GATE_LIB/env.sh"
# shellcheck source=/dev/null
source "$GATE_LIB/timeout.sh"
# shellcheck source=/dev/null
source "$GATE_LIB/prompt.sh"

# ---------------------------------------------------------------------------
# 1) Config
# ---------------------------------------------------------------------------
load_gate_env
resolve_gate_runtime_config

# ---------------------------------------------------------------------------
# 2) Lấy diff (inject file cho test > staged Python + Jinja templates)
# ---------------------------------------------------------------------------
if [ -n "${AI_GATE_DIFF_FILE:-}" ]; then
    if [ ! -f "$AI_GATE_DIFF_FILE" ]; then
        fail_open "AI_GATE_DIFF_FILE missing, skipping"
    fi
    DIFF=$(cat "$AI_GATE_DIFF_FILE" || true)
else
    DIFF=$(git diff --cached -- 'src/**/*.py' 'src/app/templates/**/*.html' || true)
fi

# Không có diff Python/template staged → không review.
if [ -z "$DIFF" ]; then
    exit 0
fi

# Temp file: diff / fingerprint checklist / prompt đầy đủ.
DIFF_FILE=$(mktemp) || fail_open "mktemp failed, skipping"
CHECKLIST_FILE=$(mktemp) || fail_open "mktemp checklist failed, skipping"
PROMPT_FILE=""
cleanup() { rm -f "${DIFF_FILE:-}" "${PROMPT_FILE:-}" "${CHECKLIST_FILE:-}"; }
trap cleanup EXIT

printf '%s\n' "$DIFF" >"$DIFF_FILE" || fail_open "write diff failed, skipping"

# ---------------------------------------------------------------------------
# 3) Redact secret trước khi hash / gửi LLM
# ---------------------------------------------------------------------------
set +e
DIFF=$(redact_secrets "$DIFF_FILE")
REDACT_RC=$?
set -e
if [ "$REDACT_RC" -ne 0 ]; then
    fail_open "redact failed, skipping"
fi
printf '%s\n' "$DIFF" >"$DIFF_FILE" || fail_open "rewrite redacted diff failed, skipping"

# ---------------------------------------------------------------------------
# 4) Hash + cache hit?
# ---------------------------------------------------------------------------
checklist_fingerprint >"$CHECKLIST_FILE" || fail_hard "missing checklist source (review.md / ai-review / code-review) — cannot review"

set +e
DIFF_HASH=$(
    { cat "$DIFF_FILE" "$CHECKLIST_FILE"; } | python3 -c '
import hashlib, sys
print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())
'
)
HASH_RC=$?
set -e
if [ "$HASH_RC" -ne 0 ] || [ -z "${DIFF_HASH:-}" ]; then
    fail_open "diff hash failed, skipping"
fi

mkdir -p "$CACHE_DIR" || fail_open "cache dir create failed, skipping"
CACHE_FILE="$CACHE_DIR/$DIFF_HASH"

# Cache hit → in lại kết quả cũ, không gọi LLM.
if [ -f "$CACHE_FILE" ]; then
    echo "[ai-commit-gate] cache hit ($DIFF_HASH), skipping LLM" >&2
    set +e
    AI_GATE_CACHE_OUT="" \
        AI_GATE_REPORT_DIR="$REPORT_DIR" \
        AI_GATE_DIFF_HASH="$DIFF_HASH" \
        AI_GATE_BRANCH="$GATE_BRANCH" \
        AI_GATE_CACHE_HIT=1 \
        python3 "$REPO_ROOT/.claude/scripts/print_ai_review.py" "$(cat "$CACHE_FILE")"
    PRINT_RC=$?
    set -e
    # DEMO=1 (mặc định): không chặn. DEMO=0: tôn trọng exit code print.
    if [ "${AI_GATE_DEMO:-1}" = "0" ] && [ "$PRINT_RC" -ne 0 ]; then
        exit "$PRINT_RC"
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# 5) Dựng prompt = checklist + diff đã redact
# ---------------------------------------------------------------------------
PROMPT=$(build_gate_prompt) || fail_hard "missing checklist source (review.md / ai-review / code-review) — cannot review"

PROMPT_FILE=$(mktemp) || fail_open "mktemp prompt failed, skipping"
{
    printf '%s\n' "$PROMPT"
    cat "$DIFF_FILE"
} >"$PROMPT_FILE" || fail_open "write prompt failed, skipping"

# ---------------------------------------------------------------------------
# 6) Gọi LLM (hoặc mock / force-no-llm cho test)
# ---------------------------------------------------------------------------
RESULT=""

# Hook test: inject JSON sẵn (bỏ qua mạng / claude CLI).
if [ -n "${AI_GATE_MOCK_RESULT_FILE:-}" ]; then
    if [ ! -f "$AI_GATE_MOCK_RESULT_FILE" ]; then
        fail_open "AI_GATE_MOCK_RESULT_FILE missing, skipping"
    fi
    RESULT=$(cat "$AI_GATE_MOCK_RESULT_FILE" || true)
# Hook test: giả không có LLM (kiểm tra REQUIRE_LLM).
elif [ "${AI_GATE_FORCE_NO_LLM:-0}" = "1" ]; then
    RESULT=""
elif ! command -v claude >/dev/null 2>&1; then
    fail_hard "claude CLI not found — install and login to Claude Code, then retry"
# Prompt qua stdin (tránh ARG_MAX). --tools "" = chỉ review text đã cho.
# --bare CHỈ khi AI_GATE_BARE=1 (cần ANTHROPIC_API_KEY; bỏ OAuth → dễ "Not logged in").
else
    set +e
    CLAUDE_ARGS=(-p --output-format json --tools "" --effort "$GATE_EFFORT")
    if [ "${AI_GATE_BARE:-0}" = "1" ]; then
        CLAUDE_ARGS+=(--bare)
    fi
    if [ -n "${GATE_MODEL:-}" ]; then
        CLAUDE_ARGS+=(--model "$GATE_MODEL")
    fi
    echo "[ai-commit-gate] calling claude model=${GATE_MODEL:-default} effort=${GATE_EFFORT} timeout=${TIMEOUT_SECS}s checklist=full bare=${AI_GATE_BARE:-0}" >&2
    CLAUDE_ERR=$(mktemp) || CLAUDE_ERR="/dev/null"
    RAW=$(
        AI_GATE_STDIN_FILE="$PROMPT_FILE" \
            run_with_timeout "$TIMEOUT_SECS" \
            claude "${CLAUDE_ARGS[@]}" \
            2>"$CLAUDE_ERR"
    )
    CLAUDE_RC=$?
    set -e
    if [ -n "${RAW:-}" ]; then
        # Parse wrapper JSON: result + is_error (kể cả khi exit != 0).
        set +e
        PARSE_OUT=$(python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    data = json.loads(raw)
except Exception as e:
    print("PARSE_FAIL", str(e), file=sys.stderr)
    sys.exit(2)
if data.get("is_error"):
    msg = data.get("result") or data.get("error") or "unknown claude error"
    print(msg, file=sys.stderr)
    sys.exit(1)
result = data.get("result")
if result is None or result == "":
    sys.exit(3)
print(result)
' <<<"$RAW" 2>"$CLAUDE_ERR.parse")
        PARSE_RC=$?
        set -e
        if [ "$PARSE_RC" -eq 0 ]; then
            RESULT="$PARSE_OUT"
        else
            ERR_MSG=$(cat "$CLAUDE_ERR.parse" 2>/dev/null | tail -n 5)
            echo "[ai-commit-gate] claude exit=${CLAUDE_RC} parse_rc=${PARSE_RC}: ${ERR_MSG:-non-JSON or empty result}" >&2
            if [ -s "$CLAUDE_ERR" ]; then
                echo "[ai-commit-gate] claude stderr: $(tail -n 3 "$CLAUDE_ERR")" >&2
            fi
            RESULT=""
        fi
    else
        echo "[ai-commit-gate] claude exit=${CLAUDE_RC} (timeout=${TIMEOUT_SECS}s or empty output)" >&2
        if [ -s "$CLAUDE_ERR" ]; then
            echo "[ai-commit-gate] claude stderr: $(tail -n 5 "$CLAUDE_ERR")" >&2
        fi
        RESULT=""
    fi
    rm -f "$CLAUDE_ERR" "$CLAUDE_ERR.parse" 2>/dev/null || true
fi

if [ -z "${RESULT:-}" ]; then
    if [ "${AI_GATE_REQUIRE_LLM:-0}" = "1" ]; then
        fail_hard "LLM required but review unavailable or timed out"
    fi
    fail_open "review unavailable or timed out, skipping"
fi

# ---------------------------------------------------------------------------
# 7) In finding + ghi cache (print_ai_review chỉ cache khi parse OK)
# ---------------------------------------------------------------------------
set +e
AI_GATE_CACHE_OUT="$CACHE_FILE" \
    AI_GATE_REPORT_DIR="$REPORT_DIR" \
    AI_GATE_DIFF_HASH="$DIFF_HASH" \
    AI_GATE_BRANCH="$GATE_BRANCH" \
    AI_GATE_CACHE_HIT=0 \
    python3 "$REPO_ROOT/.claude/scripts/print_ai_review.py" "$RESULT"
PRINT_RC=$?
set -e

if [ "${AI_GATE_DEMO:-1}" = "0" ] && [ "$PRINT_RC" -ne 0 ]; then
    exit "$PRINT_RC"
fi
exit 0
