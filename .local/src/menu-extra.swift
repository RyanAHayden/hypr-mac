// menu-extra <name>: open a Control Center menu bar item (Sound, Bluetooth, Wi-Fi, Battery, Clock...) as if clicked, for
// binds. <name> is the start of the item's accessibility description ("Wi" matches "Wi-Fi, connected..."). Talks to
// ControlCenter over the Accessibility API directly instead of osascript + System Events. Needs Accessibility for whatever
// runs it (Karabiner-Console-User-Server for binds, setup.sh grants it). Built to ~/.local/bin/menu-extra by setup.sh.
import AppKit

guard CommandLine.arguments.count == 2 else { print("usage: menu-extra <description prefix>"); exit(2) }
let name = CommandLine.arguments[1]
guard let cc = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first else { exit(1) }

func attr<T>(_ e: AXUIElement, _ key: String) -> T? {
	var v: CFTypeRef?
	return AXUIElementCopyAttributeValue(e, key as CFString, &v) == .success ? v as? T : nil
}

let app = AXUIElementCreateApplication(cc.processIdentifier)
// ControlCenter's items are in its extras menu bar (System Events calls it menu bar 1)
guard let bar: AXUIElement = attr(app, "AXExtrasMenuBar") ?? attr(app, kAXMenuBarAttribute),
	let items: [AXUIElement] = attr(bar, kAXChildrenAttribute),
	let item = items.first(where: { (attr($0, kAXDescriptionAttribute) as String?)?.hasPrefix(name) == true }) else {
	print("menu-extra: no menu bar item \"\(name)\"")
	exit(1)
}
exit(AXUIElementPerformAction(item, kAXPressAction as CFString) == .success ? 0 : 1)
