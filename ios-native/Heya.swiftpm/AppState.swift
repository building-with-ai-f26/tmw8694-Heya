import SwiftUI
import Observation
import CoreLocation
import UserNotifications

/// The shared moment after a tap.
struct Celebration: Equatable {
    var friendName: String
    var colorA: Color
    var colorB: Color
    var isFirst: Bool
    var placeName: String
}

/// All app data. In Demo mode, friends and places are samples.
/// With Demo mode off, everything is real: Bluetooth, bumps, and places saved on this phone.
@MainActor
@Observable
final class AppState {

    // MARK: Before — who you are, who can find you

    let myID: UUID
    var myName: String
    var myInitials: String
    var myAvatar: PixelGrid
    var showNameOnFriendsMaps = true
    var discoverableToFriendsOfFriends = true

    /// Sample friends and a slider instead of real Bluetooth.
    private(set) var demoMode: Bool

    // MARK: During

    var mood: Mood = .hang
    var moodSetAt: Date = .now
    var beacon = false
    /// Demo helper: fade after 30 seconds instead of 2 hours.
    var fastFade = false

    /// The friend you're looking for (opens the lantern).
    var seekingID: UUID? = nil
    /// 1 = far away, 0 = touching. Demo: from the slider. Real: from Bluetooth signal strength.
    var distance: Double = 1
    var celebration: Celebration? = nil
    /// Demo: where you are right now.
    var demoPlaceIndex = 0

    /// A Bluetooth problem to show, or nil.
    var radioMessage: String? = nil
    /// Heya phones heard over Bluetooth right now.
    var peers: [NearbyPeer] = []
    /// True while the Add a friend screen is open.
    var pairingMode = false

    // MARK: Data

    private var realFriends: [Friend]
    private var realMoments: [Moment]
    private var demoFriends: [Friend]
    private var demoMoments: [Moment]

    @ObservationIgnored private var radio: HeyaRadio?
    @ObservationIgnored private let bumps = BumpDetector()
    @ObservationIgnored private let locator = Locator()

    /// True while Heya is off screen (locked phone, another app, in a pocket).
    @ObservationIgnored private var inBackground = false
    /// When each friend last triggered a "nearby" alert, so a friend at the edge of range
    /// doesn't buzz you over and over.
    @ObservationIgnored private var lastAlerted: [UUID: Date] = [:]
    static let alertCooldown: TimeInterval = 20 * 60

    init() {
        let stored = UserDefaults.standard
        if let text = stored.string(forKey: "myID"), let saved = UUID(uuidString: text) {
            myID = saved
        } else {
            let fresh = UUID()
            stored.set(fresh.uuidString, forKey: "myID")
            myID = fresh
        }
        myName = stored.string(forKey: "name") ?? "You"
        myInitials = stored.string(forKey: "initials") ?? "ME"
        if let saved = stored.string(forKey: "avatar"), let grid = PixelGrid(storageString: saved) {
            myAvatar = grid
        } else {
            myAvatar = .me
        }
        demoMode = (stored.object(forKey: "demoMode") as? Bool) ?? true

        let saved = Storage.load()
        realFriends = saved.friends.map { friend in
            var copy = friend
            copy.isNearby = false
            return copy
        }
        realMoments = saved.moments

        let samples = Friend.makeDemo()
        demoFriends = samples
        demoMoments = Moment.makeDemo(friends: samples)

        if !demoMode { startRadio() }
    }

    // MARK: - Active data (demo or real)

    var friends: [Friend] {
        get { demoMode ? demoFriends : realFriends }
        set {
            if demoMode { demoFriends = newValue } else { realFriends = newValue }
        }
    }

    var moments: [Moment] {
        get { demoMode ? demoMoments : realMoments }
        set {
            if demoMode { demoMoments = newValue } else { realMoments = newValue }
        }
    }

    private func persist() {
        guard !demoMode else { return }
        Storage.save(SavedData(friends: realFriends, moments: realMoments))
    }

    func friend(with id: UUID) -> Friend? {
        friends.first { $0.id == id }
    }

    func setDemoMode(_ on: Bool) {
        guard on != demoMode else { return }
        startSeeking(nil)
        demoMode = on
        UserDefaults.standard.set(on, forKey: "demoMode")
        if on { stopRadio() } else { startRadio() }
    }

    // MARK: - Bluetooth

