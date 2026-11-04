#!/bin/bash
# Also in the SUPER+Escape system menu (.local/src/power-menu.swift)

# @raycast.schemaVersion 1
# @raycast.title Power: Relaunch Window Manager
# @raycast.mode silent
# @raycast.icon 🔄
# @raycast.packageName Omarchy

export PATH="/opt/homebrew/bin:$PATH"
yabai --restart-service; skhd --restart-service
