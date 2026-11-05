// display-scale up|down|list: step the main display through its Retina "Looks like" sizes (Omarchy's SUPER+/ and
// SUPER+Alt+/ monitor scaling). up = bigger text (fewer points), down = more space. Saved like System Settings does.
// Built to ~/.local/bin/display-scale by setup.sh.
import CoreGraphics
import Foundation

let display = CGMainDisplayID()
guard let current = CGDisplayCopyDisplayMode(display),
	let all = CGDisplayCopyAllDisplayModes(display, [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary) as? [CGDisplayMode]
else { exit(1) }

// Retina modes only (2 pixels per point), same refresh rate and aspect ratio as now, one per size, smallest first
let aspect = Double(current.width) / Double(current.height)
var seen = Set<String>()
let modes = all.filter {
	$0.isUsableForDesktopGUI() && $0.pixelWidth == $0.width * 2 && $0.refreshRate == current.refreshRate
		&& abs(Double($0.width) / Double($0.height) - aspect) < 0.02
}.sorted { $0.width < $1.width }.filter { seen.insert("\($0.width)x\($0.height)").inserted }

let arg = CommandLine.arguments.dropFirst().first ?? "list"
guard let i = modes.firstIndex(where: { $0.width == current.width && $0.height == current.height }) else {
	print("current \(current.width)x\(current.height) isn't one of the Retina sizes"); exit(1)
}
if arg == "list" {
	for (n, m) in modes.enumerated() { print("\(m.width)x\(m.height)\(n == i ? "  <- current" : "")") }
	exit(0)
}
let j = arg == "up" ? i - 1 : i + 1 // up = bigger UI = fewer points
guard modes.indices.contains(j) else { print("already at the \(arg == "up" ? "largest" : "smallest") size"); exit(0) }

var config: CGDisplayConfigRef?
CGBeginDisplayConfiguration(&config)
CGConfigureDisplayWithDisplayMode(config, display, modes[j], nil)
CGCompleteDisplayConfiguration(config, .permanently)
print("\(modes[j].width)x\(modes[j].height)")
