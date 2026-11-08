// wallpaper-band IN OUT: IN with its top painted black where the menu bar sits, written to OUT (its extension picks the
// format). The menu bar takes its colour from the wallpaper under it, blurred, so this keeps it black (and the workspace
// bar's black box matching) on any wallpaper. The band is worked out for "Fill Screen" (scaled to cover, centred) on
// every display, and reaches a couple of points below the menu bar so the blur only picks up black. Built to
// ~/.local/bin/wallpaper-band by setup.sh; set-wallpaper runs it.
import AppKit
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 3, let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
	let image = CGImageSourceCreateImageAtIndex(src, 0, nil)
else { FileHandle.standardError.write("usage: wallpaper-band IN OUT\n".data(using: .utf8)!); exit(1) }

let margin: CGFloat = 2

// the menu bar's height on each display: the window server's Menubar window (37 points on a notched display,
// where safeAreaInsets and visibleFrame are both off by some), or the standard height where it isn't on screen
let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
func menuBarHeight(_ screen: NSScreen) -> CGFloat {
	for w in windows where w[kCGWindowName as String] as? String == "Menubar" {
		if let b = w[kCGWindowBounds as String] as? [String: CGFloat], b["X"] == screen.frame.minX, let h = b["Height"] { return h }
	}
	return NSStatusBar.system.thickness
}

let iw = CGFloat(image.width), ih = CGFloat(image.height)
var band: CGFloat = 0 // image pixels from the top
for screen in NSScreen.screens {
	let w = screen.frame.width, h = screen.frame.height
	let menuBar = menuBarHeight(screen) + margin
	let scale = max(w / iw, h / ih) // points per image pixel
	let hidden = (ih * scale - h) / 2 / scale // cropped off the top by centring
	band = max(band, hidden + menuBar / scale)
}

guard let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
	space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { exit(1) }
ctx.draw(image, in: CGRect(x: 0, y: 0, width: iw, height: ih))
ctx.setFillColor(CGColor(gray: 0, alpha: 1))
ctx.fill(CGRect(x: 0, y: ih - ceil(band), width: iw, height: ceil(band))) // CG's origin is bottom left

let out = URL(fileURLWithPath: args[2])
let type = UTType(filenameExtension: out.pathExtension) ?? .png
// write next to OUT and rename, since IN and OUT can be the same file
let tmp = out.deletingLastPathComponent().appendingPathComponent(".\(out.lastPathComponent).tmp")
guard let result = ctx.makeImage(),
	let dest = CGImageDestinationCreateWithURL(tmp as CFURL, type.identifier as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(dest, result, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
guard CGImageDestinationFinalize(dest) else { exit(1) }
_ = try? FileManager.default.removeItem(at: out)
try FileManager.default.moveItem(at: tmp, to: out)
