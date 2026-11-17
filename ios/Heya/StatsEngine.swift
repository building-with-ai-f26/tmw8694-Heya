import Foundation

/// Numbers for Heya Wrapped. This is the Swift port of `compute_stats` in
/// `app/server.py`: every count comes from the tap file, never from the model.
enum StatsEngine {
    static let moodNames = ["hang": "Let's hang", "quiet": "Quiet company", "wave": "Busy, but wave"]
    static let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    static let monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    /// Ordered JSON object. Key order matches the Python server, which matters
    /// for mood mix (most common first) and for the prompt the model sees.
    static func compute(from data: Data) throws -> [(String, Any)] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure(description: "Tap file is not a JSON object")
        }
        let wearer = jsonString(root["wearer"])
        let age = jsonInt(root["age"])
        let type = jsonString(root["type"])
        let year = jsonInt(root["year"])
        let through = jsonString(root["through"])
        guard let tapRows = root["taps"] as? [[String: Any]], !tapRows.isEmpty else {
            throw Failure(description: "Tap file has no taps")
        }

        let taps: [Tap] = tapRows.map { row in
            Tap(date: jsonString(row["date"]),
                friend: jsonString(row["friend"]),
                place: row["place"] as? String,
                myMood: jsonString(row["my_mood"]))
        }

        var places: [String: (lat: Double, lng: Double)] = [:]
        if let rawPlaces = root["places"] as? [String: Any] {
            for (name, value) in rawPlaces {
                guard let loc = value as? [String: Any] else { continue }
                places[name] = (jsonDouble(loc["lat"]), jsonDouble(loc["lng"]))
            }
        }

        let cal = CalendarClock()
        var friends = Counter<String>()
        var moods = Counter<String>()
        var months = Counter<String>()
        var byMonth: [Int: Int] = [:]
        var weekdays = Counter<String>()
        var dates: [String] = []

        for tap in taps {
            friends.add(tap.friend)
            moods.add(tap.myMood)
            dates.append(tap.date)
            guard let day = cal.parse(tap.date) else { continue }
            let month = cal.calendar.component(.month, from: day)
            let weekday = cal.calendar.component(.weekday, from: day)
            months.add(Self.monthNames[month - 1])
            byMonth[month, default: 0] += 1
            weekdays.add(Self.weekdays[(weekday + 5) % 7])
        }

        let (streak, streakStart, streakEnd) = longestStreak(dates, cal)
        let startText = streakStart.map { cal.format($0) }
        let endText = streakEnd.map { cal.format($0) }
        let inStreak: (Tap) -> Bool = { tap in
            guard let startText, let endText else { return false }
            return startText <= tap.date && tap.date <= endText
        }

        var streakFriends = Counter<String>()
        for tap in taps where inStreak(tap) {
            streakFriends.add(tap.friend)
        }
        let streakFriend = streakFriends.mostCommon(1).first?.0
        let streakFriendDays = Set(taps.filter { inStreak($0) && $0.friend == streakFriend }.map(\.date)).count

        var firstSeen: [String: String] = [:]
        var firstOrder: [String] = []
        for tap in taps.sorted(by: { $0.date < $1.date }) where firstSeen[tap.friend] == nil {
            firstSeen[tap.friend] = tap.date
            firstOrder.append(tap.friend)
        }
        let newest = firstOrder.max { firstSeen[$0, default: ""] < firstSeen[$1, default: ""] }

        guard let busiestMonth = months.mostCommon(1).first?.0,
              let busiestWeekday = weekdays.mostCommon(1).first?.0,
              let topMoodKey = moods.mostCommon(1).first?.0,
              let topMood = moodNames[topMoodKey] else {
            throw Failure(description: "Tap file is missing a mood or a date")
        }

        let topFriends: [Any] = friends.mostCommon(5).map { name, count in
            ["name": name, "taps": count] as [String: Any]
        }
        let topName = friends.mostCommon(1).first?.0
        let lastMonth = cal.parse(through).map { cal.calendar.component(.month, from: $0) } ?? 0
        let tapsByMonth = (1...max(lastMonth, 0)).map { byMonth[$0] ?? 0 }

        var stats: [(String, Any)] = [
            ("wearer", wearer),
            ("age", age),
            ("type", type),
            ("period", "\(year)-01-01 to \(through)"),
            ("total_taps", taps.count),
            ("days_with_taps", Set(taps.map(\.date)).count),
            ("friend_count", friends.order.count),
            ("top_friends", topFriends),
            ("longest_streak_days", streak),
            ("longest_streak_dates", startText != nil ? [startText!, endText!] : NSNull()),
            ("longest_streak_friend", streakFriend ?? NSNull()),
            ("longest_streak_friend_days", streakFriendDays),
            ("busiest_month", busiestMonth),
            ("busiest_weekday", busiestWeekday),
            ("top_mood", topMood),
            ("mood_mix", moods.mostCommon(nil).map { key, count in (moodNames[key] ?? key, count as Any) }),
            ("newest_friend", newest ?? NSNull()),
            ("taps_by_month", tapsByMonth),
            ("mood_with_top_friend", topMoodName(taps.filter { $0.friend == topName }) ?? NSNull()),
            ("mood_during_streak", topMoodName(taps.filter(inStreak)) ?? NSNull()),
        ]

        if type == "adult" {
            var placeCounts = Counter<String>()
            for tap in taps {
                if let place = tap.place { placeCounts.add(place) }
            }
            var topPlaces: [Any] = []
            for (name, count) in placeCounts.mostCommon(nil) {
                var withWhom = Counter<String>()
                let here = taps.filter { $0.place == name }
                for tap in here { withWhom.add(tap.friend) }
                let mostlyWith = withWhom.mostCommon(1).first?.0 ?? ""
                let mostlyMood = topMoodName(here) ?? ""
                let loc = places[name] ?? (lat: 0, lng: 0)
                topPlaces.append([
                    "name": name,
                    "taps": count,
                    "mostly_with": mostlyWith,
                    "mostly_mood": mostlyMood,
                    "lat": loc.lat,
                    "lng": loc.lng,
                ] as [String: Any])
            }
            stats.append(("top_places", topPlaces))
            let moodAtTop = (topPlaces.first as? [String: Any])?["mostly_mood"] as? String
            stats.append(("mood_at_top_place", moodAtTop ?? NSNull()))
        }
        return stats
    }

    static func topMoodName(_ taps: [Tap]) -> String? {
        var moods = Counter<String>()
        for tap in taps { moods.add(tap.myMood) }
        guard let key = moods.mostCommon(1).first?.0 else { return nil }
        return moodNames[key]
    }

    /// Longest run of consecutive calendar days that have at least one tap.
    /// Ties keep the earliest run, matching Python's `>` check.
    static func longestStreak(_ dates: [String], _ cal: CalendarClock) -> (Int, Date?, Date?) {
        let days = Array(Set(dates.compactMap { cal.parse($0) })).sorted()
        guard let first = days.first else { return (0, nil, nil) }
        var best = 1
        var run = 1
        var bestEnd = first
        for index in days.indices.dropFirst() {
            let gap = cal.calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day
            run = gap == 1 ? run + 1 : 1
            if run > best {
                best = run
                bestEnd = days[index]
            }
        }
        let start = cal.calendar.date(byAdding: .day, value: -(best - 1), to: bestEnd)
        return (best, start, bestEnd)
    }

    struct Tap {
        let date: String
        let friend: String
        let place: String?
        let myMood: String
    }

    struct Counter<Element: Hashable> {
        private(set) var counts: [Element: Int] = [:]
        private(set) var order: [Element] = []

        mutating func add(_ element: Element) {
            if counts[element] == nil { order.append(element) }
            counts[element, default: 0] += 1
        }

        /// Most frequent first. Equal counts keep the order they were first seen.
        func mostCommon(_ limit: Int?) -> [(Element, Int)] {
            let ranked = order.sorted { counts[$0, default: 0] > counts[$1, default: 0] }
            let kept = limit.map { Array(ranked.prefix($0)) } ?? ranked
            return kept.map { ($0, counts[$0, default: 0]) }
        }
    }

    struct CalendarClock {
        let calendar: Calendar
        let formatter: DateFormatter

        init() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            self.calendar = calendar
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd"
            self.formatter = formatter
        }

        func parse(_ text: String) -> Date? { formatter.date(from: text) }
        func format(_ date: Date) -> String { formatter.string(from: date) }
    }
}

