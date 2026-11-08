#!/usr/bin/env bash
# Sets up this Mac like github.com/RyanAHayden/dotfiles (Omarchy).
# Safe to re-run. Stows with --adopt, so check `git diff` afterwards and discard what you don't want.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Homebrew packages"
command -v brew >/dev/null || { echo "Install Homebrew first: https://brew.sh"; exit 1; }
brew install stow tmux syncthing jq neovim ripgrep btop
# shell helpers like Omarchy: zoxide (cd), eza (ls), bat (ff previews), starship (prompt); fzf below
brew install zoxide eza bat starship
# sqlcipher writes Raycast's encrypted settings (see below)
brew install sqlcipher
# duti sets default apps (text files open in nvim, below)
brew install duti
brew install asmvik/formulae/yabai felixkratz/formulae/borders
# binds moved from skhd to Karabiner (.config/binds/bindings.conf, works in password fields): drop skhd if it's here
if brew list skhd >/dev/null 2>&1; then
	skhd --uninstall-service 2>/dev/null || true
	brew uninstall skhd
	rm -f ~/.config/skhd/skhdrc && rmdir ~/.config/skhd 2>/dev/null || true
fi
brew trust --formula felixkratz/formulae/borders
# LazyVim :checkhealth deps (search/explorer, lazygit, parser builds, snacks image/PDF/LaTeX previews)
brew install fd fzf lazygit tree-sitter-cli imagemagick ghostscript tectonic
brew install --cask ghostty raycast keepassxc font-jetbrains-mono-nerd-font helium-browser spotify discord alt-tab middleclick
brew install --cask karabiner-elements

echo "==> stow"
cd "$REPO"
stow . --adopt

echo "==> tmux plugins (no TPM)"
mkdir -p ~/.config/tmux/plugins
for p in tmux-resurrect tmux-continuum; do
	[ -d ~/.config/tmux/plugins/$p ] || git clone -q --depth 1 https://github.com/tmux-plugins/$p ~/.config/tmux/plugins/$p
done

echo "==> Zen (github.com/RyanAHayden/zen, shared with dotfiles)"
[ -d ~/zen ] || git clone -q https://github.com/RyanAHayden/zen ~/zen
~/zen/setup.sh

echo "==> LazyVim plugins and treesitter parsers"
nvim --headless "+Lazy! sync" +qa
# parsers snacks wants for rendering images/math in docs (norg isn't in nvim-treesitter anymore)
nvim --headless -c "lua require('nvim-treesitter').install({'latex','scss','typst','vue'}):wait(300000)" -c "qa!"
echo

echo "==> yabai-helper (workspace bar, focus fixes, alt-tab), notify-post, power-menu, sendkey and bind-repeat"
swiftc -O ~/.local/src/yabai-helper.swift -o ~/.local/bin/yabai-helper
clang -O2 ~/.local/src/notify-post.c -o ~/.local/bin/notify-post
swiftc -O ~/.local/src/power-menu.swift -o ~/.local/bin/power-menu
swiftc -O ~/.local/src/night-shift.swift -o ~/.local/bin/night-shift
swiftc -O ~/.local/src/display-scale.swift -o ~/.local/bin/display-scale
swiftc -O ~/.local/src/sendkey.swift -o ~/.local/bin/sendkey
swiftc -O ~/.local/src/bind-repeat.swift -o ~/.local/bin/bind-repeat
# crash-notify needs an app bundle to post notifications (ad-hoc signed; macOS asks to allow them on first run)
cn=~/.local/share/crash-notify/CrashNotify.app/Contents
mkdir -p "$cn/MacOS"
cat >"$cn/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key><string>com.ryha.crash-notify</string>
	<key>CFBundleName</key><string>Crash Reports</string>
	<key>CFBundleExecutable</key><string>crash-notify</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
swiftc -O ~/.local/src/crash-notify.swift -o "$cn/MacOS/crash-notify"
codesign -fs - ~/.local/share/crash-notify/CrashNotify.app
mkdir -p ~/.cache

echo "==> dark mode and wallpaper"
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
~/.local/bin/set-wallpaper ~/.local/share/wallpapers/0-dot-hands.jpg

