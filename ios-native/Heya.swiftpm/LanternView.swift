import SwiftUI
import UIKit

/// The phone becomes the ring: a full-screen glow that warms up as you get closer.
/// Hold it up so your friend can spot you across the room.
struct LanternView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let target = state.seekingFriend
        let color: Color = target.map { $0.isFriend ? $0.mood.color : Color.white } ?? Mood.hang.color
        let closeness = 1 - state.distance

        ZStack {
            Color.black.ignoresSafeArea()

            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let speed = state.inSync ? 5.0 : 2.0 + closeness * 10
                let pulse = 0.6 + 0.4 * sin(t * speed)
                RadialGradient(
                    colors: [color.opacity((0.25 + 0.75 * closeness) * pulse), color.opacity(0)],
                    center: .center,
                    startRadius: 10,
                    endRadius: 180 + 420 * closeness
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 18) {
                HStack {
                    Spacer()
                    Button {
                        state.startSeeking(nil)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Stop looking")
                }

                Spacer()

                RingView(display: state.ringDisplay, diameter: 120)

                if let celebration = state.celebration {
                    CelebrationCard(celebration: celebration)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    VStack(spacing: 8) {
                        Text(caption)
                            .font(.largeTitle.bold())
                        Text(subcaption)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .multilineTextAlignment(.center)
                }

                Spacer()

                if state.canTap {
                    Button {
                        withAnimation(.spring) { state.tapRings() }
                    } label: {
                        Label(state.demoMode ? "Tap rings" : "Bump phones (or tap here)", systemImage: "hand.tap.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(color)
                    .foregroundStyle(.black)
                    .transition(.scale.combined(with: .opacity))
                }

                if state.demoMode && state.celebration == nil {
                    VStack(spacing: 6) {
                        Slider(
                            value: Binding(get: { 1 - state.distance }, set: { state.distance = 1 - $0 }),
                            in: 0...1
                        )
                        .tint(color)
                        HStack {
                            Text("Far")
                            Spacer()
                            Text("Demo: walk closer")
                            Spacer()
                            Text("Touching")
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(24)
            .animation(.spring, value: state.canTap)
        }
        .preferredColorScheme(.dark)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var who: String {
        guard let target = state.seekingFriend else { return "Your friend" }
        return target.isFriend ? target.name : "A friend of a friend"
    }

    private var caption: String {
        if state.canTap { return state.demoMode ? "Touching!" : "Bump phones!" }
        if state.inSync { return "Right here. Look up!" }
        if state.distance > 0.7 { return "Cold" }
        if state.distance > 0.4 { return "Warmer" }
        return "Hot"
    }

    private var subcaption: String {
        if state.canTap { return "Tap together to save the moment." }
        if state.inSync { return "\(who) is a few steps away. Both screens pulse together." }
        if state.distance > 0.7 { return "\(who) is somewhere around. Walk and watch the glow." }
        return "Getting closer. Hold your phone up so they can spot your glow."
    }
}
