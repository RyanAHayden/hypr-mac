#!/usr/bin/env bash
# Workspace bar like Omarchy's Waybar: 1-5 always, higher Spaces when occupied or focused.
# The row is drawn as an image by ~/.local/bin/ws-render (source in ~/.local/src/ws-render.swift).
# A plain (non-streamable) plugin: yabai signals (yabairc) ask SwiftBar to rerun it on every Space or
# window change, plus every 5s for window counts. Streamable plugins briefly go empty when SwiftBar
# starts, which hides the item and makes macOS forget its menu bar position (swiftbar/SwiftBar#458).
# <swiftbar.hideAbout>true</swiftbar.hideAbout><swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated><swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
export PATH="/opt/homebrew/bin:$PATH"

render() {
	local spaces
	spaces=$(yabai -m query --spaces 2>/dev/null) || return 1
	# Only count real windows: a Space's window list also holds sticky windows (on every Space, e.g.
	# minimized ones, see minimize_sticky.sh) and minimized/hidden ones, which would mark every
	# Space occupied and widen the bar into the notch.
	local real
	real=$(yabai -m query --windows 2>/dev/null |
		jq -c '[ .[] | select(."is-sticky" == false and ."is-minimized" == false and ."is-hidden" == false) | .id ]') || real='[]'
	# Space 11 is workspace "0" (the ~ key, left of 1): label it 0 and draw it first
	spaces=$(jq --argjson real "$real" '[ .[] | .windows |= map(select(. as $w | $real | index($w)))
		| .name = (if .index == 11 then "0" else (.index | tostring) end) ]
		| sort_by(if .index == 11 then 0 else .index end)' <<<"$spaces")
	local args
	args=$(jq -r '[ .[] | select(.index <= 5 or ."has-focus" or (.windows | length) > 0)
		| "\(.name):\(if ."has-focus" then "a" elif (.windows | length) > 0 then "o" else "e" end)" ] | join(" ")' <<<"$spaces")
	# shellcheck disable=SC2086
	echo "| image=$("$HOME/.local/bin/ws-render" $args)"
	echo "---"
	jq -r --arg ws "$HOME/.local/bin/ws" '.[] |
		"\(if ."has-focus" then "• " else "" end)\(.name)\(if (.windows|length) > 0 then "  (\(.windows|length))" else "" end) | bash=\($ws) param1=focus param2=\(.name) terminal=false"' <<<"$spaces"
}

render
