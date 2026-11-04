// SUPER+Escape system menu, like Omarchy's: a native menu centered on the screen with the mouse. Arrows/Return or
// the underlined-style letter keys pick an item, Escape closes it. The actions are the Raycast "Power:" Script
// Commands (.config/raycast/scripts/power-*.sh), so they're also searchable in Raycast.
// Built to ~/.local/bin/power-menu by setup.sh.
import AppKit

let scripts = NSHomeDirectory() + "/.config/raycast/scripts/"
let lidSleepOff = { () -> Bool in
	let p = Process(), out = Pipe()
	p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
	p.arguments = ["-g"]
	p.standardOutput = out
	try? p.run()
	p.waitUntilExit()
	let s = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
	return s.range(of: #"SleepDisabled\s+1"#, options: .regularExpression) != nil
}()

final class Target: NSObject {
	var picked: String?
	@objc func pick(_ item: NSMenuItem) { picked = item.representedObject as? String }
}
let target = Target()
let menu = NSMenu()
menu.autoenablesItems = false
func add(_ title: String, _ key: String, _ script: String, _ symbol: String, on: Bool = false) {
	let item = NSMenuItem(title: title, action: #selector(Target.pick(_:)), keyEquivalent: key)
	item.keyEquivalentModifierMask = []
	item.target = target
	item.representedObject = script
	item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
	item.state = on ? .on : .off
	menu.addItem(item)
}
add("Lock", "l", "power-lock.sh", "lock")
add("Sleep", "s", "power-sleep.sh", "moon")
add("Keep Awake With Lid Closed", "k", "power-lid-sleep.sh", "cup.and.saucer", on: lidSleepOff)
menu.addItem(.separator())
add("Relaunch Window Manager", "w", "power-relaunch-wm.sh", "arrow.clockwise")
menu.addItem(.separator())
add("Log Out", "o", "power-logout.sh", "rectangle.portrait.and.arrow.right")
add("Restart", "r", "power-restart.sh", "restart")
add("Shut Down", "p", "power-shutdown.sh", "power")

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.activate(ignoringOtherApps: true)
let mouse = NSEvent.mouseLocation
let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main!
let size = menu.size
let at = NSPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.midY + size.height / 2)
// popUp blocks until the menu closes; with no view the point is in screen coordinates
menu.popUp(positioning: menu.items.first, at: at, in: nil)

if let script = target.picked {
	let p = Process()
	p.executableURL = URL(fileURLWithPath: "/bin/bash")
	p.arguments = [scripts + script]
	try? p.run()
	p.waitUntilExit()
}
