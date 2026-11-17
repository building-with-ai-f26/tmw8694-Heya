import Foundation

/// The one AI call. Same contract as `app/server.py`: stats are already computed,
/// and the model is only allowed to write the words around them.
enum WrappedService {
    static let openRouterURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    static let kidCards = ["top_friend", "streak", "friend_squad", "mood", "closing"]
    static let adultCards = ["top_friend", "top_place", "streak", "mood", "closing"]
    /// Fallback prices in USD per million tokens, used only if OpenRouter omits cost.
    static let prices = ["anthropic/claude-haiku-5.5": (input: 0.10, output: 0.50)]

    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static func makeWrapped(wearer: String, dataFile: URL) throws -> Data {
        let stats = try StatsEngine.compute(from: Data(contentsOf: dataFile))
        let type = string(stats, "type")
        let kid = type == "kid"
        let cards = kid ? kidCards : adultCards
        let (system, user) = buildPrompt(stats: stats, kid: kid, cards: cards)
        let (text, run) = try callOpenRouter(system: system, user: user)
        var story = try parseStory(text, cards: cards)
        var usedModelCaption = true
        if !kid {
            let caption = shareCaption(in: text)
            if let caption, !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                story.append(("share_caption", caption.trimmingCharacters(in: .whitespacesAndNewlines)))
                story.append(("caption_from_ai", true))
            } else {
                let top = (list(stats, "top_friends").first as? [String: Any])?["name"] as? String ?? ""
                let place = (list(stats, "top_places").first as? [String: Any])?["name"] as? String ?? ""
                let total = int(stats, "total_taps")
                let friends = int(stats, "friend_count")
                story.append(("share_caption", "\(total) taps with \(friends) friends. \(top) and \(place) made my year. #HeyaWrapped"))
                story.append(("caption_from_ai", false))
                usedModelCaption = false
            }
        }
        let cost = run.first { $0.0 == "cost_usd" }?.1
        let costText: String
        if let number = cost as? Double {
            costText = String(format: "%.6f", number)
        } else {
            costText = "n/a"
        }
        print("[wrapped] \(wearer): \(string(run, "model")) \(int(run, "input_tokens")) in / \(int(run, "output_tokens")) out, $\(costText), \(int(run, "ms")) ms\(usedModelCaption ? "" : ", caption fallback used")")
        return try OrderedJSON.data([
            ("stats", stats),
            ("story", story),
            ("run", run),
        ] as [(String, Any)])
    }

    // MARK: - Prompt

    static func buildPrompt(stats: [(String, Any)], kid: Bool, cards: [String]) -> (String, String) {
        let hidden = Set(kid ? ["top_places", "taps_by_month"] : ["taps_by_month"])
        var aiStats = stats.filter { !hidden.contains($0.0) && $0.0 != "top_places" }
        if !kid, let places = stats.first(where: { $0.0 == "top_places" })?.1 as? [Any] {
            let slim: [Any] = places.compactMap { place -> [String: Any]? in
                guard let place = place as? [String: Any] else { return nil }
                return [
                    "name": place["name"] as Any,
                    "taps": place["taps"] as Any,
                    "mostly_with": place["mostly_with"] as Any,
                    "mostly_mood": place["mostly_mood"] as Any,
                ]
            }
            aiStats.append(("top_places", slim))
        }

        let wearer = string(stats, "wearer")
        let age = int(stats, "age")
        let audience = kid
            ? "\(wearer) is \(age) and will read this on a parent's phone, maybe with the parent. Write for a 7-year-old: short, simple, warm words, one idea per sentence. Celebrate friendship and playing outside. Never compare friends negatively or rank anyone as a loser. No places or locations: this kid's data has none."
            : "\(wearer) is \(age), lives in a city, and may post this on social media. Write playful, confident, shareable lines, like a year-in-review recap. Place names are fine; never mention addresses."

        var schema: [(String, Any)] = [
            ("title", "a 3-7 word headline that states one real fact from the stats, e.g. '75 taps with Ava' or 'A summer at Prospect Park'. Never a personality label or 'The ___er' title"),
            ("cards", cards.map { card in
                (card, ["headline": "max 8 words", "body": "max 25 words"] as [String: Any])
            } as [(String, Any)]),
        ]
        if !kid {
            schema.append(("share_caption", "one social caption, max 20 words, may end with #HeyaWrapped"))
        }

        let system = "You write 'Heya Wrapped', a yearly recap of in-person hangouts for Heya, a bracelet that lights up when friends are nearby; friends tap bracelets when they meet. \(audience) Use ONLY the numbers and names in the stats; do not invent or change any number. Refer to friends by name, never with he/she pronouns (you don't know their pronouns). No emoji or symbols; plain words only. Don't invent activities, places, feelings or details that aren't in the stats (no 'long walks', 'coffee', etc.). longest_streak_days counts days in a row with at least one tap with ANY friend; longest_streak_friend was there on longest_streak_friend_days of those days, so never say the streak was all with one friend or every day with them unless those two numbers are equal. Reply with a single JSON object and nothing else."

        let statsJSON = String(data: (try? OrderedJSON.data(aiStats)) ?? Data("{}".utf8), encoding: .utf8) ?? "{}"
        let schemaJSON = String(data: (try? OrderedJSON.data(schema)) ?? Data("{}".utf8), encoding: .utf8) ?? "{}"
        let user = "Stats:\n\(pretty(statsJSON))\n\nReturn JSON with exactly this shape (one entry per card key, in this order):\n\(pretty(schemaJSON))"
        return (system, user)
    }

    /// Indent like Python's `json.dumps(..., indent=1)` so the prompt is familiar, not because the model requires it.
    static func pretty(_ compact: String) -> String {
        guard let data = compact.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: pretty, encoding: .utf8) else { return compact }
        return text
    }

    static func parseStory(_ text: String, cards: [String]) throws -> [(String, Any)] {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            throw Failure(description: "AI reply had no JSON object")
        }
        let slice = Data(text[start...end].utf8)
        guard let story = try JSONSerialization.jsonObject(with: slice) as? [String: Any],
              let title = story["title"] as? String,
              let rawCards = story["cards"] as? [String: Any] else {
            throw Failure(description: "AI reply is missing title or cards")
        }
        var outCards: [Any] = []
        for key in cards {
            guard let card = rawCards[key] as? [String: Any],
                  let headline = card["headline"] as? String, !headline.isEmpty,
                  let body = card["body"] as? String, !body.isEmpty else {
                throw Failure(description: "AI reply is missing card '\(key)'")
            }
            outCards.append(["key": key, "headline": headline, "body": body] as [String: Any])
        }
        return [("title", title), ("cards", outCards)]
    }

    static func shareCaption(in text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { return nil }
        guard let story = try? JSONSerialization.jsonObject(with: Data(text[start...end].utf8)) as? [String: Any] else { return nil }
        return story["share_caption"] as? String
    }

    // MARK: - OpenRouter

    static func callOpenRouter(system: String, user: String) throws -> (String, [(String, Any)]) {
        let env = Env.load()
        let key = env["OPENROUTER_API_KEY"] ?? ""
        if key.isEmpty {
            throw Failure(description: "No OPENROUTER_API_KEY. Copy .env.example to .env and paste your key.")
        }
        let model = (env["HEYA_MODEL"]?.isEmpty == false ? env["HEYA_MODEL"]! : "anthropic/claude-haiku-5.5")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1500,
            "temperature": 0.8,
            "reasoning": ["enabled": false],
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "usage": ["include": true],
        ]
        var request = URLRequest(url: openRouterURL, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Heya Wrapped (iOS)", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let started = Date()
        let (data, response) = try fetch(request)
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let detail = String(data: data, encoding: .utf8)?.prefix(300) ?? ""
            throw Failure(description: "OpenRouter returned HTTP \(http.statusCode): \(detail)")
        }
        guard let reply = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = reply["choices"] as? [[String: Any]],
              let choice = choices.first,
              let message = choice["message"] as? [String: Any] else {
            throw Failure(description: "OpenRouter returned an unexpected reply")
        }
        if choice["finish_reason"] as? String == "length" {
            throw Failure(description: "The AI ran out of room before finishing. Try again.")
        }
        let text = messageText(message)
        let usage = reply["usage"] as? [String: Any] ?? [:]
        let tin = (usage["prompt_tokens"] as? NSNumber)?.intValue ?? 0
        let tout = (usage["completion_tokens"] as? NSNumber)?.intValue ?? 0
        var cost = (usage["cost"] as? NSNumber)?.doubleValue
        if cost == nil, let price = prices[model] {
            cost = (Double(tin) * price.input + Double(tout) * price.output) / 1_000_000
        }
        let run: [(String, Any)] = [
            ("model", reply["model"] as? String ?? model),
            ("input_tokens", tin),
            ("output_tokens", tout),
            ("cost_usd", cost ?? NSNull()),
            ("ms", ms),
        ]
        return (text, run)
    }

    static func messageText(_ message: [String: Any]) -> String {
        if let text = message["content"] as? String { return text }
        if let parts = message["content"] as? [Any] {
            return parts.compactMap { item -> String? in
                (item as? [String: Any])?["text"] as? String
            }.joined()
        }
        return ""
    }

    static func fetch(_ request: URLRequest) throws -> (Data, URLResponse) {
        let transfer = Transfer()
        let wait = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                transfer.result = .failure(error)
            } else if let data, let response {
                transfer.result = .success((data, response))
            } else {
                transfer.result = .failure(Failure(description: "OpenRouter returned an empty reply"))
            }
            wait.signal()
        }.resume()
        wait.wait()
        guard let result = transfer.result else {
            throw Failure(description: "OpenRouter returned an empty reply")
        }
        return try result.get()
    }

    private final class Transfer: @unchecked Sendable {
        var result: Result<(Data, URLResponse), Error>?
    }

    // MARK: - Reading the local .env copied into the app at build time

    enum Env {
        static func load() -> [String: String] {
            var file: [String: String] = [:]
            if let url = Bundle.main.url(forResource: "local", withExtension: "env"),
               let text = try? String(contentsOf: url, encoding: .utf8) {
                for raw in text.split(whereSeparator: \.isNewline) {
                    let line = raw.trimmingCharacters(in: .whitespaces)
                    guard !line.isEmpty, !line.hasPrefix("#"), let eq = line.firstIndex(of: "=") else { continue }
                    let key = line[..<eq].trimmingCharacters(in: .whitespaces)
                    var value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
                    if value.count >= 2, let first = value.first, let last = value.last,
                       (first == "\"" && last == "\"") || (first == "'" && last == "'") {
                        value = value.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
                    }
                    if file[key] == nil { file[key] = value }
                }
            }
            var merged: [String: String] = [:]
            for key in ["OPENROUTER_API_KEY", "HEYA_MODEL"] {
                if let fromProcess = ProcessInfo.processInfo.environment[key], !fromProcess.isEmpty {
                    merged[key] = fromProcess
                } else if let fromFile = file[key] {
                    merged[key] = fromFile
                }
            }
            return merged
        }
    }

    static func string(_ pairs: [(String, Any)], _ key: String) -> String {
        (pairs.first { $0.0 == key }?.1 as? String) ?? ""
    }

    static func int(_ pairs: [(String, Any)], _ key: String) -> Int {
        (pairs.first { $0.0 == key }?.1 as? Int) ?? 0
    }

    static func list(_ pairs: [(String, Any)], _ key: String) -> [Any] {
        (pairs.first { $0.0 == key }?.1 as? [Any]) ?? []
    }
}
