import SwiftUI

/// Friends are added in person only: both people open this screen and hold phones together.
struct AddFriendView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 56))
                        .foregroundStyle(Mood.hang.color)
                        .padding(.top, 12)

                    Text("Hold phones together")
                        .font(.title2.bold())

                    Text("Heya friends are added in person only. Ask your friend to open Add a friend too.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.quiet)

                    if state.demoMode {
                        Text("You're in Demo mode. Turn it off in the You tab to add real friends.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.orange)
                    } else if let message = state.radioMessage {
                        Text(message)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.orange)
                    } else if state.pairingCandidates.isEmpty {
                        ProgressView("Looking for a phone right next to you…")
                            .padding(.top, 8)
                    }

                    ForEach(state.pairingCandidates, id: \.id) { profile in
                        HStack(spacing: 12) {
                            AvatarTile(grid: PixelGrid(storageString: profile.avatar) ?? .blank, pixel: 3.5)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                    .font(.headline)
                                Text(profile.initials)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(Palette.quiet)
                            }
                            Spacer()
                            Button("Add") {
                                withAnimation { state.addFriend(from: profile) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Mood.hang.color)
                            .foregroundStyle(.black)
                        }
                        .padding(10)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
                    }

                    let recent = state.friends.filter { $0.isNearby }
                    if !state.demoMode && !recent.isEmpty {
                        Text("Already friends nearby: \(recent.map(\.name).joined(separator: ", "))")
                            .font(.footnote)
                            .foregroundStyle(Palette.quiet)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Add a friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { state.setPairing(true) }
        .onDisappear { state.setPairing(false) }
    }
}
