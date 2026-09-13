# MODDYS World Radio for iOS v1.0.9

The new mini player, bundled for iOS: it takes the screen, and you can drag it and size it.

## What changed

**The mini player takes the screen.** Pressing the cover picture on a phone or an iPad used to leave the
station list behind the player. While the player is up the page now stands down - header, toolbar, list and
the bottom bar all go - and the mini player is what you have. ✕, a tap on the backdrop or Escape brings the
page straight back.

**It moves, and it resizes.** Drag the title bar to move it, drag the grip in its corner for any size in
between, and it remembers where you left it.

**S / M / L mean what they say.** S is a genuinely small player (320x250 at most, down from 430x330), M is
half the screen, L is the whole screen.

**A touch screen always gets the docked player** - including an iPad reporting a desktop user agent - and it
opens as the small player, never full screen. The page inside reflows at every size, so its controls stay
reachable at the smallest.

**The bundled page is the current one**, byte for byte - the same file Android 1.6.9 carries.

## Verified

- the suite that drives the real page, against this page: 236 checks, 0 failed - including a twenty-check
  section that runs the player as a tablet at 800x1280 and 1280x800: it docks, opens no tab, the site
  stands down behind it, it opens as the small player and not full screen, M is half the screen, L is all
  of it, the title bar drags it, the corner resizes it, and the docked page is a player rather than a
  minimised page
- the same suite against what moddys.net serves: 236 checks, 0 failed
- the layout sweep over 14 device shapes (Android 320 / 360 / 412, landscape, 800 tablet; iPhone
  SE / 15 / 15 Pro Max; iPad mini / Pro; macOS 1280 / 1440; Windows 1366 / 1920): 14 measured,
  0 broken, locally and against the live site
- `tools/shim_harness.py` drives the real shell over both bridges: 76 checks, 0 failed
- the downloads suite: 84 checks, 0 failed, and 28 more against the live feed, the file it points
  at, and the sha256 of what the host really serves
- the bundled `index.html` is byte-identical to the one this release puts on the site, and
  `scripts/verify_bundle.py` reads that out of the published `.app` itself

## Install

Sideload the unsigned `.ipa` with Sideloadly (or an on-device signer) and your own Apple ID - see
the download page for the two steps. Your stations and favourites stay.

## Cheers Moddy !
