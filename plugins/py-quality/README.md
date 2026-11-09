# py-quality

Python quality gates for Claude Code:

- **SessionStart**: injects the quality rules from `RULES.md` into context
  (Python projects only).
- **PostToolUse** (every `.py` edit): ruff lint, complexity and
  blanket-suppression checks, plus a ty type check.
- **Stop**: when `.py` files have uncommitted changes, flags newly added
  suppressions, skips and deleted tests, runs pytest with branch coverage,
  and checks coverage of the uncommitted changes with diff-cover. Committed
  code is not checked.
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

## Result cache

After the Stop gate runs, pass or fail, it records a fingerprint in
`.git/py-gate/` (one file per project directory). The next Stop skips the
gate if nothing that decides its result has changed: the working tree
(including untracked, non-ignored files), `HEAD`, the coverage threshold and
the test runner. So a failure is reported once, not on every Stop until it is
fixed. Delete `.git/py-gate/` to force a rerun, for example after changing
something outside the repo that the tests depend on.
