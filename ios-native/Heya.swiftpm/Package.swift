// swift-tools-version: 5.9

// Heya — phone-only version.
// Open this .swiftpm folder in Xcode (File > Open) and press Run.
// Real friend-finding needs two physical iPhones; the Simulator has no Bluetooth,
// so use Demo mode there.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Heya",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "Heya",
            targets: ["AppModule"],
            bundleIdentifier: "com.heya.demo",
            teamIdentifier: "",
            displayVersion: "0.3",
            bundleVersion: "3",
            appIcon: .placeholder(icon: .heart),
            accentColor: .presetColor(.green),
            supportedDeviceFamilies: [
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait
            ],
            capabilities: [
                .bluetoothAlways(purposeString: "Heya uses Bluetooth to notice friends' phones nearby. It never shares your location."),
                .locationWhenInUse(purposeString: "When you and a friend bump phones, Heya saves the place to your private map. It stays only on this phone.")
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ],
    swiftLanguageVersions: [.v5]
)
