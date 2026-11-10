// bind-repeat start <command> | stop: key repeat for "repeat" binds in bindings.conf. Karabiner runs a bind's command
// once per press, so binds-apply makes the press run `bind-repeat start` and the release `bind-repeat stop`. Runs the
// command, waits macOS's key repeat delay, then runs it again every repeat interval (Keyboard settings) until the key
// is released, or every modifier is (in case the release raced ahead of the press). Runs are back to back, never overlapping.
// The held file names the press that owns it: a new press takes it over, so an older run still going stops repeating,
// like a keyboard repeats only the last key pressed.
import CoreGraphics
import Foundation

let held = NSHomeDirectory() + "/.cache/bind-repeat.held"
let args = CommandLine.arguments
if args.count == 2 && args[1] == "stop" {
	try? FileManager.default.removeItem(atPath: held)
	exit(0)
}
guard args.count == 3 && args[1] == "start" else { print("usage: bind-repeat start <command> | stop"); exit(2) }

let me = String(getpid())
try? me.write(toFile: held, atomically: true, encoding: .utf8)
func run() {
	let p = Process()
	p.executableURL = URL(fileURLWithPath: "/bin/sh")
	p.arguments = ["-c", args[2]]
	try? p.run()
	p.waitUntilExit()
}
func stillHeld() -> Bool {
	(try? String(contentsOfFile: held, encoding: .utf8)) == me
		&& !CGEventSource.flagsState(.combinedSessionState).intersection([.maskCommand, .maskAlternate, .maskControl]).isEmpty
}
// defaults are in 15 ms ticks (setup.sh sets 15 and 2: 225 ms, then every 30 ms)
let delay = Double(UserDefaults.standard.object(forKey: "InitialKeyRepeat") as? Int ?? 15) * 0.015
let interval = Double(UserDefaults.standard.object(forKey: "KeyRepeat") as? Int ?? 2) * 0.015

run()
var until = Date().addingTimeInterval(delay)
while true {
	while Date() < until {
		guard stillHeld() else { exit(0) }
		usleep(5000)
	}
	guard stillHeld() else { exit(0) }
	run()
	until = Date().addingTimeInterval(interval)
}
