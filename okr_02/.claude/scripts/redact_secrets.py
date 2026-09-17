#!/usr/bin/env python3
"""Redact likely secrets from a git diff before sending to an LLM."""
from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import List, Sequence, Tuple

Pattern = Tuple[re.Pattern[str], str]

# Assignment-style name fragments (matched as substring of KEY in KEY=value).
_ASSIGN_KEY_PREFIXES = (
    r"password|passwd|pwd|secret|token|"
    r"api[_-]?key|access[_-]?key|private[_-]?key|"
    r"client[_-]?secret|app[_-]?secret|consumer[_-]?secret|"
    r"auth[_-]?token|refresh[_-]?token|id[_-]?token|session[_-]?secret|"
    r"webhook[_-]?secret|signing[_-]?secret|"
    r"jwt[_-]?secret|encryption[_-]?key|"
    r"aws[_-]?(?:access[_-]?key[_-]?id|secret[_-]?access[_-]?key|session[_-]?token)|"
    r"openai[_-]?api[_-]?key|anthropic[_-]?api[_-]?key|"
    r"claude[_-]?api[_-]?key|gemini[_-]?api[_-]?key|google[_-]?api[_-]?key|"
    r"azure[_-]?(?:openai[_-]?)?(?:key|api[_-]?key)|"
    r"huggingface[_-]?(?:token|api[_-]?key)|"
    r"cohere[_-]?api[_-]?key|groq[_-]?api[_-]?key|replicate[_-]?api[_-]?key|"
    r"xai[_-]?api[_-]?key|perplexity[_-]?api[_-]?key|"
    r"stripe[_-]?(?:secret|api)[_-]?key|sendgrid[_-]?api[_-]?key|"
    r"github[_-]?(?:token|pat)|slack[_-]?(?:token|bot[_-]?token)|"
    r"npm[_-]?token|discord[_-]?token|"
    r"smtp[_-]?password|mail[_-]?password|basic[_-]?password|"
    r"credentials?|"
    r"database_url|db_url|redis_url|broker_url"
)

_REDACT_VALUE = "[REDACTED PRIVATE KEY]"
_ENV_KEY_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def _repo_root() -> Path:
    # .claude/scripts/redact_secrets.py → repo root
    return Path(__file__).resolve().parents[2]


def _parse_env_key_names(text: str) -> List[str]:
    """Extract KEY names from dotenv-style content (values ignored)."""
    names: List[str] = []
    seen: set[str] = set()
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.lower().startswith("export "):
            line = line[7:].lstrip()
        if "=" not in line:
            continue
        key = line.split("=", 1)[0].strip()
        if not _ENV_KEY_RE.match(key):
            continue
        upper = key.upper()
        if upper in seen:
            continue
        seen.add(upper)
        names.append(key)
    return names


def load_env_key_names(root: Path | None = None) -> List[str]:
    """Load variable names from `.env` then `.env-sample` (names only)."""
    base = root if root is not None else _repo_root()
    names: List[str] = []
    seen: set[str] = set()
    for fname in (".env", ".env-sample"):
        path = base / fname
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for key in _parse_env_key_names(text):
            upper = key.upper()
            if upper in seen:
                continue
            seen.add(upper)
            names.append(key)
    return names


def _exact_env_key_alternation(env_names: Sequence[str]) -> str | None:
    """Case-sensitive exact KEY names from .env (longest first)."""
    names = sorted({n for n in env_names if n}, key=len, reverse=True)
    if not names:
        return None
    return "|".join(re.escape(n) for n in names)