echo "==> macOS settings"
# input (hypr/input.lua): fast repeat, flat mouse, natural scroll; three fingers = middle click only
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15
defaults write -g ApplePressAndHoldEnabled -bool false
defaults write -g com.apple.mouse.linear -bool true
defaults write -g com.apple.swipescrolldirection -bool true
for d in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
	defaults write $d Clicking -bool true
	defaults write $d TrackpadThreeFingerDrag -bool false
	defaults write $d TrackpadThreeFingerHorizSwipeGesture -int 0
	defaults write $d TrackpadThreeFingerVertSwipeGesture -int 0
	defaults write $d TrackpadFourFingerHorizSwipeGesture -int 2
	defaults write $d TrackpadFourFingerVertSwipeGesture -int 2
done
defaults write art.ginzburg.MiddleClick fingers -int 3
defaults write art.ginzburg.MiddleClick allowMoreFingers -bool false
# Spaces / Dock / menu bar (native menu bar, always shown)
defaults write com.apple.dock mru-spaces -bool false
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock expose-group-apps -bool true
# no hot corners (bottom-right is Quick Note by default)
for c in tl tr bl br; do
	defaults write com.apple.dock wvous-$c-corner -int 1
	defaults write com.apple.dock wvous-$c-modifier -int 0
done
# yabai tiles: no Sequoia drag-to-edge tiling or Option-drag tiling, and clicking the wallpaper doesn't hide every window
defaults write com.apple.WindowManager EnableTilingByEdgeDrag -bool false
defaults write com.apple.WindowManager EnableTopTilingByEdgeDrag -bool false
defaults write com.apple.WindowManager EnableTilingOptionAccelerator -bool false
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
defaults write com.apple.spaces spans-displays -bool false
defaults write -g _HIHideMenuBar -bool false
defaults write -g NSWindowShouldDragOnGesture -bool true
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
# restart/log out doesn't reopen the apps that were running (a stray `open file.txt` brought TextEdit back every login)
defaults write com.apple.loginwindow TALLogoutSavesState -bool false
defaults write com.apple.loginwindow LoginwindowLaunchesRelaunchApps -bool false
# Finder: list view by default, in folders and search/Recents. Folders that remember their own view
# (a .DS_Store) override the default, so clear those (not the Desktop's, which holds icon positions).
defaults write com.apple.finder FXPreferredViewStyle -string Nlsv
defaults write com.apple.finder FXPreferredSearchViewStyle -string Nlsv
find "$HOME" -name .DS_Store -not -path "$HOME/Library/*" -not -path "$HOME/Desktop/.DS_Store" -delete 2>/dev/null || true
rm -f /Applications/.DS_Store
killall Finder 2>/dev/null || true
# darker dark mode: neutral (untinted) window backgrounds
defaults write -g AppleReduceDesktopTinting -bool true
# Pitch-black menu bar: macOS 15 has no menu bar colour setting; with Reduce transparency on it's solid grey,
# with it off it shows the wallpaper, whose top edge is black. (Menus, sidebars and the Dock go translucent too.)
defaults write com.apple.universalaccess reduceTransparency -bool false 2>/dev/null ||
	echo "  (couldn't turn off Reduce transparency - do it in Accessibility > Display, or give the terminal Full Disk Access)"
# ctrl+1..9 -> Desktop 1..9 (~/.local/bin/ws uses these while SIP is on)
codes=(18 19 20 21 23 22 26 28 25)
for i in 1 2 3 4 5 6 7 8 9; do
	defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add $((117 + i)) \
		"<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>$((48 + i))</integer><integer>${codes[$((i - 1))]}</integer><integer>262144</integer></array><key>type</key><string>standard</string></dict></dict>"
