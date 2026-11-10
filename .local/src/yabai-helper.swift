// One native process for the yabai extras that have to react fast, instead of yabai starting bash + yabai + jq per
// event (each yabai CLI query is ~10-15 ms; over the socket it's ~3 ms):
//   - workspace bar over the left side of the menu bar (Apple and app menus, up to the notch or the menu bar icons),
//     on every display, like Omarchy's Waybar. Clicks pass through; it disappears while the mouse is over it or a
//     menu opened from the bar is showing, so the menus underneath stay usable.
//   - mouse follows focus: when focus moves to another window (a new window, alt-tab, a close) and the mouse isn't
//     in it, move the mouse to it, so hover focus (focus_follows_mouse) doesn't hand focus back on the next nudge.
//     Not when hover gave it focus: a quick swipe across windows leaves the mouse where you swiped to.
//     yabai's own mouse_follows_focus only covers focus changes yabai makes itself.
//   - after a window closes, minimizes or its app quits, focus the next window on this Space (macOS leaves focus
//     on nothing, or on an app with no window here).
//   - instant alt-tab across Spaces (scripting addition only): if the activated app has no window on this Space,
//     jump to its most recent one (macOS's own "switch to a Space with open windows" is off, see yabairc).
//   - SUPER+M "minimize" without the ~300 ms macOS animation: the window is parked on a hidden Space (12) and comes
//     back to the Space you're on with SUPER+Option+M, by switching to its app (Dock, Cmd+Tab, Raycast) or by picking
//     it (AltTab).
//   - real macOS minimize (yellow button): the window is made sticky while minimized, so restoring it brings it up
//     on the Space you're on rather than switching back to the one it was minimized on.
//   - no Music: macOS starts it when Play is pressed (keyboard, AirPods) with nothing playing; quit it and play Spotify.
//   - the window and workspace binds (wmctl, below): workspaces (SUPER+N, A/D, Shift+N moves, which switch and move back
//     to back so the move doesn't flash), the scratchpad, Option+Tab cycling, resizing, groups, and closing, killing and
//     quitting apps. One command at a time in the order pressed, each a few socket queries instead of bash + yabai + jq.
//   - "Keep Awake With Lid Closed" (sleep disabled) leaves the screen on when the lid shuts: blank it when it closes.
//   - SUPER+F fullscreen (yabai zoom-fullscreen) gets a blue border, and stays on the workspace: whichever window
//     you focus there is the fullscreen one.
//   - focus lock (SUPER+Shift+O, .local/bin/focus-lock), like Omarchy's: new windows open without stealing focus.
//   - apps listed in ~/.config/yabai/see-through stay slightly see-through while focused (syncSeeThrough); other
//     focused windows are opaque (yabairc).
//   - scratchpad: shown as S in the bar slot of the workspace it stands in for, with its wallpaper dimmed (Dimmer).
//   - menu bar icons left of the notch: a red lock while focus lock is on, a cup while sleep is off (Keep Awake With Lid
//     Closed); and a red "yabai paused" notice in place of the workspaces while yabai isn't running (SUPER+Shift+P).
// yabai signals (yabairc) and scripts ping it with ~/.local/bin/notify-post wm.bar | wm.focus | wm.closed | wm.demin |
// wm.menubar <1 hidden, 0 shown> | wm.created <window> | wm.focuslock | wm.awake | wm.opaque (notifyutil takes
// ~100 ms); binds send commands with ~/.local/bin/wmctl (see Binds). Built to ~/.local/bin/yabai-helper by setup.sh,
// which runs it as a LaunchAgent.
import AppKit
import IOKit
import notify

// MARK: - yabai over its socket (same message format as `yabai -m`: int32 length, then each arg NUL-terminated, then NUL)

func unixAddress(_ path: String) -> sockaddr_un {
	var addr = sockaddr_un()
	addr.sun_family = sa_family_t(AF_UNIX)
	let bytes = Array(path.utf8CString)
	withUnsafeMutableBytes(of: &addr.sun_path) { dst in bytes.withUnsafeBytes { dst.copyMemory(from: UnsafeRawBufferPointer(rebasing: $0.prefix(dst.count))) } }
	return addr
}

func connectYabai() -> Int32? {
	let fd = socket(AF_UNIX, SOCK_STREAM, 0)
	guard fd >= 0 else { return nil }
	var timeout = timeval(tv_sec: 1, tv_usec: 0)
	setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
	var addr = unixAddress("/tmp/yabai_\(NSUserName()).socket")
	let connected = withUnsafePointer(to: &addr) {
		$0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
	}
	guard connected == 0 else { close(fd); return nil }
	return fd
}

// Not running (SUPER+Shift+P paused it, or it quit): its socket file stays but nothing accepts. A busy yabai still does.
func yabaiRunning() -> Bool {
	guard let fd = connectYabai() else { return false }
	close(fd)
	return true
}

func yabai(_ args: [String]) -> Data? {
	guard let fd = connectYabai() else { return nil }
	defer { close(fd) }
	var body = [UInt8]()
	for a in args { body += Array(a.utf8) + [0] }
	body.append(0)
	var msg = withUnsafeBytes(of: Int32(body.count)) { Array($0) }
	msg += body
	guard send(fd, msg, msg.count, 0) == msg.count else { return nil }
	var out = Data()
	var buf = [UInt8](repeating: 0, count: 65536)
	while true {
		let n = recv(fd, &buf, buf.count, 0)
		if n <= 0 { break }
		out.append(buf, count: n)
	}
	return out
}

// a command that worked: yabai answers a failure with 0x07, then the error
func ok(_ args: [String]) -> Bool { yabai(args).map { $0.first != 0x07 } ?? false }
func query(_ args: [String]) -> Any? { yabai(["query"] + args).flatMap { try? JSONSerialization.jsonObject(with: $0) } }
func list(_ args: [String]) -> [[String: Any]] { query(args) as? [[String: Any]] ?? [] }
func one(_ args: [String]) -> [String: Any]? { query(args) as? [String: Any] }
func focus(_ id: Int) { _ = yabai(["window", "--focus", String(id)]) }

func frame(_ w: [String: Any]) -> CGRect? { // yabai frames are in CG coordinates (origin top-left of the main display)
	guard let f = w["frame"] as? [String: Double], let x = f["x"], let y = f["y"], let wd = f["w"], let h = f["h"] else { return nil }
	return CGRect(x: x, y: y, width: wd, height: h)
}

func flag(_ w: [String: Any], _ key: String) -> Bool { w[key] as? Bool ?? false }

// A window you'd want focus on: not minimized, hidden or sticky (sticky = minimized ones parked on every Space, see
// syncMinimized, and popped-out ones), and a normal window rather than a panel or dialog
func usable(_ w: [String: Any]) -> Bool {
	!flag(w, "is-minimized") && !flag(w, "is-hidden") && !flag(w, "is-sticky") && w["role"] as? String == "AXWindow"
}

func currentSpace() -> Int? { one(["--spaces", "--space"])?["index"] as? Int }

let scratch = 11 // the scratchpad (SUPER+S), see Binds
let attic = 12 // hidden Space SUPER+M parks windows on (not in the bar, skipped by SUPER+A/D)

