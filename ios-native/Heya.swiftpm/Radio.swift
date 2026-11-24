import Foundation
import CoreBluetooth

/// A Heya phone heard over Bluetooth.
struct NearbyPeer: Identifiable, Equatable {
    /// The Bluetooth identifier iOS gives that phone (not their Heya ID).
    let id: UUID
    var profile: PublicProfile?
    /// Smoothed signal strength in dBm: about -90 far away, -40 touching.
    var rssi: Double
    var lastSeen: Date
    var lastReadAttempt: Date?
}

/// Every Heya phone advertises itself and scans for others.
/// When it hears one, it briefly connects and reads that phone's public profile.
///
/// Prototype note: profiles are readable by any Heya phone nearby. Before launch,
/// replace this with rotating, encrypted IDs that only friends can recognize.
final class HeyaRadio: NSObject {
    static let serviceUUID = CBUUID(string: "8C5B2E10-4E61-4A57-9B3F-2D6A1E0C4801")
    static let profileUUID = CBUUID(string: "8C5B2E11-4E61-4A57-9B3F-2D6A1E0C4801")

    /// Called on the main thread whenever the list of nearby phones changes.
    var onPeersChanged: (([NearbyPeer]) -> Void)?
    /// Called with a problem to show the user, or nil when Bluetooth is working.
    var onStatusChanged: ((String?) -> Void)?

    private var central: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var serviceRequested = false
    private var serviceReady = false
    private var isActive = true
    private var wantsAdvertising = false
    private var profileData = Data()

    private var peers: [UUID: NearbyPeer] = [:]
    private var known: [UUID: CBPeripheral] = [:]
    private var connecting: Set<UUID> = []
    private var pruneTimer: Timer?
    private var inBackground = false

    /// True only in the Xcode build (`ios-native/HeyaApp.xcodeproj`), whose Info.plist turns on
    /// Bluetooth background modes. The Swift Playgrounds build (.swiftpm) can't, so there
    /// Heya only finds friends while it's open, as before.
    static let canRunInBackground: Bool = {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        return modes.contains("bluetooth-central") && modes.contains("bluetooth-peripheral")
    }()

    /// How long a phone stays "nearby" after it was last heard. In the background iOS
    /// reports phones far less often, so a short window would make friends flicker away.
    private var forgetAfter: TimeInterval { inBackground ? 120 : 8 }
    /// How often to re-read a phone's profile (moods change). Slower in the background to save battery.
    private var rereadEvery: TimeInterval { inBackground ? 60 : 6 }

    override init() {
        super.init()
        // With background modes on, a restore ID lets iOS relaunch Heya for Bluetooth
        // events after it was closed to free memory.
        central = CBCentralManager(
            delegate: self, queue: nil,
            options: HeyaRadio.canRunInBackground ? [CBCentralManagerOptionRestoreIdentifierKey: "heya.central"] : nil
        )
        peripheralManager = CBPeripheralManager(
            delegate: self, queue: nil,
            options: HeyaRadio.canRunInBackground ? [CBPeripheralManagerOptionRestoreIdentifierKey: "heya.peripheral"] : nil
        )
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.prune()
        }
    }

    // MARK: Control

    /// What to share, and whether this phone should be visible right now.
    func update(profile: PublicProfile, visible: Bool) {
        profileData = (try? JSONEncoder().encode(profile)) ?? Data()
        wantsAdvertising = visible
        refreshAdvertising()
    }

    func pause() {
        isActive = false
        if central.state == .poweredOn { central.stopScan() }
        if peripheralManager.isAdvertising { peripheralManager.stopAdvertising() }
        peers = [:]
        publish()
    }

    func resume() {
        isActive = true
        startScanning()
        refreshAdvertising()
    }

    /// Tell the radio whether the app is on screen. Scanning and advertising keep going in
    /// the background (Xcode build only); only the timing changes.
    func setBackground(_ background: Bool) {
        inBackground = background
        if !background { startScanning() }  // back on screen: get frequent updates again
    }

    // MARK: Internals

    private func refreshAdvertising() {
        guard peripheralManager.state == .poweredOn else { return }
        guard serviceReady else {
            addServiceIfNeeded()
            return
        }
        if isActive && wantsAdvertising {
            if !peripheralManager.isAdvertising {
                peripheralManager.startAdvertising([
                    CBAdvertisementDataServiceUUIDsKey: [HeyaRadio.serviceUUID],
                    CBAdvertisementDataLocalNameKey: "Heya"
                ])
            }
        } else if peripheralManager.isAdvertising {
            peripheralManager.stopAdvertising()
        }
    }

    private func addServiceIfNeeded() {
        guard !serviceRequested else { return }
        serviceRequested = true
        let characteristic = CBMutableCharacteristic(
            type: HeyaRadio.profileUUID,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )
        let service = CBMutableService(type: HeyaRadio.serviceUUID, primary: true)
        service.characteristics = [characteristic]
        peripheralManager.add(service)
    }

    private func startScanning() {
        guard isActive, central.state == .poweredOn else { return }
        central.scanForPeripherals(
            withServices: [HeyaRadio.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    /// Forget phones not heard from recently (8 seconds on screen, 2 minutes in the background).
    private func prune() {
        let cutoff = Date().addingTimeInterval(-forgetAfter)
        let before = peers.count
        peers = peers.filter { $0.value.lastSeen >= cutoff }
        if peers.count != before { publish() }
    }

    private func publish() {
        onPeersChanged?(Array(peers.values))
    }

    /// Read a phone's profile when first heard, then refresh every 6 seconds (60 in the background).
    private func readProfileIfNeeded(_ peripheral: CBPeripheral) {
        let id = peripheral.identifier
        guard var peer = peers[id], !connecting.contains(id) else { return }
        if let last = peer.lastReadAttempt, Date().timeIntervalSince(last) < rereadEvery { return }

        peer.lastReadAttempt = Date()
        peers[id] = peer
        connecting.insert(id)
        known[id] = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)

        // Give up if the read takes too long.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.connecting.contains(id) else { return }
            self.central.cancelPeripheralConnection(peripheral)
            self.connecting.remove(id)
        }
    }

    private func finish(_ peripheral: CBPeripheral) {
        central.cancelPeripheralConnection(peripheral)
        connecting.remove(peripheral.identifier)
    }
}

