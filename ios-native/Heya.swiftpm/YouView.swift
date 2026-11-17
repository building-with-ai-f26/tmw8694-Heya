import SwiftUI

/// BEFORE: who you are, who's in your inner circle, who can find you.
struct YouView: View {
    @Environment(AppState.self) private var state
    /// While dragging, every cell touched is set to this value.
    @State private var paintValue: Bool?

    var body: some View {
        @Bindable var state = state

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PhaseHeader(phase: "Before", text: "Set up who you are and who can find you. Then put your phone away.")

                    Card {
                        SectionLabel(text: "Mode")
                        Toggle(isOn: Binding(get: { state.demoMode }, set: { state.setDemoMode($0) })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Demo mode")
                                Text("Sample friends and a slider. Turn off to use real Bluetooth with friends nearby (needs real iPhones).")
                                    .font(.caption)
                                    .foregroundStyle(Palette.quiet)
                            }
                        }
                        .tint(Mood.hang.color)
                    }

                    Card {
                        SectionLabel(text: "Your pixel avatar")
                        Text("Friends see it after you meet. Tap or drag to draw.")
                            .font(.footnote)
                            .foregroundStyle(Palette.quiet)
                        editorGrid
                            .frame(maxWidth: .infinity)
                        HStack(spacing: 8) {
                            toolButton("Clear", icon: "trash") { state.myAvatar = .blank }
                            toolButton("Invert", icon: "circle.lefthalf.filled") { state.myAvatar = state.myAvatar.inverted }
                            toolButton("Random", icon: "dice") { state.myAvatar = .random() }
                        }
                        TextField("Name", text: $state.myName)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.words)
                        TextField("Initials (2 letters)", text: $state.myInitials)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }

                    Card {
                        SectionLabel(text: "Inner circle")
                        Text("Only these friends see \"Quiet company\".")
                            .font(.footnote)
                            .foregroundStyle(Palette.quiet)
                        if state.friends.filter({ $0.isFriend }).isEmpty {
                            Text("Add friends first, in person from the Look tab.")
                                .font(.footnote)
                                .foregroundStyle(Palette.quiet)
                        }
                        ForEach(state.friends.filter { $0.isFriend }) { friend in
                            Toggle(isOn: Binding(
                                get: { state.friend(with: friend.id)?.isInnerCircle ?? false },
                                set: { state.setInnerCircle(friend.id, $0) }
                            )) {
                                HStack(spacing: 10) {
                                    AvatarTile(grid: friend.avatar, pixel: 2.5)
                                    Text(friend.name)
                                }
                            }
                            .tint(Mood.quiet.color)
                        }
                    }

                    Card {
                        SectionLabel(text: "Privacy")
                        Toggle(isOn: $state.discoverableToFriendsOfFriends) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Friends of friends can spot my glint")
                                Text("Never strangers. Your name is shared only after you tap rings.")
                                    .font(.caption)
                                    .foregroundStyle(Palette.quiet)
                            }
                        }
                        Toggle(isOn: $state.showNameOnFriendsMaps) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show my name on friends' Places")
                                Text("Off: their map says \"a friend\" instead.")
                                    .font(.caption)
                                    .foregroundStyle(Palette.quiet)
                            }
                        }
                        Label("No location tracking. No map of where friends are. Ever.", systemImage: "lock.fill")
                            .font(.footnote)
                            .foregroundStyle(Palette.quiet)
                    }
                    .tint(Mood.hang.color)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("You")
            .onChange(of: state.myAvatar) { state.saveProfile() }
            .onChange(of: state.myName) { state.saveProfile() }
            .onChange(of: state.myInitials) {
                let cleaned = String(state.myInitials.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(2))
                if cleaned != state.myInitials { state.myInitials = cleaned }
                state.saveProfile()
            }
        }
    }

    private var editorGrid: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / CGFloat(PixelGrid.size)
            let grid = state.myAvatar

            Canvas { context, _ in
                for r in 0..<PixelGrid.size {
                    for c in 0..<PixelGrid.size {
                        let rect = CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell, height: cell)
                        context.fill(Path(rect), with: .color(grid[r, c] ? .white : .black))
                        context.stroke(Path(rect), with: .color(Color(white: 0.2)), lineWidth: 0.5)
                    }
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let c = Int(drag.location.x / cell)
                        let r = Int(drag.location.y / cell)
                        guard (0..<PixelGrid.size).contains(r), (0..<PixelGrid.size).contains(c) else { return }
                        if paintValue == nil { paintValue = !state.myAvatar[r, c] }
                        if let value = paintValue, state.myAvatar[r, c] != value {
                            state.myAvatar[r, c] = value
                        }
                    }
                    .onEnded { _ in paintValue = nil }
            )
            .accessibilityLabel("Pixel avatar editor, 12 by 12")
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func toolButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(.white)
    }
}
