#!/usr/bin/env bash
# Minimized windows don't keep their Space. Called by yabai's window_minimized / window_deminimized
# signals (yabairc) with min|restore (window_destroyed: gone). While minimized, a window is made sticky (on every Space), so
# restoring it (Raycast, a bind, the Dock, alt-tab) brings it up where you are instead of macOS
# switching back to the Space it was minimized on. On restore it's un-stuck, which leaves it tiled
# on the current Space. Only windows stuck here are un-stuck (a marker per window id).
export PATH="/opt/homebrew/bin:$PATH"
id=${YABAI_WINDOW_ID:?}
dir=~/.cache/yabai-min-sticky
case $1 in
	min)
		[ "$(yabai -m query --windows --window "$id" | jq '."is-sticky"')" = false ] || exit 0
		mkdir -p "$dir" && touch "$dir/$id"
		yabai -m window "$id" --toggle sticky
		;;
	restore)
		[ -e "$dir/$id" ] || exit 0
		rm -f "$dir/$id"
		yabai -m window "$id" --toggle sticky
		yabai -m window --focus "$id"
		;;
	gone) rm -f "$dir/$id" ;; # closed/quit while minimized: drop the marker so a reused id isn't affected
esac