done
# SUPER is left Cmd (Karabiner): free cmd+space for Raycast, and move screenshots off cmd+shift+3/4/5
# (SUPER+shift+N moves windows) to ctrl+shift+3/4/5, ctrl+option+shift+3/4 = to clipboard
hotkey() { # id enabled ascii keycode modmask
	defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$1" \
		"<dict><key>enabled</key><$2/><key>value</key><dict><key>parameters</key><array><integer>$3</integer><integer>$4</integer><integer>$5</integer></array><key>type</key><string>standard</string></dict></dict>"
}
hotkey 64 false 32 49 1048576
# Cmd+Option+Space (Finder search window) is SUPER+Alt+Space (Dictation)
hotkey 65 false 32 49 1572864
# Ctrl+Space / Ctrl+Option+Space (switch input source) are the tmux prefix / nvim completion
hotkey 60 false 32 49 262144
hotkey 61 false 32 49 786432
# fn/Globe alone does nothing (fn+h/j/k/l are arrows via Karabiner; it kept popping the emoji picker - use Raycast)
defaults write com.apple.HIToolbox AppleFnUsageType -int 0
# Raycast toggles itself on its own hotkey (a bind could only open it): cmd+space (49 = space)
defaults write com.raycast.macos raycastGlobalHotkey -string "Command-49"
hotkey 28 true 51 20 393216
hotkey 29 true 51 20 917504
hotkey 30 true 52 21 393216
hotkey 31 true 52 21 917504
hotkey 184 true 53 23 393216
# Ctrl+arrows are word jump in apps (Karabiner) and the shell: no Mission Control / App Exposé (32-35) or
# Desktop left/right (79-82) on them. ws resolves prev/next to a Desktop number, so its SIP-on fallback uses ctrl+N
hotkey 32 false 65535 126 8650752
hotkey 33 false 65535 125 8650752
hotkey 34 false 65535 126 8781824
hotkey 35 false 65535 125 8781824
hotkey 79 false 65535 123 8650752
hotkey 80 false 65535 123 8781824
hotkey 81 false 65535 124 8650752
hotkey 82 false 65535 124 8781824
# no Ctrl+F1..F8 keyboard navigation (keyboard access, focus menu bar / Dock / window / toolbar / floating window,
# tab movement, status menus)
fkeys=(12:122 7:120 8:99 9:118 10:96 11:97 13:98 57:100)
for f in "${fkeys[@]}"; do hotkey "${f%%:*}" false 65535 "${f#*:}" 8650752; done
# Fn+Ctrl(+Shift/Option)+arrows (Window > Move & Resize tiling; Fn+H/J/K/L are arrows) go to an unreachable
# Cmd+Option+Ctrl+Shift+F20 (an empty shortcut doesn't override them)
f20=$(printf '\xef\x9c\x97')
for i in Left Right Top Bottom "Left & Right" "Left & Quarters" "Right & Left" "Right & Quarters" \
	"Top & Bottom" "Top & Quarters" "Bottom & Top" "Bottom & Quarters"; do
	defaults write -g NSUserKeyEquivalents -dict-add $'\033Window\033Move & Resize\033'"$i" -string "@~^\$$f20"
done
# Function keys stay normal with Fn held: no Show Desktop on F11 / Shift+F11 (36/37, macOS defaults, so not in the
# saved list until overridden), and no leftover Dashboard on F12 / Shift+F12 (62/63)
hotkey 36 false 65535 103 8388608
hotkey 37 false 65535 103 8519680
hotkey 62 false 65535 111 8388608
hotkey 63 false 65535 111 8519680
# Sound and Bluetooth in the menu bar (always), so SUPER+Ctrl+S / SUPER+Ctrl+B can open their panels
defaults -currentHost write com.apple.controlcenter Sound -int 18
defaults -currentHost write com.apple.controlcenter Bluetooth -int 18
# macOS Dictation on, started by the hidden F19 key (keycode 80, no modifiers), which SUPER+Alt+Space sends
# (bindings.conf): there's no command or AppleScript to start Dictation, only its keyboard shortcut
defaults write com.apple.HIToolbox AppleDictationAutoEnable -int 1
defaults write com.apple.assistant.support "Dictation Enabled" -bool true
hotkey 164 true 65535 80 0
# skip the one-time "Do you want to enable Dictation?" prompt
defaults write com.apple.speech.recognition.AppleSpeechRecognition.prefs DictationIMIntroMessagePresented -bool true
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
# F4 (Spotlight) / F5 (Dictation) -> keyboard brightness down/up, reapplied at login by a LaunchAgent
fnmap='{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0xC00000221,"HIDKeyboardModifierMappingDst":0xFF00000009},{"HIDKeyboardModifierMappingSrc":0xC000000CF,"HIDKeyboardModifierMappingDst":0xFF00000008}]}'
hidutil property --set "$fnmap" >/dev/null
cat >~/Library/LaunchAgents/com.ryha.keyboard-brightness-keys.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>com.ryha.keyboard-brightness-keys</string>
	<key>ProgramArguments</key>
	<array><string>/usr/bin/hidutil</string><string>property</string><string>--set</string><string>$fnmap</string></array>
	<key>RunAtLoad</key><true/>
