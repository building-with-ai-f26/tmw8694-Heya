import Foundation
import Network

/// Serves the Wrapped page and the two API routes on 127.0.0.1.
/// The phone is the server: the same `app/` files run in a web view, and this
/// replaces `python3 app/server.py`.
final class LocalServer: @unchecked Sendable {
    static let shared = LocalServer()

    private let queue = DispatchQueue(label: "heya.local-server")
    private var listener: NWListener?
    private var port: UInt16?
    private var startWait: CheckedContinuation<UInt16, Error>?

    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    func start() async throws -> UInt16 {
        if let port { return port }
        return try await withCheckedThrowingContinuation { continuation in
            if let port {
                continuation.resume(returning: port)
                return
            }
            if startWait != nil {
                continuation.resume(throwing: Failure(description: "Heya is already starting"))
                return
            }
            startWait = continuation
            do {
                // Loopback only, so the page is not reachable from other devices.
                let parameters = NWParameters.tcp
                parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: .any)
                let listener = try NWListener(using: parameters)
                listener.stateUpdateHandler = { [weak self] state in
                    self?.observe(state)
                }
                listener.newConnectionHandler = { [weak self] connection in
                    self?.accept(connection)
                }
                self.listener = listener
                listener.start(queue: queue)
            } catch {
                finishStart(.failure(error))
            }
        }
    }

    private func observe(_ state: NWListener.State) {
        switch state {
        case .ready:
            guard let raw = listener?.port?.rawValue else {
                finishStart(.failure(Failure(description: "Heya could not open a local port")))
                return
            }
            port = raw
            finishStart(.success(raw))
        case .failed(let error):
            finishStart(.failure(error))
        default:
            break
        }
    }

    private func finishStart(_ result: Result<UInt16, Error>) {
        guard let startWait else { return }
        self.startWait = nil
        startWait.resume(with: result)
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, buffer: Data())
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var next = buffer
            if let data { next.append(data) }
            if next.count > 1_000_000 {
                connection.cancel()
                return
            }
            if let (request, consumed) = Self.parseRequest(next) {
                self.route(request, connection: connection)
                if next.count > consumed {
                    // One request per connection. Extra bytes are ignored.
                }
                return
            }
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            self.receive(connection, buffer: next)
        }
    }

    struct Request {
        var method: String
        var path: String
        var query: String
        var body: Data
    }

    static func parseRequest(_ buffer: Data) -> (Request, Int)? {
        guard let marker = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerText = String(data: buffer.subdata(in: buffer.startIndex..<marker.lowerBound), encoding: .utf8) ?? ""
        let lines = headerText.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let first = lines.first else { return nil }
        let parts = first.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let target = String(parts[1])
        let split = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = split.first.map(String.init) ?? "/"
        let query = split.count > 1 ? String(split[1]) : ""
        var length = 0
        for line in lines.dropFirst() {
            let pair = line.split(separator: ":", maxSplits: 1)
            if pair.count == 2, pair[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" {
                length = Int(pair[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        let bodyStart = marker.upperBound
        guard buffer.distance(from: bodyStart, to: buffer.endIndex) >= length else { return nil }
        let bodyEnd = buffer.index(bodyStart, offsetBy: length)
        let body = buffer.subdata(in: bodyStart..<bodyEnd)
        let request = Request(method: String(parts[0]), path: path.removingPercentEncoding ?? path, query: query, body: body)
        return (request, buffer.distance(from: buffer.startIndex, to: bodyEnd))
    }

    private func route(_ request: Request, connection: NWConnection) {
        if request.path == "/api/stats", request.method == "GET" {
            let wearer = query(request.query, "wearer") ?? ""
            guard let file = dataFile(for: wearer) else {
                sendJSON(connection, status: 404, object: ["error": "unknown wearer"])
                return
            }
            do {
                let stats = try StatsEngine.compute(from: Data(contentsOf: file))
                send(connection, status: 200, type: "application/json", body: try OrderedJSON.data(stats))
            } catch {
                let message = (error as? StatsEngine.Failure)?.description ?? error.localizedDescription
                sendJSON(connection, status: 502, object: ["error": message])
            }
            return
        }
        if request.path == "/api/wrapped", request.method == "POST" {
            DispatchQueue.global(qos: .userInitiated).async {
                let result: Result<(Int, Data), Error>
                do {
                    let payload = (try? JSONSerialization.jsonObject(with: request.body)) as? [String: Any]
                    let wearer = payload?["wearer"] as? String ?? ""
                    guard let file = self.dataFile(for: wearer) else {
                        result = .success((400, try JSONSerialization.data(withJSONObject: ["error": "wearer must be 'grant' or 'faith'"])))
                        self.queue.async { self.reply(connection, result) }
                        return
                    }
                    result = .success((200, try WrappedService.makeWrapped(wearer: wearer, dataFile: file)))
                } catch {
                    print("[wrapped] error: \(error)")
                    let message = (error as? WrappedService.Failure)?.description
                        ?? (error as? StatsEngine.Failure)?.description
                        ?? error.localizedDescription
                    let body = (try? JSONSerialization.data(withJSONObject: ["error": message])) ?? Data("{}".utf8)
                    result = .success((502, body))
                }
                self.queue.async { self.reply(connection, result) }
            }
            return
        }
        if request.method == "GET" {
            serveFile(request.path, connection: connection)
            return
        }
        sendJSON(connection, status: 404, object: ["error": "not found"])
    }

    private func dataFile(for wearer: String) -> URL? {
        guard wearer == "grant" || wearer == "faith", let root = webRoot() else { return nil }
        let url = root.appendingPathComponent("data").appendingPathComponent("\(wearer).json")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func webRoot() -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent("app", isDirectory: true)
    }

    private func serveFile(_ path: String, connection: NWConnection) {
        guard let root = webRoot() else {
            sendJSON(connection, status: 404, object: ["error": "not found"])
            return
        }
        let relative = path == "/" ? "index.html" : String(path.dropFirst())
        if relative == "server.py" || relative.hasPrefix("server.py/") || relative == "data" || relative.hasPrefix("data/") || relative.contains("..") {
            sendJSON(connection, status: 404, object: ["error": "not found"])
            return
        }
        let file = root.appendingPathComponent(relative).standardizedFileURL
        let rootPath = root.standardizedFileURL.path
        let filePath = file.path
        guard filePath == rootPath || filePath.hasPrefix(rootPath + "/"),
              FileManager.default.fileExists(atPath: filePath),
              !directory(filePath) else {
            send(connection, status: 404, type: "text/plain; charset=utf-8", body: Data("Not found".utf8))
            return
        }
        guard let body = try? Data(contentsOf: file) else {
            send(connection, status: 404, type: "text/plain; charset=utf-8", body: Data("Not found".utf8))
            return
        }
        send(connection, status: 200, type: mime(file.pathExtension), body: body)
    }

    private func directory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    private func mime(_ ext: String) -> String {
        switch ext.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "js": return "text/javascript; charset=utf-8"
        case "json": return "application/json"
        case "txt": return "text/plain; charset=utf-8"
        case "svg": return "image/svg+xml"
        case "woff2": return "font/woff2"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        default: return "application/octet-stream"
        }
    }

    private func query(_ query: String, _ name: String) -> String? {
        for pair in query.split(separator: "&") {
            let bits = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if bits.count == 2, bits[0] == Substring(name) {
                return String(bits[1]).removingPercentEncoding
            }
        }
        return nil
    }

    private func reply(_ connection: NWConnection, _ result: Result<(Int, Data), Error>) {
        switch result {
        case .success(let pair):
            send(connection, status: pair.0, type: "application/json", body: pair.1)
        case .failure(let error):
            sendJSON(connection, status: 502, object: ["error": error.localizedDescription])
        }
    }

    private func sendJSON(_ connection: NWConnection, status: Int, object: [String: Any]) {
        let body = (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
        send(connection, status: status, type: "application/json", body: body)
    }

    private func send(_ connection: NWConnection, status: Int, type: String, body: Data) {
        let reason = [200: "OK", 400: "Bad Request", 404: "Not Found", 502: "Bad Gateway"][status] ?? "Error"
        let head = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var payload = Data(head.utf8)
        payload.append(body)
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
