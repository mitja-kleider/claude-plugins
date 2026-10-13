# claude-mods

Mods for [Claude Code](https://code.claude.com/docs/en/plugins/mods/overview).

| Mod | What it does |
| --- | --- |
| [bang-run](mods/bang-run) | Adds a ▶ run button under every `! command` Claude suggests. |

## Install

At a Claude Code prompt:

```
/plugin install <mod> --marketplace mitja-kleider/claude-mods
```

Answer `y` to add the marketplace, then pick a scope.

## Adding a mod

Put it in `mods/<name>/` and list it in `.claude-plugin/marketplace.json`.
Check it with `claude plugin validate mods/<name>` and
`claude plugin test mods/<name>`.
