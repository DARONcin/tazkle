#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[4]
LINK = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
SKIP_PARTS = {".git", ".next", ".vinext", "dist", "node_modules"}
errors: list[str] = []

for document in sorted(ROOT.rglob("*.md")):
    if SKIP_PARTS.intersection(document.parts):
        continue
    text = document.read_text(encoding="utf-8")
    for target in LINK.findall(text):
        target = target.strip().strip("<>")
        if not target or target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        path_text = unquote(target.split("#", 1)[0])
        if not path_text:
            continue
        resolved = (document.parent / path_text).resolve()
        if not resolved.exists():
            errors.append(f"{document.relative_to(ROOT)} -> {target}")

if errors:
    print("markdown-links: broken relative links", file=sys.stderr)
    for error in errors:
        print(error, file=sys.stderr)
    raise SystemExit(1)

print("markdown-links: passed")
