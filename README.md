# claude-plugins

[Mods](https://code.claude.com/docs/en/plugins/mods/overview) and plugins for
Claude Code.

| Name | Kind | What it does |
| --- | --- | --- |
| [bang-run](mods/bang-run) | mod | Adds a ▶ run button under every `! command` Claude suggests. |
| [py-quality](plugins/py-quality) | plugin | Python quality gates on every edit and before Claude finishes. |

## Install

At a Claude Code prompt:

```
/plugin install <name> --marketplace mitja-kleider/claude-plugins
```

Answer `y` to add the marketplace, then pick a scope.

## Adding a mod or plugin

Mods (modules that change Claude Code's interface) go in `mods/<name>/`,
other plugins (hooks, commands, skills) in `plugins/<name>/`. List it in
`.claude-plugin/marketplace.json` and check it with
`claude plugin validate <dir>`, plus `claude plugin test <dir>` for mods.
