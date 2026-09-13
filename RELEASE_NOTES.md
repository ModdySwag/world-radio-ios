# MODDYS World Radio for iOS v1.0.7

The same page housekeeping as the Android release, bundled for iOS.

## What changed

**Two lines of dead code, gone** from `index.html` - a channel-message counter and a
recent-stations helper that nothing called - and the counter also leaves `popout.html`. Nothing a
listener can see or press changes: the toolbar, the search, the filters, Saved, 🎲 Random and
the hand-over are exactly as they were in 1.0.6.

**The bundled page is the current one**, byte for byte.

Inside the app the player is the app's own bottom sheet (a phone has no second window), so the
site's pop-out is not part of this build, as before.

`MODDYSWorldRadio-v1.0.7-unsigned.ipa` is **unsigned** and installs on nothing by itself - iOS
refuses an unsigned app. It is here so you can sign it on your side (Sideloadly with your own
Apple ID, an on-device signer, or your own certificate). Details on the downloads page.

## Verified

- the same 213-check page suite the Android release runs, against the files this bundle carries:
  213 checks, 0 failed
- the layout sweep over 14 device shapes, iOS among them (iPhone SE / 15 / 15 Pro Max, iPad mini /
  Pro): 14 measured, 0 broken
- the shell shim under WebKit, the engine this app runs: 76 checks, 0 failed
- `scripts/verify_bundle.py` on the .app inside this .ipa: 31 checks, 0 failed - every bundled
  file byte-identical to the repo copy, the shim matching the recorded shared-shell revision,
  and the bundle id, minimum iOS version and background-audio declaration as they should be

## Install

The .ipa is unsigned: sign it on your side (Sideloadly, an on-device signer, or your own
certificate). Your stations and favourites stay.

## Cheers Moddy !