private func jsonString(_ value: Any?) -> String {
    value as? String ?? ""
}

private func jsonInt(_ value: Any?) -> Int {
    (value as? NSNumber)?.intValue ?? 0
}

private func jsonDouble(_ value: Any?) -> Double {
    (value as? NSNumber)?.doubleValue ?? 0
}

enum OrderedJSON {
    static func data(_ value: Any) throws -> Data {
        var text = ""
        try write(value, into: &text)
        return Data(text.utf8)
    }

    private static func write(_ value: Any, into text: inout String) throws {
        if value is NSNull {
            text += "null"
        } else if let flag = value as? Bool {
            text += flag ? "true" : "false"
        } else if let number = value as? Int {
            text += String(number)
        } else if let number = value as? Double {
            let encoded = try JSONSerialization.data(withJSONObject: [number])
            guard let rendered = String(data: encoded, encoding: .utf8), rendered.count >= 2 else {
                throw StatsEngine.Failure(description: "Could not encode a number")
            }
            text += rendered.dropFirst().dropLast()
        } else if let string = value as? String {
            text += "\"" + escape(string) + "\""
        } else if let pairs = value as? [(String, Any)] {
            text += "{"
            for (index, pair) in pairs.enumerated() {
                if index > 0 { text += "," }
                text += "\"" + escape(pair.0) + "\":"
                try write(pair.1, into: &text)
            }
            text += "}"
        } else if let object = value as? [String: Any] {
            text += "{"
            for (index, key) in object.keys.sorted().enumerated() {
                if index > 0 { text += "," }
                text += "\"" + escape(key) + "\":"
                try write(object[key]!, into: &text)
            }
            text += "}"
        } else if let list = value as? [Any] {
            text += "["
            for (index, item) in list.enumerated() {
                if index > 0 { text += "," }
                try write(item, into: &text)
            }
            text += "]"
        } else if let list = value as? [String] {
            try write(list.map { $0 as Any }, into: &text)
        } else if let list = value as? [Int] {
            try write(list.map { $0 as Any }, into: &text)
        } else {
            throw StatsEngine.Failure(description: "Could not encode \(type(of: value))")
        }
    }

    private static func escape(_ string: String) -> String {
        var out = ""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out
    }
}

#if STATS_CLI
@main
enum StatsCLI {
    static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let stats = try StatsEngine.compute(from: Data(contentsOf: url))
        FileHandle.standardOutput.write(try OrderedJSON.data(stats))
    }
}
#endif
