# Vibe Scrolling

<p align="center">
  <img src="assets/banner.png" alt="A developer leans back with their feet on the desk, watching a vertical video on one monitor while the other monitor shows code generating by itself" width="800">
</p>

> You vibe code. Claude does the work. Why are you still staring at the terminal?

**vibe-scrolling** is a Claude Code plugin that opens Instagram Reels every time you send a prompt, then drags you back to your terminal when Claude is done.

It's a joke. It works, though.

## What it actually does

So you know exactly what you're installing:

- **When you send a prompt** (`UserPromptSubmit` hook), it opens `https://www.instagram.com/reels/` in your browser. On macOS it first looks for a Reels tab that's already open and switches to it instead of opening another one.
- **When Claude finishes** (`Stop` hook, macOS only), it switches back to the app you run Claude Code in, but only if you're still in the browser. If you've wandered off to Slack, it leaves you alone.
- It prints a sarcastic one-liner in Claude Code each time.
- **Nothing else.** It sends no data anywhere and installs no browser extension. Everything is in two small scripts in [`scripts/`](scripts/).

## Install

Inside Claude Code:

```
/plugin marketplace add scaltunsoy/vibe-scrolling
/plugin install vibe-scrolling@vibe-scrolling
```

Restart Claude Code and send any prompt. Enjoy your break.

To try a local checkout without installing:

```bash
claude --plugin-dir /path/to/vibe-scrolling
```

## Configuration

Use the built-in command:

```
/vibe-scrolling:config                  # show current settings
/vibe-scrolling:config off              # pause it (on to resume)
/vibe-scrolling:config browser chrome   # pick a browser
/vibe-scrolling:config cooldown 300     # at most once every 5 minutes
```

Settings live in `~/.config/vibe-scrolling/config` (see [`config.example`](config.example)). Every key can also be set with an environment variable, e.g. `VIBE_SCROLLING_BROWSER=firefox`.

| key | default | meaning |
|---|---|---|
| `enabled` | `true` | Master switch. You can also disable the plugin in `/plugin`. |
| `browser` | `default` | `default`, `safari`, `chrome`, `brave`, `edge`, `arc`, `vivaldi`, `chromium`, `firefox`, or any app name or command |
| `url` | `https://www.instagram.com/reels/` | What to open. TikTok people, this is your line. |
| `cooldown` | `0` | Minimum seconds between openings |
| `return` | `true` | macOS: switch back to the terminal when Claude is done |

## Platform support

| | Opens Reels | Reuses an open tab | Brings you back when Claude is done |
|---|---|---|---|
| macOS + Safari, Chrome, Brave, Edge, Vivaldi, Chromium | ✅ | ✅ | ✅ |
| macOS + Arc | ✅ | 🤷 probably | ✅ |
| macOS + Firefox | ✅ | ❌ new tab each time (use `cooldown`) | ✅ |
| Linux | ✅ | ❌ | ❌ |
| Windows (Git Bash) | ✅ | ❌ | ❌ |

### macOS permissions

The first time it looks for an existing tab, macOS asks whether your terminal may control your browser. Click **OK** to allow it. If you click **Don't Allow**, the plugin opens a new tab each time instead. You can change this later in System Settings → Privacy & Security → Automation.

### Known limits

- "Back to the terminal" brings your terminal *app* to the front, not a specific window or tab.
- If you interrupt Claude (Esc), the Stop hook doesn't fire, so you stay where you are. Consider it a reward.

## Debugging

```bash
echo '{"session_id":"test"}' | VIBE_SCROLLING_DRY_RUN=1 bash scripts/vibe-scrolling.sh prompt
```

Dry run explains every decision on stderr and opens nothing.

## Uninstall

`/plugin uninstall vibe-scrolling`, then go back to being productive. Or try to.

## License

[MIT](LICENSE)
