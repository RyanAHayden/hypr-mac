#!/bin/bash
# Makes ~/Applications/<Name>.app (like setup's "Fix Keyboard"), so Raycast/Spotlight can launch it.
# Target is a file/folder/app/URL to open, or else a shell command (run in a login zsh, in the background).

# @raycast.schemaVersion 1
# @raycast.title Create App Shortcut
# @raycast.mode compact
# @raycast.icon 🚀
# @raycast.packageName Omarchy
# @raycast.argument1 { "type": "text", "placeholder": "Name" }
# @raycast.argument2 { "type": "text", "placeholder": "File or command" }

name=${1//\//-}
target=$2
[ -n "$name" ] && [ -n "$target" ] || { echo "Need a name and a file or command"; exit 1; }
app="$HOME/Applications/$name.app"

# only replace shortcuts made by this (AppleScript applets), never a real app
if [ -e "$app" ] && [ ! -f "$app/Contents/Resources/Scripts/main.scpt" ]; then
	echo "$name.app already exists and isn't a shortcut"; exit 1
fi

path=${target/#\~/$HOME}
if [ -e "$path" ] || [[ $target =~ ^[a-z][a-z0-9+.-]*:// ]]; then
	[ -e "$path" ] && target=$(cd "$(dirname "$path")" && echo "$PWD/$(basename "$path")")
	run="open"; what="Opens $target"
else
	run="nohup /bin/zsh -lc"; what="Runs $target"
fi

# AppleScript string literal: escape backslashes and quotes, then quoted form of it for the shell
lit=${target//\\/\\\\}; lit=${lit//\"/\\\"}
mkdir -p ~/Applications
rm -rf "$app"
osacompile -o "$app" -e "do shell script \"$run \" & quoted form of \"$lit\" & \" >/dev/null 2>&1 &\"" 2> >(grep -v "replacing existing signature" >&2) ||
	{ echo "osacompile failed"; exit 1; }
echo "$name: $what"
