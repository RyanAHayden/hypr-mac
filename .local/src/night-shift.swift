// night-shift [on|off|toggle]: turn macOS Night Shift on/off (SUPER+Ctrl+N, like Omarchy's nightlight toggle).
// There's no public API or CLI for it, so this calls CoreBrightness's CBBlueLightClient (what Control Center uses).
// Built to ~/.local/bin/night-shift by setup.sh.
import Foundation

guard dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW) != nil,
	let cls = NSClassFromString("CBBlueLightClient") as? NSObject.Type,
	let send = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "objc_msgSend") else { // -2 = RTLD_DEFAULT
	FileHandle.standardError.write("night-shift: CoreBrightness unavailable\n".data(using: .utf8)!)
	exit(1)
}
let client = cls.init()
typealias GetStatus = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> Bool
typealias SetEnabled = @convention(c) (AnyObject, Selector, Bool) -> Bool
// Status struct starts with BOOL active, BOOL enabled, ... (64 bytes is more than it needs)
let status = UnsafeMutableRawPointer.allocate(byteCount: 64, alignment: 8)
status.initializeMemory(as: UInt8.self, repeating: 0, count: 64)
_ = unsafeBitCast(send, to: GetStatus.self)(client, NSSelectorFromString("getBlueLightStatus:"), status)
let enabled = status.load(fromByteOffset: 1, as: Bool.self)
let want: Bool
switch CommandLine.arguments.dropFirst().first ?? "toggle" {
case "on": want = true
case "off": want = false
case "status": print(enabled ? "on" : "off"); exit(0)
default: want = !enabled
}
_ = unsafeBitCast(send, to: SetEnabled.self)(client, NSSelectorFromString("setEnabled:"), want)
print(want ? "on" : "off")
