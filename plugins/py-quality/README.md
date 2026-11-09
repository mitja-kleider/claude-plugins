# py-quality

Python quality gates for Claude Code:

- **SessionStart**: injects the quality rules from `RULES.md` into context
  (Python projects only).
- **PostToolUse** (every `.py` edit): ruff lint, complexity and
  blanket-suppression checks, plus a ty type check.
- **Stop**: flags newly added suppressions, skips and deleted tests, runs
  pytest with branch coverage, and checks coverage of changed lines with
  diff-cover.
- **`/py-quality`**: an on-demand report (radon, hotspots, vulture, bandit,
  mutation testing).
- **Skill `python-quality-tools`**: a reference of FOSS tools and when to use
  them.

## Requirements

`jq`, `uv` and `git` on `PATH`. Optionally `uv tool install ruff ty`;
otherwise `uvx` is used.

## Install

```
/plugin install py-quality --marketplace mitja-kleider/claude-plugins
```

## Configure

Environment variables:

- `PY_GATE_MAX_COMPLEXITY` (default 10)
- `PY_GATE_MIN_DIFF_COVERAGE` (default 80)
- `PY_GATE_TYPECHECK=0` skips type checking

Opt a single repo out with `touch .claude/no-py-gate`.
