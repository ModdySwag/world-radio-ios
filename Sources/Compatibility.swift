import Foundation
import UIKit

/// The iOS half of the compatibility story.
///
/// The install-time floor is `MinimumOSVersion` in Info.plist - below it the App Store will
/// not offer the app and the device will not run it. That part is enforced by Apple.
///
/// This class handles everything above that floor: saying so, once, when the device's iOS is
/// older than the version the app is tuned for. Every threshold comes from the same
/// `compat.json` the Android app and the website read, so the three cannot drift apart - and
/// the verdict it produces is the one the shell's Check panel renders, so the launch notice
/// and the panel can never disagree.
final class Compatibility {

    struct Level {
        let label: String
        let value: Double
    }

    let platform: String
    let osName: String
    let hard: Level
    let soft: Level
    let engineLabel: String
    let engineName: String
    let engineNote: String
    let noticeTitle: String
    let noticeBody: String
    let positiveAction: String
    let neutralAction: String
    let unsupportedTitle: String
    let unsupportedBody: String

    /// Every default here is a plain literal: a missing compat.json must degrade to
    /// something sensible, never to another lookup of itself.
    init(spec: [String: Any]) {
        let os = spec["os"] as? [String: Any] ?? [:]
        let hardD = os["hard"] as? [String: Any] ?? [:]
        let softD = os["soft"] as? [String: Any] ?? [:]
        let eng = spec["engine"] as? [String: Any] ?? [:]
        let notice = spec["notice"] as? [String: Any] ?? [:]
        let unsup = spec["unsupported"] as? [String: Any] ?? [:]

        platform = spec["platform"] as? String ?? "ios"
        osName = os["name"] as? String ?? "iOS"
        hard = Level(label: hardD["label"] as? String ?? "iOS 15",
                     value: Spec.number(hardD["os"], fallback: 15))
        soft = Level(label: softD["label"] as? String ?? "iOS 18",
                     value: Spec.number(softD["os"], fallback: hard.value))
        engineLabel = eng["label"] as? String ?? "WebKit"
        engineName = eng["name"] as? String ?? "WebKit"
        engineNote = eng["note"] as? String ?? ""
        noticeTitle = notice["title"] as? String ?? "This iOS version is older than the app is tuned for"
        noticeBody = notice["body"] as? String ?? ""
        positiveAction = notice["positiveAction"] as? String ?? "Continue anyway"
        neutralAction = notice["neutralAction"] as? String ?? ""
        unsupportedTitle = unsup["title"] as? String ?? "This iOS version is not supported"
        unsupportedBody = unsup["body"] as? String ?? ""
    }

    static let shared = Compatibility(spec: Spec.load())

    // MARK: - this device

    var systemVersion: String { UIDevice.current.systemVersion }

    private var systemValue: Double { Double(systemVersion) ?? 0 }

    /// "iOS 16.6 (iPad7,5)" - what the device reports, shaped like the label in compat.json.
    var systemLabel: String { "\(osName) \(systemVersion) (\(DeviceInfo.modelIdentifier))" }

    var supported: Bool { systemValue >= hard.value }

    var recommended: Bool { systemValue >= soft.value }

    var deviceSummary: String {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad: return "Apple iPad"
        case .phone: return "Apple iPhone"
        default: return "Apple device"
        }
    }

    // MARK: - what the page sees

    /// The facts the shell injects as `window.__wrDevice` before the page runs, in the same
    /// shape the Android bridge returns from `device()`, so the shared shim needs no
    /// platform branch of its own.
    func pageFacts(appVersion: String) -> [String: Any] {
        [
            "manufacturer": "Apple",
            "model": DeviceInfo.modelIdentifier,
            "platform": platform,
            "osName": osName,
            "osVersion": systemVersion,
            "release": systemVersion,
            "system": systemLabel,
            "app": appVersion,
            "engineLabel": engineLabel,
            "engine": engineLabel,
            "compat": verdict(),
        ]
    }

    func verdict() -> [String: Any] {
        [
            "supported": supported,
            "recommended": recommended,
            "system": systemLabel,
            "hardLabel": hard.label,
            "softLabel": soft.label,
            "engineNote": engineNote,
        ]
    }

    /// Fill {system} / {hard} / {soft} / {engine} in the notice copy.
    func fill(_ text: String) -> String {
        text.replacingOccurrences(of: "{system}", with: systemLabel)
            .replacingOccurrences(of: "{hard}", with: hard.label)
            .replacingOccurrences(of: "{soft}", with: soft.label)
            .replacingOccurrences(of: "{engine}", with: engineName)
    }

    // MARK: - the notice

    /// One dismissible notice per app version, and only when this device is below the version
    /// the app is tuned for. Once is deliberate: the information is worth having, a nag is
    /// not, and the Check panel keeps the verdict visible from then on.
    func maybeWarn(appVersion: String, in host: UIViewController, onDetails: @escaping () -> Void) {
        if supported && recommended { return }

        let key = "compat.notice.shown"
        let stamp = "\(appVersion)/\(hard.value)/\(soft.value)/\(systemVersion)"
        if UserDefaults.standard.string(forKey: key) == stamp { return }

        let ok = supported
        let title = fill(ok ? noticeTitle : unsupportedTitle)
        let body = fill(ok ? noticeBody : unsupportedBody)
        guard !body.isEmpty else { return }

        let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: fill(positiveAction), style: .default))
        if ok && !neutralAction.isEmpty {
            alert.addAction(UIAlertAction(title: fill(neutralAction), style: .default) { _ in
                onDetails()
            })
        }
        host.present(alert, animated: true)
        UserDefaults.standard.set(stamp, forKey: key)
    }
}

/// Reading compat.json, which ships next to the web app in the bundle.
enum Spec {

    static func load() -> [String: Any] {
        // A folder reference and a flat copy put the file in different places; try both
        // rather than assume which one the project produced.
        for name in ["compat.json", "www/compat.json"] {
            let base = (name as NSString).deletingPathExtension
            let path = (name as NSString).pathExtension
            if let url = Bundle.main.url(forResource: base, withExtension: path),
               let data = try? Data(contentsOf: url),
               let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return o
            }
        }
        NSLog("WorldRadio: compat.json not found in the bundle - using built-in defaults")
        return [:]
    }

    static func number(_ any: Any?, fallback: Double) -> Double {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let s = any as? String { return Double(s) ?? fallback }
        return fallback
    }
}

/// The two facts only the device itself can tell us. Kept apart from Compatibility so the
/// version maths there reads as maths.
enum DeviceInfo {

    /// The hardware identifier ("iPad7,5", "iPhone14,2") rather than UIDevice's model, which
    /// on iOS is always just "iPhone" or "iPad" and so is useless in a bug report.
    static var modelIdentifier: String {
        var info = utsname()
        uname(&info)
        let mirror = Mirror(reflecting: info.machine)
        let id = mirror.children.reduce(into: "") { acc, child in
            if let byte = child.value as? Int8, byte != 0 {
                acc.append(Character(UnicodeScalar(UInt8(byte))))
            }
        }
        return id.isEmpty ? "unknown" : id
    }

    static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
