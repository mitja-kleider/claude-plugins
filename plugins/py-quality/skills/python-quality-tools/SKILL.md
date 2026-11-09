---
name: python-quality-tools
description: Reference of FOSS tools for judging Python complexity, error risk, and test quality (ruff, ty/pyright/pyrefly/mypy, radon, xenon, complexipy, wily, bandit, semgrep, vulture, deptry, pip-audit, coverage.py, diff-cover, mutmut, cosmic-ray, hypothesis, code-maat). Use when choosing, configuring, or interpreting code-quality tooling for a Python project, setting up CI quality gates, or deciding how to measure test strength or find risky code.
---

# Python quality tooling reference

Prefer running tools via `uvx <tool>` so nothing is added to the project unless the user asks.
Prefer JSON output and diff-scoped checks; summarize rather than pasting raw output.

## Complexity
- **ruff** rules `C901` (McCabe) and `PLR0911/0912/0913/0915` (returns/branches/args/statements). Cheapest gate.
- **radon**: cyclomatic complexity, Maintainability Index, Halstead (`radon cc -s -j`, `radon mi -j`). Ranks A–F.
- **xenon**: radon with thresholds and a failing exit code (`xenon --max-absolute B --max-modules A --max-average A src`).
- **complexipy**: cognitive complexity (closer to "hard for humans to read"), Rust, fast.
- **lizard**: language-agnostic alternative.
- **wily**: tracks metrics over git history (is it getting worse?).

## Error risk (static analysis)
- **ruff**: linting (replaces flake8, isort, pyupgrade, much of pylint).
- **Type checkers**: mypy and pyright (mature); pyrefly (Meta) and ty (Astral, beta) are fast Rust-based newcomers. Biggest single bug-catcher.
- **bandit**: security smells. **Semgrep CE**: custom pattern rules for project conventions.
- **vulture**: dead code. **deptry**: unused/missing dependencies. **pip-audit**: known CVEs.
- **pylint**: some deeper checks ruff lacks; slow.

## Test quality
- **coverage.py / pytest-cov**: always use branch coverage (`--cov-branch`). Coverage = executed, not verified.
- **diff-cover**: coverage of changed lines only vs a base branch; `diff-quality` does the same for lint.
- **Mutation testing** — the real measure of test strength: **mutmut** (easiest), **cosmic-ray** (configurable, distributed). Slow: run on specific modules, nightly, or on request. Surviving mutants = concrete missing test cases.
- **hypothesis**: property-based tests for edge cases.
- **pytest-randomly**: shuffled order exposes inter-test dependencies/flakiness.

## Risk hotspots
- Defects concentrate where **complexity × change frequency** is high.
- **code-maat** mines git history for hotspots and change coupling. Quick version: commit counts per file
  (`git log --since=12.months --format= --name-only -- '*.py' | sort | uniq -c | sort -rn`) joined with radon scores.
- **SonarQube Community Edition**: aggregate dashboard, heavier to run.

## Pitfalls
- Metric gaming: suppressions (`# type: ignore`, `# noqa`, `# pragma: no cover`), weakened asserts,
  deleted/skipped tests. Forbid blanket ignores (ruff `PGH003`, `PGH004`); mutation testing is hard to fake.
- Gate on the diff, not the whole repo, in legacy codebases.
