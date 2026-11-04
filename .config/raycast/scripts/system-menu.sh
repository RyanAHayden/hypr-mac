#!/bin/bash
# Omarchy's SUPER+Escape system menu as a Raycast Script Command (skhdrc opens it by deeplink).
# Raycast needs this folder once: Settings > Extensions > + > Add Script Directory > ~/.config/raycast/scripts

# @raycast.schemaVersion 1
# @raycast.title System
# @raycast.mode silent
# @raycast.icon ⏻
# @raycast.packageName Omarchy
# @raycast.argument1 { "type": "dropdown", "placeholder": "Action", "data": [{"title": "Lock", "value": "lock"}, {"title": "Sleep", "value": "sleep"}, {"title": "Relaunch window manager", "value": "relaunch"}, {"title": "Log out", "value": "logout"}, {"title": "Restart", "value": "restart"}, {"title": "Shut down", "value": "shutdown"}] }

export PATH="/opt/homebrew/bin:$PATH"
case $1 in
	lock) pmset displaysleepnow ;;
	sleep) pmset sleepnow ;;
	relaunch) yabai --restart-service; skhd --restart-service ;;
	logout) osascript -e 'tell application "System Events" to log out' ;;
	restart) osascript -e 'tell application "System Events" to restart' ;;
	shutdown) osascript -e 'tell application "System Events" to shut down' ;;
esac
