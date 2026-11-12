#!/usr/bin/env python3
"""Checks that every relative link and image in the Markdown files points at something.

Looks at Markdown links and images (`[text](target)`, `![alt](target)`) and at the
`href` and `src` of the HTML used in the README header. External URLs, `mailto:` and
links to a heading on the same page are skipped, and so is anything inside a code block.
A link that leaves the repository or names a path that does not exist is an error.

Usage: check-links.py [repository root]      (default: the parent of scripts/)
"""
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent).resolve()
MARKDOWN = re.compile(r"!?\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
HTML = re.compile(r"\b(?:href|src)\s*=\s*[\"']([^\"']+)[\"']", re.IGNORECASE)
FENCE = re.compile(r"^(```|~~~).*?^\1[^\n]*$", re.MULTILINE | re.DOTALL)
INLINE_CODE = re.compile(r"`[^`\n]*`")

errors = []
checked = 0
for page in sorted(ROOT.rglob("*.md")):
    if ".git" in page.relative_to(ROOT).parts:
        continue
    text = INLINE_CODE.sub("", FENCE.sub("", page.read_text(encoding="utf-8")))
    for target in MARKDOWN.findall(text) + HTML.findall(text):
        if re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target) or target.startswith("#"):
            continue
        checked += 1
        path = (page.parent / target.split("#", 1)[0].split("?", 1)[0]).resolve()
        where = page.relative_to(ROOT)
        if ROOT not in path.parents and path != ROOT:
            errors.append(f"{where}: {target} points outside the repository")
        elif not path.exists():
            errors.append(f"{where}: {target} does not exist")

for line in errors:
    print(line, file=sys.stderr)
print(f"{checked} relative links and images checked, {len(errors)} broken")
sys.exit(1 if errors else 0)
