#!/usr/bin/env python3
"""Render ai-commit-gate JSON findings to the terminal and set exit code.

Demo mode (DEMO=1, default): always exits 0 — warn-only, does not block commit.
Real gate mode (DEMO=0): exits 1 only when any critical finding is present.
Major and suggestions are always warn-only (never block).

Also writes a markdown report when AI_GATE_REPORT_DIR is set (latest.md + dated archive).
"""
from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

RED = "\033[91m"
YEL = "\033[93m"
DIM = "\033[2m"
BOLD = "\033[1m"
RST = "\033[0m"

_EXPECTED_KEYS = ("critical", "major", "suggestions")


def _extract_json_object(text: str) -> str:
    """Pull outermost {...} via brace depth (handles fences + trailing prose)."""
    start = text.find("{")
    if start < 0:
        raise ValueError("no JSON object found")

    depth = 0
    in_string = False
    escape = False
    for i in range(start, len(text)):
        ch = text[i]
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[start : i + 1]
    raise ValueError("unbalanced JSON braces")


def parse(raw: str) -> dict:
    text = raw.strip()
    # Prefer fenced block body when present (do not strip backticks inside summary).
    fence = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", text)
    if fence:
        text = fence.group(1).strip()

    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        data = json.loads(_extract_json_object(text))

    if not isinstance(data, dict):
        raise ValueError("review root must be object")

    # Reject arbitrary JSON (e.g. claude tool-call blobs) masquerading as review output.
    if not all(k in data for k in _EXPECTED_KEYS):
        raise ValueError("review JSON must include critical, major, and suggestions")

    for key in _EXPECTED_KEYS:
        val = data[key]
        if val is None:
            val = []
        if not isinstance(val, list):
            raise ValueError(f"'{key}' must be a list")
        data[key] = val
    return data


def show(items, label, color, *, always: bool = False):
    """Print a severity section. If always=True, print header even when empty."""
    if not items and not always:
        return
    print(f"{color}{BOLD}{label} ({len(items)}){RST}")
    if not items:
        print(f"  {DIM}(không có){RST}")
        print()
        return
    for it in items:
        if not isinstance(it, dict):
            print(f"  {color}?{RST}  {it}")
            continue
        file = it.get("file", "?")
        line = it.get("line", "?")
        summary = it.get("summary", "")
        print(f"  {color}{file}:{line}{RST}  {summary}")
    print()


def _md_escape_cell(text: str) -> str:
    return str(text).replace("|", "\\|").replace("\n", " ").strip()


def _verdict(critical: list, major: list, demo_mode: bool) -> str:
    # Chỉ critical chặn commit; major chỉ cảnh báo.
    if critical:
        if demo_mode:
            return "CẢNH BÁO (demo — lẽ ra chặn vì critical)"
        return "CHẶN"
    if major:
        return "CẢNH BÁO (có major — không chặn)"
    return "ĐẠT"


def _section_md(title: str, items: list) -> str:
    lines = [f"## {title} ({len(items)})", ""]
    if not items:
        lines.append("_Không có_")
        lines.append("")
        return "\n".join(lines)

    lines.append("| File | Dòng | Tóm tắt |")
    lines.append("|------|------|---------|")
    for it in items:
        if not isinstance(it, dict):
            lines.append(f"| ? | ? | {_md_escape_cell(it)} |")
            continue
        lines.append(
            "| {file} | {line} | {summary} |".format(
                file=_md_escape_cell(it.get("file", "?")),
                line=_md_escape_cell(it.get("line", "?")),
                summary=_md_escape_cell(it.get("summary", "")),
            )
        )
    lines.append("")
    return "\n".join(lines)


def build_report_md(
    data: dict,
    *,
    demo_mode: bool,
    diff_hash: str = "",
    branch: str = "",
    cache_hit: bool = False,
    when: datetime | None = None,
) -> str:
    critical = data.get("critical", [])
    major = data.get("major", [])
    suggestions = data.get("suggestions", [])
    when = when or datetime.now(timezone.utc)
    stamp = when.strftime("%Y-%m-%d %H:%M:%S %Z")
    mode = "demo (chỉ cảnh báo)" if demo_mode else "enforce (chặn commit)"
    verdict = _verdict(critical, major, demo_mode)

    parts = [
        "# AI Commit Gate — Kết quả review",
        "",
        f"- **Ngày:** {stamp}",
        f"- **Chế độ:** {mode}",
        f"- **Kết luận:** {verdict}",
        f"- **Diff hash:** `{diff_hash or 'n/a'}`",
        f"- **Branch:** `{branch or 'n/a'}`",
        f"- **Cache:** {'trúng' if cache_hit else 'trượt'}",
        f"- **Số lượng:** critical={len(critical)}, major={len(major)}, suggestions={len(suggestions)}",
        "",
        _section_md("Nghiêm trọng (Critical)", critical),
        _section_md("Quan trọng (Major)", major),
        _section_md("Gợi ý (Suggestions)", suggestions),
        "## Ghi chú",
        "",
        "- Sinh bởi `print_ai_review.py` (ai-commit-gate).",
        "- Không commit secret; diff đã được redact trước khi gửi LLM.",
        "",
    ]
    return "\n".join(parts)


