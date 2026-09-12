import AVFoundation
import UIKit
import WebKit

/// Hosts the existing MODDYS World Radio web app in a WKWebView and connects it to the iOS
/// shell it never had: background playback, lock-screen controls, and permission for the
/// ~8,330 cleartext streams in the catalogue.
///
/// Nothing about playback logic is re-implemented here. The page owns the stream (its own
/// single-owner model); this class forwards state and commands, exactly as the Android app's
/// MainActivity does - and the two apps share one shell script, `_shell_shim.js`, so the
/// player sheet, the theme, the visualiser, the compatibility notice and the Check panel are
/// literally the same code on both platforms.
///
/// The bridge is where the platforms differ: Android hands JS a synchronous object, iOS gets
/// asynchronous messages plus one injected facts object (there is no synchronous JS-to-native
/// call on iOS). The shim hides that difference from itself; anyone reading native() in
/// `_shell_shim.js` can see both sides in ten lines.
final class RadioViewController: UIViewController {

    static let bridgeName = "wr"
    static let background = UIColor(red: 0.043, green: 0.043, blue: 0.059, alpha: 1)   // #0B0B0F

    private var web: WKWebView!
    private var port: UInt16?
    private var playing = false
    private var wasPlaying = false
    private var noticeShown = false
    private var engineLabel = "WebKit"
    private let nowPlaying = NowPlaying()
    private var message: UIView?

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = RadioViewController.background
        overrideUserInterfaceStyle = .dark
        configureAudioSession()
        buildWeb()
        nowPlaying.command = { [weak self] command in self?.send(command) }
        loadPage()
    }

    /// Category `.playback` is what lets the stream keep playing when the app is not on screen
    /// or the device is locked.
    ///
    /// It is the app's one and only audio session - the same one WebKit uses when the page
    /// plays, because there is one session per app. So this is not a second owner asking for
    /// the sound: it is the app declaring what it does with it. That distinction is the whole
    /// of the Android app's v1.5.0 release note, and it is why nothing here ever reacts to an
    /// audio event by showing the user a dialog.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            NSLog("WorldRadio: audio session: \(error)")
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(interrupted(_:)),
                                               name: AVAudioSession.interruptionNotification,
                                               object: nil)
    }

    /// A real interruption (a call, an alarm) pauses; when it ends and the system says the user
    /// meant to carry on, resume through the page. Quiet by design: no alert, nothing on a
    /// timer, nothing invented.
    @objc private func interrupted(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

        if type == .began {
            wasPlaying = playing
            send("pause")
            return
        }
        let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        if AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume),
           wasPlaying {
            send("play")
        }
    }

    // MARK: - the web view

    private func buildWeb() {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        // The page's own play button is the user's tap. A shell that has to restart a stream -
        // after an interruption, or from the lock screen - cannot wait for one, and this is the
        // switch that decides it. Same setting, same name, as the Android shell's
        // setMediaPlaybackRequiresUserGesture(false).
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true

        let content = configuration.userContentController
        content.add(self, name: RadioViewController.bridgeName)
        if let facts = deviceScript() {
            content.addUserScript(WKUserScript(source: facts,
                                               injectionTime: .atDocumentStart,
                                               forMainFrameOnly: true))
        }
        if let shim = shimSource() {
            content.addUserScript(WKUserScript(source: shim,
                                               injectionTime: .atDocumentEnd,
                                               forMainFrameOnly: true))
        }

        web = WKWebView(frame: .zero, configuration: configuration)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.isOpaque = false
        web.backgroundColor = RadioViewController.background
        web.scrollView.backgroundColor = RadioViewController.background
        // The page lays itself out with viewport-fit=cover and env(safe-area-inset-*), and the
        // web view is pinned inside the safe area, so no double padding.
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.allowsBackForwardNavigationGestures = false
        web.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(web)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            web.topAnchor.constraint(equalTo: guide.topAnchor),
            web.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
        ])
    }

    private func loadPage() {
        guard let root = webRoot() else {
            showMissingBundle()
            return
        }
        if let opened = LocalServer.shared.start(bundleRoot: root) {
            port = opened
            if let url = URL(string: "http://127.0.0.1:\(opened)/index.html") {
                web.load(URLRequest(url: url))
                return
            }
        }
        // No loopback port: file:// still plays the radio, it just may not remember favourites
        // between launches. That is better than a blank screen.
        NSLog("WorldRadio: no loopback port - loading the page from file://")
        web.loadFileURL(root.appendingPathComponent("index.html"), allowingReadAccessTo: root)
    }

    // MARK: - bridge

    private func send(_ command: String) {
        guard command == "play" || command == "pause" || command == "toggle" else { return }
        evaluate("window.__wr&&window.__wr.\(command)&&window.__wr.\(command)()")
    }

    private func evaluate(_ js: String) {
        web.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Ask the site whether a newer build exists, and hand the answer to the shell, which owns
    /// the notice and the button. Silent when it cannot be reached: a failed check must never
    /// interrupt listening.
    private func checkForUpdate(manual: Bool) {
        UpdateChecker.check(manual: manual) { [weak self] info in
            guard let self else { return }
            if let info, info.available {
                self.evaluate("window.__wrUpdate && window.__wrUpdate.available(\(info.json))")
            } else {
                self.evaluate("window.__wrUpdate && window.__wrUpdate.none("
                              + RadioViewController.jsString(info?.version ?? "") + ")")
            }
        }
    }

    /// Called when the page has finished loading the shim: the one moment it is worth asking.
    private func checkForUpdateAfterLoad() {
        checkForUpdate(manual: false)
    }

    /// The device facts the shim reads as `window.__wrDevice`, in the same shape the Android
    /// bridge returns from `device()`, so the shared shim needs no platform branch.
    private func deviceScript() -> String? {
        let facts = Compatibility.shared.pageFacts(appVersion: DeviceInfo.appVersion)
        guard let data = try? JSONSerialization.data(withJSONObject: facts),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return "window.__wrDevice=\(json);"
    }

    /// The WebKit version is the most useful single fact about this device - it, not the iOS
    /// version, is what decides which streams decode - and it is only knowable from the page's
    /// own user agent. So it is read once the page loads and pushed into the facts.
    private func reportEngine() {
        web.evaluateJavaScript("navigator.userAgent") { [weak self] value, _ in
            guard let self = self, let agent = value as? String else { return }
            let version = RadioViewController.firstMatch(in: agent, pattern: "AppleWebKit/([0-9.]+)")
            let label = version.isEmpty ? "WebKit" : "WebKit \(version)"
            self.engineLabel = label
            self.evaluate("if(window.__wrDevice){window.__wrDevice.engine=\(RadioViewController.jsString(label));window.__wrDevice.engineLabel=\"WebKit\";}")
        }
    }

    private func showCompatNotice() {
        Compatibility.shared.maybeWarn(appVersion: DeviceInfo.appVersion, in: self) { [weak self] in
            // Straight to the answer: expand the player and open the Check panel.
            self?.evaluate("window.__wr&&window.__wr.compat&&window.__wr.compat()")
        }
    }

    // MARK: - files

    private func shimSource() -> String? {
        guard let url = bundleFile("_shell_shim.js") else {
            NSLog("WorldRadio: _shell_shim.js is missing from the bundle - the player will not be built")
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// A folder reference puts the web app in `www/`; a flat copy puts it at the top level. Try
    /// both rather than assume which one the project produced.
    private func bundleFile(_ name: String) -> URL? {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        if let nested = Bundle.main.url(forResource: base, withExtension: ext, subdirectory: "www") {
            return nested
        }
        return Bundle.main.url(forResource: base, withExtension: ext)
    }

    private func webRoot() -> URL? {
        guard let index = bundleFile("index.html") else { return nil }
        return index.deletingLastPathComponent()
    }

    // MARK: - messages to the user

    private func showMissingBundle() {
        show(notice: """
            This build is missing the bundled radio page, so there is nothing to play.

            Everything the app needs - index.html, stations.js and countries.js - should sit \
            inside the app itself. Reinstalling it usually fixes this.
            """,
             retry: false)
    }

    private func showLoadFailure(_ error: Error) {
        show(notice: "The radio page could not be loaded on this device.\n\n\(error.localizedDescription)",
             retry: true)
    }

    private func show(notice text: String, retry: Bool) {
        if message != nil { return }
        let box = UIStackView()
        box.axis = .vertical
        box.spacing = 16
        box.alignment = .leading
        box.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = UIColor(red: 0.96, green: 0.94, blue: 0.92, alpha: 1)
        label.font = UIFont.systemFont(ofSize: 15)
        label.text = text
        box.addArrangedSubview(label)

        if retry {
            let button = UIButton(type: .system)
            button.setTitle("Try again", for: .normal)
            button.addTarget(self, action: #selector(retryLoad), for: .touchUpInside)
            box.addArrangedSubview(button)
        }

        view.addSubview(box)
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            box.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            box.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        message = box
    }

    @objc private func retryLoad() {
        message?.removeFromSuperview()
        message = nil
        loadPage()
    }

    // MARK: - small helpers

    private static func jsString(_ text: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [text]),
              let json = String(data: data, encoding: .utf8) else { return "\"\"" }
        return String(json.dropFirst().dropLast())      // strip the array brackets
    }

    private static func firstMatch(in text: String, pattern: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return "" }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let found = Range(match.range(at: 1), in: text) else { return "" }
        return String(text[found])
    }
}

// MARK: - navigation

extension RadioViewController: WKNavigationDelegate {

    /// The app is one page. Anything that is not the bundled app or its loopback origin is a
    /// station's stream or homepage, and belongs in the phone's browser - without this the
    /// player would be replaced by a web page, exactly as it would on Android.
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        if isInternal(url) {
            decisionHandler(.allow)
            return
        }
        decisionHandler(.cancel)
        openExternal(url)
    }

    private func isInternal(_ url: URL) -> Bool {
        if url.isFileURL { return true }
        if let scheme = url.scheme, ["about", "data", "blob"].contains(scheme) { return true }
        guard let host = url.host else { return false }
        return host == "127.0.0.1" || host == "localhost"
    }

    private func openExternal(_ url: URL) {
        guard let scheme = url.scheme,
              ["http", "https", "mailto", "tel"].contains(scheme) else { return }
        UIApplication.shared.open(url, options: [:]) { opened in
            if !opened { NSLog("WorldRadio: nothing on this device could open \(url)") }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        reportEngine()
        if !noticeShown {
            noticeShown = true
            showCompatNotice()
        }
        /* The page and the shim are both up: the one moment an update check is worth making. */
        checkForUpdateAfterLoad()
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        NSLog("WorldRadio: page failed to load: \(error)")
        showLoadFailure(error)
    }

    func webView(_ webView: WKWebView,
                 didFail navigation: WKNavigation!,
                 withError error: Error) {
        NSLog("WorldRadio: navigation failed: \(error)")
    }

    /// Low-memory devices kill the web content process, which takes the page and the audio with
    /// it. Rebuild rather than leaving a blank screen and a dead player - the same recovery the
    /// Android shell does in onRenderProcessGone.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        NSLog("WorldRadio: web content process gone - reloading")
        web.reload()
    }
}

