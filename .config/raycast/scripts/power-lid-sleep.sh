#!/bin/bash
# Toggles sleep off/on, so closing the lid only turns the screen off (long Claude runs keep going).
# sudo works without a password through /private/etc/sudoers.d/pmset (setup.sh).

# @raycast.schemaVersion 1
# @raycast.title Power: Toggle Lid Sleep
# @raycast.mode compact
# @raycast.icon ☕
# @raycast.packageName Omarchy

if pmset -g | grep -q 'SleepDisabled *1'; then
	sudo -n pmset -a disablesleep 0 && echo "Sleep back on"
else
	sudo -n pmset -a disablesleep 1 && echo "Staying awake: lid close only turns the screen off"
fi
