import Foundation
import Network

/// Serves the bundled web app to the WebView over loopback.
///
/// Why not simply load `file://`? Three reasons, each of which bites on iOS:
///
/// 1. `localStorage` on a `file://` origin is not reliably persistent, and the site keeps
///    favourites and volume there.
/// 2. A `file://` page is an opaque origin, which makes the page's own script/data loading
///    fragile.
/// 3. Media is blocked as mixed content when a page is served from a secure or custom scheme.
///    Serving the page over `http` keeps the page and the streams on the same scheme, which is
///    what keeps the ~8,330 cleartext `http://` stations playable.
///
/// The port is pinned and remembered, because `localStorage` is keyed by origin: a different
/// port on every launch would silently lose the user's favourites.
///
/// Loopback only (`acceptLocalOnly`), so nothing on the network can reach this server.
final class LocalServer {

    static let shared = LocalServer()

    private let queue = DispatchQueue(label: "com.moddys.worldradio.server")
    private var listener: NWListener?
    private var root: URL?
    private(set) var isRunning = false

    private static let candidates: [UInt16] = [8791, 8792, 8793, 8794, 8795]
    private static let portKey = "LocalServer.port"

    private init() {}

    /// Start serving `bundleRoot`. Returns the port, or nil if none could be opened.
    func start(bundleRoot: URL) -> UInt16? {
        root = bundleRoot

        var order = LocalServer.candidates
        if let remembered = UserDefaults.standard.object(forKey: LocalServer.portKey) as? Int,
           let port = UInt16(exactly: remembered),
           let index = order.firstIndex(of: port) {
            order.remove(at: index)
            order.insert(port, at: 0)
        }

        for port in order {
            if let opened = tryListen(on: port) { return opened }
        }
        NSLog("WorldRadio: no loopback port available - the app will fall back to file://")
        return nil
    }

    private func tryListen(on port: UInt16) -> UInt16? {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return nil }

        let parameters = NWParameters.tcp
        parameters.acceptLocalOnly = true          // 127.0.0.1 and nothing else
        parameters.allowLocalEndpointReuse = true

        guard let candidate = try? NWListener(using: parameters, on: nwPort) else { return nil }

        let ready = DispatchSemaphore(value: 0)
        var opened = false
        candidate.stateUpdateHandler = { state in
            switch state {
            case .ready:
                opened = true
                ready.signal()
            case .failed, .cancelled:
                ready.signal()
            default:
                break
            }
        }
        candidate.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        candidate.start(queue: queue)

        if ready.wait(timeout: .now() + 1.5) == .timedOut {
            candidate.cancel()
            return nil
        }
        guard opened else {
            candidate.cancel()
            return nil
        }

        listener = candidate
        isRunning = true
        UserDefaults.standard.set(Int(port), forKey: LocalServer.portKey)
        NSLog("WorldRadio: serving the bundled app on http://127.0.0.1:\(port)/")
        return port
    }

    // MARK: - requests

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, buffer: Data())
    }

    /// Read until the end of the request head. Static files, so nothing else is needed - no
    /// request bodies, no keep-alive, no ranges (the streams a user plays are fetched by the
    /// WebView itself, straight from the station, never through here).
    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) {
            [weak self] data, _, isComplete, error in
            guard let self = self else {
                connection.cancel()
                return
            }
            var accumulated = buffer
            if let chunk = data { accumulated.append(chunk) }

            if let end = accumulated.range(of: Data("\r\n\r\n".utf8)) {
                let head = String(decoding: accumulated[accumulated.startIndex..<end.lowerBound],
                                  as: UTF8.self)
                self.respond(connection, request: head)
                return
            }
            if error != nil || isComplete || accumulated.count > 64 * 1024 {
                connection.cancel()
                return
            }
            self.receive(connection, buffer: accumulated)
        }
    }

    private func respond(_ connection: NWConnection, request: String) {
        let lines = request.components(separatedBy: "\r\n")
        let parts = (lines.first ?? "").components(separatedBy: " ")
        let method = parts.count > 0 ? parts[0] : ""
        let target = parts.count > 1 ? parts[1] : "/"
        let headOnly = method == "HEAD"

        guard method == "GET" || headOnly else {
            send(connection, status: "405 Method Not Allowed", type: "text/plain",
                 body: Data("only GET is served here".utf8), headOnly: true)
            return
        }
        guard let file = resolve(target), let body = try? Data(contentsOf: file) else {
            send(connection, status: "404 Not Found", type: "text/plain; charset=utf-8",
                 body: Data("not found".utf8), headOnly: headOnly)
            return
        }
        send(connection, status: "200 OK", type: LocalServer.mimeType(file.pathExtension),
             body: body, headOnly: headOnly)
    }

    /// Map a request path onto a file inside the bundle, refusing anything that tries to
    /// climb out of it.
    private func resolve(_ target: String) -> URL? {
        guard let root = root else { return nil }
        var path = String(target.split(separator: "?").first ?? "/")
        if let decoded = path.removingPercentEncoding { path = decoded }
        if path.isEmpty || path == "/" { path = "/index.html" }
        if path.contains("..") { return nil }

        var file = root
        for component in path.split(separator: "/") where !component.isEmpty {
            file.appendPathComponent(String(component))
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else { return nil }
        return file
    }

    private func send(_ connection: NWConnection, status: String, type: String,
                      body: Data, headOnly: Bool) {
        var head = "HTTP/1.1 \(status)\r\n"
        head += "Content-Type: \(type)\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Cache-Control: no-store\r\n"
        head += "Connection: close\r\n\r\n"

        var out = Data(head.utf8)
        if !headOnly { out.append(body) }

        connection.send(content: out, contentContext: .finalMessage, isComplete: true,
                        completion: .contentProcessed { _ in connection.cancel() })
    }

    static func mimeType(_ ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js", "mjs": return "application/javascript; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "svg": return "image/svg+xml"
        case "ico": return "image/x-icon"
        case "txt": return "text/plain; charset=utf-8"
        default: return "application/octet-stream"
        }
    }
}