// MARK: - the page's messages

extension RadioViewController: WKUIDelegate {

    /// The page is full of `target="_blank"` links (a station's stream and homepage). With no
    /// second window they do nothing at all on Android and would open a new WKWebView here -
    /// either way the player is gone or the link is dead. The shell intercepts those clicks in
    /// JavaScript, so this is the safety net for anything that slips past: no second window,
    /// straight to the phone's browser.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            openExternal(url)
        }
        return nil
    }
}

extension RadioViewController: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == RadioViewController.bridgeName,
              let body = message.body as? [String: Any],
              let name = body["m"] as? String else { return }
        let args = body["a"] as? [Any] ?? []

        switch name {
        case "log":
            NSLog("WorldRadio: page: \(text(args, 0))")

        case "state":
            let live = flag(args.first)
            playing = live
            nowPlaying.setPlaying(live)
            let error = text(args, 2)
            if !error.isEmpty { NSLog("WorldRadio: stream error: \(error)") }

        case "nowplaying":
            nowPlaying.set(title: text(args, 0), subtitle: text(args, 1), art: text(args, 2))

        case "url":
            if let url = URL(string: text(args, 0)) { openExternal(url) }

        case "dismissKeyboard":
            /* A search was committed. Blurring the field is usually enough in a browser, but
               this is a WKWebView and the keyboard is the system's: endEditing is what
               reliably puts it away. */
            view.endEditing(true)

        case "checkUpdate":
            checkForUpdate(manual: true)

        case "updateApp":
            /* Nothing on iOS can install an update over a sideloaded app, so this opens the
               download page and says why. */
            let page = UpdateChecker.downloadPage(text(args, 0))
            let alert = UIAlertController(
                title: "Install the new version",
                message: "iOS will not let an app update itself when it was installed outside the "
                       + "App Store. This opens the download page — install it the same way you "
                       + "did the first time, and your saved stations stay.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Open the page", style: .default) { [weak self] _ in
                self?.openExternal(page)
            })
            alert.addAction(UIAlertAction(title: "Later", style: .cancel))
            present(alert, animated: true)

        default:
            NSLog("WorldRadio: unhandled bridge message '\(name)'")
        }
    }

    private func text(_ args: [Any], _ index: Int) -> String {
        guard index < args.count, let value = args[index] as? String else { return "" }
        return value
    }

    private func flag(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        return false
    }
}
