// One native process for the yabai extras that have to react fast, instead of yabai starting bash + yabai + jq per
// event (each yabai CLI query is ~10-15 ms; over the socket it's ~3 ms):
//   - workspace bar over the left side of the menu bar (Apple and app menus, up to the notch or the menu bar icons),
//     on every display, like Omarchy's Waybar. Clicks pass through; it disappears while the mouse is over it or a
//     menu opened from the bar is showing, so the menus underneath stay usable.
//   - mouse follows focus: when focus moves to another window (a new window, alt-tab, a close) and the mouse isn't
//     in it, move the mouse to it, so hover focus (focus_follows_mouse) doesn't hand focus back on the next nudge.
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
//   - `ws move` (SUPER+Shift+N): switch and move back to back over the socket, so the move doesn't flash.
// yabai signals (yabairc) and skhd ping it with ~/.local/bin/notify-post wm.bar | wm.focus | wm.closed | wm.demin |
// wm.hide | wm.unhide | wm.move <space> | wm.menubar <1 hidden, 0 shown> (notifyutil takes ~100 ms). Built to ~/.local/bin/yabai-helper by setup.sh, which runs it as a LaunchAgent.
import AppKit
import notify

// MARK: - yabai over its socket (same message format as `yabai -m`: int32 length, then each arg NUL-terminated, then NUL)