def write_report_md(report: str, report_dir: str, diff_hash: str = "") -> list[str]:
    """Write latest.md and a dated archive. Returns written paths."""
    root = Path(report_dir)
    root.mkdir(parents=True, exist_ok=True)

    written: list[str] = []
    latest = root / "latest.md"
    latest.write_text(report, encoding="utf-8")
    written.append(str(latest))

    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    short = (diff_hash or "nohash")[:12]
    archive = root / f"{stamp}-{short}.md"
    archive.write_text(report, encoding="utf-8")
    written.append(str(archive))
    return written


def main() -> int:
    raw = sys.argv[1] if len(sys.argv) > 1 else sys.stdin.read()

    demo_mode = os.environ.get("AI_GATE_DEMO", "1") != "0"
    report_dir = os.environ.get("AI_GATE_REPORT_DIR", "").strip()
    diff_hash = os.environ.get("AI_GATE_DIFF_HASH", "").strip()
    branch = os.environ.get("AI_GATE_BRANCH", "").strip()
    cache_hit = os.environ.get("AI_GATE_CACHE_HIT", "0") == "1"

    try:
        data = parse(raw)
    except (json.JSONDecodeError, ValueError, TypeError):
        print(
            f"{YEL}[ai-commit-gate] không parse được output review, bỏ qua{RST}",
            file=sys.stderr,
        )
        snippet = raw.strip().replace("\n", " ")[:200]
        if snippet:
            print(f"{DIM}  raw (rút gọn): {snippet}{RST}", file=sys.stderr)
        if not demo_mode:
            print(
                f"{RED}{BOLD}Commit bị chặn: output review không hợp lệ (chế độ enforce).{RST}"
            )
            return 1
        return 0

    # Persist only after successful parse (shell sets AI_GATE_CACHE_OUT).
    cache_out = os.environ.get("AI_GATE_CACHE_OUT", "").strip()
    if cache_out:
        try:
            with open(cache_out, "w", encoding="utf-8") as f:
                f.write(raw)
        except OSError as e:
            print(
                f"{YEL}[ai-commit-gate] ghi cache thất bại: {e}{RST}",
                file=sys.stderr,
            )

    critical = data.get("critical", [])
    major = data.get("major", [])
    suggestions = data.get("suggestions", [])

    if report_dir:
        try:
            report = build_report_md(
                data,
                demo_mode=demo_mode,
                diff_hash=diff_hash,
                branch=branch,
                cache_hit=cache_hit,
            )
            paths = write_report_md(report, report_dir, diff_hash=diff_hash)
            print(
                f"{DIM}[ai-commit-gate] đã ghi báo cáo: {paths[0]}{RST}",
                file=sys.stderr,
            )
        except OSError as e:
            print(
                f"{YEL}[ai-commit-gate] ghi báo cáo thất bại: {e}{RST}",
                file=sys.stderr,
            )

    if not (critical or major or suggestions):
        print(f"{BOLD}--- AI Commit Quality Gate ---{RST}")
        show([], "NGHIÊM TRỌNG (CRITICAL)", RED, always=True)
        print(f"{DIM}[ai-commit-gate] không có finding{RST}")
        return 0

    print(f"{BOLD}--- AI Commit Quality Gate ---{RST}")
    # Critical luôn hiện; major / suggestions chỉ khi có item.
    show(critical, "NGHIÊM TRỌNG (CRITICAL)", RED, always=True)
    show(major, "QUAN TRỌNG (MAJOR)", YEL)
    show(suggestions, "GỢI Ý (SUGGESTIONS)", DIM)

    # Enforce: chỉ critical chặn. Major/suggestions luôn warn-only.
    if critical and not demo_mode:
        print(
            f"{RED}{BOLD}Commit bị chặn: {len(critical)} nghiêm trọng (critical).{RST}"
        )
        return 1

    if critical and demo_mode:
        print(
            f"{YEL}[chế độ demo] lẽ ra chặn commit ({len(critical)} nghiêm trọng) — chưa enforce{RST}"
        )

    if major and not critical:
        print(
            f"{YEL}[ai-commit-gate] {len(major)} quan trọng (major) — chỉ cảnh báo, không chặn{RST}"
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
