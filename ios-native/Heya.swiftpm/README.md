# Heya — clickable demo (v0.2)

Signal → Seek → Meet → Remember. Friends, places and taps are simulated on the phone; nothing leaves it.

## Run it

Two ways to build the same Swift files:

- **`../HeyaApp.xcodeproj` (use this on real phones).** Double-click it, pick your Apple ID under the Heya target → Signing & Capabilities, choose your iPhone and press Run. This build has Bluetooth **background modes** on, so Heya keeps noticing friends while the phone is locked and shows "*Name* is nearby" on the lock screen. The background settings are in `../HeyaApp/Info.plist`.
- **`Heya.swiftpm` (Swift Playgrounds / quick demos).** Open it in Xcode (File > Open) or Swift Playgrounds, choose an iPhone simulator, press Run (▶). Swift Playgrounds apps can't turn on background modes, so here Heya only works while it's open.

Needs Xcode 15+ and iOS 17+. New Swift files added to this folder are picked up by both builds automatically.

## The demo, before → during → after

- **You (Before):** draw your 12 x 12 pixel avatar, pick your inner circle (the only friends who see "Quiet company"), privacy switches.
- **Ring (During):** the ring shows your mood. In **Demo controls**, choose who to *walk toward* and drag the slider from Far to Touching:
  - the friend's color fills in around the ring as you get warmer, pulsing faster;
  - within a few steps both rings pulse in sync;
  - touching: **Tap rings** plays your shared colors and saves the moment.
  - "A friend of a friend walks by" makes a white glint run around the ring. Walk toward them and tap to meet.
- **Places (After):** a private map of every place you've tapped rings. Pins grow with visits, a star marks a first. Tap a pin to see moments or delete the place.
- **Friends (After):** streaks and hangouts (only in-person taps count), plus people you met through friends, with an Add button.