</dict>
</plist>
PLIST
# yabai-helper (.local/src/yabai-helper.swift): workspace bar, mouse follows focus, focus after close, alt-tab
cat >~/Library/LaunchAgents/com.ryha.yabai-helper.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>com.ryha.yabai-helper</string>
	<key>ProgramArguments</key><array><string>$HOME/.local/bin/yabai-helper</string></array>
	<key>RunAtLoad</key><true/>
	<key>KeepAlive</key><true/>
</dict>
</plist>
PLIST
launchctl bootout gui/$UID/com.ryha.yabai-helper 2>/dev/null || true
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.ryha.yabai-helper.plist
# lid-sleep-watcher (.local/bin): blanks the screen when the lid shuts while sleep is disabled ("Keep Awake With Lid
# Closed"). Disabled sleep survives a reboot, so start it at login too; it quits right away if sleep is on, and the
# toggle kickstarts it.
cat >~/Library/LaunchAgents/com.ryha.lid-sleep-watcher.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>com.ryha.lid-sleep-watcher</string>
	<key>ProgramArguments</key><array><string>$HOME/.local/bin/lid-sleep-watcher</string></array>
	<key>RunAtLoad</key><true/>
</dict>
</plist>
PLIST
launchctl bootout gui/$UID/com.ryha.lid-sleep-watcher 2>/dev/null || true
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.ryha.lid-sleep-watcher.plist
# Crash notifications instead of macOS's "quit unexpectedly" dialog (.local/src/crash-notify.swift); reports are
# still written to ~/Library/Logs/DiagnosticReports
defaults write com.apple.CrashReporter DialogType none
cat >~/Library/LaunchAgents/com.ryha.crash-notify.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>com.ryha.crash-notify</string>
	<key>ProgramArguments</key><array><string>$HOME/.local/share/crash-notify/CrashNotify.app/Contents/MacOS/crash-notify</string></array>
	<key>RunAtLoad</key><true/>
	<key>KeepAlive</key><true/>
</dict>
</plist>
PLIST
launchctl bootout gui/$UID/com.ryha.crash-notify 2>/dev/null || true
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.ryha.crash-notify.plist
# Default menu bar icon spacing (it was tightened to fit the old right-side workspace bar next to the notch)
defaults -currentHost delete -globalDomain NSStatusItemSpacing 2>/dev/null || true
defaults -currentHost delete -globalDomain NSStatusItemSelectionPadding 2>/dev/null || true
raydb="$HOME/Library/Application Support/com.raycast.macos/raycast-enc.sqlite"
# Raycast makes its settings database (written below) on first launch, so launch it once on a fresh Mac
if [ ! -f "$raydb" ]; then
	open -ga Raycast
	for _ in $(seq 30); do [ -f "$raydb" ] && break; sleep 1; done
	sleep 3
fi
# hide menu bar icons: AltTab, MiddleClick, Raycast, Spotlight (quit apps first or they overwrite this)
for a in AltTab MiddleClick Raycast; do osascript -e "quit app \"$a\"" 2>/dev/null || true; done
sleep 2
defaults write com.lwouis.alt-tab-macos menubarIconShown -string false
defaults write com.lwouis.alt-tab-macos "NSStatusItem Visible Item-0" -bool false
# AltTab takes over Cmd+Tab = SUPER+Tab (it turns off the macOS app switcher while it holds that shortcut). AltTab 11
# stores shortcuts as archived objects and drops plain strings, but converts strings when upgrading settings from
# before 10.4, so write them as strings and mark the settings that old (AltTab is quit here; it converts on launch).
if ! defaults read com.lwouis.alt-tab-macos holdShortcut 2>/dev/null | grep -q 'U2318'; then
	defaults write com.lwouis.alt-tab-macos holdShortcut -string "⌘"
	defaults write com.lwouis.alt-tab-macos nextWindowShortcut -string "⇥"
	defaults write com.lwouis.alt-tab-macos preferencesVersion -string "10.4.0"
