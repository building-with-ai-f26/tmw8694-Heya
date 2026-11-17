import SwiftUI

// MARK: - Colors

enum Palette {
    static let card = Color(white: 0.09)
    static let cardBorder = Color(white: 0.17)
    static let quiet = Color(white: 0.64)
}

// MARK: - The ring

/// What the 12 LEDs should show.
struct RingDisplay {
    /// Your mood color, what friends see.
    var base: Color
    var baseLit: Bool
    var basePulse: Bool
    /// A friend's color filling in as you get closer (warmer / colder).
    var accent: Color? = nil
    var accentCount: Int = 0
    var accentPulseSpeed: Double = 0
    /// A white sparkle running around the band: a friend of a friend is near.
    var glint: Bool = false
    /// Tap moment: both colors chase around the band.
    var celebrateA: Color? = nil
    var celebrateB: Color? = nil

    func led(_ index: Int, at t: Double) -> (color: Color, level: Double) {
        if let a = celebrateA, let b = celebrateB {
            return ((index + Int(t * 10)) % 2 == 0 ? a : b, 1)
        }
        if glint, index == Int(t * 7) % 12 {
            return (.white, 1)
        }
        if let accent, index < accentCount {
            let level = accentPulseSpeed > 0 ? 0.55 + 0.45 * sin(t * accentPulseSpeed) : 1
            return (accent, level)
        }
        guard baseLit else { return (.clear, 0) }
        let level = basePulse ? 0.62 + 0.38 * sin(t * 3.4) : 1
        return (base, level)
    }
}

/// A plain band with 12 LEDs glowing through a frosted channel.
struct RingView: View {
    var display: RingDisplay
    var diameter: CGFloat = 200

    private let metal = LinearGradient(
        colors: [Color(white: 0.93), Color(white: 0.56), Color(white: 0.80), Color(white: 0.44)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .stroke(metal, lineWidth: diameter * 0.17)
                Circle()
                    .stroke(Color(white: 0.11), lineWidth: diameter * 0.05)
                ForEach(0..<12, id: \.self) { i in
                    let led = display.led(i, at: t)
                    ZStack {
                        Circle()
                            .fill(led.color)
                            .frame(width: diameter * 0.12, height: diameter * 0.12)
                            .blur(radius: diameter * 0.04)
                            .opacity(led.level * 0.85)
                        Circle()
                            .fill(led.color)
                            .frame(width: diameter * 0.045, height: diameter * 0.045)
                            .opacity(led.level)
                    }
                    .offset(y: -diameter / 2)
                    .rotationEffect(.degrees(Double(i) * 30))
                }
            }
            .frame(width: diameter, height: diameter)
        }
        .padding(diameter * 0.12)
        .accessibilityElement()
        .accessibilityLabel("Heya ring")
    }
}

// MARK: - Pixel avatar

struct PixelAvatarView: View {
    let grid: PixelGrid
    var pixel: CGFloat = 4

    var body: some View {
        let side = pixel * CGFloat(PixelGrid.size)
        Canvas { context, _ in
            for r in 0..<PixelGrid.size {
                for c in 0..<PixelGrid.size where grid[r, c] {
                    let rect = CGRect(x: CGFloat(c) * pixel, y: CGFloat(r) * pixel, width: pixel, height: pixel)
                    context.fill(Path(rect), with: .color(.white))
                }
            }
        }
        .frame(width: side, height: side)
        .background(Color.black)
        .accessibilityHidden(true)
    }
}

/// Avatar on a black tile, like a 1-bit screen.
struct AvatarTile: View {
    let grid: PixelGrid
    var pixel: CGFloat = 4

    var body: some View {
        PixelAvatarView(grid: grid, pixel: pixel)
            .padding(pixel * 1.5)
            .background(Color.black, in: RoundedRectangle(cornerRadius: pixel * 2.5))
    }
}

// MARK: - Labels

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(Palette.quiet)
    }
}

/// "Before", "During" or "After", with one line on what this screen is for.
struct PhaseHeader: View {
    let phase: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(phase.uppercased())
                .font(.caption.bold())
                .tracking(1.5)
                .foregroundStyle(Mood.hang.color)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Palette.quiet)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 22))
    }
}
