import SwiftUI

@main
struct HeyaApp: App {
    @State private var state = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
                .preferredColorScheme(.dark)
                .tint(Mood.hang.color)
        }
        .onChange(of: scenePhase) { _, phase in
            state.setInBackground(phase == .background)
        }
    }
}

/// Before → During → After, as tabs.
struct ContentView: View {
    enum Tab: Hashable {
        case you, look, places, friends
    }

    @State private var tab: Tab = .look

    var body: some View {
        TabView(selection: $tab) {
            YouView()
                .tabItem { Label("You", systemImage: "person.crop.square") }
                .tag(Tab.you)
            LookView()
                .tabItem { Label("Look", systemImage: "dot.radiowaves.left.and.right") }
                .tag(Tab.look)
            PlacesView()
                .tabItem { Label("Places", systemImage: "map") }
                .tag(Tab.places)
            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.2.fill") }
                .tag(Tab.friends)
        }
    }
}
