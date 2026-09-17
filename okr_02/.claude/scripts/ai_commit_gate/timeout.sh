#!/usr/bin/env bash
# timeout.sh — chạy lệnh có giới hạn thời gian (portable macOS/Linux).
#
# QUAN TRỌNG: không dùng bash `cmd &` + `wait` bên trong `$()` —
# trên macOS (không có GNU timeout) pattern đó làm `claude` treo đến khi
# bị kill (đủ AI_GATE_TIMEOUT giây), dù API chỉ mất ~5–15s.

# AI_GATE_STDIN_FILE (tuỳ chọn): feed stdin cho child.
run_with_timeout() {
    local secs=$1
    shift
    local stdin_file="${AI_GATE_STDIN_FILE:-}"

    _run_child() {
        if [ -n "$stdin_file" ]; then
            "$@" <"$stdin_file"
        else
            "$@"
        fi
    }

    # Linux / GNU coreutils — giữ process foreground.
    if command -v timeout >/dev/null 2>&1; then
        _run_child timeout "$secs" "$@"
        return $?
    fi
    # macOS: gtimeout qua Homebrew coreutils.
    if command -v gtimeout >/dev/null 2>&1; then
        _run_child gtimeout "$secs" "$@"
        return $?
    fi

    # Portable foreground timeout qua Python (không background → không treo $()).
    # Exit 124 khi hết giờ (giống GNU timeout).
    AI_GATE_STDIN_FILE="$stdin_file" python3 - "$secs" "$@" <<'PY'
import os
import subprocess
import sys

secs = int(sys.argv[1])
cmd = sys.argv[2:]
stdin_path = os.environ.get("AI_GATE_STDIN_FILE") or ""
stdin = open(stdin_path, "rb") if stdin_path else None
try:
    proc = subprocess.Popen(cmd, stdin=stdin)
    try:
        rc = proc.wait(timeout=secs)
    except subprocess.TimeoutExpired:
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        sys.exit(124)
    sys.exit(rc if rc is not None else 1)
finally:
    if stdin is not None:
        stdin.close()
PY
}
