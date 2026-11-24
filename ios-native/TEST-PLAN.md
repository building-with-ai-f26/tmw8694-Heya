# Two-phone test plan (Tara + Jorge)

**App:** the native SwiftUI app with real Bluetooth, in `ios-native/`. This is *not* the `ios/` Wrapped app. Use **`ios-native/HeyaApp.xcodeproj`** (it can run in the background) for test 10; the Playgrounds package `Heya.swiftpm` only works while the app is open.
**Who:** Tara and Jorge only, one iPhone each. Not for outside testers yet. Any Heya phone nearby can read your name, avatar and mood, and the app only works while it's open on screen.
**Time:** about 45 minutes, together in person.
**Goal:** answer one question. **Can two phones reliably notice each other and get "warmer" as you walk closer?**

## Setup (each person)

1. Pull the repo, then open `ios-native/HeyaApp.xcodeproj` in Xcode (double-click it). The old `Heya.swiftpm` still works for tests 1–9, but it can't run in the background.
2. Plug in your iPhone. Turn on Settings → Privacy & Security → **Developer Mode** (it restarts the phone).
3. In Xcode, click the **Heya** target → Signing & Capabilities, and pick your own Apple ID as the **Team**. If Xcode says the bundle ID (`com.heya.app`) isn't available, change it on your own machine (for example to `com.heya.app.jorge`). Don't commit that change.
4. Choose your iPhone at the top and press Run. Allow **Bluetooth** and **Location** when asked.
5. In the app's **You** tab: turn **Demo mode off**, draw an avatar, and set your name.
6. Keep both phones' screens on and Heya open for every test (Settings → Display & Brightness → Auto-Lock → Never, for the session).

## Tests

Write results in the table below as you go. "Works" means it works 4 out of 5 tries.

| # | Test | How | What to write down |
|---|---|---|---|
| 1 | **Add a friend** | Both open Look → Add a friend in person, and hold the phones side by side. | Did the other person show up? How many seconds? Did you have to touch phones? |
| 2 | **See each other's mood** | Each picks green (Let's hang). Then change to yellow, then Off. | Does the friend appear lit? How long until a mood change shows (about 6 s expected)? Does Off make you disappear? |
| 3 | **Quiet company** | One person picks purple. Test with Inner circle off, then on (Friends → tap friend → Inner circle). | Hidden when off, shown when on? |
| 4 | **Warmer, warmer** | Tap your friend → Find. Start about 15 m apart (other end of a room or hallway) and walk toward each other slowly. Repeat with a phone in a pocket. | At what distance does the friend first appear? Does the ring fill steadily, or jump around? Distance when the rings pulse in sync? |
| 5 | **Walls and crowds** | Repeat test 4 with a wall or door between you, and once somewhere busy (a café or hallway). | Detection distance compared with test 4. |
| 6 | **Bump to tap** | When close, bump phones together. Then try a few false alarms: set a phone down hard, or walk briskly while holding it. | Does a real bump save the moment? Did any false alarm save one? |
| 7 | **Place saved** | After a successful tap, check the **Places** and **Friends** tabs. | Is the place name right? Is the hangout counted? |
| 8 | **Leave the app** | During test 4, lock one phone for 10 seconds, then switch to another app. | Does the other phone lose you? How fast does it recover when you come back? |
| 9 | **Battery** | Note battery % at the start and end of the session. | % used per 30 minutes with Heya open. |
| 10 | **Friend nearby, phone locked** (Xcode build only) | Both pick green. Allow notifications. Walk apart until you lose each other (or into separate rooms), lock **one** phone and put it in a pocket, then walk back together. Repeat with **both** phones locked. | Does the locked phone show "*Name* is nearby · Let's hang"? How close were you? How long did it take? With both locked, does it show at all? Battery % after an hour locked with Heya running. |

## Results

### Session 1 (by Nov 22, 2026)

Phones: **iPhone 17** and **iPhone 12 mini**. 7 of the 9 tests run. Not yet run: **tests 4 and 5** (distance: "warmer, warmer", walls and crowds). Write the numbers in the table as you have them.

| # | Works? | Notes |
|---|---|---|
| 1 | | |
| 2 | | |
| 3 | | |
| 4 | Not run yet | |
| 5 | Not run yet | |
| 6 | **Yes** | Bump-to-tap saved the moment, and it saves easily. |
| 7 | | |
| 8 | | |
| 9 | | |

### Session 2 (background build)

| # | Works? | Notes |
|---|---|---|
| 4 | | |
| 5 | | |
| 8 | | |
| 10 (one phone locked) | | |
| 10 (both locked) | | |

## What we expect (so surprises are useful)

- **Test 4 will be jumpy.** Bluetooth signal strength bounces around, especially with a phone in a pocket or a body in the way. The app guesses distance from it: about -90 dBm is far away, -40 dBm is touching.
- **Test 8 will probably fail with `Heya.swiftpm`.** The Playgrounds package can't run Bluetooth in the background. `HeyaApp.xcodeproj` can (added Nov 23).
- **Test 10: one phone locked should work; both locked may not.** When an iPhone is in the background, iOS hides Heya's advertisement in a special "overflow" area that other phones only see if they're actively looking for it. A phone in a pocket hears friends much less often than an open one (we wait up to 2 minutes before calling a friend gone). Two locked phones finding each other is the riskiest part of using phones instead of bracelets, so write down exactly what happens.
- Distance thresholds to tune afterwards, in `AppState.swift`: pairing needs a signal stronger than -60 dBm, and a tap needs `distance <= 0.2`. The bump threshold is `1.0` g, in `Sensors.swift`.

## Afterwards

- Add the results to this file (or to the Build log on the product page) and commit them.
- Decide the next fix. Likely candidates: smoothing the signal, background Bluetooth, and private rotating IDs so only friends can recognize you. Those three are what stand between this and testing with other people.
