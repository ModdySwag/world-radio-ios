# MODDYS World Radio for iOS v1.0.8

The tablet fix, bundled for iOS.

## What changed

**The page no longer sends the mini player to a tab on a touch device.** Pressing the cover picture
on a phone or a tablet used to ask the browser for a pop-up window; Chrome on Android and Safari on
iOS both open that as a whole tab instead, where the player came up minimised - a nearly empty page
with a play button and a "click anywhere to expand" note on it. On a mobile browser the player now
opens docked in the page, which is the compact player a phone already gets when a pop-up is blocked.
The page also refuses to open minimised in a wide window, and holds itself to a centred column when
it is a tab, so a tablet sees a mini player rather than a stretched page.

**The docked player sits above the bar** instead of behind it: the bar is fixed to the same bottom
edge and is taller than the dock's inset, so the volume row and the footer were covered.

**The bundled page is the current one**, byte for byte - the same file Android 1.6.8 carries.

## Verified

- the suite that drives the real page, against this page: 226 checks, 0 failed - including a new
  eight-check section that runs the player at 800x1280 and 1280x800 as a tablet: the player docks,
  opens no tab, sits clear of the bar, and is a player rather than a minimised page
- the same suite against what moddys.net serves: 226 checks, 0 failed
- the layout sweep over 14 device shapes (Android 320 / 360 / 412, landscape, 800 tablet; iPhone
  SE / 15 / 15 Pro Max; iPad mini / Pro; macOS 1280 / 1440; Windows 1366 / 1920): 14 measured,
  0 broken, locally and against the live site
- `tools/shim_harness.py` drives the real shell over both bridges: 76 checks, 0 failed
- the downloads suite: 84 checks, 0 failed, and 28 more against the live feed, the file it points
  at, and the sha256 of what the host really serves
- the bundled `index.html` is byte-identical to the one this release puts on the site
  (sha256 `3c170425cc7e26eb…`), and `scripts/verify_bundle.py` reads that out of the published
  `.app` itself: 31 checks, 0 failed

## Install

Sideload the unsigned `.ipa` with Sideloadly (or an on-device signer) and your own Apple ID - see
the download page for the two steps. Your stations and favourites stay.

## Cheers Moddy !