    private func startRadio() {
        if radio == nil {
            let newRadio = HeyaRadio()
            newRadio.onPeersChanged = { [weak self] list in
                Task { @MainActor in self?.peersUpdated(list) }
            }
            newRadio.onStatusChanged = { [weak self] message in
                Task { @MainActor in self?.radioMessage = message }
            }
            radio = newRadio
        }
        radio?.resume()
        pushProfile()
        bumps.onBump = { [weak self] in
            Task { @MainActor in self?.bumped() }
        }
        bumps.start()
        // Alerts only make sense when Heya can listen in the background (Xcode build).
        if HeyaRadio.canRunInBackground {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    // MARK: - Off screen

    /// Called when Heya leaves or returns to the screen.
    func setInBackground(_ background: Bool) {
        inBackground = background
        radio?.setBackground(background)
    }

    /// The phone's stand-in for the bracelet's glow: a lock-screen alert when a friend
    /// shows up nearby with a lit mood. Only while Heya is off screen, only if you're
    /// lit yourself (Off means you're not looking), and at most once per friend every 20 minutes.
    private func alertFriendNearby(_ friend: Friend) {
        guard inBackground, !demoMode, mood.isLit, friend.isFriend, friend.mood.isLit else { return }
        if let last = lastAlerted[friend.id], Date().timeIntervalSince(last) < AppState.alertCooldown { return }
        lastAlerted[friend.id] = Date()

        let content = UNMutableNotificationContent()
        content.title = "\(friend.name) is nearby"
        content.body = friend.mood.title
        content.sound = .default
        let request = UNNotificationRequest(identifier: "nearby-\(friend.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func stopRadio() {
        radio?.pause()
        bumps.stop()
        peers = []
        radioMessage = nil
        for index in realFriends.indices {
            realFriends[index].isNearby = false
        }
    }

    /// Share your current profile. While Off, you're invisible (unless adding a friend).
    private func pushProfile() {
        guard let radio else { return }
        let profile = PublicProfile(
            id: myID,
            name: myName,
            initials: myInitials,
            avatar: myAvatar.storageString,
            mood: mood,
            pairing: pairingMode,
            quietFor: realFriends.filter { $0.isInnerCircle }.map(\.id)
        )
        radio.update(profile: profile, visible: mood.isLit || pairingMode)
    }

    private func peersUpdated(_ list: [NearbyPeer]) {
        peers = list
        var byFriendID: [UUID: NearbyPeer] = [:]
        for peer in list {
            if let profile = peer.profile { byFriendID[profile.id] = peer }
        }

        for index in realFriends.indices {
            let id = realFriends[index].id
            let wasVisible = realFriends[index].isNearby && realFriends[index].mood.isLit
            defer {
                if !wasVisible, realFriends[index].isNearby, realFriends[index].mood.isLit {
                    alertFriendNearby(realFriends[index])
                }
            }
            if let peer = byFriendID[id], let profile = peer.profile {
                realFriends[index].isNearby = true
                // "Quiet company" shows only to the inner circle; everyone else sees nothing.
                let mayShowQuiet = profile.quietFor.contains(myID)
                realFriends[index].mood = (profile.mood == .quiet && !mayShowQuiet) ? .off : profile.mood
                realFriends[index].name = profile.name
                realFriends[index].initials = profile.initials
                if let grid = PixelGrid(storageString: profile.avatar) {
                    realFriends[index].avatar = grid
                }
            } else {
                realFriends[index].isNearby = false
            }
        }

        if !demoMode, let id = seekingID, let peer = byFriendID[id] {
            // About -90 dBm far away, -40 dBm touching.
            let closeness = min(1, max(0, (peer.rssi + 90) / 50))
            distance = 1 - closeness
        }
    }

    // MARK: - Adding friends in person

    func setPairing(_ on: Bool) {
        pairingMode = on
        pushProfile()
    }

    /// Phones right next to you that also have Add a friend open.
    var pairingCandidates: [PublicProfile] {
        peers.compactMap { peer -> PublicProfile? in
            guard let profile = peer.profile,
                  profile.pairing,
                  peer.rssi > -60,
                  !realFriends.contains(where: { $0.id == profile.id }) else { return nil }
            return profile
        }
    }

    func addFriend(from profile: PublicProfile) {
        guard !realFriends.contains(where: { $0.id == profile.id }) else { return }
        let friend = Friend(
            id: profile.id,
            name: profile.name,
            initials: profile.initials,
            avatar: PixelGrid(storageString: profile.avatar) ?? .blank,
            mood: profile.mood,
            colorIndex: realFriends.count,
            isNearby: true
        )
        realFriends.append(friend)
        persist()
        pushProfile()
    }

    func removeFriend(_ id: UUID) {
        if demoMode {
            demoFriends.removeAll { $0.id == id }
        } else {
            realFriends.removeAll { $0.id == id }
            persist()
            pushProfile()
        }
    }

    // MARK: - Mood and the 2-hour fade

    var fadeDuration: TimeInterval { fastFade ? 30 : 2 * 60 * 60 }

    func setMood(_ newMood: Mood) {
        mood = newMood
        moodSetAt = .now
        if newMood == .off {
            beacon = false
            startSeeking(nil)
        }
        pushProfile()
    }

    func remaining(at now: Date) -> TimeInterval? {
        guard mood.isLit else { return nil }
        return max(0, fadeDuration - now.timeIntervalSince(moodSetAt))
    }

    func tick(now: Date) {
        if mood.isLit, now.timeIntervalSince(moodSetAt) >= fadeDuration {
            setMood(.off)
        }
    }

    // MARK: - Seeking: warmer, colder, sync, tap

    /// People you can look for right now.
    var seekCandidates: [Friend] {
        friends.filter { $0.isNearby && $0.mood.isLit }
    }

    var seekingFriend: Friend? {
        guard let id = seekingID else { return nil }
        return friend(with: id)
    }

    func startSeeking(_ id: UUID?) {
        seekingID = id
        distance = 1
    }

    var inSync: Bool {
        mood.isLit && seekingFriend != nil && distance <= 0.15
    }

    var canTap: Bool {
        mood.isLit && seekingFriend != nil && celebration == nil && distance <= (demoMode ? 0.05 : 0.2)
    }

    var friendOfFriendNearby: Bool {
        friends.contains { !$0.isFriend && $0.isNearby && $0.mood.isLit }
    }

    /// Demo: a friend of a friend walks by (or away).
    func toggleFriendOfFriend() {
        guard demoMode, let index = demoFriends.firstIndex(where: { !$0.isFriend }) else { return }
        demoFriends[index].isNearby.toggle()
        if !demoFriends[index].isNearby, seekingID == demoFriends[index].id {
            startSeeking(nil)
        }
    }

    /// What your ring (or lantern) shows right now.
    var ringDisplay: RingDisplay {
        if let c = celebration {
            return RingDisplay(base: c.colorA, baseLit: true, basePulse: false, celebrateA: c.colorA, celebrateB: c.colorB)
        }
        guard mood.isLit else {
            return RingDisplay(base: Mood.off.color, baseLit: false, basePulse: false)
        }
        var display = RingDisplay(base: mood.color, baseLit: true, basePulse: mood == .quiet || beacon)
        if let target = seekingFriend {
            let closeness = 1 - distance
            display.accent = target.isFriend ? target.mood.color : .white
            display.accentCount = max(1, min(12, Int((closeness * 12).rounded(.up))))
            display.accentPulseSpeed = inSync ? 5 : 2 + closeness * 10
            display.glint = !target.isFriend
        } else if friendOfFriendNearby {
            display.glint = true
        }
        return display
    }

    /// Real mode: bumping phones while very close counts as a tap.
    private func bumped() {
        guard !demoMode, seekingFriend != nil, distance <= 0.2 else { return }
        tapRings()
    }

    /// Save the moment and play the shared colors.
    func tapRings() {
        guard mood.isLit, celebration == nil, let target = seekingFriend else { return }
        let isFirst = !moments.contains { $0.friendID == target.id }

        var moment = Moment(friendID: target.id, date: .now)
        if demoMode {
            let place = DemoPlace.all[demoPlaceIndex]
            moment.latitude = place.latitude
            moment.longitude = place.longitude
            moment.placeName = place.name
        }
        moments.append(moment)
        if let index = friends.firstIndex(where: { $0.id == target.id }) {
            friends[index].metInPerson = true
        }
        persist()

        celebration = Celebration(
            friendName: target.name,
            colorA: mood.color,
            colorB: target.isFriend ? target.mood.color : .white,
            isFirst: isFirst,
            placeName: moment.placeName ?? "this spot"
        )

        if !demoMode {
            let momentID = moment.id
            locator.currentLocation { [weak self] location in
                guard let location else { return }
                Locator.placeName(for: location) { name in
                    Task { @MainActor in
                        self?.setPlace(for: momentID, location: location, name: name)
                    }
                }
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.spring) {
                self.celebration = nil
                self.startSeeking(nil)
            }
        }
    }

    private func setPlace(for momentID: UUID, location: CLLocation, name: String?) {
        guard let index = realMoments.firstIndex(where: { $0.id == momentID }) else { return }
        realMoments[index].latitude = location.coordinate.latitude
        realMoments[index].longitude = location.coordinate.longitude
        realMoments[index].placeName = name ?? "A spot"
        persist()
    }

    // MARK: - Friends (after)

    func setInnerCircle(_ id: UUID, _ value: Bool) {
        guard let index = friends.firstIndex(where: { $0.id == id }) else { return }
        friends[index].isInnerCircle = value
        persist()
        pushProfile()
    }

    /// Demo: add a friend of a friend you've met.
    func addFriend(_ id: UUID) {
        guard let index = friends.firstIndex(where: { $0.id == id }) else { return }
        friends[index].isFriend = true
        persist()
    }

    var metThroughFriends: [Friend] {
        friends.filter { !$0.isFriend && $0.metInPerson }
    }

    var friendsRanked: [Friend] {
        friends
            .filter { $0.isFriend }
            .sorted {
                let a = hangoutsThisMonth(with: $0.id), b = hangoutsThisMonth(with: $1.id)
                if a != b { return a > b }
                return streakWeeks(for: $0.id) > streakWeeks(for: $1.id)
            }
    }

    func hangoutsThisMonth(with id: UUID) -> Int {
        let start = Date.now.addingTimeInterval(-30 * 86_400)
        return moments.filter { $0.friendID == id && $0.date >= start }.count
    }

    func totalHangouts(with id: UUID) -> Int {
        moments.filter { $0.friendID == id }.count
    }

    /// Consecutive weeks (ending this week or last week) with at least one tap.
    func streakWeeks(for id: UUID) -> Int {
        let calendar = Calendar.current
        func weekStart(_ date: Date) -> Date {
            calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        }
        let weeks = Set(moments.filter { $0.friendID == id }.map { weekStart($0.date) })
        guard !weeks.isEmpty else { return 0 }

        var cursor = weekStart(.now)
        if !weeks.contains(cursor) {
            cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) ?? cursor
        }
        var count = 0
        while weeks.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    /// Places you've met this friend, most visited first.
    func placesMet(with id: UUID) -> [PlaceVisit] {
        var counts: [String: Int] = [:]
        for m in moments where m.friendID == id {
            counts[m.placeName ?? "Place not saved", default: 0] += 1
        }
        return counts
            .map { PlaceVisit(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Places map (after)

    var placeGroups: [PlaceGroup] {
        var groups: [String: PlaceGroup] = [:]
        for m in moments {
            guard let key = PlaceGroup.key(for: m), let lat = m.latitude, let lon = m.longitude else { continue }
            if groups[key] == nil {
                groups[key] = PlaceGroup(id: key, name: m.placeName ?? "A spot", latitude: lat, longitude: lon)
            }
        }
        return groups.values.sorted { $0.name < $1.name }
    }

    func moments(inGroup key: String) -> [Moment] {
        moments
            .filter { PlaceGroup.key(for: $0) == key }
            .sorted { $0.date > $1.date }
    }

    /// The friend you've met most often at this place.
    func topFriend(inGroup key: String) -> Friend? {
        var counts: [UUID: Int] = [:]
        for m in moments where PlaceGroup.key(for: m) == key {
            counts[m.friendID, default: 0] += 1
        }
        guard let best = counts.max(by: { $0.value < $1.value }) else { return nil }
        return friend(with: best.key)
    }

    /// The first time you tapped with that friend.
    func isFirst(_ moment: Moment) -> Bool {
        moments
            .filter { $0.friendID == moment.friendID }
            .min { $0.date < $1.date }?.id == moment.id
    }

    func hasFirst(inGroup key: String) -> Bool {
        moments.contains { PlaceGroup.key(for: $0) == key && isFirst($0) }
    }

    func deleteMoments(inGroup key: String) {
        moments.removeAll { PlaceGroup.key(for: $0) == key }
        persist()
    }

    var monthSummary: (friends: Int, places: Int) {
        let start = Date.now.addingTimeInterval(-30 * 86_400)
        let recent = moments.filter { $0.date >= start }
        let placeKeys = Set(recent.compactMap { PlaceGroup.key(for: $0) })
        return (Set(recent.map(\.friendID)).count, placeKeys.count)
    }

    // MARK: - Saving your profile

    func saveProfile() {
        let stored = UserDefaults.standard
        stored.set(myName, forKey: "name")
        stored.set(myInitials, forKey: "initials")
        stored.set(myAvatar.storageString, forKey: "avatar")
        pushProfile()
    }
}
