import SwiftUI
import MapKit

/// AFTER: a private map of every place you've tapped with a friend. Only on this phone.
struct PlacesView: View {
    @Environment(AppState.self) private var state
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedPlace: PlaceGroup?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    PhaseHeader(phase: "After", text: "Every place you've met up in person. Visible only to you.")
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Mood.hang.color)
                        Text(summaryText)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                ZStack {
                    Map(position: $position) {
                        ForEach(state.placeGroups) { place in
                            Annotation(place.name, coordinate: place.coordinate) {
                                PlacePin(
                                    count: state.moments(inGroup: place.id).count,
                                    color: state.topFriend(inGroup: place.id)?.signature ?? Mood.hang.color,
                                    hasFirst: state.hasFirst(inGroup: place.id)
                                )
                                .onTapGesture { selectedPlace = place }
                            }
                        }
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))

                    if state.placeGroups.isEmpty {
                        Text("No places yet. Meet a friend and bump phones to save your first.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .padding(24)
                    }
                }

                Text("Saved only on this phone. Heya never tracks you; it saves a place only when you meet up.")
                    .font(.caption)
                    .foregroundStyle(Palette.quiet)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .navigationTitle("Places")
            .sheet(item: $selectedPlace) { place in
                PlaceDetailView(groupID: place.id, title: place.name)
            }
        }
    }

    private var summaryText: String {
        let s = state.monthSummary
        let friendWord = s.friends == 1 ? "friend" : "friends"
        let placeWord = s.places == 1 ? "place" : "places"
        return "This month: \(s.friends) \(friendWord) in \(s.places) \(placeWord)"
    }
}

/// Pins grow with every visit; a star marks a first meetup.
struct PlacePin: View {
    let count: Int
    let color: Color
    let hasFirst: Bool

    var body: some View {
        let size = 24 + CGFloat(min(count, 8)) * 5
        ZStack {
            Circle()
                .fill(color.opacity(0.35))
                .frame(width: size * 1.7, height: size * 1.7)
                .blur(radius: 6)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
            Text("\(count)")
                .font(.caption.bold())
                .foregroundStyle(.black)
            if hasFirst {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)
                    .offset(x: size / 2, y: -size / 2)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(count) meetups here")
    }
}

/// The moments at one place, with a way to delete them.
struct PlaceDetailView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let groupID: String
    let title: String

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(state.moments(inGroup: groupID)) { moment in
                        if let friend = state.friend(with: moment.friendID) {
                            HStack(spacing: 12) {
                                AvatarTile(grid: friend.avatar, pixel: 2.5)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.name)
                                        .font(.headline)
                                    Text(moment.date, format: .dateTime.month().day().hour().minute())
                                        .font(.caption)
                                        .foregroundStyle(Palette.quiet)
                                }
                                Spacer()
                                if state.isFirst(moment) {
                                    Label("First", systemImage: "star.fill")
                                        .font(.caption.bold())
                                        .foregroundStyle(.yellow)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Moments here")
                } footer: {
                    Text("Only you can see this. Heya saved this place because you met up here.")
                }

                Section {
                    Button("Delete this place", role: .destructive) {
                        state.deleteMoments(inGroup: groupID)
                        dismiss()
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