fi
# while it's open, S minimizes/restores the selected window (W closes it, AltTab's default) and the switcher stays
# open, and / is search (AltTab's default search key is S, and search mode keeps the switcher open after releasing
# Cmd). Karabiner lets Cmd+S/W// through to it then, and sends Cmd+M as Cmd+S. Written archived: SRShortcuts for
# keyCode 1 ("s") and 44 ("/"), the shape AltTab saves itself
defaults write com.lwouis.alt-tab-macos minDeminWindowShortcut -dict string S secureData -data \
	62706c6973743030d40102030405061e215924617263686976657258246f626a656374735424746f70582476657273696f6e5f100f4e534b657965644172636869766572a607081516171855246e756c6cd6090a0b0c0d0e0f10111213145624636c6173735a636861726163746572735f101b6368617261637465727349676e6f72696e674d6f64696669657273576b6579436f64655d6d6f646966696572466c6167735776657273696f6e800580048004800280038003100110005173d2191a1b1c5824636c61737365735a24636c6173736e616d65a21c1d5a535253686f7274637574584e534f626a656374d11f2054726f6f74800112000186a008111b242932444b515e65708e96a4acaeb0b2b4b6b8babcbec3ccd7dae5eef1f6f800000000000001010000000000000022000000000000000000000000000000fd
defaults write com.lwouis.alt-tab-macos searchShortcut -dict string / secureData -data \
	62706c6973743030d40102030405061e215924617263686976657258246f626a656374735424746f70582476657273696f6e5f100f4e534b657965644172636869766572a607081516171855246e756c6cd6090a0b0c0d0e0f10111213145624636c6173735a636861726163746572735f101b6368617261637465727349676e6f72696e674d6f64696669657273576b6579436f64655d6d6f646966696572466c6167735776657273696f6e800580048004800280038003102c1000512fd2191a1b1c5824636c61737365735a24636c6173736e616d65a21c1d5a535253686f7274637574584e534f626a656374d11f2054726f6f74800112000186a008111b242932444b515e65708e96a4acaeb0b2b4b6b8babcbec3ccd7dae5eef1f6f800000000000001010000000000000022000000000000000000000000000000fd
defaults write art.ginzburg.MiddleClick "NSStatusItem Visible Item-0" -bool false
defaults write com.raycast.macos "NSStatusItem Visible raycastIcon" -bool false
defaults write com.raycast.macos showGettingStartedLink -bool false
# minimal Raycast: compact window (no suggestions until you type), no favorites, and the deeplinks the binds use
# run without a "Request to run" prompt
defaults write com.raycast.macos raycastPreferredWindowMode -string compact
defaults write com.raycast.macos showFavoritesInCompactMode -bool false
defaults write com.raycast.macos alwaysAllowCommandDeeplinking -dict-add builtin_command_clipboardHistory -bool true
defaults write com.raycast.macos alwaysAllowCommandDeeplinking -dict-add builtin_command_searchEmoji -bool true
# AI, upsells (Pro, affiliate, Wrapped, Store), Notes, Focus, Teams, MCP, Calendar, Translate, Window Management
# etc. turned off, and the script folder added: .config/raycast/settings.sql, made by turning them off in Settings and
# dumping raycastConfiguration. Raycast's database is SQLCipher, keyed by sha256(keychain key + a salt in the app).
# @SCRIPTS@ in it is the script folder, in this repo wherever it's cloned.
if raykey=$(security find-generic-password -s Raycast -a database_key -w 2>/dev/null) && [ -f "$raydb" ]; then
	raykey=$(printf '%s' "${raykey}yvkwWXzxPPBAqY2tmaKrB*DvYjjMaeEf" | shasum -a 256 | cut -d' ' -f1)
	{ echo "PRAGMA key = '$raykey';"; sed "s|@SCRIPTS@|$REPO/.config/raycast/scripts|" "$REPO/.config/raycast/settings.sql"; } |
		"$(brew --prefix sqlcipher)/bin/sqlcipher" "$raydb" >/dev/null
