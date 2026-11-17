import SwiftUI
import CoreLocation

// MARK: - Mood

enum Mood: String, CaseIterable, Identifiable, Codable {
    /// High energy: actively up for hanging out.
    case hang
    /// Low-key: "sit with me, no big conversation needed."
    case quiet
    case wave
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hang: return "Let's hang"
        case .quiet: return "Quiet company"
        case .wave: return "Busy, but wave"
        case .off: return "Off"
        }
    }

    var shortTitle: String {
        switch self {
        case .hang: return "Hang"
        case .quiet: return "Quiet"
        case .wave: return "Wave"
        case .off: return "Off"
        }
    }

    var color: Color {
        switch self {
        case .hang: return Color(red: 0.20, green: 0.83, blue: 0.60)
        case .quiet: return Color(red: 0.65, green: 0.55, blue: 0.98)
        case .wave: return Color(red: 0.98, green: 0.75, blue: 0.14)
        case .off: return Color(white: 0.22)
        }
    }

    var isLit: Bool { self != .off }
}

// MARK: - Pixel avatar (12 x 12, black and white)

struct PixelGrid: Equatable, Codable {
    static let size = 12

    var bits: [Bool]

    init(bits: [Bool]) {
        let count = PixelGrid.size * PixelGrid.size
        self.bits = bits.count == count ? bits : Array(repeating: false, count: count)
    }

    /// Build from rows of text: "#" is a white pixel, anything else is black.
    init(art: [String]) {
        var result: [Bool] = []
        for r in 0..<PixelGrid.size {
            let row = r < art.count ? Array(art[r]) : []
            for c in 0..<PixelGrid.size {
                result.append(c < row.count && row[c] == "#")
            }
        }
        self.bits = result
    }

    subscript(row: Int, col: Int) -> Bool {
        get { bits[row * PixelGrid.size + col] }
        set { bits[row * PixelGrid.size + col] = newValue }
    }

    static var blank: PixelGrid {
        PixelGrid(bits: Array(repeating: false, count: size * size))
    }

    /// A random, left-right symmetric shape.
    static func random() -> PixelGrid {
        var grid = PixelGrid.blank
        let half = size / 2
        for r in 0..<size {
            for c in 0..<half {
                let on = Bool.random()
                grid[r, c] = on
                grid[r, size - 1 - c] = on
            }
        }
        return grid
    }

    var inverted: PixelGrid {
        PixelGrid(bits: bits.map { !$0 })
    }

    var storageString: String {
        bits.map { $0 ? "1" : "0" }.joined()
    }

    init?(storageString: String) {
        guard storageString.count == PixelGrid.size * PixelGrid.size else { return nil }
        self.init(bits: storageString.map { $0 == "1" })
    }

    // Saved as the compact "0101…" string.
    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        self = PixelGrid(storageString: text) ?? PixelGrid.blank
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageString)
    }
}

// MARK: - Friend

struct Friend: Identifiable, Equatable, Codable {
    /// For real friends this is their Heya ID, learned when you added them in person.
    var id: UUID
    var name: String
    var initials: String
    var avatar: PixelGrid
    var mood: Mood
    /// Index into `Friend.signatures`: the friend's color on your Places map.
    var colorIndex: Int
    var isNearby: Bool
    /// false = a friend of a friend you haven't added yet (demo only for now).
    var isFriend: Bool
    var introducedBy: String?
    /// Inner circle friends are the only ones who see "Quiet company".
    var isInnerCircle: Bool
    /// For friends of friends: true once you've met in person.
    var metInPerson: Bool

    init(
        id: UUID = UUID(),
        name: String,
        initials: String,
        avatar: PixelGrid,
        mood: Mood,
        colorIndex: Int,
        isNearby: Bool = false,
        isFriend: Bool = true,
        introducedBy: String? = nil,
        isInnerCircle: Bool = false,
        metInPerson: Bool = false
    ) {
        self.id = id
        self.name = name
        self.initials = initials
        self.avatar = avatar
        self.mood = mood
        self.colorIndex = colorIndex
        self.isNearby = isNearby
        self.isFriend = isFriend
        self.introducedBy = introducedBy
        self.isInnerCircle = isInnerCircle
        self.metInPerson = metInPerson
    }

    static let signatures: [Color] = [
        Color(red: 1.00, green: 0.45, blue: 0.40),
        Color(red: 0.35, green: 0.70, blue: 1.00),
        Color(red: 0.62, green: 0.90, blue: 0.30),
        Color(red: 1.00, green: 0.45, blue: 0.75),
        Color(red: 1.00, green: 0.65, blue: 0.25),
        Color(red: 0.30, green: 0.85, blue: 0.80)
    ]

    var signature: Color {
        Friend.signatures[colorIndex % Friend.signatures.count]
    }
}

// MARK: - Moments and places (stored only on this phone)

/// One in-person tap: who, when, and (if known) where.
struct Moment: Identifiable, Equatable, Codable {
    var id = UUID()
    var friendID: UUID
    var date: Date
    var latitude: Double? = nil
    var longitude: Double? = nil
    var placeName: String? = nil
}

/// Moments within about a block of each other, shown as one pin.
struct PlaceGroup: Identifiable, Equatable {
    var id: String
    var name: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func key(for moment: Moment) -> String? {
        guard let lat = moment.latitude, let lon = moment.longitude else { return nil }
        return String(format: "%.3f,%.3f", lat, lon)
    }
}

