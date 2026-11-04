// Renders the menu bar workspace row as a base64 PNG for SwiftBar's image= parameter.
// Usage: ws-render 1:a 2:o 3:e ...   (a = active, o = has windows, e = empty)
import AppKit

let slotW: CGFloat = 24, h: CGFloat = 22, scale: CGFloat = 2
let items = CommandLine.arguments.dropFirst().compactMap { arg -> (String, Character)? in
	let p = arg.split(separator: ":")
	return p.count == 2 ? (String(p[0]), p[1].first!) : nil
}
let w = slotW * CGFloat(max(items.count, 1))
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w * scale), pixelsHigh: Int(h * scale),
	bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
	colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: w, height: h)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

for (i, (label, state)) in items.enumerated() {
	let slot = NSRect(x: CGFloat(i) * slotW, y: 0, width: slotW, height: h)
	let font = NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .medium)
	var color = NSColor.white
	switch state {
	case "a":
		NSColor.white.setFill()
		NSBezierPath(roundedRect: slot.insetBy(dx: 3, dy: 3), xRadius: 5, yRadius: 5).fill()
		color = .black
	case "o": color = NSColor.white.withAlphaComponent(0.95)
	default: color = NSColor.white.withAlphaComponent(0.38)
	}
	let text = NSAttributedString(string: label, attributes: [.font: font, .foregroundColor: color])
	let size = text.size()
	text.draw(at: NSPoint(x: slot.midX - size.width / 2, y: slot.midY - size.height / 2 + 0.5))
}

NSGraphicsContext.restoreGraphicsState()
print(rep.representation(using: .png, properties: [:])!.base64EncodedString())
