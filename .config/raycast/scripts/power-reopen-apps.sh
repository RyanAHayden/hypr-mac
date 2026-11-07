#!/bin/bash
# Also in the SUPER+Escape system menu (.local/src/power-menu.swift)
# Toggles reopening the apps that were running when you restart / log out ("Reopen windows when logging back in").
# setup.sh turns it off.

# @raycast.schemaVersion 1
# @raycast.title Power: Reopen Apps at Login
# @raycast.mode compact
# @raycast.icon 🔁
# @raycast.packageName Omarchy

if [ "$(defaults read com.apple.loginwindow TALLogoutSavesState 2>/dev/null)" = 1 ]; then
	on=false msg="Apps won't reopen after restart / log out"
else
	on=true msg="Running apps reopen after restart / log out"
fi
defaults write com.apple.loginwindow TALLogoutSavesState -bool $on
defaults write com.apple.loginwindow LoginwindowLaunchesRelaunchApps -bool $on
echo "$msg"
