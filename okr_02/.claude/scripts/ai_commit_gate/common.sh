#!/usr/bin/env bash
# common.sh — helper chung (exit + gọi Python redact).
# Cần REPO_ROOT đã set trước khi source.

# Thoát 0 (fail-open): lỗi phụ trợ / timeout → không chặn commit.
fail_open() {
    echo "[ai-commit-gate] $1" >&2
    exit 0
}

# Thoát 1 (fail-hard): thiếu claude CLI hoặc bắt buộc LLM mà không có kết quả.
fail_hard() {
    echo "[ai-commit-gate] $1" >&2
    exit 1
}

# Che secret trong file diff trước khi gửi LLM (stdout = text đã redact).
redact_secrets() {
    python3 "$REPO_ROOT/.claude/scripts/redact_secrets.py" "$1"
}
