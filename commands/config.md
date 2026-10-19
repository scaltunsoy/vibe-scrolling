---
description: Show or change vibe-scrolling settings (on/off, browser, cooldown, return)
argument-hint: "[show | on | off | <key> <value>]"
allowed-tools: Read, Write, Edit
---

Manage the settings file of the vibe-scrolling plugin. Arguments: `$ARGUMENTS`

Settings file: `$XDG_CONFIG_HOME/vibe-scrolling/config`, which is `~/.config/vibe-scrolling/config` when `XDG_CONFIG_HOME` is unset. Use the absolute path. Format: one `key=value` per line, `#` starts a comment line.

| key | default | allowed values |
|---|---|---|
| `enabled` | `true` | `true` / `false` |
| `browser` | `default` | `default`, `safari`, `chrome`, `brave`, `edge`, `arc`, `vivaldi`, `chromium`, `firefox`, or any installed app name |
| `url` | `https://www.instagram.com/reels/` | any http(s) URL |
| `cooldown` | `0` | whole seconds between openings, `0` = every prompt |
| `return` | `true` | `true` / `false`: macOS only, switch back to the terminal when Claude finishes |

Do exactly this:

1. Read the settings file. If it does not exist, treat every key as its default.
2. Interpret the arguments:
   - empty or `show`: list the effective value of every key in a compact table. Note that `VIBE_SCROLLING_<KEY>` environment variables override the file.
   - `on` / `off`: set `enabled` to `true` / `false`.
   - `<key> <value>`: set that key. If the key or value is not allowed by the table, say what is allowed and change nothing.
   - `reset`: write the file with every key at its default.
3. When changing something, create the file if needed (one `key=value` line per key from the table, defaults for the rest). Otherwise edit only the affected line and keep everything else.
4. Reply in one short line confirming the change. A bit of sarcasm is welcome. Do nothing else.
