# MODDYS World Radio for iOS v1.0.0

**The radio, on the iPhone and the iPad.** Same web app, same station list, same player —
wrapped in the iOS shell it never had: it keeps playing when you leave the app or lock the
screen, and it puts the station on your lock screen with a play button.

This is the iOS twin of the Android app, and the two are deliberately the same product: the
bundled `index.html`, `stations.js` and `countries.js` are byte-identical to what moddys.net
serves, and the entire front end — the player sheet, the theme, the visualiser, the
compatibility notice, the Check panel — is **one file shared by both apps**.

## What's here

- **Background playback** through a normal iOS audio session, so the stream survives the app
  going away and the device locking.
- **A real lock-screen card**: artwork, station name, country · language · codec · bitrate,
  with play, pause and stop. No next/previous and no scrubbing, because live radio has neither
  and offering them would be a lie.
- **The player sheet**, exactly as on Android: drag it up for the full view, drag it down to
  fold it back to a bar, with volume, transport, and one-tap jumps to Search, Light/Dark,
  Favourites, Random, Playable, Reset, Top, Visual and Check.
- **Five visualiser styles**, lifted out of the page (which hides them on anything narrower
  than 900px) and into the expanded player.
- **Light mode**, remembered between launches.
- **The Check panel**, reporting this device: iOS version, hardware model, the WebKit version
  that decides what can decode, codec support, and how many of the 47,994 stations this device
  can actually play — with a copy button for a bug report.
- **Version compatibility, said out loud.** Below iOS 15 the app cannot be installed at all
  (Apple enforces that from `MinimumOSVersion`). Below iOS 18 — the version the app is tuned
  for — you get one dismissible notice at first launch explaining what is likely to be rough
  and why, and the Check panel keeps that verdict visible afterwards.
- **Links leave the app properly**: a station's website or stream opens in Safari instead of
  replacing the player.

## Verified

- **The built app is checked after CI, not the build log.** Bundle identity, the install-time
  version floor against `compat.json`, the background-audio declaration, the cleartext
  declaration, both device families, and the compiled binary's own strings for the bridge and
  the notice.
- **The bundled web app is byte-identical** to the repo's copy of the site files, and the
  shell shim's SHA-256 is compared against the revision the Android app ships — inside the
  built bundle, not just in the working tree.
- **38 checks** driving the real shell in a real browser, on all three bridge paths: Android's
  synchronous interface, iOS's message handler, and no bridge at all.

## Install

Not a tap-to-install download, and it is worth being straight about why: iOS will not run an
app that Apple has not signed. What CI produces is a verified, **unsigned** `.ipa`.

- **On your own device:** sideload it with Sideloadly or AltStore using any Apple ID. A free
  Apple ID works, and needs the app re-signed every 7 days.
- **For everyone else:** that needs the Apple Developer Program ($99/year), and then TestFlight
  or the App Store. The build is already wired for signing — add the App Store Connect secrets
  and the signed job runs.
- **Nothing at all, today:** moddys.net → Share → **Add to Home Screen**. Full-screen, own
  icon, and iOS keeps the audio playing in the background.

**Privacy & safety:** nothing is collected, nothing is sent anywhere except the streams you
press play on. No analytics, no accounts, no third-party SDKs, no external dependencies —
Apple's own WebView, audio and media frameworks, plus a loopback-only HTTP server that serves
the bundled page to the app itself. Cleartext `http://` is permitted because 8,330 of the
47,994 stations are still plain HTTP; certificate checks are never bypassed.

Cheers Moddy !
