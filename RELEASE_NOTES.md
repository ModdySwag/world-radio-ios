# MODDYS World Radio for iOS v1.0.6

The same page work as the Android release, bundled for iOS.

## What changed

**Four tidy rows, all the same width.** The header, then the search field, then the stations line
(the count and the Verified switch), then Format · Bitrate · Country, then Saved and Reset. Every
row is cut to the shape of the search field, which is what makes it read as one thing instead of a
pile of buttons.

**The genre panel is gone.** It was too complicated and it cluttered the screen in landscape, and
the search field already did the job: type `dub`, `news` or `spanish` and the list narrows to that.
The station line is now just the count — no page number, no "1–240", no "10,965 hidden" — and the
Verified switch at its right-hand end decides whether that number is the stations this browser can
play or all of them.

**🎲 Random** plays a station out of the list you are looking at. Your search, your filters and the
Verified switch all still apply, and it prefers one this browser can actually play.

**On a phone the page arrows take a line of their own**, filling it, so a hundred-odd pages of
results are easier to move through.

Inside the app the player is the app's own bottom sheet (a phone has no second window), so the
site's pop-out is not part of this build — the page's playing, pausing and skipping all go through
the sheet as before.

`MODDYSWorldRadio-v1.0.6-unsigned.ipa` is **unsigned** and installs on nothing by itself - iOS
refuses an unsigned app. It is here so you can sign it on your side (Sideloadly with your own
Apple ID, an on-device signer, or your own certificate). Details on the downloads page.

## Verified

- `scripts/verify_bundle.py` on the .app inside this .ipa: 31 checks, 0 failed — the bundled
  `index.html`, `stations.js`, `countries.js`, `viz.js`, the shell shim and `compat.json` are all
  byte-identical to the repo copies, the shim is the recorded shared-shell revision, and the bundle
  id, minimum iOS version and background-audio declaration are as they should be
- the same 213-check page suite that the Android release runs, against the files this bundle carries

## Install

The .ipa is unsigned: sign it on your side (Sideloadly, an on-device signer, or your own
certificate). Your stations and favourites stay.

## Cheers Moddy !
