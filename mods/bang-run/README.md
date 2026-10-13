# bang-run

Adds a ▶ run button under every `! command` in Claude's replies, inline
(`` `! cmd` ``) or as a `! ` line in a code block.

A press runs the command through `$SHELL -lc` (ten minutes at most) and
submits the command and its output as your prompt, so Claude sees it and
replies.

Mods cannot enter the prompt's `!` bash mode, so the command gets no
terminal: interactive commands (`gcloud auth login`, `tsh login`) need to
be typed with `!` yourself.

```
/plugin install bang-run --marketplace mitja-kleider/claude-mods
```