// MARK: - Scanning for other phones

extension HeyaRadio: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            onStatusChanged?(nil)
            startScanning()
        case .unsupported:
            onStatusChanged?("This device has no Bluetooth (the Simulator doesn't). Turn on Demo mode in the You tab.")
        case .unauthorized:
            onStatusChanged?("Heya needs Bluetooth. Allow it in Settings > Heya.")
        case .poweredOff:
            onStatusChanged?("Turn on Bluetooth to find friends nearby.")
        default:
            break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let value = RSSI.doubleValue
        guard value < 0, value > -100 else { return } // 127 means "unknown"

        let id = peripheral.identifier
        known[id] = peripheral
        var peer = peers[id] ?? NearbyPeer(id: id, profile: nil, rssi: value, lastSeen: Date(), lastReadAttempt: nil)
        peer.rssi = peer.rssi * 0.75 + value * 0.25
        peer.lastSeen = Date()
        peers[id] = peer
        publish()
        readProfileIfNeeded(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([HeyaRadio.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connecting.remove(peripheral.identifier)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connecting.remove(peripheral.identifier)
    }

    /// iOS relaunched Heya in the background for a Bluetooth event (Xcode build only).
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        for peripheral in restored {
            peripheral.delegate = self
            known[peripheral.identifier] = peripheral
            central.cancelPeripheralConnection(peripheral)  // a half-finished profile read; start fresh
        }
        inBackground = true
    }
}

// MARK: - Reading another phone's profile

extension HeyaRadio: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == HeyaRadio.serviceUUID }) else {
            finish(peripheral)
            return
        }
        peripheral.discoverCharacteristics([HeyaRadio.profileUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == HeyaRadio.profileUUID }) else {
            finish(peripheral)
            return
        }
        peripheral.readValue(for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value,
           let profile = try? JSONDecoder().decode(PublicProfile.self, from: data),
           var peer = peers[peripheral.identifier] {
            peer.profile = profile
            peers[peripheral.identifier] = peer
            publish()
        }
        finish(peripheral)
    }
}

// MARK: - Being visible to other phones

extension HeyaRadio: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            refreshAdvertising()
        }
    }

    /// iOS relaunched Heya and still has our service published; don't add it twice.
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] ?? []
        if services.contains(where: { $0.uuid == HeyaRadio.serviceUUID }) {
            serviceRequested = true
            serviceReady = true
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        serviceReady = (error == nil)
        if error != nil { serviceRequested = false }
        refreshAdvertising()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard request.characteristic.uuid == HeyaRadio.profileUUID else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }
        let data = profileData
        guard request.offset <= data.count else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = data.subdata(in: request.offset..<data.count)
        peripheral.respond(to: request, withResult: .success)
    }
}
