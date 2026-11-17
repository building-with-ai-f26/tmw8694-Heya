# Heya — clickable demo (v0.2)

Signal → Seek → Meet → Remember. Friends, places and taps are simulated on the phone; nothing leaves it.

## Run it

Open `Heya.swiftpm` in Xcode (File > Open), choose an iPhone simulator, press Run (▶). Needs Xcode 15+; iOS 17+.

## The demo, before → during → after

- **You (Before):** draw your 12 x 12 pixel avatar, pick your inner circle (the only friends who see "Quiet company"), privacy switches.
- **Ring (During):** the ring shows your mood. In **Demo controls**, choose who to *walk toward* and drag the slider from Far to Touching:
  - the friend's color fills in around the ring as you get warmer, pulsing faster;
  - within a few steps both rings pulse in sync;
  - touching: **Tap rings** plays your shared colors and saves the moment.
  - "A friend of a friend walks by" makes a white glint run around the ring. Walk toward them and tap to meet.
- **Places (After):** a private map of every place you've tapped rings. Pins grow with visits, a star marks a first. Tap a pin to see moments or delete the place.
- **Friends (After):** streaks and hangouts (only in-person taps count), plus people you met through friends, with an Add button.