// Native fullscreen Desktops belong to the workspace they were made from (.local/bin/fs-origin records it):
// fullscreen Space id -> its workspace's Space id
func fsOrigins() -> [Int: Int] {
	let dir = NSHomeDirectory() + "/.cache/fs-origin/"
	var origins = [Int: Int]()
	for f in (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [] {
		if let fs = Int(f), let o = (try? String(contentsOfFile: dir + f, encoding: .utf8)).flatMap({ Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }) { origins[fs] = o }
	}
	return origins
}

// Without the scripting addition yabai can't switch Spaces: press macOS's own "Switch to Desktop N" (ctrl+alt+cmd+N,
// setup.sh). Needs Post Event access for this helper (SIP on: Privacy & Security > Accessibility, add yabai-helper).
func desktopKey(_ n: Int) {
	let codes: [Int: CGKeyCode] = [1: 18, 2: 19, 3: 20, 4: 21, 5: 23, 6: 22, 7: 26, 8: 28, 9: 25, 10: 29]
	guard let code = codes[n] else { return }
	for down in [true, false] {
		let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
		e?.flags = [.maskControl, .maskAlternate, .maskCommand]
		e?.post(tap: .cghidEventTap)
	}
}

// Focus lock is on while this file exists (.local/bin/focus-lock toggles it and posts wm.focuslock)
let lockFile = NSHomeDirectory() + "/.local/state/focus-lock"
var focusLocked = FileManager.default.fileExists(atPath: lockFile)
// Keep Awake With Lid Closed (pmset disablesleep, .config/raycast/scripts/power-lid-sleep.sh) is on
func sleepDisabled() -> Bool {
	let pm = NSDictionary(contentsOfFile: "/Library/Preferences/com.apple.PowerManagement.plist")
	return ((pm?["SystemPowerSettings"] as? [String: Any])?["SleepDisabled"] as? NSNumber)?.boolValue ?? false
}
var stayAwake = sleepDisabled()

// MARK: - Focus

final class Focus {
	var lastID = 0
	var warpedAt = Date.distantPast
	var warpedTo = CGPoint.zero
	var checkPending = false
	var closedAt = Date.distantPast // a close, quit, hide or Space switch: macOS activates some app right after
	var openingAt = Date.distantPast // a "new window" bind (wmctl opening): a window is on its way
	var trail = [(at: Date, point: CGPoint)]() // where the mouse has been in the last moment (global mouse monitor)
	var parked = [Int]() // SUPER+M'd window ids, oldest first (windows found on the attic without a record go last)
	let stuckDir = NSHomeDirectory() + "/.cache/yabai-min-sticky" // windows made sticky while minimized, one file per id

	// wm.focus: focus moved, or a window moved/resized. Opening several windows at once fires a burst of these,
	// so coalesce them and act on wherever focus ends up.
	// One query of the focused window per check, handed to each step (only a zoom handover changes it in between).
	func changed() {
		if focusLocked, holdFocus(one(["--windows", "--window"])) { return } // straight away, not after the burst: keys typed meanwhile go to the new window
		guard !checkPending else { return }
		checkPending = true
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
			self.checkPending = false
			var w = one(["--windows", "--window"])
			if self.holdFocus(w) { return } // focus goes straight back; don't zoom or move the mouse to the new window
			if self.syncZoom(w) { w = one(["--windows", "--window"]) }
			self.syncSeeThrough(w)
			self.followFocus(w)
		}
	}

	// SUPER+F (zoom-fullscreen): the border takes the theme's zoom colour (blue unless that's the border's) while a zoomed
	// window has focus. Toggling zoom fires
	// window_resized, so wm.focus lands here. Hover focus is off meanwhile: the zoomed window covers the Space, so
	// hover could only refocus it, and a mouse nudge right after alt-tab/SUPER+H/J/K/L would undo the switch
	// before passZoom hands the zoom over.
	var zoomColor = false
	var hoverFocus = "autoraise" // yabairc's focus_follows_mouse, put back when zoom loses focus

	// true when it handed the zoom to this window (its frame changed)
	@discardableResult
	func syncZoom(_ w: [String: Any]?) -> Bool {
		guard let w else { return false }
		let passed = !flag(w, "has-fullscreen-zoom") && passZoom(to: w)
		let zoomed = flag(w, "has-fullscreen-zoom") || passed
		guard zoomed != zoomColor else { return passed }
		zoomColor = zoomed
		if zoomed {
			if let d = yabai(["config", "focus_follows_mouse"]), let v = String(data: d, encoding: .utf8)?
				.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty, v != "off", v != "disabled" { hoverFocus = v }
			_ = yabai(["config", "focus_follows_mouse", "off"])
		} else {
			_ = yabai(["config", "focus_follows_mouse", hoverFocus])
		}
		let borders = Process()
		borders.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/borders")
		// the theme's colours (theme script): border-zoom while zoomed, else border, as bordersrc starts with
		func themed(_ file: String, _ fallback: String) -> String {
			(try? String(contentsOfFile: NSHomeDirectory() + "/.local/state/theme/" + file, encoding: .utf8))?
				.trimmingCharacters(in: .whitespacesAndNewlines) ?? fallback
		}
		borders.arguments = ["active_color=\(zoomed ? themed("border-zoom", "0xff3b82f6") : themed("border", "0xffe8ddd0"))"] // updates the running instance (bordersrc)
		try? borders.run()
		return passed
	}

	// SUPER+F is fullscreen for the workspace: when focus moves to another tiled window on a Space with a zoomed one
	// (SUPER+H/J/K/L, a new window, a close), the newly focused window takes over the zoom
	func passZoom(to w: [String: Any]) -> Bool {
		guard usable(w), !flag(w, "is-floating"), w["subrole"] as? String == "AXStandardWindow",
			let id = w["id"] as? Int, let space = w["space"] as? Int else { return false }
		let full = list(["--windows", "--space", String(space)]).compactMap { o -> Int? in
			guard let oid = o["id"] as? Int, oid != id, flag(o, "has-fullscreen-zoom"), !flag(o, "is-floating") else { return nil }
			return oid
		}
		guard !full.isEmpty else { return false }
		_ = yabai(["window", String(id), "--toggle", "zoom-fullscreen"])
		for oid in full { _ = yabai(["window", String(oid), "--toggle", "zoom-fullscreen"]) }
		return true
	}

	func followFocus(_ w: [String: Any]?) {
		guard NSEvent.pressedMouseButtons == 0, // dragging a window: leave the mouse alone
			let w, let id = w["id"] as? Int, let f = frame(w),
			let at = CGEvent(source: nil)?.location else { return }
		// something focused a parked window (AltTab, Raycast's window search): bring it here instead
		if w["space"] as? Int == attic, let space = currentSpace(), space != attic { bring(id, to: space); return }
		let fresh = id != lastID
		lastID = id
		if f.contains(at) { return } // hover focused it, or the mouse is already there
		// Hover focused it and the mouse has already moved on (a quick swipe across windows): the mouse's path crossed the
		// window. Warping back here would snap the cursor onto it. A fast swipe's samples can be hundreds of points
		// apart, landing either side of the window, so check the lines between them rather than the points.
		let path = trail.map(\.point) + [at]
		if zip(path, path.dropFirst()).contains(where: { crosses(f, $0, $1) }) { return }
		// Only new focus, or the same window still being tiled right after we moved the mouse to it (as long as the
		// mouse hasn't been touched since). Otherwise windows moving in the background would yank the mouse around.
		let settling = Date().timeIntervalSince(warpedAt) < 1.5 && hypot(at.x - warpedTo.x, at.y - warpedTo.y) < 2
		guard fresh || settling, w["subrole"] as? String == "AXStandardWindow" else { return } // not Raycast & co.
		let c = CGPoint(x: f.midX, y: f.midY)
		CGWarpMouseCursorPosition(c)
		CGAssociateMouseAndMouseCursorPosition(1) // warping freezes the cursor briefly otherwise
		warpedAt = Date()
		warpedTo = c
	}

	// Does the line from a to b pass through r? Checked every few points along it.
	func crosses(_ r: CGRect, _ a: CGPoint, _ b: CGPoint) -> Bool {
		let steps = max(1, Int(hypot(b.x - a.x, b.y - a.y) / 4))
		return (0...steps).contains { i in
			let t = CGFloat(i) / CGFloat(steps)
			return r.contains(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
		}
	}

	// Mouse moved: keep the last second of positions; a swipe fires a burst of hover focus changes that can reach
	// followFocus several hundred ms behind the mouse
	func track(_ point: CGPoint?) {
		guard let point else { return }
		let now = Date()
		trail.removeAll { now.timeIntervalSince($0.at) > 1 }
		trail.append((now, point))
	}

	// wm.closed: macOS picks what gets focus a little after the close; check soon, and again in case it lands late
	func closed() {
		closedAt = Date()
		syncMinimized()
		for delay in [0.04, 0.15] { DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.refocus() } }
	}

	func refocus() {
		guard let space = currentSpace() else { return }
		if let w = one(["--windows", "--window"]), w["space"] as? Int == space || flag(w, "is-sticky") { return }
		// front-to-back, so the first match is the most recently used window here
		if let id = list(["--windows", "--space"]).first(where: { usable($0) && flag($0, "is-visible") })?["id"] as? Int { focus(id) }
	}

	// Instant alt-tab: macOS's own Space switch on activate is off (yabairc, scripting addition only), so do it here
	func activated(_ app: NSRunningApplication) {
		// the activation a close, quit, hide or Space switch causes, not an alt-tab. Those land 70-110 ms after; 300 ms
		// covers them without eating a real alt-tab.
		if Date().timeIntervalSince(closedAt) < 0.3 { return }
		let pid = Int(app.processIdentifier)
		guard let space = currentSpace(), space != attic else { return }
		let windows = list(["--windows"])
		let mine = windows.filter { $0["pid"] as? Int == pid && !flag($0, "is-minimized") && !flag($0, "is-hidden") }
		// already has a window here. Sticky ones (a PiP) count as here: yabai reports them on one Space (often the
		// attic), so hovering one would otherwise jump to the app's main window.
		if mine.contains(where: { $0["space"] as? Int == space || flag($0, "is-sticky") }) { return }
		// switching to an app whose windows are all parked (Dock, Cmd+Tab, Raycast) brings back its latest one
		let atticIDs = mine.filter { $0["space"] as? Int == attic && !flag($0, "is-sticky") }.compactMap { $0["id"] as? Int }
		if !atticIDs.isEmpty, !mine.contains(where: { $0["space"] as? Int != attic && !flag($0, "is-sticky") }) {
			bring(parked.last(where: atticIDs.contains) ?? atticIDs[0], to: space)
			return
		}
		guard let switchOnActivate = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleSpacesSwitchOnActivate"] as? NSNumber,
			!switchOnActivate.boolValue else { return }
		// a "new window" bind just ran: a window is on its way, so stay put
		if Date().timeIntervalSince(openingAt) < 2 { return }
		// front-to-back, so the first match is the app's most recently used window
		if let id = mine.first(where: { !flag($0, "is-sticky") && $0["space"] as? Int != attic })?["id"] as? Int { focus(id) }
	}

	// wmctl ws move: take the focused window to that Space and follow it. Switch first, then
	// move it onto the now-visible Space (yabai only tiles visible Spaces, so moving first shows it at its old size
	// for a moment), and send both over the socket back to back so the empty Space shows for under a frame.
	func move(to space: Int) {
		guard let id = one(["--windows", "--window"])?["id"] as? Int, space != currentSpace() else { return }
		closedAt = Date() // the switch makes macOS activate an app; that's not an alt-tab
		let switched = yabai(["space", "--focus", String(space)]).map { $0.first != 0x07 } ?? false // 0x07 = yabai error
		_ = yabai(["window", String(id), "--space", String(space)])
		if switched { focus(id) } else { desktopKey(space) } // without the scripting addition: macOS's Desktop shortcut
	}

	// MARK: see-through while focused

	// Focused windows are fully opaque (yabairc); apps listed in ~/.config/yabai/see-through stay slightly see-through
	// while focused too (unfocused, every window fades). Their focused window gets its own opacity, dropped again when
	// focus moves on; windows pinned with SUPER+Backspace (.local/bin/window-opacity, a marker per id) are left alone.
	// The list is read again when it changes, so edits apply on the next focus change.
	let seeThroughOpacity = "0.95"
	var seeThroughID = 0

	var seeThroughRead: (at: Date, apps: Set<String>)?
	func seeThroughApps() -> Set<String> {
		let path = NSHomeDirectory() + "/.config/yabai/see-through"
		let changed = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date ?? .distantPast
		if let r = seeThroughRead, r.at == changed { return r.apps }
		let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
		let apps = Set(text.split(separator: "\n").map { $0.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
			.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
		seeThroughRead = (changed, apps)
		return apps
	}

	func syncSeeThrough(_ w: [String: Any]?) {
		let id = w?["id"] as? Int ?? 0
		guard id != seeThroughID else { return }
		if seeThroughID != 0, !pinned(seeThroughID) { _ = yabai(["window", String(seeThroughID), "--opacity", "0.0"]) } // 0 = back to yabairc's
		seeThroughID = 0
		guard let w, let app = w["app"] as? String, seeThroughApps().contains(app), !pinned(id) else { return }
		_ = yabai(["window", String(id), "--opacity", seeThroughOpacity])
		seeThroughID = id
	}

	// wm.opaque: SUPER+Backspace unpinned a window, which drops its opacity back to yabairc's; a focused listed one is see-through again
	func repin() {
		if seeThroughID != 0, !pinned(seeThroughID) { _ = yabai(["window", String(seeThroughID), "--opacity", seeThroughOpacity]) }
	}

	func pinned(_ id: Int) -> Bool { FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.cache/yabai-opaque/\(id)") }

	// MARK: focus lock

	// Like hypr-win's: focus that lands on a window opened under a second ago is stolen and goes back to the window that
	// had it; any other focus change (binds, hover, alt-tab, clicking the new window later) moves the lock to that window.
	let stealGrace: TimeInterval = 1
	var born = [Int: Date]() // windows opened while locked (wm.created)
	var lockTarget = 0, prevTarget = 0
	var targetSetAt = Date.distantPast

	func lockChanged() {
		focusLocked = FileManager.default.fileExists(atPath: lockFile)
		born = [:]
		prevTarget = 0
		lockTarget = focusLocked ? one(["--windows", "--window"])?["id"] as? Int ?? 0 : 0
	}

	func holdFocus(_ w: [String: Any]?) -> Bool {
		guard focusLocked, let id = w?["id"] as? Int, id != lockTarget else { return false }
		if let at = born[id], Date().timeIntervalSince(at) < stealGrace, lockTarget != 0 {
			focus(lockTarget)
			return true
		}
		prevTarget = lockTarget
		lockTarget = id
		targetSetAt = Date()
		return false
	}

	// wm.created: remember it, and take focus back if it already has it. yabai can report the focus before the window, in which case holdFocus already took it for
	// a focus change you made; hand it back.
	func created(_ id: Int) {
		guard focusLocked else { return }
		let now = Date()
		born = born.filter { now.timeIntervalSince($0.value) < stealGrace }
		born[id] = now
		if one(["--windows", "--window"])?["id"] as? Int == id, lockTarget != 0, lockTarget != id { focus(lockTarget); return }
		if id == lockTarget, prevTarget != 0, now.timeIntervalSince(targetSetAt) < stealGrace {
			lockTarget = prevTarget
			focus(lockTarget)
		}
	}

	// MARK: SUPER+M parking

	func hide() {
		guard let w = one(["--windows", "--window"]), let id = w["id"] as? Int, usable(w),
			let space = currentSpace(), space != attic else { return }
		closedAt = Date() // macOS activates another app after this; that's not a switch to it
		parked.removeAll { $0 == id }
		parked.append(id)
		_ = yabai(["window", String(id), "--space", String(attic)])
		refocus()
	}

	func unhide() {
		guard let space = currentSpace(), space != attic else { return }
		let here = list(["--windows", "--space", String(attic)]).filter(usable).compactMap { $0["id"] as? Int }
		parked.removeAll { !here.contains($0) }
		if let id = parked.last ?? here.first { bring(id, to: space) }
	}

	// Never stay on the attic. Closing an app's last window makes macOS activate another app, and if that app's only
	// window is parked there, macOS switches to Space 12 (activated() deliberately ignores activations right after a
	// close). Go back to where you were and bring that window along, the same as switching to a parked app does.
	func leaveAttic() {
		guard currentSpace() == attic, let back = one(["--spaces", "--space", "recent"])?["index"] as? Int, back != attic else { return }
		closedAt = Date() // the switch back makes macOS activate an app; that's not an alt-tab
		let front = NSWorkspace.shared.frontmostApplication.map { Int($0.processIdentifier) }
		let here = list(["--windows", "--space", String(attic)]).filter { usable($0) }
		_ = yabai(["space", "--focus", String(back)])
		if let w = here.first(where: { $0["pid"] as? Int == front }), let id = w["id"] as? Int { bring(id, to: back) }
	}

	func bring(_ id: Int, to space: Int) {
		parked.removeAll { $0 == id }
		_ = yabai(["window", String(id), "--space", String(space)])
		focus(id)
	}

	// MARK: real macOS minimize

	// wm.closed (minimized, closed, quit) and wm.demin: minimized windows become sticky; ones restored since are
	// un-stuck (re-tiled here) and focused; markers of windows that are gone are dropped (ids get reused)
	func syncMinimized() {
		try? FileManager.default.createDirectory(atPath: stuckDir, withIntermediateDirectories: true)
		let windows = list(["--windows"])
		guard !windows.isEmpty else { return }
		let byID = Dictionary(windows.compactMap { w in (w["id"] as? Int).map { ($0, w) } }, uniquingKeysWith: { a, _ in a })
		let stuck = Set((try? FileManager.default.contentsOfDirectory(atPath: stuckDir))?.compactMap(Int.init) ?? [])
		for (id, w) in byID where flag(w, "is-minimized") && !flag(w, "is-sticky") && !stuck.contains(id) {
			FileManager.default.createFile(atPath: "\(stuckDir)/\(id)", contents: nil)
			_ = yabai(["window", String(id), "--toggle", "sticky"])
		}
		for id in stuck {
			guard let w = byID[id] else { try? FileManager.default.removeItem(atPath: "\(stuckDir)/\(id)"); continue }
			if flag(w, "is-minimized") { continue }
			try? FileManager.default.removeItem(atPath: "\(stuckDir)/\(id)")
			if flag(w, "is-sticky") { _ = yabai(["window", String(id), "--toggle", "sticky"]) }
			focus(id)
		}
	}
}

// MARK: - Workspace bar

let slotW: CGFloat = 24, pillH: CGFloat = 22, pad: CGFloat = 6, iconW: CGFloat = 22

// SF Symbols drawn at the bar's right end, just left of the notch (or the menu bar icons), like the dotfiles' Waybar ones
func indicators() -> [(name: String, color: NSColor)] {
	(focusLocked ? [("lock.fill", NSColor.systemRed)] : []) + (stayAwake ? [("cup.and.saucer.fill", NSColor.white)] : [])
}

// yabai stopped: a red notice in place of the workspaces (which would be stale), so it's obvious nothing is tiling
let pausedText = NSAttributedString(string: "YABAI PAUSED  ·  SUPER+SHIFT+P",
	attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .heavy), .foregroundColor: NSColor.white])

typealias Item = (label: String, state: Character) // a = shown on its display, o = has windows, e = empty

// 1-5 always, higher Spaces when occupied or shown. Space 11, the scratchpad, isn't drawn: while it's shown it stands in
// for the workspace you came from (Binds.pad), which stays lit. Only real windows count (not sticky, minimized or hidden ones). Keyed by display UUID; nil if yabai didn't answer (busy or
// restarting), so the bar keeps what it shows instead of blinking off and uncovering the menus.
var onFullscreen = false // a display shows a native fullscreen Desktop (set by workspaces())
// Menu bar set to auto-hide (SUPER+Shift+Space, .local/bin/toggle-menubar): no bar. toggle-menubar posts wm.menubar with
// the new state (1 = hidden); read once at launch. Not re-read from preferences each time: a long-running process can
// keep a stale cached value.
var menuBarHidden: Bool = {
	CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
	return CFPreferencesGetAppBooleanValue("_HIHideMenuBar" as CFString, kCFPreferencesAnyApplication, nil)
}()

func workspaces() -> [String: [Item]]? {
	guard let windows = query(["--windows"]) as? [[String: Any]], let displays = query(["--displays"]) as? [[String: Any]],
		let spaces = query(["--spaces"]) as? [[String: Any]], !displays.isEmpty, !spaces.isEmpty else { return nil }
	let real = Set(windows.filter {
		!flag($0, "is-sticky") && !flag($0, "is-minimized") && !flag($0, "is-hidden")
	}.compactMap { $0["id"] as? Int })
	var uuidOf = [Int: String]()
	for d in displays { if let i = d["index"] as? Int, let u = d["uuid"] as? String { uuidOf[i] = u } }
	// Native fullscreen Desktops belong to the workspace they came from (.local/bin/fs-origin): shown as "F" right after it
	var indexOf = [Int: Int]()
	for s in spaces { if let id = s["id"] as? Int, let i = s["index"] as? Int { indexOf[id] = i } }
	var originOf = [Int: Int]() // fullscreen space index -> its workspace's index
	for (fs, o) in fsOrigins() { if let fi = indexOf[fs], let oi = indexOf[o] { originOf[fi] = oi } }
	let parents = Set(originOf.values)
	let padShown = spaces.contains { $0["index"] as? Int == scratch && flag($0, "is-visible") }
	let ret = scratchReturn()
	var rows = [String: [(Double, Item)]]()
	var fullscreen = Set<String>() // displays showing a native fullscreen Space: no menu bar there, so no bar
	for s in spaces {
		guard let i = s["index"] as? Int, i != attic, i != scratch, let d = s["display"] as? Int, let uuid = uuidOf[d] else { continue }
		let shown = flag(s, "is-visible") || (padShown && i == ret)
		if flag(s, "is-native-fullscreen") {
			if flag(s, "is-visible") { fullscreen.insert(uuid) }
			rows[uuid, default: []].append((Double(originOf[i] ?? 100 + i) + 0.5, ("F", shown ? "a" : "o")))
			continue
		}
		let occupied = (s["windows"] as? [Int] ?? []).contains { real.contains($0) }
		guard i <= 5 || shown || occupied || parents.contains(i) else { continue }
		let label = padShown && i == ret ? "S" : String(i) // the scratchpad shows in the slot of the workspace it stands in for
		rows[uuid, default: []].append((Double(i), (label, shown ? "a" : occupied ? "o" : "e")))
	}
	for uuid in fullscreen { rows[uuid] = [] } // layout() orders out a display's bar with no items
	onFullscreen = !fullscreen.isEmpty
	return rows.mapValues { $0.sorted { $0.0 < $1.0 }.map(\.1) }
}

func uuid(of screen: NSScreen) -> String? {
	guard let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
		let u = CGDisplayCreateUUIDFromDisplayID(n)?.takeRetainedValue() else { return nil }
	return CFUUIDCreateString(nil, u) as String
}

// The window server's on-screen windows; fetched once per layout or check and handed to the functions below
func screenWindows() -> [[String: Any]] { CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? [] }

// The menu bar's height: the window server's Menubar window on that screen (37 points on a notched display, where
// visibleFrame leaves a point more, so the bar hung below the menu bar), else the gap above visibleFrame
func barHeight(_ screen: NSScreen, _ list: [[String: Any]]) -> CGFloat {
	for w in list where w[kCGWindowName as String] as? String == "Menubar" {
		if let b = w[kCGWindowBounds as String] as? [String: CGFloat], b["X"] == screen.frame.minX, let h = b["Height"], h > 0 { return h }
	}
	return screen.frame.maxY - screen.visibleFrame.maxY
}

// The left side of the menu bar: up to the notch, or else up to the first menu bar icon (status items) on that screen
func leftWidth(_ screen: NSScreen, _ list: [[String: Any]]) -> CGFloat {
	if let notch = screen.auxiliaryTopLeftArea, notch.width > 0 { return notch.width }
	let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
	let icons = list.compactMap { w -> CGFloat? in
		guard w[kCGWindowLayer as String] as? Int == statusLevel, let b = w[kCGWindowBounds as String] as? [String: CGFloat],
			let x = b["X"], x > screen.frame.minX, x < screen.frame.maxX else { return nil }
		return x
	}
	return (icons.min().map { $0 - screen.frame.minX - 8 }) ?? screen.frame.width / 2
}

final class Row: NSView {
	var items: [Item] = [] { didSet { needsDisplay = true } }
	var icons: [(name: String, color: NSColor)] = [] { didSet { needsDisplay = true } }
	var paused = false { didSet { needsDisplay = true } }
	override func draw(_ dirty: NSRect) {
		NSColor.black.setFill() // the menu bar is black (set-wallpaper paints the wallpaper's top black), so this blends in over the menus it covers
		bounds.fill()
		if paused {
			let size = pausedText.size()
			let pill = NSRect(x: pad, y: (bounds.height - pillH) / 2, width: size.width + 20, height: pillH)
			NSColor.systemRed.setFill()
			NSBezierPath(roundedRect: pill, xRadius: 5, yRadius: 5).fill()
			pausedText.draw(at: NSPoint(x: pill.minX + 10, y: pill.midY - size.height / 2 + 0.5))
		}
		let font = NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .medium)
		for (i, item) in items.enumerated() {
			let slot = NSRect(x: pad + CGFloat(i) * slotW, y: (bounds.height - pillH) / 2, width: slotW, height: pillH)
			var color = NSColor.white
			switch item.state {
			case "a":
				NSColor.white.setFill()
				NSBezierPath(roundedRect: slot.insetBy(dx: 3, dy: 3), xRadius: 5, yRadius: 5).fill()
				color = .black
			case "o": color = NSColor.white.withAlphaComponent(0.95)
			default: color = NSColor.white.withAlphaComponent(0.38)
			}
			let text = NSAttributedString(string: item.label, attributes: [.font: font, .foregroundColor: color])
			let size = text.size()
			text.draw(at: NSPoint(x: slot.midX - size.width / 2, y: slot.midY - size.height / 2 + 0.5))
		}
		for (i, icon) in icons.reversed().enumerated() {
			let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium).applying(.init(paletteColors: [icon.color]))
			guard let image = NSImage(systemSymbolName: icon.name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { continue }
			let slot = NSRect(x: bounds.maxX - pad - CGFloat(i + 1) * iconW, y: 0, width: iconW, height: bounds.height)
			image.draw(in: NSRect(x: slot.midX - image.size.width / 2, y: slot.midY - image.size.height / 2,
				width: image.size.width, height: image.size.height))
		}
	}
}

