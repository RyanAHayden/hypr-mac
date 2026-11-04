#!/bin/bash
# Also in the SUPER+Escape system menu (.local/src/power-menu.swift)
# Toggles sleep off/on, so closing the lid only turns the screen off (long Claude runs keep going).
# sudo works without a password through /private/etc/sudoers.d/pmset (setup.sh).

# @raycast.schemaVersion 1
# @raycast.title Power: Keep Awake With Lid Closed
# @raycast.mode compact
# @raycast.icon ☕
# @raycast.packageName Omarchy

if pmset -g | grep -q 'SleepDisabled[[:space:]]*1'; then
	sudo -n pmset -a disablesleep 0 && echo "Sleep back on"
else
	sudo -n pmset -a disablesleep 1 || exit 1
	# blanks the screen while the lid is closed (LaunchAgent from setup.sh, which also runs it at login)
	launchctl kickstart -k "gui/$(id -u)/com.ryha.lid-sleep-watcher"
	echo "Staying awake: lid close only turns the screen off"
fi
