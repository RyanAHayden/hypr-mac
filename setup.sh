#!/usr/bin/env bash
# Sets up this Mac like github.com/RyanAHayden/dotfiles (Omarchy), on top of Macarchy.
# Safe to re-run. Stows with --adopt, so check `git diff` afterwards and discard what you don't want.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACARCHY="$HOME/macarchy"

echo "==> Homebrew packages"
command -v brew >/dev/null || { echo "Install Homebrew first: https://brew.sh"; exit 1; }
brew install stow tmux syncthing jq
# LazyVim :checkhealth deps (search/explorer, lazygit, parser builds, snacks image/PDF/LaTeX previews)
brew install fd fzf lazygit tree-sitter-cli imagemagick ghostscript tectonic
brew install --cask keepassxc font-jetbrains-mono-nerd-font helium-browser spotify discord alt-tab swiftbar middleclick

echo "==> Macarchy (everything except its SketchyBar; the native menu bar + SwiftBar is used instead)"
[ -d "$MACARCHY" ] || git clone https://github.com/HarryRandall/macarchy "$MACARCHY"
# if yabairc is Macarchy's plus appended lines (the local.yabairc include, re-added below), restore
# Macarchy's copy so it isn't seen as locally edited; any other edit is left for Macarchy to report
yrc=~/.config/yabai/yabairc
if [ -f "$yrc" ] && head -c "$(wc -c <"$MACARCHY/yabai/yabairc")" "$yrc" | cmp -s - "$MACARCHY/yabai/yabairc"; then
	cp "$MACARCHY/yabai/yabairc" "$yrc"
fi
# files this repo overrides that Macarchy also installs (skhdrc, nvim config): Macarchy stops if they
# differ from its copy, so move any local edits into the repo and let it reinstall; stow links ours back below
overrides=$(cd "$REPO" && git ls-files .config | while read -r f; do if [ -e "$MACARCHY/${f#.config/}" ]; then echo "$f"; fi; done)
for f in $overrides; do
	if [ -f ~/"$f" ] && [ ! -L ~/"$f" ] && ! cmp -s ~/"$f" "$MACARCHY/${f#.config/}"; then cp ~/"$f" "$REPO/$f"; fi
	rm -f ~/"$f"
done
"$MACARCHY/install" window-manager terminal shell nvim utilities themes raycast
brew trust --formula felixkratz/formulae/borders

echo "==> stow"
cd "$REPO"
for f in $overrides; do rm -f ~/"$f"; done
stow . --adopt
# Macarchy's yabairc has no local include; add one line for local.yabairc
grep -q local.yabairc ~/.config/yabai/yabairc || printf '\n# Personal overrides (not managed by Macarchy)\n[ -f "$CONFIG_ROOT/local.yabairc" ] && source "$CONFIG_ROOT/local.yabairc"\n' >>~/.config/yabai/yabairc

echo "==> tmux plugins (no TPM)"
mkdir -p ~/.config/tmux/plugins
for p in tmux-resurrect tmux-continuum; do
	[ -d ~/.config/tmux/plugins/$p ] || git clone -q --depth 1 https://github.com/tmux-plugins/$p ~/.config/tmux/plugins/$p
done

echo "==> LazyVim plugins and treesitter parsers"
nvim --headless "+Lazy! sync" +qa
# parsers snacks wants for rendering images/math in docs (norg isn't in nvim-treesitter anymore)
nvim --headless -c "lua require('nvim-treesitter').install({'latex','scss','typst','vue'}):wait(300000)" -c "qa!"
echo

echo "==> workspace bar renderer"
swiftc -O ~/.local/src/ws-render.swift -o ~/.local/bin/ws-render
mkdir -p ~/.cache

echo "==> theme"
~/.local/bin/theme-switch ryha-silver

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
defaults write com.apple.spaces spans-displays -bool false
defaults write -g _HIHideMenuBar -bool false
defaults write -g NSWindowShouldDragOnGesture -bool true
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
# darker dark mode: neutral (untinted) window backgrounds, solid instead of translucent menus/sidebars/Dock
defaults write -g AppleReduceDesktopTinting -bool true
defaults write com.apple.universalaccess reduceTransparency -bool true 2>/dev/null ||
	echo "  (couldn't set Reduce transparency - turn it on in Accessibility > Display, or give the terminal Full Disk Access)"
# ctrl+1..9 -> Desktop 1..9 (~/.local/bin/ws uses these while SIP is on)
codes=(18 19 20 21 23 22 26 28 25)
for i in 1 2 3 4 5 6 7 8 9; do
	defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add $((117 + i)) \
		"<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>$((48 + i))</integer><integer>${codes[$((i - 1))]}</integer><integer>262144</integer></array><key>type</key><string>standard</string></dict></dict>"
done
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
# SwiftBar workspace plugin, leftmost of the status items
defaults write com.ameba.SwiftBar PluginDirectory -string "$HOME/.config/swiftbar"
defaults write com.ameba.SwiftBar SUEnableAutomaticChecks -bool false
defaults write com.ameba.SwiftBar "NSStatusItem Preferred Position workspace.sh" -float 9000
# hide menu bar icons: AltTab, MiddleClick, Raycast, Spotlight (quit apps first or they overwrite this)
for a in AltTab MiddleClick Raycast; do osascript -e "quit app \"$a\"" 2>/dev/null || true; done
sleep 2
defaults write com.lwouis.alt-tab-macos menubarIconShown -string false
defaults write com.lwouis.alt-tab-macos "NSStatusItem Visible Item-0" -bool false
defaults write art.ginzburg.MiddleClick "NSStatusItem Visible Item-0" -bool false
defaults write com.raycast.macos "NSStatusItem Visible raycastIcon" -bool false
defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1
killall Dock SystemUIServer 2>/dev/null || true

echo "==> services and login items"
yabai --start-service 2>/dev/null || yabai --restart-service
skhd --start-service 2>/dev/null || skhd --restart-service
brew services start borders
brew services start syncthing
for a in AltTab MiddleClick SwiftBar Raycast; do
	open -a "$a"
	osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"/Applications/$a.app\", hidden:true}" >/dev/null 2>&1 || true
done

cat <<'EOF'

Done - check `git diff` (stow --adopt pulled existing files into the repo) and `git checkout .` what you don't want.
Manual steps:
  1. Privacy & Security > Accessibility: allow yabai, skhd, AltTab, MiddleClick (+ Screen Recording for AltTab),
     then: yabai --restart-service; skhd --restart-service
  2. Mission Control (ctrl+up): add Desktops until there are 10
  3. Log out and back in (key repeat, trackpad)
  4. Syncthing: http://127.0.0.1:8384
EOF