final class Bar {
	var panels = [String: (panel: NSPanel, row: Row, screen: NSScreen)]()
	var hidden = false
	var refreshPending = false

	func rebuild() {
		panels.values.forEach { $0.panel.orderOut(nil) }
		panels = [:]
		for screen in NSScreen.screens {
			guard let id = uuid(of: screen) else { continue }
			let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
			panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
			panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle] // not over native fullscreen apps
			panel.ignoresMouseEvents = true
			panel.hasShadow = false
			panel.isOpaque = true
			panel.hidesOnDeactivate = false
			let row = Row()
			panel.contentView = row
			panels[id] = (panel, row, screen)
		}
		refresh()
	}

	// wm.bar arrives in bursts (a window opening fires several events); redraw once per burst
	func refresh() {
		guard !refreshPending else { return }
		refreshPending = true
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
			self.refreshPending = false
			if !yabaiRunning() { self.layout([:], paused: true) } else if let rows = workspaces() { self.layout(rows) }
		}
	}

	var leftFullscreen = false
	func layout(_ rows: [String: [Item]], paused: Bool = false) {
		// A panel ordered out on a native fullscreen Desktop comes back pinned to the one Space it's shown on again
		// (canJoinAllSpaces lost, re-ordering doesn't help); fresh panels join all Spaces, so rebuild once on the way out.
		if onFullscreen { leftFullscreen = true } else if leftFullscreen { leftFullscreen = false; rebuild(); return }
		let icons = indicators()
		let windows = screenWindows()
		for (id, p) in panels {
			let h = barHeight(p.screen, windows)
			let items = rows[id] ?? []
			guard h > 0, !menuBarHidden, paused || !items.isEmpty else { p.panel.orderOut(nil); continue } // menu bar auto-hidden, or no Spaces there
			if p.row.items.map(\.label) != items.map(\.label) || p.row.items.map(\.state) != items.map(\.state) { p.row.items = items }
			if p.row.icons.map(\.name) != icons.map(\.name) { p.row.icons = icons }
			if p.row.paused != paused { p.row.paused = paused }
			let content = paused ? pausedText.size().width + 20 : slotW * CGFloat(items.count)
			let w = max(pad * 2 + content + iconW * CGFloat(icons.count), leftWidth(p.screen, windows))
			let f = NSRect(x: p.screen.frame.minX, y: p.screen.frame.maxY - h, width: w, height: h)
			if p.panel.frame != f { p.panel.setFrame(f, display: true) }
			p.panel.alphaValue = hidden ? 0 : 1
			if !p.panel.isVisible { p.panel.orderFrontRegardless() }
		}
	}

	// Hide while the mouse is on the bar; once hidden, stay hidden while a menu dropped from the menu bar is open
	// (you went for the Apple or an app menu), so its title and the menus next to it aren't covered again.
	func trackMouse() {
		let m = NSEvent.mouseLocation
		var hide = panels.values.contains { $0.panel.isVisible && $0.panel.frame.insetBy(dx: -1, dy: -1).contains(m) }
		if !hide && hidden { hide = menuOpen() }
		guard hide != hidden else { return }
		hidden = hide
		panels.values.forEach { $0.panel.alphaValue = hide ? 0 : 1 }
	}

	func menuOpen() -> Bool {
		guard let mainH = NSScreen.screens.first?.frame.height else { return false }
		let list = screenWindows()
		let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
		// where a menu dropped from each display's menu bar starts
		let menuTops = panels.values.map { mainH - $0.screen.frame.maxY + barHeight($0.screen, list) }
		return list.contains { w in
			guard w[kCGWindowLayer as String] as? Int == menuLevel,
				let b = w[kCGWindowBounds as String] as? [String: CGFloat], let y = b["Y"] else { return false }
			// a menu bar menu starts right under the bar of its display (CG coordinates: origin top-left of the main display)
			return menuTops.contains { abs(y - $0) < 4 }
		}
	}
}