def build_patterns(env_names: Sequence[str] | None = None) -> List[Pattern]:
    """Compile redaction patterns; assignment keys use env names + prefixes."""
    names = list(env_names) if env_names is not None else load_env_key_names()
    exact_keys = _exact_env_key_alternation(names)

    patterns: List[Pattern] = []
    # Exact .env KEY names — case-sensitive so Python locals
    # (my_admin_web_server = ...) are not treated as MY_ADMIN_WEB_SERVER.
    if exact_keys:
        patterns.append(
            (
                re.compile(
                    rf"(?<![A-Za-z0-9_])((?:{exact_keys})\s*[=:]\s*)"
                    rf"([\"']?)([^\s\"']+)(\2)"
                ),
                rf"\1\2{_REDACT_VALUE}\4",
            )
        )
    # Secret-ish name fragments (password, token, api_key, …)
    patterns.append(
        (
            re.compile(
                rf"(?i)((?:{_ASSIGN_KEY_PREFIXES})\s*[=:]\s*)"
                rf"([\"']?)([^\s\"']+)(\2)"
            ),
            rf"\1\2{_REDACT_VALUE}\4",
        )
    )
    patterns.extend(
        [
        # PEM / OpenSSH private keys
        (
            re.compile(
                r"-----BEGIN (?:RSA |OPENSSH |EC |DSA |ENCRYPTED )?PRIVATE KEY-----"
                r"[\s\S]*?"
                r"-----END (?:RSA |OPENSSH |EC |DSA |ENCRYPTED )?PRIVATE KEY-----"
            ),
            _REDACT_VALUE,
        ),
        # --- AI / LLM provider tokens (value-shape) ---
        (re.compile(r"\b(sk-(?:proj|svcacct)-[A-Za-z0-9_-]{20,})\b"), _REDACT_VALUE),
        (re.compile(r"\b(sk-[A-Za-z0-9_-]{20,})\b"), _REDACT_VALUE),
        (re.compile(r"\b(sk-ant-[A-Za-z0-9_-]{20,})\b"), _REDACT_VALUE),
        (re.compile(r"\b(AIza[0-9A-Za-z_-]{35})\b"), _REDACT_VALUE),
        (re.compile(r"\b(hf_[A-Za-z0-9]{20,})\b"), _REDACT_VALUE),
        (re.compile(r"\b(gsk_[A-Za-z0-9]{20,})\b"), _REDACT_VALUE),
        (re.compile(r"\b(r8_[A-Za-z0-9]{20,})\b"), _REDACT_VALUE),
        (re.compile(r"\b(xai-[A-Za-z0-9]{20,})\b"), _REDACT_VALUE),
        (re.compile(r"\b(pplx-[A-Za-z0-9]{20,})\b"), _REDACT_VALUE),
        # --- Cloud / infra ---
        (re.compile(r"\b(AKIA[0-9A-Z]{16})\b"), _REDACT_VALUE),
        (re.compile(r"\b(ASIA[0-9A-Z]{16})\b"), _REDACT_VALUE),
        (
            re.compile(r"(?i)(AccountKey\s*=\s*)([A-Za-z0-9+/=]{20,})"),
            rf"\1{_REDACT_VALUE}",
        ),
        (
            re.compile(r"(?i)([?&]sig=)([A-Za-z0-9%+/=]{16,})"),
            rf"\1{_REDACT_VALUE}",
        ),
        # --- Dev platform tokens ---
        (
            re.compile(
                r"\b(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b"
            ),
            _REDACT_VALUE,
        ),
        (re.compile(r"\b(xox[baprs]-[A-Za-z0-9-]{10,})\b"), _REDACT_VALUE),
        (
            re.compile(r"\b((?:sk|rk|pk)_(?:live|test)_[A-Za-z0-9]{20,})\b"),
            _REDACT_VALUE,
        ),
        (re.compile(r"\b(SG\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,})\b"), _REDACT_VALUE),
        (re.compile(r"\b(npm_[A-Za-z0-9]{36,})\b"), _REDACT_VALUE),
        # --- Connection strings / auth headers ---
        (
            re.compile(
                r"(?i)\b((?:mysql|postgresql|postgres|mongodb|redis|amqp|https?)://)"
                r"([^:@/\s]+):([^@/\s]+)@"
            ),
            rf"\1\2:{_REDACT_VALUE}@",
        ),
        (re.compile(r"(?i)(Bearer\s+)([A-Za-z0-9\-._~+/]+=*)"), rf"\1{_REDACT_VALUE}"),
        (
            re.compile(
                r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"
            ),
            _REDACT_VALUE,
        ),
        ]
    )
    return patterns


# Default patterns (env keys loaded at import from repo .env / .env-sample).
PATTERNS: List[Pattern] = build_patterns()


def redact(text: str, patterns: Sequence[Pattern] | None = None) -> tuple[str, int]:
    """Return (redacted_text, hit_count)."""
    use = list(patterns) if patterns is not None else PATTERNS
    redacted = text
    hits = 0
    for cre, repl in use:
        redacted, n = cre.subn(repl, redacted)
        hits += n
    return redacted, hits


def resolve_input_path(raw: str) -> Path:
    """Resolve file path from cwd, repo root, or after stripping leading ``..``."""
    root = _repo_root()
    given = Path(raw)
    candidates: List[Path] = []
    if given.is_absolute():
        candidates.append(given)
    else:
        candidates.append(Path.cwd() / given)
        candidates.append(root / given)
        parts = list(given.parts)
        while parts and parts[0] == "..":
            parts = parts[1:]
        if parts:
            candidates.append(root.joinpath(*parts))
        # Common: path mentions src/... somewhere
        norm = raw.replace("\\", "/")
        marker = "src/"
        idx = norm.find(marker)
        if idx >= 0:
            candidates.append(root / norm[idx:])

    tried: List[str] = []
    for cand in candidates:
        tried.append(str(cand))
        if cand.is_file():
            return cand.resolve()
    raise FileNotFoundError(
        f"No such file: {raw!r} (tried: {', '.join(dict.fromkeys(tried))})"
    )


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: redact_secrets.py <diff-or-source-file>", file=sys.stderr)
        return 2
    try:
        path = resolve_input_path(sys.argv[1])
    except FileNotFoundError as e:
        print(f"[ai-commit-gate] {e}", file=sys.stderr)
        return 2
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        text = f.read()
    # Rebuild so a fresh .env on disk is picked up each run.
    patterns = build_patterns(load_env_key_names())
    redacted, hits = redact(text, patterns)
    sys.stdout.write(redacted)
    if hits:
        print(
            f"[ai-commit-gate] redacted {hits} likely secret(s) from diff before review",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
