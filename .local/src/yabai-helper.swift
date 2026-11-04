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
// yabai signals (yabairc) ping it with ~/.local/bin/notify-post wm.bar | wm.focus | wm.closed (notifyutil takes
// ~100 ms). Built to ~/.local/bin/yabai-helper by setup.sh, which runs it as a LaunchAgent.
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
// minimize_sticky.sh, and popped-out ones), and a normal window rather than a panel or dialog
func usable(_ w: [String: Any]) -> Bool {
	!flag(w, "is-minimized") && !flag(w, "is-hidden") && !flag(w, "is-sticky") && w["role"] as? String == "AXWindow"
}

func currentSpace() -> Int? { one(["--spaces", "--space"])?["index"] as? Int }

// MARK: - Focus

final class Focus {
	var lastID = 0
	var warpedAt = Date.distantPast
	var warpedTo = CGPoint.zero
	var checkPending = false
	var closedAt = Date.distantPast

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
		guard let switchOnActivate = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleSpacesSwitchOnActivate"] as? NSNumber,
			!switchOnActivate.boolValue else { return }
		// skhd's "new window" binds touch this first: a window is on its way, so stay put
		if age("yabai-new-window") < 2 { return }
		// ws just switched Spaces, or a window just closed / an app quit (close binds, yabairc): this activation came
		// from that, not from alt-tab. Those land 70-110 ms after; 300 ms covers them without eating a real alt-tab.
		if age("ws-switch") < 0.3 || Date().timeIntervalSince(closedAt) < 0.3 { return }
		let pid = Int(app.processIdentifier)
		let windows = list(["--windows"])
		guard let space = currentSpace() else { return }
		let mine = windows.filter { $0["pid"] as? Int == pid && !flag($0, "is-minimized") && !flag($0, "is-hidden") }
		if mine.contains(where: { $0["space"] as? Int == space }) { return } // already has a window here
		// front-to-back, so the first match is the app's most recently used window
		if let id = mine.first(where: { !flag($0, "is-sticky") })?["id"] as? Int { focus(id) }
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
// windows count (not sticky, minimized or hidden ones). Keyed by display UUID.
func workspaces() -> [String: [Item]] {
	let real = Set(list(["--windows"]).filter {
		!flag($0, "is-sticky") && !flag($0, "is-minimized") && !flag($0, "is-hidden")
	}.compactMap { $0["id"] as? Int })
	var uuidOf = [Int: String]()
	for d in list(["--displays"]) { if let i = d["index"] as? Int, let u = d["uuid"] as? String { uuidOf[i] = u } }
	var rows = [String: [(Int, Item)]]()
	for s in list(["--spaces"]) {
		guard let i = s["index"] as? Int, let d = s["display"] as? Int, let uuid = uuidOf[d] else { continue }
		let occupied = (s["windows"] as? [Int] ?? []).contains { real.contains($0) }
		let shown = flag(s, "is-visible")
		guard i <= 5 || shown || occupied else { continue }
		let label = i == 11 ? "S" : String(i) // 11 = the scratchpad (.local/bin/scratchpad)
		rows[uuid, default: []].append((i == 11 ? 0 : i, (label, shown ? "a" : occupied ? "o" : "e")))
	}
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
			self.layout(workspaces())
		}
	}

	func layout(_ rows: [String: [Item]]) {
		for (id, p) in panels {
			let h = barHeight(p.screen)
			let items = rows[id] ?? []
			guard h > 0, !items.isEmpty else { p.panel.orderOut(nil); continue } // menu bar auto-hidden, or yabai down
			if p.row.items.map(\.label) != items.map(\.label) || p.row.items.map(\.state) != items.map(\.state) { p.row.items = items }
			let w = max(pad * 2 + slotW * CGFloat(items.count), leftWidth(p.screen))
			p.panel.setFrame(NSRect(x: p.screen.frame.minX, y: p.screen.frame.maxY - h, width: w, height: h), display: true)
			p.panel.alphaValue = hidden ? 0 : 1
			p.panel.orderFrontRegardless()
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
let bar = Bar()
let focuser = Focus()
var tokens = [Int32](repeating: 0, count: 3)
notify_register_dispatch("wm.bar", &tokens[0], .main) { _ in bar.refresh() }
notify_register_dispatch("wm.focus", &tokens[1], .main) { _ in focuser.changed() }
notify_register_dispatch("wm.closed", &tokens[2], .main) { _ in focuser.closed(); bar.refresh() }
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