else
	echo "  (Raycast hasn't made its database yet - open it once, then re-run setup for its settings)"
fi
defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1
killall Dock SystemUIServer 2>/dev/null || true
# SIP off (see README): grant Ghostty/Terminal every permission in the TCC databases, drop the privacy
# indicator dots (systemstatusd draws them), and let yabai load its scripting addition without a password
sip_off=false
csrutil status | grep -q disabled && sip_off=true
if $sip_off; then
	echo "==> SIP is off: TCC grants, no privacy dots, yabai scripting addition (sudo)"
	csreq_hex() { codesign -d -r- "$1" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' | csreq -r- -b /dev/stdout | xxd -p | tr -d '\n'; }
	tcc_grant() { # db service client(bundle-id, or path for a bare binary) app-or-binary-path [client_type: 0 bundle, 1 path]
		sudo sqlite3 "$1" "INSERT OR REPLACE INTO access (service,client,client_type,auth_value,auth_reason,auth_version,csreq,flags,last_modified)
			VALUES ('$2','$3',${5:-0},2,3,1,X'$(csreq_hex "$4")',0,CAST(strftime('%s','now') AS INTEGER));"
	}
	tcc_automation() { # client app-or-binary-path [client_type 0 bundle/1 path] [target-bundle-id target-path]: let it send
		# Apple Events to the target without the "wants to control" prompt (default: System Events, for osascript below)
		local tid=${4:-com.apple.systemevents} tpath=${5:-/System/Library/CoreServices/System Events.app}
		sqlite3 "$userdb" "INSERT OR REPLACE INTO access (service,client,client_type,auth_value,auth_reason,auth_version,csreq,flags,
			indirect_object_identifier_type,indirect_object_identifier,indirect_object_code_identity,last_modified)
			VALUES ('kTCCServiceAppleEvents','$1',${3:-0},2,3,1,X'$(csreq_hex "$2")',0,0,'$tid',X'$(csreq_hex "$tpath")',
			CAST(strftime('%s','now') AS INTEGER));"
	}
	sysdb="/Library/Application Support/com.apple.TCC/TCC.db"
	userdb="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
	for app in "com.mitchellh.ghostty:/Applications/Ghostty.app" "com.apple.Terminal:/System/Applications/Utilities/Terminal.app"; do
		id=${app%%:*} path=${app#*:}
		for svc in SystemPolicyAllFiles Accessibility ListenEvent PostEvent ScreenCapture SystemPolicyAppBundles DeveloperTool; do
			tcc_grant "$sysdb" "kTCCService$svc" "$id" "$path"
		done
		for svc in SystemPolicyAppData SystemPolicyDocumentsFolder SystemPolicyDesktopFolder SystemPolicyDownloadsFolder \
			SystemPolicyNetworkVolumes SystemPolicyRemovableVolumes; do
			tcc_grant "$userdb" "kTCCService$svc" "$id" "$path"
		done
		tcc_automation "$id" "$path"
	done
	# everything else that would otherwise prompt or need switching on by hand
	yabai_bin=$(readlink -f "$(command -v yabai)")
	tcc_grant "$sysdb" kTCCServiceAccessibility "$yabai_bin" "$yabai_bin" 1
	# binds run from Karabiner-Console-User-Server, so it's what macOS asks about: Accessibility (osascript clicking
	# menu bar items, power-menu's key tap), posting keys (sendkey) and scripting System Events and Finder
	kcus=org.pqrs.Karabiner-Console-User-Server
	kcus_app="/Library/Application Support/org.pqrs/Karabiner-Elements/Karabiner-Console-User-Server.app"
	for svc in Accessibility PostEvent; do
		tcc_grant "$sysdb" "kTCCService$svc" $kcus "$kcus_app"
	done
	tcc_automation $kcus "$kcus_app"
	tcc_automation $kcus "$kcus_app" 0 com.apple.finder /System/Library/CoreServices/Finder.app
	for svc in Accessibility ScreenCapture; do
		tcc_grant "$sysdb" "kTCCService$svc" com.lwouis.alt-tab-macos /Applications/AltTab.app
	done
	tcc_grant "$sysdb" kTCCServiceAccessibility art.ginzburg.MiddleClick /Applications/MiddleClick.app
	# Karabiner needs Input Monitoring or it never grabs the keyboard (no SUPER, caps lock stays caps lock)
	tcc_grant "$sysdb" kTCCServiceListenEvent org.pqrs.Karabiner-Core-Service \
		"/Library/Application Support/org.pqrs/Karabiner-Elements/Karabiner-Core-Service.app"
	sudo killall tccd 2>/dev/null || true
	launchctl disable "gui/$(id -u)/com.apple.systemstatusd"
	launchctl bootout "gui/$(id -u)/com.apple.systemstatusd" 2>/dev/null || true
	# the hash pins the rule (and the yabai grant above) to this binary, so re-run setup after upgrading them
	echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 "$(readlink -f "$(command -v yabai)")" | cut -d' ' -f1) $(command -v yabai) --load-sa" |
		sudo tee /private/etc/sudoers.d/yabai >/dev/null
	sudo chmod 440 /private/etc/sudoers.d/yabai
	nvram boot-args 2>/dev/null | grep -q arm64e_preview_abi || {
		sudo nvram boot-args=-arm64e_preview_abi
		echo "  (set boot-args for the scripting addition - reboot, then re-run setup)"
	}