// MARK: - Binds (wmctl)

// The window and workspace binds in bindings.conf send their command here with ~/.local/bin/wmctl, one datagram each on
// ~/.cache/yabai-helper.sock (args NUL-separated). They run on the main queue one after another, so quick presses queue
// in order instead of overlapping (reading focus mid-switch) or being dropped.
//   ws focus|move|silent <N|prev|next>, ws focus recent   workspaces (silent: send the window there, stay here)
//   pad toggle|show|move                                  scratchpad
//   cycle next|prev                                       Option+Tab through this workspace's windows
//   resize w|h <px>                                       grow/shrink the focused window
//   group toggle|into <dir>|next|prev                     groups (yabai stacks)
//   close | kill | quit                                   SUPER+W / SUPER+Shift+W / SUPER+Q
//   hide | unhide                                         SUPER+M parking (Focus)
//   opening                                               a "new window" bind is about to open one (Focus.activated)

// The scratchpad stands in for the Space you came from (the bar lights that slot as S, SUPER+A/D go on from it). Kept in
// a file so the bar and a restarted helper know it.
let returnFile = NSHomeDirectory() + "/.cache/scratchpad-return"
func scratchReturn() -> Int {
	(try? String(contentsOfFile: returnFile, encoding: .utf8)).flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
		.flatMap { $0 == scratch ? nil : $0 } ?? 1
}

