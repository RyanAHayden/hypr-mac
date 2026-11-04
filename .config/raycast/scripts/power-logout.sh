#!/bin/bash
# SUPER+Escape opens Raycast filtered to the "Power:" commands (~/.local/bin/power-menu)

# @raycast.schemaVersion 1
# @raycast.title Power: Log Out
# @raycast.mode silent
# @raycast.icon 🚪
# @raycast.packageName Omarchy

osascript -e 'tell application "System Events" to log out'
