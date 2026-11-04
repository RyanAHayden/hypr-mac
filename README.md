# My macOS config

yabai, skhd, JankyBorders, Karabiner-Elements, Ghostty, LazyVim and zsh, set up to work like my Omarchy
[dotfiles](https://github.com/RyanAHayden/dotfiles), with the ryha-silver colors. Everything here is a plain
config file stowed into `~`. Older setups are in git history.

## Setup

1. **Turn SIP off first** (optional, but do it before running setup). Recovery (hold power at boot > Options >
   Utilities > Terminal):

   ```sh
   csrutil disable
   nvram boot-args=-arm64e_preview_abi
   ```

   Reboot. With SIP off, setup writes every privacy permission straight into the TCC databases (Ghostty/Terminal
   get everything, plus yabai, skhd, AltTab, MiddleClick, Karabiner and scripting System Events), so you don't
   click through Allow prompts. It also disables `systemstatusd` (the purple/orange privacy dots), adds a sudoers
   rule so yabai loads its scripting addition (instant Space switching, Space creation, swapping, opacity), and
   creates the 11 Desktops. `csrutil enable` in Recovery turns SIP back on.
2. `./setup.sh` - installs packages, stows using --adopt so you can see git changes before discarding what you
   want to change, and applies the macOS settings, dark mode and wallpaper. Re-run it after upgrading yabai or
   skhd (the sudoers rule and permissions pin the binaries). It also turns off automatic macOS update
   downloads/installs (security responses still install): check yabai supports a new macOS before upgrading, and
   install minor updates by hand from Software Update ("Other updates" lists same-major ones).
3. Approve Karabiner-Elements' driver (General > Login Items & Extensions) and log out/in. With SIP on you also
   have to do the rest by hand: grant Accessibility (yabai, skhd, AltTab, MiddleClick), Input Monitoring
   (Karabiner-Core-Service), give Ghostty and Terminal every Privacy & Security permission (Full Disk Access,
   Accessibility, Input Monitoring, Screen Recording, App Management, Developer Tools), re-run setup.sh from
   Ghostty (silences AltTab's monthly screen recording prompt) and add 11 Desktops in Mission Control.

## Keys (Cmd = SUPER, Cmd+Option = SUPER+ALT)

Modifiers are laid out like Linux, via Karabiner-Elements (`.config/karabiner/karabiner.json`):

| Physical key | Becomes | Used for |
|---|---|---|
| Caps Lock | Ctrl | Same as Ctrl |
| Ctrl | Linux-style Ctrl | Ctrl+C/V/S/T/W/F/Z/1..0... = Cmd+... in GUI apps, Ctrl+arrows/Backspace = word jump/delete, Home/End = line start/end. Real Ctrl in Ghostty/Terminal (copy/paste there is Ctrl+Shift+C/V) |
| Option | Alt | Never bound by skhd, so nvim/tmux get Meta (M-h, M-1..9, M-Enter) from either side |
| Cmd | SUPER | All window manager binds (skhd). Unbound Cmd combos still reach apps: Cmd+C/V/X, Cmd+Q, Cmd+Tab |
| Fn+H/J/K/L | Arrows | Everywhere, Shift works for selecting |

Karabiner swaps the Cmd keys: physical left Cmd sends right Cmd (SUPER), physical right Cmd sends left Cmd (a
normal Cmd), and the Ctrl shortcuts send left Cmd too. skhd binds only `rcmd`, so right Cmd and Ctrl+S stay normal. Screenshots move to Ctrl+Shift+3/4/5 (Ctrl+Option+Shift+3/4 to
the clipboard) and Spotlight's Cmd+Space goes to Raycast. Full list: `.config/skhd/skhdrc` (Cmd+I shows it).

| Key | Action |
|---|---|
| Cmd+Return / Cmd+Option+Return | Ghostty / Ghostty in tmux `Work` |
| Cmd+Space | Raycast (its own hotkey, so it toggles) |
| Option+Tab | AltTab (window switcher with previews) |
| Cmd+Shift+B / Return / Option+B | Helium / new window / incognito |
| Cmd+Shift+F, N, T, / | Finder, nvim, btop, KeePassXC |
| Cmd+W / Cmd+Shift+W / Cmd+S | close / force kill / minimize |
| Cmd+H/J/K/L, Shift+H/J/K/L | focus / move (warp) |
| Cmd+1..0, Shift+1..0 | Space / move window to Space |
| Cmd+A/D, Shift+A/D | prev/next Space / move window there |
| Cmd+F, Cmd+T, Cmd+\ | fullscreen, float, toggle split |
| Cmd+Shift+I, Ctrl+Shift+I | promote to largest, mirror split |
| Cmd+Option+G | quadrant mode (no gaps, no borders) |
| Cmd+Shift+Space | toggle menu bar auto-hide |
| Cmd+drag / right-drag | move / resize window (yabai takes Cmd+click; three-finger middle click opens links in a new tab) |
| F4 / F5 | keyboard brightness down / up (instead of Spotlight / Dictation) |

## Workspace bar

Workspaces 1-9 and 10 sit on SUPER+1..0; workspace "0" is the 11th Space on SUPER+` (move a window there:
SUPER+Shift+`) and is drawn first in the bar, matching the key left of 1. SUPER+A/D cycle in that order
(0, 1..10) and wrap around.
`.config/swiftbar/workspace.5s.sh` (SwiftBar) shows 1-5 plus any occupied Space; current = white pill,
occupied = white, empty = grey. Drawn by `.local/src/ws-render.swift` (built to `~/.local/bin/ws-render` by setup.sh).
yabai signals in `.config/yabai/yabairc` call `swiftbar://refreshplugin?name=workspace` so it redraws instantly.
It is deliberately not a streamable plugin: those reset their menu bar position on every SwiftBar start
(swiftbar/SwiftBar#458). To move it: SUPER+Shift+P (pause yabai), Cmd-drag it, SUPER+Shift+P again.

SUPER+Shift+P pauses/resumes yabai entirely (`.local/bin/yabai-pause`): yabai owns SUPER(Cmd)+drag and can't tell
left Cmd from right, so this is how Cmd-drag reaches macOS. While paused nothing tiles, the bar stops updating,
workspace keys fall back to the slower macOS switch (1-9 only), and alt-tab won't jump to other Spaces.

## Sacrifices vs Omarchy

- With SIP on (see above for turning it off), no yabai scripting addition: Space switching goes through macOS ctrl+N (slide animation;
  Accessibility > Reduce motion makes it a fade), Desktops are created by hand, no window opacity, no Space swapping,
  no scratchpad (yabai's needs the SA).
- Not ported (Linux/desktop only): gaming (stretched res, MangoHud caps, gamescope, crosshair, xpadneo), Sunshine,
  sddm/limine/plymouth, TPM2, reboot-to-windows, GPU toggle, monitor mirror/TV/pin, focus lock, window labels,
  per-window volume, SUPER+scroll zoom (use Accessibility > Zoom with a modifier), `clds` (Linux sudo wrapper). `c` runs `cld` (claude, bypass permissions, auto-trusts $PWD).
- Substitutes: Dolphin -> Finder, wiremix/bluetui -> System Settings, quickshell switcher -> AltTab,
  voxtype -> macOS Dictation, bash -> zsh (`.zshrc`), Waybar -> native menu bar + SwiftBar.
- Menu bar is pitch black because Reduce transparency is off and the wallpaper's top edge is black (macOS 15 has
  no menu bar colour setting; Reduce transparency makes it solid grey). A wallpaper with a lighter top shows through.
- Syncthing runs always (brew service) instead of being bound to a mount.
