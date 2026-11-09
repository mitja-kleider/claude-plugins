## Python code quality (global)

Automated hooks check every Python edit (ruff lint + complexity, ty type check) and,
before you finish, run tests and check branch coverage of changed lines.
When a hook reports findings:

- Fix the cause. Do not add `# type: ignore`, `# noqa`, `# pragma: no cover`, or skip
  markers to silence findings. If a suppression is genuinely right, use the narrowest
  form (specific error code) and explain why in a comment and in your summary.
- Never delete, weaken, or skip existing tests to make a check pass without asking me first.
- Keep functions under cyclomatic complexity 10; prefer extracting well-named helpers
  over clever compression.
- New or changed behaviour needs tests that would fail if the behaviour broke —
  assert on outcomes, not just that code runs.
- If a project has no tests or no .venv/uv setup, say so instead of inventing a setup.
- Use the `/py-quality` command for a deeper, slower analysis (hotspots, dead code, mutation testing).
- For background on available tools and when to use which, use the `python-quality-tools` skill.
