# Heya roadmap

Last updated: November 23, 2026. Shared plan for Tara and Jorge. Update it when priorities change.

## Current thinking: who gets the bracelet?

- **Kids without phones (Grant):** the bracelet is the product. Parents buy it; it gives a visible mood glow, in-person taps, and location for parents.
- **Adults with phones (Faith):** a separate bracelet may be a hard sell (another device to buy and charge). Heya may work better as an **iPhone + Apple Watch app**: the watch taps or buzzes when a friend is close and shows their mood at a glance.
- **Trade-off:** a bracelet's glow can be seen by friends across a room; a watch only alerts the wearer. That visible signal is part of Heya's "off your phone" promise.
- **First test:** a poll on the product page ("bracelet, phone app, or Apple Watch app?"), tracked in PostHog as `device_preference_answered` with a `choice` property. Not decided yet.

## Priority 1: Xcode proximity spike (iPhone / Apple Watch)

This matters more now: if adults use the app instead of a bracelet, the phone and watch *are* the product. The biggest technical unknown is whether two devices can reliably sense each other.

Goal: two iPhones (and then Watches) standing in for two bracelets.

Start from Tara's native app (`ios-native/HeyaApp.xcodeproj`, which builds the code in `ios-native/Heya.swiftpm`): it already advertises and scans over Bluetooth, estimates distance from signal strength, and saves a tap when phones bump. Run `ios-native/TEST-PLAN.md` first to see what holds up on real phones.

- [ ] Detect a paired friend nearby over Bluetooth LE and show signal strength ("warmer, warmer"). Detection works; the distance tests (4 and 5) haven't been run yet.
- [ ] Trigger a "pulse" (haptic + screen color) when the two devices are very close.
- [x] Save a "tap" when the devices touch or bump, like bracelets tapping. (Session 1: iPhone 17 + iPhone 12 mini, saves easily.)
- [ ] Find out what still works with the app in the **background** and the screen locked. iOS limits background Bluetooth; this is the riskiest part. **In progress:** `ios-native/HeyaApp.xcodeproj` turns on Bluetooth background modes and shows a lock-screen alert ("*Name* is nearby · Let's hang") when a friend arrives. Run test 10 in `ios-native/TEST-PLAN.md`.
- [ ] Try Nearby Interaction (UWB) on supported iPhones/Watches for distance and direction, and compare with Bluetooth.
- [ ] Mood colors stay meaningful: green = Let's hang, purple = Quiet company, yellow = Busy, but wave, off = invisible.
- [ ] Write down what worked, what didn't, and battery impact.

Keep it to a few test screens. Don't rebuild Wrapped in Swift yet.

**While waiting for bracelet parts:** the phone app stands in for the bracelet. Next after the background test: smoother distance (signal strength jumps around) and private rotating IDs, so only friends can recognize your phone. Both are needed before anyone outside the team can try it.

## Priority 2: web app (screens + AI)

- Keep iterating Wrapped, stats, and AI prompts in `app/` (fast to change, tested with PostHog).
- Later, turn `app/server.py` into a shared API that both the web app and the iOS app call, so stats and the AI call live in one place.

## How we work together

- Pull before you start; work on a branch and open a pull request for big changes.
- Avoid editing `app/index.html` at the same time.
- Natural split: one person on the Xcode spike, the other on the web app.
- Follow `AGENTS.md` (no secrets in commits, privacy rules, mood colors mean moods).
