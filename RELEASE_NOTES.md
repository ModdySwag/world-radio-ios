# MODDYS World Radio for iOS v1.0.1

**The same app as 1.0.0 - carrying the cleaned-up page.** Nothing about playback, the station
list or your favourites has changed.

`MODDYSWorldRadio-v1.0.1-unsigned.ipa` is **unsigned** and installs on nothing by itself - iOS
refuses an unsigned app. It is here so it can be signed on your side (Sideloadly with your own
Apple ID, an on-device signer, or your own certificate). Details on the downloads page.

## What changed

- **The header no longer collapses.** The control is gone from the page and the header is always
  the full-size one, whatever an older version may have left in storage. The shell used to have
  to hide that control and force the header open; that code went with it.
- **The filter panel starts closed**, so the station list is the first thing you see and
  "Filters" opens the rest - which matters more on an iPhone than anywhere else, because the
  panel used to push the list down behind the player.
- **The download button has a pointing finger above it** - an inline SVG in the site's own cyan,
  violet and pink. Hidden from screen readers, takes no clicks, and stops bobbing for anyone with
  reduced motion set.
- **The mini-player window's scroll wheel now changes transparency instead of opacity** - it
  fades the background layers and leaves the text, artwork and buttons fully opaque, so the
  window stays readable however far you take it. Same gesture as before, stops at 75%.

## Verified

- **34 new checks** for those four changes, against the built page and again against the live
  site, including the returning-visitor cases (a stored collapsed-header flag and a stored
  open-filter state both come up correct on load).
- **46 checks** driving the shared shell in a real browser on the iOS bridge.
- **The built app is inspected from the inside** before it is published: bundle id
  `com.moddys.worldradio`, version 1.0.1, `MinimumOSVersion 15.0`, both device families,
  `UIBackgroundModes: audio`, and the bundled page hashed against the one moddys.net serves.

## Install

iPhone and iPad, iOS 15 or newer to install - tuned for iOS 18 or newer. Easiest route needs no
computer: open moddys.net in Safari, then Share > **Add to Home Screen**. For the real app shell,
sign this `.ipa` yourself.

**Privacy & safety:** the app talks to one thing only, the radio directory and the streams you
play. No analytics, no accounts, no tracking, nothing collected, nothing sent anywhere.
Cleartext `http://` streams are allowed because 8,330 of the 47,994 stations are still plain
HTTP; certificate checks are never bypassed.

Cheers Moddy !
