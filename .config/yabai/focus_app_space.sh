#!/usr/bin/env bash
# Instant alt-tab across Spaces. Called by yabai's application_activated signal
# (yabairc) only when the scripting addition is loaded and macOS's own
# "switch to a Space with open windows" is off. If the activated app has no
# window on the current Space, jump straight to one with yabai (no animation).
export PATH="/opt/homebrew/bin:$PATH"
pid=${YABAI_PROCESS_ID:?}

# skhd's "new window" binds touch this first: a window is on its way, so stay put.
marker=~/.cache/yabai-new-window
[ -n "$(find "$marker" -mtime -2s 2>/dev/null)" ] && exit 0
# Otherwise jump right away: if the app sees no window on this Space when it handles
# the reopen event (Raycast, Dock click, `open -a`), it creates a new one.

windows=$(yabai -m query --windows) || exit 0
space=$(yabai -m query --spaces --space | jq -r .index)

# Already has a usable window here: nothing to do.
jq -e --argjson pid "$pid" --argjson s "$space" \
  'any(.[]; .pid == $pid and .space == $s and ."is-minimized" == false and ."is-hidden" == false)' \
  <<<"$windows" >/dev/null && exit 0

# query --windows is front-to-back per Space, so the first match is the
# app's most recently used window.
id=$(jq -r --argjson pid "$pid" \
  'first(.[] | select(.pid == $pid and ."is-minimized" == false and ."is-hidden" == false and ."is-sticky" == false) | .id) // empty' \
  <<<"$windows")
[ -n "$id" ] && yabai -m window --focus "$id"
