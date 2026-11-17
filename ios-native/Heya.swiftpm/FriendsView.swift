import SwiftUI

/// AFTER: streaks and hangouts. Only in-person taps count.
struct FriendsView: View {
    @Environment(AppState.self) private var state
    @State private var selectedFriend: Friend?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    PhaseHeader(phase: "After", text: "Only counted when you meet up in person. Nothing here can be earned online.")

                    if state.friendsRanked.isEmpty {
                        Text("No friends yet. Add friends in person from the Look tab: hold your phones together.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.quiet)
                    }

                    SectionLabel(text: "Streaks and hangouts")
                        .padding(.top, 6)
                    ForEach(state.friendsRanked) { friend in
                        Button {
                            selectedFriend = friend
                        } label: {
                            StreakRow(
                                friend: friend,
                                streak: state.streakWeeks(for: friend.id),
                                thisMonth: state.hangoutsThisMonth(with: friend.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if !state.metThroughFriends.isEmpty {
                        SectionLabel(text: "Met through friends")
                            .padding(.top, 10)
                        ForEach(state.metThroughFriends) { friend in
                            MetThroughRow(friend: friend) {
                                withAnimation(.spring) { state.addFriend(friend.id) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("Friends")
            .sheet(item: $selectedFriend) { friend in
                FriendDetailView(friendID: friend.id)
            }
        }
    }
}

struct StreakRow: View {
    let friend: Friend
    let streak: Int
    let thisMonth: Int

    var body: some View {
        HStack(spacing: 12) {
            AvatarTile(grid: friend.avatar, pixel: 3.5)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(friend.name)
                        .font(.headline)
                    if friend.isInnerCircle {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(Mood.quiet.color)
                            .accessibilityLabel("Inner circle")
                    }
                }
                HStack(spacing: 5) {
                    Image(systemName: streak > 0 ? "flame.fill" : "flame")
                        .foregroundStyle(streak > 0 ? Color.orange : Palette.quiet)
                    Text(streak > 0 ? "\(streak)-week streak" : "No streak yet")
                        .font(.subheadline)
                        .foregroundStyle(Palette.quiet)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text("×\(thisMonth)")
                    .font(.system(.title3, design: .monospaced).bold())
                Text("this month")
                    .font(.caption2)
                    .foregroundStyle(Palette.quiet)
            }
        }
        .padding(10)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.cardBorder, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct MetThroughRow: View {
    let friend: Friend
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarTile(grid: friend.avatar, pixel: 3.5)
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.headline)
                Text("\(friend.introducedBy ?? "A friend")'s friend · you tapped rings")
                    .font(.subheadline)
                    .foregroundStyle(Palette.quiet)
            }
            Spacer(minLength: 0)
            Button("Add", action: onAdd)
                .buttonStyle(.borderedProminent)
                .tint(Mood.hang.color)
                .foregroundStyle(.black)
        }
        .padding(10)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.5), lineWidth: 1))
    }
}

/// One friend: streak, totals, and where you've met.
struct FriendDetailView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let friendID: UUID

    var body: some View {
        NavigationStack {
            if let friend = state.friend(with: friendID) {
                List {
                    Section {
                        VStack(spacing: 12) {
                            AvatarTile(grid: friend.avatar, pixel: 10)
                            Text(friend.initials)
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                            HStack(spacing: 24) {
                                stat("\(state.streakWeeks(for: friend.id))", "week streak")
                                stat("\(state.hangoutsThisMonth(with: friend.id))", "this month")
                                stat("\(state.totalHangouts(with: friend.id))", "all time")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }

                    Section("Where you've met") {
                        let met = state.placesMet(with: friend.id)
                        if met.isEmpty {
                            Text("No meetups yet. Find each other and bump phones.")
                                .foregroundStyle(Palette.quiet)
                        }
                        ForEach(met) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text("×\(item.count)")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(Palette.quiet)
                            }
                        }
                    }

                    if friend.isFriend {
                        Section {
                            Toggle("Inner circle", isOn: Binding(
                                get: { state.friend(with: friendID)?.isInnerCircle ?? false },
                                set: { state.setInnerCircle(friendID, $0) }
                            ))
                        } footer: {
                            Text("Only your inner circle sees \"Quiet company\".")
                        }
                    }
                }
                .navigationTitle(friend.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            } else {
                Text("Friend not found")
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .monospaced).bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(Palette.quiet)
        }
    }
}
