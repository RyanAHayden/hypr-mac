// Crash notifications like Omarchy's: macOS's "X quit unexpectedly" dialog is off (setup.sh sets CrashReporter
// DialogType none), and this posts a notification for each new crash report instead. Clicking it opens Ghostty with
// Claude (cld) on the report and the app's last few minutes of log. Crashes from a deliberate close (SUPER+W, SUPER+Shift+W,
// SUPER+Q: yabai-helper marks the pid in ~/.cache/quiet-crash) are skipped. Runs as a LaunchAgent; setup.sh builds it
// into ~/.local/share/crash-notify/CrashNotify.app, since notifications need an app bundle.
import AppKit
import UserNotifications

let reports = NSHomeDirectory() + "/Library/Logs/DiagnosticReports"
let quiet = NSHomeDirectory() + "/.cache/quiet-crash"
let work = NSHomeDirectory() + "/.cache/crashes"
let fm = FileManager.default

func run(_ path: String, _ args: [String], output: String? = nil) {
	let p = Process()
	p.executableURL = URL(fileURLWithPath: path)
	p.arguments = args
	if let output {
		fm.createFile(atPath: output, contents: nil)
		p.standardOutput = FileHandle(forWritingAtPath: output)
	}
	try? p.run()
}

final class Watcher: NSObject, UNUserNotificationCenterDelegate {
	var seen = Set<String>()
	var source: DispatchSourceFileSystemObject?

	func start() {
		try? fm.createDirectory(atPath: work, withIntermediateDirectories: true)
		seen = Set((try? fm.contentsOfDirectory(atPath: reports)) ?? [])
		let center = UNUserNotificationCenter.current()
		center.delegate = self
		center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
		let fd = open(reports, O_EVTONLY)
		guard fd >= 0 else { exit(1) }
		let s = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
		// ReportCrash may still be writing when the directory changes; give it a moment
		s.setEventHandler { [weak self] in DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self?.scan() } }
		s.resume()
		source = s
	}

	func scan() {
		for name in (try? fm.contentsOfDirectory(atPath: reports)) ?? [] where !seen.contains(name) {
			seen.insert(name)
			if name.hasSuffix(".ips") { handle(reports + "/" + name) }
		}
	}

	// .ips: a JSON header line, then the JSON report
	func handle(_ path: String) {
		guard let text = try? String(contentsOfFile: path, encoding: .utf8),
		      let nl = text.firstIndex(of: "\n"),
		      let header = try? JSONSerialization.jsonObject(with: Data(text[..<nl].utf8)) as? [String: Any],
		      header["bug_type"] as? String == "309" else { return }
		let body = (try? JSONSerialization.jsonObject(with: Data(text[text.index(after: nl)...].utf8))) as? [String: Any] ?? [:]
		let app = header["app_name"] as? String ?? header["name"] as? String ?? "An app"
		if let pid = body["pid"] as? Int, fm.fileExists(atPath: "\(quiet)/\(pid)") {
			try? fm.removeItem(atPath: "\(quiet)/\(pid)")
			return
		}
		// the unified log rotates, so save the app's last few minutes now
		let log = work + "/" + URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent + ".log"
		let predicate = (body["pid"] as? Int).map { "processID == \($0)" } ?? "process == \"\(app)\""
		run("/usr/bin/log", ["show", "--last", "5m", "--style", "compact", "--predicate", predicate], output: log)

		let termination = body["termination"] as? [String: Any]
		let c = UNMutableNotificationContent()
		c.title = "\(app) quit unexpectedly"
		c.body = "\(termination?["indicator"] as? String ?? "Crashed"). Click to look into it with Claude."
		c.sound = .default
		c.userInfo = ["app": app, "report": path, "log": log]
		UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: path, content: c, trigger: nil))
	}

	// show banners even though this (background) app counts as frontmost when it posts
	func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
	                            withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
		done([.banner, .list, .sound])
	}

	func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
	                            withCompletionHandler done: @escaping () -> Void) {
		defer { done() }
		guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
		      let info = response.notification.request.content.userInfo as? [String: String],
		      let app = info["app"], let report = info["report"], let log = info["log"] else { return }
		let prompt = """
			\(app) just crashed on this Mac. The crash report is \(report) (macOS .ips: a JSON header line, then JSON) \
			and the process's unified log from the last 5 minutes is \(log). Read them, tell me in plain words why it \
			crashed (faulting thread, exception, the frames that matter), and whether it's a known bug in this version \
			with a fix or workaround.
			"""
		// a login shell so brew's PATH (claude, jq) is set; cld trusts the working directory
		run(NSHomeDirectory() + "/.local/bin/term", ["--cwd", work, "/bin/zsh", "-lc", "exec ~/.local/bin/cld \"$1\"", "zsh", prompt])
	}
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let watcher = Watcher()
watcher.start()
app.run()