fi
# no automatic macOS updates (a new major breaks the yabai scripting addition until yabai catches up);
# still check, and keep Rapid Security Responses / XProtect data. Update by hand in System Settings.
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -bool true
# "Keep Awake With Lid Closed" (.config/raycast/scripts/power-lid-sleep.sh) flips sleep without a password
echo "$(whoami) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1" |
	sudo tee /private/etc/sudoers.d/pmset >/dev/null
sudo chmod 440 /private/etc/sudoers.d/pmset
# AltTab: stop Sequoia's monthly "bypass the private window picker" screen recording prompt
# (replayd's container is App Data, so this needs the terminal to have Full Disk Access)
defaults write ~/Library/Group\ Containers/group.com.apple.replayd/ScreenCaptureApprovals \
	/Applications/AltTab.app/Contents/MacOS/AltTab -date "3024-01-01 00:00:00 +0000" 2>/dev/null ||
	echo "  (couldn't silence AltTab's screen recording prompt - give the terminal Full Disk Access and re-run)"

# list Terminal under Privacy & Security > Developer Tools (Ghostty is added there with the + button)
spctl developer-mode enable-terminal 2>/dev/null || true

echo "==> services and login items"
yabai --start-service 2>/dev/null || yabai --restart-service
# binds: bindings.conf -> Karabiner rule now, and again whenever it's saved (Karabiner reloads its config itself)
~/.local/bin/binds-apply
cat >~/Library/LaunchAgents/com.ryha.binds.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>com.ryha.binds</string>
	<key>ProgramArguments</key><array><string>$HOME/.local/bin/binds-apply</string></array>
	<key>WatchPaths</key><array><string>$HOME/.config/binds</string></array>
</dict>
</plist>
PLIST
launchctl bootout gui/$UID/com.ryha.binds 2>/dev/null || true
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.ryha.binds.plist
brew services start borders 2>/dev/null || brew services restart borders
brew services start syncthing
# "Fix Keyboard" app (Raycast/Spotlight): runs ~/.local/bin/fixkeys to reapply the binds and restart Karabiner
mkdir -p ~/Applications
osacompile -o ~/Applications/Fix\ Keyboard.app -e "do shell script \"$HOME/.local/bin/fixkeys\"" 2>/dev/null
# "Nvim" app (~/Applications): opens files in nvim in a new Ghostty window; the default for text and code files, so
# Finder, `open` and Raycast never use TextEdit (RTF still opens in TextEdit)
osacompile -o ~/Applications/Nvim.app -e "on open fs
	set args to \"\"
	repeat with f in fs
		set args to args & \" \" & quoted form of POSIX path of f
	end repeat
	do shell script \"open -na Ghostty --args -e $(command -v nvim)\" & args
end open
on run
	do shell script \"open -na Ghostty --args -e $(command -v nvim)\"