final class Binds {
	let focuser: Focus
	init(_ focuser: Focus) { self.focuser = focuser }

	func run(_ a: [String]) {
		let arg = a.count > 1 ? a[1] : "", arg2 = a.count > 2 ? a[2] : ""
		switch (a.first ?? "", arg) {
		case ("ws", "focus"): wsFocus(arg2)
		case ("ws", "move"): if let n = resolve(arg2) { focuser.move(to: n) }
		case ("ws", "silent"): wsSilent(arg2)
		case ("pad", _): pad(arg)
		case ("cycle", _): cycle(arg)
		case ("resize", _): if let d = Int(arg2) { resize(arg, d) }
		case ("group", _): group(arg, arg2)
		case ("close", _): close()
		case ("kill", _): forceKill()
		case ("quit", _): quit()
		case ("hide", _): focuser.hide(); bar.refresh()
		case ("unhide", _): focuser.unhide(); bar.refresh()
		case ("opening", _): focuser.openingAt = Date()
		default: NSLog("wmctl: unknown command %@", a.joined(separator: " "))
		}
	}

	// MARK: workspaces

	// prev/next go through 1..10 on this display and wrap around at either end, skipping the scratchpad and the attic;
	// a fullscreen Desktop comes right after its workspace (2, 2's fullscreen app, 3, ...). On the scratchpad they go on
	// from the workspace it stands in for.
	func resolve(_ t: String) -> Int? {
		if let n = Int(t) { return n }
		guard t == "prev" || t == "next", var cur = currentSpace() else { return nil }
		if cur == scratch { cur = scratchReturn() }
		let spaces = list(["--spaces", "--display"])
		var indexOf = [Int: Int]()
		for s in spaces { if let id = s["id"] as? Int, let i = s["index"] as? Int { indexOf[id] = i } }
		let origins = fsOrigins()
		let fs = spaces.filter { flag($0, "is-native-fullscreen") }.compactMap { s -> (index: Int, origin: Int?)? in
			guard let i = s["index"] as? Int, let id = s["id"] as? Int else { return nil }
			return (i, origins[id].flatMap { indexOf[$0] })
		}
		let plain = spaces.filter { !flag($0, "is-native-fullscreen") }.compactMap { $0["index"] as? Int }
			.filter { $0 < scratch || $0 == cur }.sorted()
		var order = plain.flatMap { n in [n] + fs.filter { $0.origin == n }.map(\.index) }
		order += fs.map(\.index).filter { !order.contains($0) }
		guard !order.isEmpty else { return nil }
		let i = order.firstIndex(of: cur) ?? 0
		return order[((i + (t == "next" ? 1 : -1)) % order.count + order.count) % order.count]
	}