func yabai(_ args: [String]) -> Data? {
	let fd = socket(AF_UNIX, SOCK_STREAM, 0)
	guard fd >= 0 else { return nil }
	defer { close(fd) }
	var timeout = timeval(tv_sec: 1, tv_usec: 0)
	setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
	var addr = sockaddr_un()
	addr.sun_family = sa_family_t(AF_UNIX)
	let path = Array("/tmp/yabai_\(NSUserName()).socket".utf8CString)
	withUnsafeMutableBytes(of: &addr.sun_path) { dst in path.withUnsafeBytes { dst.copyMemory(from: UnsafeRawBufferPointer(rebasing: $0.prefix(dst.count))) } }
	let connected = withUnsafePointer(to: &addr) {
		$0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
	}
	guard connected == 0 else { return nil }
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

let attic = 12 // hidden Space SUPER+M parks windows on (not in the bar, skipped by SUPER+A/D)

// MARK: - Focus

final class Focus {
	var lastID = 0
	var warpedAt = Date.distantPast
	var warpedTo = CGPoint.zero
	var checkPending = false
	var closedAt = Date.distantPast
	var parked = [Int]() // SUPER+M'd window ids, oldest first (windows found on the attic without a record go last)
	let stuckDir = NSHomeDirectory() + "/.cache/yabai-min-sticky" // windows made sticky while minimized, one file per id

	// wm.focus: focus moved, or a window moved/resized. Opening several windows at once fires a burst of these,
	// so coalesce them and act on wherever focus ends up.
	func changed() {
		guard !checkPending else { return }
		checkPending = true
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
			self.checkPending = false
			self.followFocus()
		}
	}

	func followFocus() {
		guard NSEvent.pressedMouseButtons == 0, // dragging a window: leave the mouse alone
			let w = one(["--windows", "--window"]), let id = w["id"] as? Int, let f = frame(w),
			let at = CGEvent(source: nil)?.location else { return }
		// something focused a parked window (AltTab, Raycast's window search): bring it here instead
		if w["space"] as? Int == attic, let space = currentSpace(), space != attic { bring(id, to: space); return }
		let fresh = id != lastID
		lastID = id
		if f.contains(at) { return } // hover focused it, or the mouse is already there
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
		if Date().timeIntervalSince(closedAt) < 0.3 { return } // the activation a close/hide causes, not a switch
		let pid = Int(app.processIdentifier)
		guard let space = currentSpace(), space != attic else { return }
		let windows = list(["--windows"])
		let mine = windows.filter { $0["pid"] as? Int == pid && !flag($0, "is-minimized") && !flag($0, "is-hidden") }
		if mine.contains(where: { $0["space"] as? Int == space }) { return } // already has a window here
		// switching to an app whose windows are all parked (Dock, Cmd+Tab, Raycast) brings back its latest one
		let atticIDs = mine.filter { $0["space"] as? Int == attic }.compactMap { $0["id"] as? Int }
		if !atticIDs.isEmpty, !mine.contains(where: { $0["space"] as? Int != attic && !flag($0, "is-sticky") }) {
			bring(parked.last(where: atticIDs.contains) ?? atticIDs[0], to: space)
			return
		}
		guard let switchOnActivate = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleSpacesSwitchOnActivate"] as? NSNumber,
			!switchOnActivate.boolValue else { return }
		// skhd's "new window" binds touch this first: a window is on its way, so stay put
		if age("yabai-new-window") < 2 { return }
		// ws just switched Spaces, or a window just closed / an app quit (close binds, yabairc): this activation came
		// from that, not from alt-tab. Those land 70-110 ms after; 300 ms covers them without eating a real alt-tab.
		if age("ws-switch") < 0.3 { return }
		// front-to-back, so the first match is the app's most recently used window
		if let id = mine.first(where: { !flag($0, "is-sticky") && $0["space"] as? Int != attic })?["id"] as? Int { focus(id) }
	}

	// wm.move (state = Space), from `ws move`: take the focused window to that Space and follow it. Switch first, then
	// move it onto the now-visible Space (yabai only tiles visible Spaces, so moving first shows it at its old size
	// for a moment), and send both over the socket back to back so the empty Space shows for under a frame.
	func move(to space: Int) {
		guard let id = one(["--windows", "--window"])?["id"] as? Int, space != currentSpace() else { return }
		closedAt = Date() // the switch makes macOS activate an app; that's not an alt-tab
		let switched = yabai(["space", "--focus", String(space)]).map { $0.first != 0x07 } ?? false // 0x07 = yabai error
		_ = yabai(["window", String(id), "--space", String(space)])
		if switched { focus(id) } // without the scripting addition it can't switch Spaces; the window still moves
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

	func age(_ marker: String) -> TimeInterval {
		let path = NSHomeDirectory() + "/.cache/" + marker
		guard let m = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date else { return .infinity }
		return Date().timeIntervalSince(m)
	}
}

// MARK: - Workspace bar

let slotW: CGFloat = 24, pillH: CGFloat = 22, pad: CGFloat = 6

typealias Item = (label: String, state: Character) // a = shown on its display, o = has windows, e = empty

// 1-5 always, higher Spaces when occupied or shown; Space 11 is the scratchpad ("S") and goes first. Only real
// windows count (not sticky, minimized or hidden ones). Keyed by display UUID; nil if yabai didn't answer (busy or
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
	let dir = NSHomeDirectory() + "/.cache/fs-origin/"
	var indexOf = [Int: Int]()
	for s in spaces { if let id = s["id"] as? Int, let i = s["index"] as? Int { indexOf[id] = i } }
	var originOf = [Int: Int]() // fullscreen space index -> its workspace's index
	for f in (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [] {
		guard let fs = Int(f), let o = (try? String(contentsOfFile: dir + f, encoding: .utf8)).flatMap({ Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }),
			let fi = indexOf[fs], let oi = indexOf[o] else { continue }
		originOf[fi] = oi
	}
	let parents = Set(originOf.values)
	var rows = [String: [(Double, Item)]]()
	var fullscreen = Set<String>() // displays showing a native fullscreen Space: no menu bar there, so no bar
	for s in spaces {
		guard let i = s["index"] as? Int, i != attic, let d = s["display"] as? Int, let uuid = uuidOf[d] else { continue }
		let shown = flag(s, "is-visible")
		if flag(s, "is-native-fullscreen") {
			if shown { fullscreen.insert(uuid) }
			rows[uuid, default: []].append((Double(originOf[i] ?? 100 + i) + 0.5, ("F", shown ? "a" : "o")))
			continue
		}
		let occupied = (s["windows"] as? [Int] ?? []).contains { real.contains($0) }
		guard i <= 5 || shown || occupied || parents.contains(i) else { continue }
		let label = i == 11 ? "S" : String(i) // 11 = the scratchpad (.local/bin/scratchpad)
		rows[uuid, default: []].append((Double(i == 11 ? 0 : i), (label, shown ? "a" : occupied ? "o" : "e")))
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

func barHeight(_ screen: NSScreen) -> CGFloat { screen.frame.maxY - screen.visibleFrame.maxY }

// The left side of the menu bar: up to the notch, or else up to the first menu bar icon (status items) on that screen
func leftWidth(_ screen: NSScreen) -> CGFloat {
	if let notch = screen.auxiliaryTopLeftArea, notch.width > 0 { return notch.width }
	let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
	let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
	let icons = list.compactMap { w -> CGFloat? in
		guard w[kCGWindowLayer as String] as? Int == statusLevel, let b = w[kCGWindowBounds as String] as? [String: CGFloat],
			let x = b["X"], x > screen.frame.minX, x < screen.frame.maxX else { return nil }
		return x
	}
	return (icons.min().map { $0 - screen.frame.minX - 8 }) ?? screen.frame.width / 2
}

final class Row: NSView {
	var items: [Item] = [] { didSet { needsDisplay = true } }
	override func draw(_ dirty: NSRect) {
		NSColor.black.setFill() // the menu bar is black (see README), so this blends in over the menus it covers
		bounds.fill()
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
			if let rows = workspaces() { self.layout(rows) }
		}
	}

	var leftFullscreen = false
	func layout(_ rows: [String: [Item]]) {
		// A panel ordered out on a native fullscreen Desktop comes back pinned to the one Space it's shown on again
		// (canJoinAllSpaces lost, re-ordering doesn't help); fresh panels join all Spaces, so rebuild once on the way out.
		if onFullscreen { leftFullscreen = true } else if leftFullscreen { leftFullscreen = false; rebuild(); return }
		for (id, p) in panels {
			let h = barHeight(p.screen)
			let items = rows[id] ?? []
			guard h > 0, !menuBarHidden, !items.isEmpty else { p.panel.orderOut(nil); continue } // menu bar auto-hidden, or no Spaces there
			if p.row.items.map(\.label) != items.map(\.label) || p.row.items.map(\.state) != items.map(\.state) { p.row.items = items }
			let w = max(pad * 2 + slotW * CGFloat(items.count), leftWidth(p.screen))
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
		guard let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]],
			let mainH = NSScreen.screens.first?.frame.height else { return false }
		let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
		return list.contains { w in
			guard w[kCGWindowLayer as String] as? Int == menuLevel,
				let b = w[kCGWindowBounds as String] as? [String: CGFloat], let y = b["Y"] else { return false }
			// a menu bar menu starts right under the bar of its display (CG coordinates: origin top-left of the main display)
			return panels.values.contains { p in abs(y - (mainH - p.screen.frame.maxY + barHeight(p.screen))) < 4 }
		}
	}
}

// MARK: - Wiring

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
// `ws` checks this (kill -0) before handing moves over; cheaper than pgrep
try? String(getpid()).write(toFile: NSHomeDirectory() + "/.cache/yabai-helper.pid", atomically: true, encoding: .utf8)
let bar = Bar()
let focuser = Focus()
var tokens = [Int32](repeating: 0, count: 8)
notify_register_dispatch("wm.bar", &tokens[0], .main) { _ in bar.refresh() }
notify_register_dispatch("wm.focus", &tokens[1], .main) { _ in focuser.changed() }
notify_register_dispatch("wm.closed", &tokens[2], .main) { _ in focuser.closed(); bar.refresh() }
notify_register_dispatch("wm.demin", &tokens[3], .main) { _ in focuser.syncMinimized(); bar.refresh() }
notify_register_dispatch("wm.hide", &tokens[4], .main) { _ in focuser.hide(); bar.refresh() }
notify_register_dispatch("wm.unhide", &tokens[5], .main) { _ in focuser.unhide(); bar.refresh() }
notify_register_dispatch("wm.menubar", &tokens[7], .main) { token in
	var state: UInt64 = 0
	notify_get_state(token, &state)
	menuBarHidden = state == 1
	bar.refresh()
}
notify_register_dispatch("wm.move", &tokens[6], .main) { token in
	var space: UInt64 = 0
	notify_get_state(token, &space)
	focuser.move(to: Int(space))
}
let ws = NSWorkspace.shared.notificationCenter
ws.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in bar.refresh() }
ws.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
	if let a = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { focuser.activated(a) }
}
NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in bar.rebuild() }
// Mouse moves drive the bar's hover hiding (no permission needed for mouse events); the slow timer catches menus
// closing while the mouse is still, and window counts changing without an event.
NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { _ in bar.trackMouse() }
Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in bar.trackMouse() }
Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in bar.refresh() }
bar.rebuild()
app.run()
