// sendkey "ctrl - 1" | "escape": press a key (with modifiers) as if typed, for scripts (ws, notifications).
// Same "mods - key" syntax as bindings.conf; mods are cmd, shift, alt, ctrl. Needs Accessibility (or Post Event)
// for whatever runs it: Ghostty, or Karabiner-Console-User-Server for binds (setup.sh grants both).
import CoreGraphics
import Foundation

let keys: [String: CGKeyCode] = [
	"a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14,
	"r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29,
	"o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46, "return": 36, "tab": 48,
	"space": 49, "backspace": 51, "escape": 53, "left": 123, "right": 124, "down": 125, "up": 126,
]
let mods: [String: CGEventFlags] = ["cmd": .maskCommand, "shift": .maskShift, "alt": .maskAlternate, "ctrl": .maskControl]

guard CommandLine.arguments.count == 2 else { print("usage: sendkey \"mods - key\""); exit(2) }
let spec = CommandLine.arguments[1]
let parts = spec.components(separatedBy: " - ")
let keyName = parts.last!.trimmingCharacters(in: .whitespaces)
guard let code = keys[keyName] else { print("sendkey: unknown key \(keyName)"); exit(2) }
var flags: CGEventFlags = []
if parts.count > 1 {
	for m in parts[0].split(separator: "+").map({ $0.trimmingCharacters(in: .whitespaces) }) {
		guard let f = mods[m] else { print("sendkey: unknown modifier \(m)"); exit(2) }
		flags.insert(f)
	}
}
let src = CGEventSource(stateID: .hidSystemState)
for down in [true, false] {
	let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down)!
	e.flags = flags
	e.post(tap: .cghidEventTap)
}