/// How often you've met a friend at one place.
struct PlaceVisit: Identifiable {
    var name: String
    var count: Int
    var id: String { name }
}

/// What your phone shares over Bluetooth with Heya phones nearby.
struct PublicProfile: Codable, Equatable {
    var id: UUID
    var name: String
    var initials: String
    var avatar: String
    var mood: Mood
    /// True while the "Add a friend" screen is open.
    var pairing: Bool
    /// Friends allowed to see "Quiet company" (your inner circle).
    var quietFor: [UUID]
}

// MARK: - Demo data

struct DemoPlace {
    let name: String
    let latitude: Double
    let longitude: Double

    static let all: [DemoPlace] = [
        DemoPlace(name: "Washington Square Park", latitude: 40.7308, longitude: -73.9973),
        DemoPlace(name: "Joe's Pizza", latitude: 40.7305, longitude: -74.0022),
        DemoPlace(name: "Union Square", latitude: 40.7359, longitude: -73.9906),
        DemoPlace(name: "Bryant Park", latitude: 40.7536, longitude: -73.9832),
        DemoPlace(name: "The High Line", latitude: 40.7480, longitude: -74.0048),
        DemoPlace(name: "Tompkins Square Park", latitude: 40.7265, longitude: -73.9817),
        DemoPlace(name: "The Strand", latitude: 40.7332, longitude: -73.9907)
    ]
}

extension PixelGrid {
    static let me = PixelGrid(art: [
        "...######...",
        "..#......#..",
        ".#........#.",
        "#..##..##..#",
        "#..##..##..#",
        "#..........#",
        "#.#......#.#",
        "#..#....#..#",
        ".#..####..#.",
        "..#......#..",
        "...######...",
        "............"
    ])

    static let sam = PixelGrid(art: [
        "....####....",
        "..########..",
        ".##########.",
        ".##..##..##.",
        ".##########.",
        ".###.##.###.",
        ".####..####.",
        "..########..",
        "....####....",
        "..########..",
        ".##########.",
        "############"
    ])

    static let priya = PixelGrid(art: [
        "...######...",
        "..########..",
        ".###....###.",
        ".##.#..#.##.",
        ".##......##.",
        ".##.#..#.##.",
        ".##..##..##.",
        ".###....###.",
        ".##.####.##.",
        ".##......##.",
        "##.######.##",
        "############"
    ])

    static let jordan = PixelGrid(art: [
        "..########..",
        ".##########.",
        "############",
        "..#......#..",
        "..#.#..#.#..",
        "..#......#..",
        "..#.####.#..",
        "...#....#...",
        "....####....",
        "..########..",
        ".##########.",
        "############"
    ])

    static let maya = PixelGrid(art: [
        "....####....",
        "....####....",
        "...######...",
        "..#......#..",
        ".#..#..#..#.",
        ".#........#.",
        ".#..####..#.",
        "..#......#..",
        "...######...",
        "..########..",
        ".##########.",
        "############"
    ])

    static let theo = PixelGrid(art: [
        "..########..",
        ".#........#.",
        ".#........#.",
        "###.####.###",
        "#.#.#..#.#.#",
        "###.####.###",
        ".#........#.",
        ".#..####..#.",
        "..#......#..",
        "...######...",
        ".##########.",
        "############"
    ])

    static let ava = PixelGrid(art: [
        "##..####..##",
        "###.####.###",
        ".#.######.#.",
        "..#......#..",
        "..#.#..#.#..",
        "..#......#..",
        "..#.#..#.#..",
        "..#..##..#..",
        "...######...",
        "..########..",
        ".##########.",
        "############"
    ])
}

extension Friend {
    /// Order matters for `Moment.makeDemo`.
    static func makeDemo() -> [Friend] {
        [
            Friend(name: "Priya", initials: "PR", avatar: .priya, mood: .quiet, colorIndex: 0, isNearby: true, isInnerCircle: true),
            Friend(name: "Jordan", initials: "JO", avatar: .jordan, mood: .wave, colorIndex: 1, isNearby: true),
            Friend(name: "Sam", initials: "SM", avatar: .sam, mood: .hang, colorIndex: 2, isNearby: true, isInnerCircle: true),
            Friend(name: "Theo", initials: "TH", avatar: .theo, mood: .off, colorIndex: 3),
            Friend(name: "Ava", initials: "AV", avatar: .ava, mood: .wave, colorIndex: 4),
            Friend(name: "Maya", initials: "MA", avatar: .maya, mood: .hang, colorIndex: 5, isFriend: false, introducedBy: "Priya")
        ]
    }
}

extension Moment {
    static func makeDemo(friends: [Friend]) -> [Moment] {
        func m(_ friend: Int, _ place: Int, _ days: Double) -> Moment {
            let p = DemoPlace.all[place]
            return Moment(
                friendID: friends[friend].id,
                date: Date.now.addingTimeInterval(-days * 86_400),
                latitude: p.latitude,
                longitude: p.longitude,
                placeName: p.name
            )
        }
        return [
            m(0, 0, 1), m(0, 0, 6), m(0, 0, 13), m(0, 0, 20), m(0, 1, 9), m(0, 1, 27),
            m(1, 3, 4), m(1, 3, 18),
            m(2, 2, 2), m(2, 2, 15), m(2, 5, 8), m(2, 5, 36),
            m(3, 4, 5), m(3, 4, 12), m(3, 4, 40)
        ]
    }
}