	func wsFocus(_ t: String) {
		focuser.closedAt = Date() // the switch makes macOS activate an app; that's not an alt-tab
		if t == "recent" { _ = yabai(["space", "--focus", "recent"]); return } // no macOS shortcut for it without the SA
		guard var n = resolve(t) else { return }
		if Int(t) != nil, let kid = fullscreenKid(n) { n = kid }
		if !ok(["space", "--focus", String(n)]) { desktopKey(n) }
	}

	// SUPER+N: when workspace N's only window is fullscreen (or you're already on N), go to its fullscreen Desktop
	func fullscreenKid(_ n: Int) -> Int? {
		let origins = fsOrigins()
		guard !origins.isEmpty else { return nil }
		let spaces = list(["--spaces"])
		guard let ws = spaces.first(where: { $0["index"] as? Int == n }), let wsID = ws["id"] as? Int else { return nil }
		let kids = spaces.filter { flag($0, "is-native-fullscreen") && origins[$0["id"] as? Int ?? -1] == wsID }.compactMap { $0["index"] as? Int }
		guard let kid = kids.first else { return nil }
		let own = list(["--windows"]).contains { $0["space"] as? Int == n && !flag($0, "is-sticky") && !flag($0, "is-minimized") && !flag($0, "is-hidden") }
		return !own || flag(ws, "has-focus") ? kid : nil
	}

	// send the focused window to Space t and stay here, focusing a window left on this Space (not the moved one, which
	// would pull us over to it)
	func wsSilent(_ t: String) {
		guard let n = resolve(t) else { return }
		focuser.closedAt = Date()
		guard ok(["window", "--space", String(n)]) else { return }
		if let id = list(["--windows", "--space"]).first(where: { flag($0, "is-visible") && !flag($0, "is-minimized") && !flag($0, "has-focus") })?["id"] as? Int { focus(id) }
	}

