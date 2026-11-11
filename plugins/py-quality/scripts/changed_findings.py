#!/usr/bin/env -S uv run --quiet --no-active --script
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Keep the findings on lines changed since HEAD, read from stdin.

Each finding is one `path:line:col: message` line, as ruff's and ty's concise
output print them. A finding about a whole function (complexity, too many
branches, ...) is reported on its `def` line, so it counts when any line of
the function changed. A file outside git, untracked or without a HEAD counts
as changed throughout. Lines that aren't findings, such as summaries, are
dropped.
"""

import ast
import re
import subprocess
import sys
from functools import cache
from pathlib import Path

FINDING = re.compile(r"^(?P<path>.+?):(?P<line>\d+):\d+: (?P<code>\S+)")
HUNK = re.compile(r"^@@ -\S+ \+(?P<start>\d+)(?:,(?P<count>\d+))? @@")
FUNCTION_CODES = {"C901", "PLR0911", "PLR0912", "PLR0913", "PLR0915"}


def git(path: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(path.parent), *args],
        capture_output=True,
        text=True,
        check=False,
    )


@cache
def changed_lines(path: Path) -> frozenset[int] | None:
    """The lines of `path` added or edited since HEAD, with the line next to
    each deletion; None when every line counts as changed."""
    if git(path, "ls-files", "--error-unmatch", "--", path.name).returncode:
        return None
    diff = git(path, "diff", "-U0", "--no-color", "--no-ext-diff", "HEAD", "--", path.name)
    if diff.returncode:
        return None
    lines: set[int] = set()
    for hunk in map(HUNK.match, diff.stdout.splitlines()):
        if not hunk:
            continue
        start, count = int(hunk["start"]), int(hunk["count"] or 1)
        lines.update(range(start, start + count) if count else (start, start + 1))
    return frozenset(lines)


@cache
def function_spans(path: Path) -> dict[int, range]:
    """The lines each function in `path` spans, by its `def` line."""
    try:
        tree = ast.parse(path.read_text())
    except (OSError, SyntaxError, ValueError):
        return {}
    return {
        node.lineno: range(node.lineno, (node.end_lineno or node.lineno) + 1)
        for node in ast.walk(tree)
        if isinstance(node, ast.FunctionDef | ast.AsyncFunctionDef)
    }


def is_changed(path: Path, line: int, code: str) -> bool:
    changed = changed_lines(path)
    if changed is None:
        return True
    span = function_spans(path).get(line) if code in FUNCTION_CODES else None
    return any(n in changed for n in span or (line,))


def main() -> None:
    for text in sys.stdin:
        finding = FINDING.match(text)
        if not finding:
            continue
        path = Path(finding["path"]).resolve()
        if is_changed(path, int(finding["line"]), finding["code"]):
            sys.stdout.write(text)


if __name__ == "__main__":
    main()
