# My macOS config

[Macarchy](https://github.com/HarryRandall/macarchy) (yabai, skhd, JankyBorders, Ghostty, LazyVim, theme-switch)
set up to work like my Omarchy [dotfiles](https://github.com/RyanAHayden/dotfiles).
The previous yabai/SketchyBar setup is in git history.

`./setup.sh` - installs packages and Macarchy, stows using --adopt so you can see git changes before
discarding what you want to change, applies the macOS settings and the `ryha-silver` theme.
Then grant Accessibility (yabai, skhd, AltTab, MiddleClick), add 10 Desktops in Mission Control and log out/in.

Re-running Macarchy's `./install` stops at files stowed from here (`skhdrc`, nvim); use `--force`, then re-run `stow . --adopt` and `git checkout .`.

## Keys (left Option = SUPER, Option+Cmd = SUPER+ALT)

Cmd is left alone for macOS apps. Right Option still reaches tmux as Meta (M-1..9, M-Enter).
Full list: `.config/skhd/local.skhdrc` (Option+I shows it).

| Key | Action |
|---|---|
| Option+Return / Option+Cmd+Return | Ghostty / Ghostty in tmux `Work` |
| Option+Space | Raycast |
| Option+Tab | AltTab (window switcher with previews) |
| Option+Shift+B / Return / Cmd+B | Helium / new window / incognito |
| Option+Shift+F, N, T, / | Finder, nvim, btop, KeePassXC |
| Option+W / Option+Shift+W / Option+S | close / force kill / minimize |
| Option+H/J/K/L, Shift+H/J/K/L | focus / move (warp) |
| Option+1..0, Shift+1..0 | Space / move window to Space |
| Option+A/D, Shift+A/D | prev/next Space / move window there |
| Option+F, Option+T, Option+\ | fullscreen, float, toggle split |
| Option+Shift+I, Ctrl+Shift+I | promote to largest, mirror split |
| Option+Cmd+G | quadrant mode (no gaps, no borders) |
| Option+Shift+Space | toggle menu bar auto-hide |
| Option+drag / right-drag | move / resize window |

## Workspace bar

`.config/swiftbar/workspace.sh` (SwiftBar, streamable) shows 1-5 plus any occupied Space; current = white pill,
occupied = white, empty = grey. Drawn by `.local/src/ws-render.swift` (built to `~/.local/bin/ws-render` by setup.sh).
yabai signals in `.config/yabai/local.yabairc` poke `~/.cache/ryha-workspace.fifo` so it redraws instantly.

## Sacrifices vs Omarchy

- SIP stays on, so no yabai scripting addition: Space switching goes through macOS ctrl+N (slide animation;
  Accessibility > Reduce motion makes it a fade), Desktops are created by hand, no window opacity, no Space swapping,
  no scratchpad (yabai's needs the SA).
- No real SUPER key: left Option combos bound in skhd can't type special characters.
- Not ported (Linux/desktop only): gaming (stretched res, MangoHud caps, gamescope, crosshair, xpadneo), Sunshine,
  sddm/limine/plymouth, TPM2, reboot-to-windows, GPU toggle, monitor mirror/TV/pin, focus lock, window labels,
  per-window volume, SUPER+scroll zoom (use Accessibility > Zoom with a modifier), `clds`.
- Substitutes: Dolphin -> Finder, wiremix/bluetui -> System Settings, quickshell switcher -> AltTab,
  voxtype -> macOS Dictation, bash -> zsh (`.config/zsh/local.zsh`), Waybar -> native menu bar + SwiftBar.
- Syncthing runs always (brew service) instead of being bound to a mount.
