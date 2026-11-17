import SwiftUI
import Combine

/// DURING: open Heya to look around, pick a friend, then follow the glow.
struct LookView: View {
    @Environment(AppState.self) private var state
    @State private var now = Date()
    @State private var showAddFriend = false

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PhaseHeader(phase: "During", text: "Look around, pick a friend, then put your eyes up and follow the glow.")

                    if !state.demoMode, let message = state.radioMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    RingView(display: state.ringDisplay, diameter: 160)
                        .frame(maxWidth: .infinity)

                    MoodPad(now: now)

                    nearbySection

                    if state.demoMode {
                        DemoPanel()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .animation(.spring, value: state.seekCandidates.map(\.id))
            }
            .navigationTitle("Heya")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("Add a friend")
                }
            }
            .onReceive(clock) { date in
                now = date
                state.tick(now: date)
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView()
            }
            .fullScreenCover(isPresented: Binding(
                get: { state.seekingID != nil },
                set: { if !$0 { state.startSeeking(nil) } }
            )) {
                LanternView()
            }
        }
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Nearby now")
                Spacer()
                if !state.demoMode && state.radioMessage == nil {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if state.seekCandidates.isEmpty {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(Palette.quiet)
                    .padding(.vertical, 4)
                if !state.demoMode && state.friends.isEmpty {
                    Button {
                        showAddFriend = true
                    } label: {
                        Label("Add a friend in person", systemImage: "person.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Mood.hang.color)
                    .foregroundStyle(.black)
                }
            }

            ForEach(state.seekCandidates) { friend in
                Button {
                    state.startSeeking(friend.id)
                } label: {
                    NearbyRow(friend: friend)
                }
                .buttonStyle(.plain)
                .disabled(!state.mood.isLit)
            }

            if !state.mood.isLit && !state.seekCandidates.isEmpty {
                Text("Pick a mood to look for friends. While you're Off, nobody can see you.")
                    .font(.footnote)
                    .foregroundStyle(Palette.quiet)
            }
        }
    }

    private var emptyText: String {
        if state.demoMode {
            return "Nobody nearby. Use the demo controls below."
        }
        if state.friends.isEmpty {
            return "Heya friends are added in person. Hold your phones together to start."
        }
        return "No friends nearby right now. Friends show up when they're close by with Heya open."
    }
}

// MARK: - Nearby row

struct NearbyRow: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: 12) {
            if friend.isFriend || friend.metInPerson {
                AvatarTile(grid: friend.avatar, pixel: 3.5)
            } else {
                // Friends of friends stay a mystery until you meet.
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.black)
                    Image(systemName: "sparkles")
                        .foregroundStyle(.white)
                }
                .frame(width: 52, height: 52)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.isFriend ? friend.name : "Friend of \(friend.introducedBy ?? "a friend")")
                    .font(.headline)
                HStack(spacing: 6) {
                    Circle()
                        .fill(friend.mood.color)
                        .frame(width: 9, height: 9)
                    Text(friend.mood.title)
                        .font(.subheadline)
                        .foregroundStyle(Palette.quiet)
                }
            }
            Spacer(minLength: 0)
            Label("Find", systemImage: "scope")
                .font(.subheadline.bold())
                .foregroundStyle(friend.isFriend ? friend.mood.color : Color.white)
        }
        .padding(10)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(friend.isFriend ? Palette.cardBorder : Color.white.opacity(0.6), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Celebration card

struct CelebrationCard: View {
    let celebration: Celebration

    var body: some View {
        VStack(spacing: 6) {
            Text(celebration.isFirst ? "First tap with \(celebration.friendName)!" : "Heya, \(celebration.friendName)!")
                .font(.title2.bold())
            Text("Saved to your Places: \(celebration.placeName)")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            LinearGradient(
                colors: [celebration.colorA.opacity(0.35), celebration.colorB.opacity(0.35)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 22)
        )
    }
}

// MARK: - Mood pad

struct MoodPad: View {
    @Environment(AppState.self) private var state
    let now: Date

    var body: some View {
        Card {
            SectionLabel(text: "Your mood")

            HStack(spacing: 10) {
                Circle()
                    .fill(state.mood.color)
                    .frame(width: 16, height: 16)
                    .shadow(color: state.mood.isLit ? state.mood.color : .clear, radius: 6)
                Text(state.mood.title)
                    .font(.title3.bold())
            }

            Text(fadeText)
                .font(.footnote)
                .foregroundStyle(Palette.quiet)

            HStack(spacing: 8) {
                ForEach(Mood.allCases) { mood in
                    MoodChip(mood: mood, selected: state.mood == mood) {
                        withAnimation(.easeInOut(duration: 0.2)) { state.setMood(mood) }
                    }
                }
            }

            if state.mood == .quiet {
                Text("Low-key. Only your inner circle sees this one.")
                    .font(.footnote)
                    .foregroundStyle(Mood.quiet.color)
            }

            Toggle(isOn: Binding(get: { state.beacon }, set: { state.beacon = $0 })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Beacon")
                        .font(.subheadline.bold())
                    Text("I'm free, come find me")
                        .font(.caption)
                        .foregroundStyle(Palette.quiet)
                }
            }
            .tint(state.mood.color)
            .disabled(!state.mood.isLit)
        }
    }

    private var fadeText: String {
        guard let left = state.remaining(at: now) else {
            return "All lights off. Friends can't see you."
        }
        let seconds = Int(left.rounded(.up))
        let text: String
        if seconds >= 3600 {
            text = "\(seconds / 3600) h \((seconds % 3600) / 60) min"
        } else if seconds >= 60 {
            text = "\(seconds / 60) min \(seconds % 60) s"
        } else {
            text = "\(seconds) s"
        }
        return "Fades to off in \(text)"
    }
}

struct MoodChip: View {
    let mood: Mood
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(mood.shortTitle)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(selected ? Color.black : Color.white)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selected ? fill : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selected ? fill : Color(white: 0.25), lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var fill: Color {
        mood == .off ? Color(white: 0.92) : mood.color
    }
}

// MARK: - Demo controls

struct DemoPanel: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        Card {
            SectionLabel(text: "Demo controls")

            HStack {
                Text("You're at")
                Spacer()
                Picker("You're at", selection: $state.demoPlaceIndex) {
                    ForEach(DemoPlace.all.indices, id: \.self) { index in
                        Text(DemoPlace.all[index].name).tag(index)
                    }
                }
                .labelsHidden()
            }

            Button {
                withAnimation(.spring) { state.toggleFriendOfFriend() }
            } label: {
                Label(
                    state.friendOfFriendNearby ? "Friend of a friend walks away" : "A friend of a friend walks by",
                    systemImage: "sparkles"
                )
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(.white)

            Toggle("Fast fade (30 s demo)", isOn: $state.fastFade)
                .font(.subheadline)

            Text("Tap a friend above to open the lantern, then drag its slider from Far to Touching.")
                .font(.caption)
                .foregroundStyle(Palette.quiet)
        }
    }
}
