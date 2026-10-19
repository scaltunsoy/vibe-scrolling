#!/usr/bin/env bash
# vibe-scrolling: because your prompt can definitely wait.
#
# Usage: vibe-scrolling.sh prompt|stop   (Claude Code hook JSON arrives on stdin)
#   prompt  UserPromptSubmit: open (or focus) Reels in the browser
#   stop    Stop: Claude is done, bring the user back to the terminal (macOS)
#
# Set VIBE_SCROLLING_DRY_RUN=1 to log decisions to stderr instead of opening anything.

set -u

mode="${1:-prompt}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_file="${VIBE_SCROLLING_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/vibe-scrolling/config}"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/vibe-scrolling"
dry_run="${VIBE_SCROLLING_DRY_RUN:-0}"

# Defaults
enabled=true
browser=default
url=https://www.instagram.com/reels/
cooldown=0
return_to=true

say() { [ "$dry_run" = 1 ] && printf 'vibe-scrolling: %s\n' "$*" >&2; return 0; }

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

is_true() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    true|1|yes|on) return 0 ;;
  esac
  return 1
}

set_opt() {
  case "$1" in
    enabled) enabled="$2" ;;
    browser) browser="$2" ;;
    url) url="$2" ;;
    cooldown) cooldown="$2" ;;
    return) return_to="$2" ;;
  esac
}

load_config() {
  local line key var val
  if [ -f "$config_file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      line="$(trim "$line")"
      case "$line" in
        ''|\#*) continue ;;
        *=*) set_opt "$(trim "${line%%=*}")" "$(trim "${line#*=}")" ;;
      esac
    done < "$config_file"
  fi

  for key in enabled browser url cooldown return; do
    var="VIBE_SCROLLING_$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')"
    val="${!var:-}"
    [ -n "$val" ] && set_opt "$key" "$val"
  done

  case "$cooldown" in ''|*[!0-9]*) cooldown=0 ;; esac
  [ -n "$browser" ] || browser=default
  [ -n "$url" ] || url=https://www.instagram.com/reels/
}

# Run a command fully detached so the hook returns immediately.
run_detached() {
  if [ "$dry_run" = 1 ]; then
    say "would run: $*"
    return
  fi
  nohup "$@" </dev/null >/dev/null 2>&1 &
}

pick() { local lines=("$@"); printf '%s' "${lines[RANDOM % ${#lines[@]}]}"; }

# Messages must not contain double quotes or backslashes: they go into JSON as-is.
emit() { printf '{"systemMessage":"%s"}\n' "$1"; }

# Bundle id of the app running this Claude Code session (Terminal, iTerm2, VS Code, ...).
terminal_bundle() {
  if [ -n "${__CFBundleIdentifier:-}" ]; then
    printf '%s' "$__CFBundleIdentifier"
    return
  fi
  case "${TERM_PROGRAM:-}" in
    Apple_Terminal) printf 'com.apple.Terminal' ;;
    iTerm.app) printf 'com.googlecode.iterm2' ;;
    ghostty) printf 'com.mitchellh.ghostty' ;;
    WezTerm) printf 'com.github.wez.wezterm' ;;
    WarpTerminal) printf 'dev.warp.Warp-Stable' ;;
    vscode) printf 'com.microsoft.VSCode' ;;
  esac
}

frontmost_bundle() {
  osascript -l JavaScript -e 'ObjC.import("AppKit"); ObjC.unwrap($.NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier)' 2>/dev/null
}

on_prompt() {
  local now last stamp term os
  rm -f "$marker"

  if ! is_true "$enabled"; then say "disabled, doing nothing"; return; fi

  now="$(date +%s)"
  stamp="$cache_dir/last_opened"
  if [ "$cooldown" -gt 0 ] && [ -f "$stamp" ]; then
    last="$(cat "$stamp" 2>/dev/null)"
    case "$last" in ''|*[!0-9]*) last=0 ;; esac
    if [ $((now - last)) -lt "$cooldown" ]; then
      say "cooldown active ($((now - last))s of ${cooldown}s)"
      return
    fi
  fi
  mkdir -p "$cache_dir"
  printf '%s\n' "$now" > "$stamp"

  os="$(uname -s)"
  case "$os" in
    Darwin)
      term=""
      is_true "$return_to" && term="$(terminal_bundle)"
      say "terminal bundle: ${term:-<none, will not return>}"
      if [ "$dry_run" = 1 ]; then
        say "$(VIBE_SCROLLING_DRY_RUN=1 osascript -l JavaScript "$here/focus-or-open.js" "$browser" "$url" "$marker" "$term" 2>&1)"
      else
        run_detached osascript -l JavaScript "$here/focus-or-open.js" "$browser" "$url" "$marker" "$term"
      fi
      ;;
    Linux)
      if [ "$browser" != default ] && command -v "$browser" >/dev/null 2>&1; then
        run_detached "$browser" "$url"
      else
        run_detached xdg-open "$url"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      case "$browser" in
        default) run_detached cmd.exe //c start "" "$url" ;;
        edge) run_detached cmd.exe //c start "" msedge "$url" ;;
        *) run_detached cmd.exe //c start "" "$browser" "$url" ;;
      esac
      ;;
    *)
      say "unsupported OS: $os"
      return
      ;;
  esac

  local msg
  msg="$(pick \
    "Reels opened. Claude will handle the thinking." \
    "Your prompt is in good hands. Your attention span is not." \
    "Deep work mode: activated. Reels: also activated." \
    "Claude is working. You deserve a break. You always do." \
    "Just one reel. Sure." \
    "Outsourcing your brain, one prompt at a time.")"
  emit "$msg"
}

on_stop() {
  local term browser_id front msg
  [ -f "$marker" ] || { say "no marker, Reels was not opened this turn"; return; }
  term="$(sed -n 1p "$marker")"
  browser_id="$(sed -n 2p "$marker")"
  rm -f "$marker"

  is_true "$return_to" || { say "return disabled"; return; }
  [ "$(uname -s)" = Darwin ] || return
  [ -n "$term" ] && [ -n "$browser_id" ] || { say "incomplete marker"; return; }

  front="$(frontmost_bundle)"
  if [ "$front" != "$browser_id" ]; then
    say "frontmost app is ${front:-unknown}, not $browser_id: leaving the user alone"
    return
  fi

  run_detached open -b "$term"
  msg="$(pick \
    "Break is over. Claude finished while you were scrolling." \
    "Welcome back. Claude did the work, you did the scrolling." \
    "Claude is done. Please pretend you were reading along." \
    "Back to work. The reel will still be there. Unfortunately.")"
  emit "$msg"
}

input=""
[ -t 0 ] || input="$(cat 2>/dev/null)"
session_id="$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1 | tr -cd 'A-Za-z0-9_-')"
marker="$cache_dir/away-${session_id:-default}"

load_config
case "$mode" in
  prompt) on_prompt ;;
  stop) on_stop ;;
  *) say "unknown mode: $mode" ;;
esac
exit 0
