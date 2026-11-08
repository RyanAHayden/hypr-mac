// finder-trash: pin the Trash to the top of Finder's sidebar Favorites (Finder won't let you drag it there).
// The LSSharedFileList API returns nothing on Sequoia, so this edits the list sharedfilelistd keeps on disk
// (a keyed archive of plain dictionaries) and restarts it and Finder to pick it up.
// Built to ~/.local/bin/finder-trash and run by setup.sh. Safe to re-run: moves an existing Trash entry to the top.
import Foundation

func fail(_ msg: String) -> Never {
	FileHandle.standardError.write("finder-trash: \(msg)\n".data(using: .utf8)!)
	exit(1)
}

let sfl = URL(fileURLWithPath: NSHomeDirectory()
	+ "/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.FavoriteItems.sfl3")
let trash = URL(fileURLWithPath: NSHomeDirectory() + "/.Trash", isDirectory: true)
let classes = [NSDictionary.self, NSArray.self, NSString.self, NSData.self, NSNumber.self, NSUUID.self, NSDate.self]
guard let data = try? Data(contentsOf: sfl),
	let root = (try? NSKeyedUnarchiver.unarchivedObject(ofClasses: classes, from: data)) as? [String: Any],
	var items = root["items"] as? [[String: Any]] else { fail("can't read \(sfl.path)") }

func target(_ item: [String: Any]) -> String? {
	guard let bookmark = item["Bookmark"] as? Data else { return nil }
	var stale = false
	return (try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting],
		bookmarkDataIsStale: &stale))?.standardizedFileURL.path
}
items.removeAll { target($0) == trash.standardizedFileURL.path }
guard let bookmark = try? trash.bookmarkData() else { fail("can't bookmark \(trash.path)") }
items.insert(["visibility": 0, "CustomItemProperties": [String: Any](), "Bookmark": bookmark,
	"uuid": UUID().uuidString], at: 0)
var out = root
out["items"] = items
guard let archived = try? NSKeyedArchiver.archivedData(withRootObject: out, requiringSecureCoding: false)
else { fail("can't archive the list") }

func killall(_ name: String) {
	let p = Process()
	p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
	p.arguments = [name]
	p.standardError = FileHandle.nullDevice
	try? p.run()
	p.waitUntilExit()
}
// sharedfilelistd holds the list in memory and would write its copy back over ours
killall("sharedfilelistd")
do { try archived.write(to: sfl, options: .atomic) } catch { fail("can't write \(sfl.path): \(error)") }
killall("sharedfilelistd")
killall("Finder")
