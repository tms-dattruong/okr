#!/usr/bin/env bash
# prompt.sh — fingerprint checklist + dựng prompt gửi Claude.
# Cần REPO_ROOT đã set trước khi source.

# Bỏ YAML frontmatter (--- ... ---) đầu file markdown skill/command.
strip_frontmatter() {
    awk 'BEGIN { c = 0 } /^---$/ { c++; next } c >= 2'
}

# Đường dẫn 3 nguồn checklist (review.md + ai-review + code-review).
_gate_checklist_paths() {
    REVIEW_CMD="$REPO_ROOT/.claude/commands/review.md"
    AI_REVIEW="$REPO_ROOT/.claude/skills/ai-review/SKILL.md"
    CODE_REVIEW="$REPO_ROOT/.claude/skills/code-review/SKILL.md"
}

# Nội dung nguồn review dùng hash cache; sửa checklist → bust cache.
# Thiếu file nguồn → return 1 (KHÔNG fallback); caller phải fail_hard.
checklist_fingerprint() {
    _gate_checklist_paths
    if [ -f "$REVIEW_CMD" ] && [ -f "$AI_REVIEW" ] && [ -f "$CODE_REVIEW" ]; then
        printf 'checklist=full\n'
        cat "$REVIEW_CMD" "$AI_REVIEW" "$CODE_REVIEW"
        return 0
    fi
    return 1
}

# Dựng prompt gate. Thiếu file nguồn → return 1.
build_gate_prompt() {
    _gate_checklist_paths
    if [ ! -f "$REVIEW_CMD" ] || [ ! -f "$AI_REVIEW" ] || [ ! -f "$CODE_REVIEW" ]; then
        return 1
    fi

    cat <<'PROMPT_HEADER'
You are the AI commit gate for ha-speaking-admin-web (mode=full).

Context: review ONLY the git diff at the end. Do not assume other files exist unless the diff implies it.
Project: Flask admin (ha-speaking-admin-web).

Output language requirement: every finding's "summary" MUST be written in Vietnamese.
Keep file names, symbols, API, class names in English when citing evidence.

PROMPT_HEADER

    printf '%s\n' '--- /review command ---'
    strip_frontmatter <"$REVIEW_CMD"
    printf '\n%s\n' '--- skill ai-review ---'
    strip_frontmatter <"$AI_REVIEW"
    printf '\n%s\n' '--- skill code-review ---'
    strip_frontmatter <"$CODE_REVIEW"

    cat <<'PROMPT_FOOTER'

Gate-specific output rules (override any markdown format above):
- Critical → "critical", Major → "major", Suggestions → "suggestions".
- Missing important tests → "major" or "suggestions" (JSON has no dedicated category).
- Return ONLY raw JSON, no markdown fence, no prose, matching this schema exactly:
{"critical":[{"file":"","line":0,"summary":""}],"major":[{"file":"","line":0,"summary":""}],"suggestions":[{"file":"","line":0,"summary":""}]}
- "file": path relative to repo root; "line": best estimate from the diff; "summary": one line, MUST be in Vietnamese, with evidence.
- Empty category → empty array [].
- Report every real issue in the diff: prefer completeness (critical + major + suggestions) over a single sparse finding.
- Do not collapse multiple issues into one summary.

Diff:
PROMPT_FOOTER
}
