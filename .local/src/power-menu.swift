// SUPER+Escape system menu, like Omarchy's: a native menu centered on the screen with the mouse. Arrows/Return or
// the underlined-style letter keys pick an item, Escape closes it; Up/Down wrap around at either end. The actions are the Raycast "Power:" Script
// Commands (.config/raycast/scripts/power-*.sh), so they're also searchable in Raycast.
// Built to ~/.local/bin/power-menu by setup.sh.
import AppKit

let scripts = NSHomeDirectory() + "/.config/raycast/scripts/"
func lidSleepOff() -> Bool {
	let p = Process(), out = Pipe()
	p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
	p.arguments = ["-g"]
	p.standardOutput = out
	try? p.run()
	p.waitUntilExit()
	let s = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
	return s.range(of: #"SleepDisabled\s+1"#, options: .regularExpression) != nil
}
func reopenApps() -> Bool {
	UserDefaults(suiteName: "com.apple.loginwindow")?.bool(forKey: "TALLogoutSavesState") ?? false
}
// toggles keep the menu open: the event tap below takes their Return/click/letter, runs the script in the background
// and flips the check mark in place
let toggles = ["power-lid-sleep.sh": lidSleepOff, "power-reopen-apps.sh": reopenApps]

final class Target: NSObject {
	var picked: String?
	@objc func pick(_ item: NSMenuItem) { picked = item.representedObject as? String }
}
let target = Target()
let menu = NSMenu()
menu.autoenablesItems = false
func add(_ title: String, _ key: String, _ script: String, _ symbol: String) {
	let item = NSMenuItem(title: title, action: #selector(Target.pick(_:)), keyEquivalent: key)
	item.keyEquivalentModifierMask = []
	item.target = target
	item.representedObject = script
	item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
	// a blank off-state image the size of the check mark keeps its column even with nothing checked, so toggling
	// doesn't shift the text
	let check = NSImage(named: NSImage.menuOnStateTemplateName)!
	item.onStateImage = check
	item.offStateImage = NSImage(size: check.size)
	menu.addItem(item)
}
add("Lock", "l", "power-lock.sh", "lock")
add("Sleep", "s", "power-sleep.sh", "moon")
add("Keep Awake With Lid Closed", "k", "power-lid-sleep.sh", "cup.and.saucer")
add("Reopen Apps at Login", "a", "power-reopen-apps.sh", "arrow.uturn.backward.square")
menu.addItem(.separator())
add("Relaunch Window Manager", "w", "power-relaunch-wm.sh", "arrow.clockwise")
menu.addItem(.separator())
add("Log Out", "o", "power-logout.sh", "rectangle.portrait.and.arrow.right")
add("Restart", "r", "power-restart.sh", "restart")
add("Shut Down", "p", "power-shutdown.sh", "power")

// Up on the first item goes to the last and Down on the last to the first (NSMenu stops at the ends). Menu tracking
// doesn't pass keys to NSEvent monitors, so an event tap catches them (allowed: Karabiner-Console-User-Server starts
// this, and has Accessibility); highlightItem: is NSMenu's private highlight setter.
final class Wrap: NSObject, NSMenuDelegate {
	var highlighted: NSMenuItem?
	func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) { highlighted = item }
}
let wrap = Wrap()
menu.delegate = wrap
func toggle(_ item: NSMenuItem) {
	guard let script = item.representedObject as? String, let on = toggles[script] else { return }
	item.state = item.state == .on ? .off : .on
	// blink the row once: off, then back on
	for (i, lit) in [false, true].enumerated() {
		let t = Timer(timeInterval: 0.08 * Double(i + 1), repeats: false) { _ in
			menu.perform(NSSelectorFromString("highlightItem:"), with: lit ? item : nil)
			wrap.highlighted = item
		}
		RunLoop.main.add(t, forMode: .common)
	}
	DispatchQueue.global().async {
		run(script)
		let now = on()
		RunLoop.main.perform(inModes: [.common]) { item.state = now ? .on : .off }
	}
}
let isToggle = { (item: NSMenuItem?) in toggles[item?.representedObject as? String ?? ""] != nil }
let mask = [CGEventType.keyDown, .leftMouseUp].reduce(CGEventMask(0)) { $0 | 1 << $1.rawValue }
let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
	eventsOfInterest: mask, callback: { _, type, event, _ in
	let pass = Unmanaged.passUnretained(event)
	if type == .leftMouseUp {
		guard isToggle(wrap.highlighted) else { return pass }
		toggle(wrap.highlighted!)
		return nil
	}
	guard type == .keyDown else { return pass }
	let items = menu.items.filter { !$0.isSeparatorItem }
	let key = NSEvent(cgEvent: event)?.charactersIgnoringModifiers?.lowercased() ?? ""
	if let item = items.first(where: { isToggle($0) && $0.keyEquivalent == key }) {
		toggle(item)
		return nil
	}
	let to: NSMenuItem?
	switch event.getIntegerValueField(.keyboardEventKeycode) {
	case 36, 76, 49 where isToggle(wrap.highlighted):
		toggle(wrap.highlighted!)
		return nil
	case 126 where wrap.highlighted == nil || wrap.highlighted == items.first: to = items.last
	case 125 where wrap.highlighted == items.last: to = items.first
	default: return pass
	}
	menu.perform(NSSelectorFromString("highlightItem:"), with: to)
	wrap.highlighted = to
	return nil
}, userInfo: nil)
if let tap { CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes) }

func run(_ script: String) {
	let p = Process()
	p.executableURL = URL(fileURLWithPath: "/bin/bash")
	p.arguments = [scripts + script]
	try? p.run()
	p.waitUntilExit()
}

// activate once launching has finished: before that macOS ignores the request and the menu gets no keys
final class Delegate: NSObject, NSApplicationDelegate {
	func applicationDidFinishLaunching(_ note: Notification) {
		NSApp.activate(ignoringOtherApps: true)
		DispatchQueue.main.async {
			let mouse = NSEvent.mouseLocation
			let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main!
			let size = menu.size
			let at = NSPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.midY + size.height / 2)
			for item in menu.items { if let on = toggles[item.representedObject as? String ?? ""] { item.state = on() ? .on : .off } }
			// popUp blocks until the menu closes; with no view the point is in screen coordinates
			menu.popUp(positioning: menu.items.first, at: at, in: nil)
			if let script = target.picked { run(script) }
			exit(0)
		}
	}
}
let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
