#!/bin/bash
# Also in the SUPER+Escape system menu (.local/src/power-menu.swift)

# @raycast.schemaVersion 1
# @raycast.title Power: Log Out
# @raycast.mode silent
# @raycast.icon 🚪
# @raycast.packageName Omarchy

osascript -e 'tell application "System Events" to log out'
