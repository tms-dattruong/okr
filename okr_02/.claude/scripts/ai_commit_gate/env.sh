#!/usr/bin/env bash
# env.sh — load config + resolve đường dẫn / timeout runtime.
# Cần REPO_ROOT đã set trước khi source.

# Đọc .claude/ai-commit-gate.env; biến đã có sẵn (hook/CI/shell) không bị ghi đè.
load_gate_env() {
    local env_file="$REPO_ROOT/.claude/ai-commit-gate.env"
    [ -f "$env_file" ] || return 0
    local line key val
    while IFS= read -r line || [ -n "$line" ]; do
        # Bỏ comment #... và trim khoảng trắng hai đầu.
        line="${line%%#*}" # Bỏ comment #...
        line="${line#"${line%%[![:space:]]*}"}" # Trim khoảng trắng bên trái.
        line="${line%"${line##*[![:space:]]}"}" # Trim khoảng trắng bên phải.
        [ -z "$line" ] && continue # Bỏ dòng rỗng.
        [[ "$line" == *"="* ]] || continue # Bỏ dòng không có =.
        key="${line%%=*}" # Lấy key.
        val="${line#*=}" # Lấy value.
        key="${key#"${key%%[![:space:]]*}"}" # Trim khoảng trắng bên trái.
        key="${key%"${key##*[![:space:]]}"}" # Trim khoảng trắng bên phải.
        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue # Bỏ key không hợp lệ.
        # Chỉ export nếu key chưa tồn tại trong môi trường.
        if [ -z "${!key+x}" ]; then
            export "$key=$val" # Export key và value.
        fi
    done <"$env_file" # Đọc file env.
}

# Set CACHE_DIR, REPORT_DIR, TIMEOUT_SECS, GATE_MODEL, GATE_EFFORT, GATE_BRANCH.
resolve_gate_runtime_config() {
    local _raw_cache _raw_report _raw_timeout _raw_effort

    # Thư mục cache kết quả review (key = hash diff+checklist).
    _raw_cache="${AI_GATE_CACHE_DIR:-.git/ai-commit-gate-cache}"
    if [[ "$_raw_cache" = /* ]]; then
        CACHE_DIR="$_raw_cache"
    else
        CACHE_DIR="$REPO_ROOT/$_raw_cache"
    fi

    # Thư mục báo cáo markdown (latest.md + archive theo ngày). Rỗng = tắt.
    _raw_report="${AI_GATE_REPORT_DIR:-.claude/reports/ai-commit-gate}"
    if [ -z "$_raw_report" ]; then
        REPORT_DIR=""
    elif [[ "$_raw_report" = /* ]]; then
        REPORT_DIR="$_raw_report"
    else
        REPORT_DIR="$REPO_ROOT/$_raw_report"
    fi

    # Timeout gọi claude (giây); giá trị lỗi → mặc định 90.
    _raw_timeout="${AI_GATE_TIMEOUT:-90}"
    if [[ "$_raw_timeout" =~ ^[1-9][0-9]*$ ]]; then
        TIMEOUT_SECS="$_raw_timeout"
    else
        echo "[ai-commit-gate] invalid AI_GATE_TIMEOUT='${_raw_timeout}', using 90" >&2
        TIMEOUT_SECS=90
    fi

    # Model nhanh mặc định (haiku). Để trống = model mặc định của CLI.
    GATE_MODEL="${AI_GATE_MODEL:-haiku}"

    # Effort: low|medium|high|... — low = nhanh hơn.
    _raw_effort="${AI_GATE_EFFORT:-low}"
    case "$_raw_effort" in
        low|medium|high|xhigh|max) GATE_EFFORT="$_raw_effort" ;;
        *)
            echo "[ai-commit-gate] invalid AI_GATE_EFFORT='${_raw_effort}', using low" >&2
            GATE_EFFORT="low"
            ;;
    esac

    # Tên branch gắn metadata report (best-effort).
    GATE_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
}