end run" 2>/dev/null
plist=~/Applications/Nvim.app/Contents/Info.plist
plutil -replace CFBundleIdentifier -string com.ryha.nvim "$plist"
plutil -replace CFBundleDocumentTypes -json '[{"CFBundleTypeRole":"Editor","LSHandlerRank":"Alternate","LSItemContentTypes":["public.text","public.data"]}]' "$plist"
codesign -f -s - ~/Applications/Nvim.app 2>/dev/null
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f ~/Applications/Nvim.app
for t in public.plain-text public.utf8-plain-text public.text public.source-code public.script public.shell-script \
	public.json public.xml public.yaml net.daringfireball.markdown public.comma-separated-values-text public.log \
	public.python-script public.ruby-script public.perl-script public.c-source public.c-header public.swift-source \
	com.netscape.javascript-source public.css; do
	duti -s com.ryha.nvim "$t" all 2>/dev/null
done
for e in txt md markdown log conf cfg ini toml yaml yml json jsonc lua sh bash zsh fish py rb js ts tsx jsx css scss \
	xml csv tsv env gitignore gitconfig vim swift c h cpp rs go java kt sql tex typ nix; do
	duti -s com.ryha.nvim ".$e" all 2>/dev/null
done
if $sip_off; then
	# yabairc loads the scripting addition now that sudo -n works; then create Desktops up to 12 (1-9, 10 on 0, 11 = scratchpad on SUPER+S, 12 = SUPER+M parking)
	yabai --restart-service
	sleep 2
	# yabai >= 7.1.16 builds the SA loader with arm64e PAC ABI v1 but Sequoia's Dock is v0, so injection fails
	# ("could not spawn remote thread"): flip the loader back to v0 and ad-hoc re-sign (asmvik/yabai#2686)
	if ! sudo -n yabai --load-sa 2>/dev/null; then
		loader=/Library/ScriptingAdditions/yabai.osax/Contents/MacOS/loader
		read -r arch off <<<"$(otool -f "$loader" | awk '/architecture/{i=$2} /capabilities 0x81/{f=1} f&&/offset/{print i, $2; exit}')"
		if [ -n "$off" ]; then
			printf '\x80' | sudo dd of="$loader" bs=1 seek=$((8 + arch * 20 + 4)) count=1 conv=notrunc 2>/dev/null
			printf '\x80' | sudo dd of="$loader" bs=1 seek=$((off + 11)) count=1 conv=notrunc 2>/dev/null
			sudo codesign -f -s - "$loader" >/dev/null 2>&1
		fi
		sudo -n yabai --load-sa || echo "  (yabai scripting addition still failing to load)"
	fi
	while [ "$(yabai -m query --spaces --display | jq length)" -lt 12 ]; do yabai -m space --create || break; done
fi
open -a Karabiner-Elements   # first launch activates its keyboard driver (approve it, see below)
for a in AltTab MiddleClick Raycast Tailscale; do
	open -a "$a"
	osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"/Applications/$a.app\", hidden:true}" >/dev/null 2>&1 || true
done

cat <<'EOF'

Done - check `git diff` (stow --adopt pulled existing files into the repo) and `git checkout .` what you don't want.
Manual steps:
  1. Privacy & Security > Accessibility: allow yabai, Karabiner-Console-User-Server (it runs the binds), AltTab,
     MiddleClick (+ Screen Recording for AltTab), then: yabai --restart-service
     SIP on only (with SIP off setup grants these and makes the Desktops itself):
     Ghostty and Terminal get everything, so nothing run in them prompts: turn both on in Full Disk Access
     (covers "access data from other apps"), Accessibility, Input Monitoring, Screen & System Audio Recording,
     App Management and Developer Tools; then re-run this script from Ghostty so the AltTab fix above is written
  2. Open Karabiner-Elements: allow its driver extension (General > Login Items & Extensions) and Input Monitoring
     for Karabiner-Core-Service (SIP off: done above). Until then no binds, Ctrl shortcuts or Caps Lock -> Ctrl
  3. SIP on only: Mission Control (F3 or four-finger swipe up): add Desktops until there are 12 (11 = scratchpad, 12 = SUPER+M parking)
  4. Log out and back in (key repeat, trackpad)
  5. Syncthing: http://127.0.0.1:8384
EOF