	// Omarchy's scratchpad as the 11th Space, tiled like any other; Discord, Spotify and KeePassXC live there (yabairc).
	//   toggle: go there, or back to the Space you came from if you're on it; show: go there (stay if already there);
	//   move: send the focused window there (stay here); on the scratchpad, send it back instead
	func pad(_ action: String) {
		guard let cur = currentSpace() else { return }
		let leave = { try? String(cur).write(toFile: returnFile, atomically: true, encoding: .utf8) }
		switch action {
		case "toggle": if cur == scratch { wsFocus(String(scratchReturn())) } else { leave(); wsFocus(String(scratch)) }
		case "show": if cur != scratch { leave(); wsFocus(String(scratch)) }
		case "move": wsSilent(String(cur == scratch ? scratchReturn() : scratch))
		default: break
		}
	}

	// MARK: windows

	// Option+Tab / Option+Shift+Tab: focus the next/previous window on this workspace, tiled and floating alike (yabai's
	// own --focus next/prev only walks the tiling tree), left to right then top to bottom, wrapping around. A fullscreen
	// (SUPER+F) window's frame is the whole Space, which would sort it first every time and bounce between two windows as
	// the zoom follows focus, so while one is zoomed it keeps the order saved when none was.
	var cycleOrder = [Int: [Int]]() // Space id -> window ids

	func cycle(_ dir: String) {
		guard let space = one(["--spaces", "--space"])?["id"] as? Int else { return }
		let all = list(["--windows", "--space"]).filter { flag($0, "is-visible") && !flag($0, "is-minimized") && !flag($0, "is-hidden") }
		let framed: [(frame: CGRect, id: Int)] = all.compactMap { w in
			guard let f = frame(w), let id = w["id"] as? Int else { return nil }
			return (f, id)
		}
		let byFrame = framed.sorted { a, b in a.frame.minX != b.frame.minX ? a.frame.minX < b.frame.minX : a.frame.minY < b.frame.minY }.map(\.id)
		var order = byFrame
		if all.contains(where: { flag($0, "has-fullscreen-zoom") }) {
			let kept = (cycleOrder[space] ?? []).filter(byFrame.contains)
			order = kept + byFrame.filter { !kept.contains($0) }
		}
		cycleOrder[space] = order
		guard order.count > 1 else { return }
		let focused = all.first { flag($0, "has-focus") }?["id"] as? Int
		let i = focused.flatMap { order.firstIndex(of: $0) } ?? -1
		let n = order.count
		focus(order[((i + (dir == "prev" ? -1 : 1)) % n + n) % n])
	}

	// Grow (+) or shrink (-) the focused window by px, Omarchy SUPER+-/= style. yabai resizes a tiled window by dragging
	// the edge it shares with a neighbour, so drag the right/bottom edge when there's a window that side, else the
	// left/top one the other way. Floating windows grow from bottom-right.
	func resize(_ axis: String, _ d: Int) {
		guard let w = one(["--windows", "--window"]) else { return }
		let wide = axis == "w"
		if flag(w, "is-floating") { _ = yabai(["window", "--resize", wide ? "bottom_right:\(d):0" : "bottom_right:0:\(d)"]); return }
		if one(["--windows", "--window", wide ? "east" : "south"]) != nil {
			_ = yabai(["window", "--resize", wide ? "right:\(d):0" : "bottom:0:\(d)"])
		} else {
			_ = yabai(["window", "--resize", wide ? "left:\(-d):0" : "top:0:\(-d)"])
		}
	}

	// Omarchy window groups as yabai stacks (windows sharing one tile, one shown at a time).
	//   toggle: ungroup the focused window, or group it with its nearest neighbour; into <dir>: move it into the
	//   window/group to west|east|north|south; next|prev: cycle the windows in the focused group (wraps)
	func group(_ action: String, _ dir: String) {
		switch action {
		case "next": if !ok(["window", "--focus", "stack.next"]) { _ = yabai(["window", "--focus", "stack.first"]) }
		case "prev": if !ok(["window", "--focus", "stack.prev"]) { _ = yabai(["window", "--focus", "stack.last"]) }
		case "toggle", "into":
			guard let w = one(["--windows", "--window"]), let id = w["id"] as? Int else { return }
			let stacked = (w["stack-index"] as? Int ?? 0) > 0
			// yabai has no unstack: floating drops it out of the stack, unfloating re-tiles it
			if stacked, ok(["window", String(id), "--toggle", "float"]) { _ = yabai(["window", String(id), "--toggle", "float"]) }
			if action == "into" { _ = yabai(["window", dir, "--stack", String(id)]) }
			else if !stacked { for d in ["east", "west", "south", "north"] where ok(["window", d, "--stack", String(id)]) { break } }
		default: break
		}
	}

	// MARK: closing

	// The window SUPER+W/Shift+W/Q act on: the focused one if it's on screen. yabai sometimes loses track of focus
	// (e.g. Infuse/Catalyst video players), so else the frontmost app's window on screen. Never one on another Space: on
	// an empty workspace macOS keeps the last app frontmost with its windows elsewhere (SUPER+Q there quit a Moonlight
	// stream on the scratchpad), so then nothing happens.
	func target() -> [String: Any]? {
		if let w = one(["--windows", "--window"]), flag(w, "is-visible") { return w }
		guard let pid = frontPID() else { return nil }
		return list(["--windows"]).first { $0["pid"] as? Int == pid && flag($0, "is-visible") && !flag($0, "is-minimized") }
	}

	// SUPER+W: close the window. Apps that only order their window out on close (Spotify, Discord) keep running with a
	// blank tile in yabai, so quit those instead.
	func close() {
		guard let w = target(), let id = w["id"] as? Int, let pid = w["pid"] as? Int else { return }
		focuser.closedAt = Date() // closing makes macOS activate another app; that's not an alt-tab
		quietCrash(pid)
		if ["Spotify", "Discord"].contains(w["app"] as? String ?? "") || !ok(["window", String(id), "--close"]) { terminate(pid) }
	}

	// SUPER+Shift+W: SIGKILL the window's app (works on frozen apps)
	func forceKill() {
		guard let pid = target()?["pid"] as? Int, pid > 1 else { return }
		focuser.closedAt = Date()
		quietCrash(pid)
		kill(pid_t(pid), SIGKILL)
	}

	// SUPER+Q: quit the window's app (a normal quit, so it can still ask to save), rather than leaving it to the app's own
	// Cmd+Q, which some players swallow (Infuse during playback)
	func quit() {
		guard let pid = target()?["pid"] as? Int, let app = NSRunningApplication(processIdentifier: pid_t(pid)) else { return }
		switch app.bundleIdentifier {
		case "com.apple.finder": return // Finder has no Quit (Cmd+Q does nothing there); keep it that way
		case "com.mitchellh.ghostty": close() // one Ghostty runs every terminal (.local/bin/term): quit just this one
		default:
			focuser.closedAt = Date()
			quietCrash(Int(app.processIdentifier))
			app.terminate()
		}
	}

	func frontPID() -> Int? { NSWorkspace.shared.frontmostApplication.map { Int($0.processIdentifier) } }
	func terminate(_ pid: Int) { NSRunningApplication(processIdentifier: pid_t(pid))?.terminate() }

