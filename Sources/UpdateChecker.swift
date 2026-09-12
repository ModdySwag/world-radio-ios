import Foundation

/// Keeps the app current — as far as iOS allows, which is not far, and saying so is the point.
///
/// The Android app can download its own APK and install it over itself. An iOS app cannot: there
/// is no supported way for a sideloaded, non-App-Store app to install an update of itself. So this
/// checks the same feed, tells the shell what it found, and the shell's button opens the download
/// page. That is the honest ceiling; pretending otherwise would be a button that fails.
final class UpdateChecker {

    static let feed = URL(string: "https://moddys.net/updates.json")!
    private static var lastChecked: Date?

    struct Info {
        var available = false
        var version = ""
        var build = 0
        var url = ""
        var notes = ""

        /// The shape the shell reads: window.__wrUpdate.available({...}).
        var json: String {
            let fields: [String: Any] = ["version": version, "url": url, "notes": notes,
                                         "code": build, "platform": "ios", "sha256": ""]
            guard let data = try? JSONSerialization.data(withJSONObject: fields),
                  let text = String(data: data, encoding: .utf8) else { return "{}" }
            return text
        }
    }

    /// Ask the site what the newest build is. Never throws; failures just do nothing.
    static func check(manual: Bool, completion: @escaping (Info?) -> Void) {
        if !manual, let last = lastChecked, Date().timeIntervalSince(last) < 600 {
            return                       // a launch check already ran recently
        }
        lastChecked = Date()

        var request = URLRequest(url: feed)
        request.timeoutInterval = 6
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ios = root["ios"] as? [String: Any] else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            var info = Info()
            let theirs = ios["build"] as? Int ?? 0
            let mine = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
            info.build = theirs
            info.version = ios["version"] as? String ?? ""
            info.url = ios["url"] as? String ?? ""
            info.notes = ios["notes"] as? String ?? ""
            info.available = theirs > mine
            DispatchQueue.main.async { completion(info) }
        }.resume()
    }

    /// Where the shell's Update button lands: the download page, which explains the install.
    static func downloadPage(_ url: String) -> URL {
        if !url.isEmpty, let u = URL(string: url) { return u }
        return URL(string: "https://moddys.net/downloads.html")!
    }
}
