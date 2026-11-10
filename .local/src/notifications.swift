// Omarchy's notification binds on macOS (SUPER+comma family):
//   notifications dismiss      close the newest notification (a banner on screen, or the top of Notification Center)
//   notifications dismiss-all  clear every notification in Notification Center
//   notifications center       toggle Notification Center (history)
// Notifications are groups in NotificationCenter's window with a "Close" accessibility action. Talks to it over the
// Accessibility API directly (System Events took a round trip per element it walked). Needs Accessibility and Post Event
// for whatever runs it (Karabiner-Console-User-Server for binds, setup.sh grants both). Built by setup.sh.
import AppKit

func attr<T>(_ e: AXUIElement, _ key: String) -> T? {
	var v: CFTypeRef?
	return AXUIElementCopyAttributeValue(e, key as CFString, &v) == .success ? v as? T : nil
}

func app(_ bundle: String) -> AXUIElement? {
	NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first.map { AXUIElementCreateApplication($0.processIdentifier) }
}

let nc = app("com.apple.notificationcenterui")
func windows() -> [AXUIElement] { nc.flatMap { attr($0, kAXWindowsAttribute) } ?? [] }
func isOpen() -> Bool { windows().contains { (attr($0, kAXTitleAttribute) as String?) == "Notification Center" } }

// Opened by clicking the clock; a second click doesn't close it, a real Escape key event does
func center() {
	if isOpen() {
		let src = CGEventSource(stateID: .hidSystemState)
		for down in [true, false] { CGEvent(keyboardEventSource: src, virtualKey: 53, keyDown: down)?.post(tap: .cghidEventTap) }
		return
	}
	guard let cc = app("com.apple.controlcenter"), let bar: AXUIElement = attr(cc, "AXExtrasMenuBar"),
		let items: [AXUIElement] = attr(bar, kAXChildrenAttribute),
		let clock = items.first(where: { (attr($0, kAXDescriptionAttribute) as String?) == "Clock" }) else { return }
	AXUIElementPerformAction(clock, kAXPressAction as CFString)
}

// The first notification (or group) on screen and its close action's name ("Name:Close\nTarget:...")
func firstClosable() -> (AXUIElement, CFString)? {
	func walk(_ e: AXUIElement, _ depth: Int) -> (AXUIElement, CFString)? {
		if (attr(e, kAXRoleAttribute) as String?) == kAXGroupRole {
			var names: CFArray?
			if AXUIElementCopyActionNames(e, &names) == .success, let close = (names as? [String])?.first(where: { $0.contains("Name:Close") }) {
				return (e, close as CFString)
			}
		}
		guard depth < 7 else { return nil }
		for k in (attr(e, kAXChildrenAttribute) as [AXUIElement]?) ?? [] { if let found = walk(k, depth + 1) { return found } }
		return nil
	}
	return windows().first.flatMap { walk($0, 0) }
}

// Close the first notification, or all of them. A closed one can take a moment to leave the tree, so if the same one
// comes back it waits a little and looks again (up to about half a second per notification).
func close(all: Bool) {
	var last: AXUIElement?
	var retries = 0
	for _ in 0..<200 {
		guard let (e, action) = firstClosable() else { return }
		if let last, CFEqual(last, e) {
			retries += 1
			if retries > 25 { return }
			usleep(20_000)
			continue
		}
		AXUIElementPerformAction(e, action)
		if !all { return }
		last = e
		retries = 0
	}
}

switch CommandLine.arguments.dropFirst().first ?? "dismiss" {
case "center": center()
case "dismiss": close(all: false)
case "dismiss-all":
	// clearing history needs Notification Center open; leave it how it was
	if isOpen() { close(all: true); break }
	center()
	for _ in 0..<50 where !isOpen() { usleep(20_000) }
	close(all: true)
	center()
default:
	print("usage: notifications dismiss | dismiss-all | center")
	exit(2)
}
