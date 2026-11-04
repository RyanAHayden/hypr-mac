#!/usr/bin/env bash
# Workspace bar like Omarchy's Waybar: 1-5 always, higher Spaces when occupied or focused.
# The row is drawn as an image by ~/.local/bin/ws-render (source in ~/.local/src/ws-render.swift).
# Streamable: stays running and redraws as soon as yabai pokes the FIFO (signals in local.yabairc).
# <swiftbar.type>streamable</swiftbar.type>
# <swiftbar.hideAbout>true</swiftbar.hideAbout><swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated><swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
export PATH="/opt/homebrew/bin:$PATH"
FIFO="$HOME/.cache/ryha-workspace.fifo"
[[ -p $FIFO ]] || { rm -f "$FIFO"; mkfifo "$FIFO"; }
exec 3<>"$FIFO" # read-write open never blocks, and keeps writers from blocking

render() {
	local spaces
	spaces=$(yabai -m query --spaces 2>/dev/null) || return 1
	# Space 11 is workspace "0" (the ~ key, left of 1): label it 0 and draw it first
	spaces=$(jq '[ .[] | .name = (if .index == 11 then "0" else (.index | tostring) end) ]
		| sort_by(if .index == 11 then 0 else .index end)' <<<"$spaces")
	local args
	args=$(jq -r '[ .[] | select(.index <= 5 or ."has-focus" or (.windows | length) > 0)
		| "\(.name):\(if ."has-focus" then "a" elif (.windows | length) > 0 then "o" else "e" end)" ] | join(" ")' <<<"$spaces")
	echo "~~~"
	# shellcheck disable=SC2086
	echo "| image=$("$HOME/.local/bin/ws-render" $args)"
	echo "---"
	jq -r --arg ws "$HOME/.local/bin/ws" '.[] |
		"\(if ."has-focus" then "• " else "" end)\(.name)\(if (.windows|length) > 0 then "  (\(.windows|length))" else "" end) | bash=\($ws) param1=focus param2=\(.name) terminal=false"' <<<"$spaces"
}

last=""
while :; do
	# keep the last good row if yabai is briefly unavailable (e.g. restarting)
	if out=$(render) && [[ $out != "$last" ]]; then printf '%s\n' "$out"; last=$out; fi
	# wake instantly on a yabai signal, or every 5s as a fallback (window counts etc.)
	read -r -t 5 -u 3 _
	while read -r -t 0.01 -u 3 _; do :; done # coalesce bursts of signals
done
