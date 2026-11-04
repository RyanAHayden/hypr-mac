#!/bin/bash
# SUPER+Escape opens Raycast filtered to the "Power:" commands (~/.local/bin/power-menu)

# @raycast.schemaVersion 1
# @raycast.title Power: Relaunch Window Manager
# @raycast.mode silent
# @raycast.icon 🔄
# @raycast.packageName Omarchy

export PATH="/opt/homebrew/bin:$PATH"
yabai --restart-service; skhd --restart-service