	// This app is being closed on purpose, so crash-notify (.local/src/crash-notify.swift) stays quiet if it crashes on
	// the way out; some apps segfault in their own quit code (KeePassXC, soh). Pids get reused, so old marks are dropped.
	func quietCrash(_ pid: Int) {
		let dir = NSHomeDirectory() + "/.cache/quiet-crash/", fm = FileManager.default
		try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
		for f in (try? fm.contentsOfDirectory(atPath: dir)) ?? [] {
			if let m = (try? fm.attributesOfItem(atPath: dir + f))?[.modificationDate] as? Date, Date().timeIntervalSince(m) > 86400 { try? fm.removeItem(atPath: dir + f) }
		}
		fm.createFile(atPath: dir + String(pid), contents: nil)
	}
}

// MARK: - Lid closed while staying awake

// With sleep disabled ("Keep Awake With Lid Closed", .config/raycast/scripts/power-lid-sleep.sh) macOS leaves the screen
// on when the lid shuts, so blank it: when the lid closes, and when the screen wakes while it's closed.
let pmRoot = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
func blankIfLidClosed(_ closed: Bool? = nil) {
	let shut = closed ?? (IORegistryEntryCreateCFProperty(pmRoot, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?
		.takeRetainedValue() as? Bool ?? false)
	guard shut, sleepDisabled() else { return }
	let p = Process()
	p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
	p.arguments = ["displaysleepnow"]
	try? p.run()
}

// MARK: - Scratchpad dim

// The scratchpad's wallpaper is dimmed, like Hyprland's dim_special behind the special workspace: a translucent black
// window just above the wallpaper, under every app window. Made while Space 11 is showing and not set to join all
// Spaces, so macOS keeps it on that Space and shows and hides it with the Space, without reacting to switches.
let padDim: CGFloat = 0.5

final class Dimmer {
	var panel: NSPanel?
	var spaceID = 0 // the Space it was made on; Spaces can be renumbered, so it's made again if 11 is a different one

	// on Space 11 (helper start, Space changes): make it if it isn't there yet
	func ensure() {
		guard let s = one(["--spaces", "--space"]), s["index"] as? Int == scratch, let id = s["id"] as? Int, id != spaceID || panel == nil,
			let d = s["display"] as? Int, let du = list(["--displays"]).first(where: { $0["index"] as? Int == d })?["uuid"] as? String,
			let screen = NSScreen.screens.first(where: { uuid(of: $0) == du }) else { return }
		reset()
		let p = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
		p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
		p.collectionBehavior = [.ignoresCycle, .stationary]
		p.backgroundColor = NSColor.black.withAlphaComponent(padDim)
		p.isOpaque = false
		p.ignoresMouseEvents = true
		p.hasShadow = false
		p.hidesOnDeactivate = false
		p.setFrame(screen.frame, display: false)
		p.orderFrontRegardless()
		panel = p
		spaceID = id
	}

	// displays changed: drop it; the next visit to the scratchpad makes it again at the new size
	func reset() {
		panel?.orderOut(nil)
		panel = nil
		spaceID = 0
	}
}

// MARK: - Wiring

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let bar = Bar()
let focuser = Focus()
let binds = Binds(focuser)
let dimmer = Dimmer()
// wmctl's socket (Binds)
let sockPath = NSHomeDirectory() + "/.cache/yabai-helper.sock"
unlink(sockPath)
let sock = socket(AF_UNIX, SOCK_DGRAM, 0)
var sockAddr = unixAddress(sockPath)
_ = withUnsafePointer(to: &sockAddr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(sock, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
_ = fcntl(sock, F_SETFL, O_NONBLOCK)
let wmctl = DispatchSource.makeReadSource(fileDescriptor: sock, queue: .main)
wmctl.setEventHandler {
	var buf = [UInt8](repeating: 0, count: 1024)
	while true {
		let n = recv(sock, &buf, buf.count, 0)
		if n <= 0 { break }
		binds.run(buf[0..<n].split(separator: 0).map { String(decoding: $0, as: UTF8.self) })
	}
}
wmctl.resume()
var tokens = [Int32](repeating: 0, count: 12)
notify_register_dispatch("wm.bar", &tokens[0], .main) { _ in bar.refresh() }
notify_register_dispatch("wm.focus", &tokens[1], .main) { _ in focuser.changed() }
notify_register_dispatch("wm.closed", &tokens[2], .main) { _ in focuser.closed(); bar.refresh() }
notify_register_dispatch("wm.demin", &tokens[3], .main) { _ in focuser.syncMinimized(); bar.refresh() }
notify_register_dispatch("wm.menubar", &tokens[7], .main) { token in
	var state: UInt64 = 0
	notify_get_state(token, &state)
	menuBarHidden = state == 1
	bar.refresh()
}
notify_register_dispatch("wm.created", &tokens[8], .main) { token in
	var id: UInt64 = 0
	notify_get_state(token, &id)
	focuser.created(Int(id))
}
notify_register_dispatch("wm.opaque", &tokens[11], .main) { _ in focuser.repin() }
notify_register_dispatch("wm.focuslock", &tokens[9], .main) { _ in focuser.lockChanged(); bar.refresh() }
notify_register_dispatch("wm.awake", &tokens[10], .main) { _ in stayAwake = sleepDisabled(); bar.refresh() }
let ws = NSWorkspace.shared.notificationCenter
ws.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in focuser.leaveAttic(); dimmer.ensure(); bar.refresh() }
ws.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
	// focus lock: the app activating can come before yabai reports its new window focused, so check now too
	if focusLocked, focuser.holdFocus(one(["--windows", "--window"])) { return }
	if let a = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { focuser.activated(a) }
}
// Music can't be deleted (sealed system volume) and macOS has no setting for what Play starts, so swap it for Spotify.
// Telling Spotify to play needs Automation, which setup grants (it signs this binary with a fixed identifier for that).
ws.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { note in
	guard let a = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
		a.bundleIdentifier == "com.apple.Music" else { return }
	a.forceTerminate()
	let play = Process()
	play.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
	play.arguments = ["-e", "tell application \"Spotify\" to play"] // starts Spotify if needed (yabairc puts it on the scratchpad)
	try? play.run()
}
ws.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in blankIfLidClosed() }
// IOPMrootDomain's kIOPMMessageClamshellStateChange; its argument's bit 0 (kClamshellStateBit) is set when the lid is shut
let lidPort = IONotificationPortCreate(kIOMainPortDefault)
IONotificationPortSetDispatchQueue(lidPort, .main)
var lidNote: io_object_t = 0
IOServiceAddInterestNotification(lidPort, pmRoot, "IOGeneralInterest", { _, _, type, arg in
	if type == 0xE003_4100 { blankIfLidClosed(Int(bitPattern: arg) & 1 != 0) }
}, nil, &lidNote)
NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in bar.rebuild(); dimmer.reset(); dimmer.ensure() }
// Mouse moves drive the bar's hover hiding and tell followFocus where hover focus came from (no permission needed for
// mouse events); the slow timer catches menus closing while the mouse is still, and window counts changing without an event.
NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { e in bar.trackMouse(); focuser.track(e.cgEvent?.location) }
Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in bar.trackMouse() }
Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in stayAwake = sleepDisabled(); bar.refresh() } // sleep also changes outside the toggle (sudo pmset)
bar.rebuild()
dimmer.ensure()
focuser.syncZoom(one(["--windows", "--window"])) // a window may already be zoomed (helper restarted)
focuser.lockChanged()
blankIfLidClosed() // at login with sleep still disabled
app.run()
