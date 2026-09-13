# MODDYS World Radio for iOS v1.1.1

The page buttons, redone for iPhone and iPad: the arrows take you to the page, one tap is always one
page, and the row is laid out properly on every screen size.

## What changed

**The arrows take you to the page.** They always did turn it - but every turn jumped you to the very
top of the page, which on a phone is the header and the search field, with the freshly loaded stations
below the fold: it looks exactly like "the button did nothing". A turn now lands on the results, and
turning from the bottom pager (240 cards down) comes back up to the first card of the new page.

**One tap, one page - never two, never none.** Two things could turn a page: WebKit's click, and a
fallback for the cases where the click after a touch never arrives. Which of them had already acted was
decided by a stopwatch, so a tap landing just inside the window was swallowed (nothing happened) and
one just outside it was counted twice (two pages a tap). They now share a single flag per touch: the
click claims its own touch, and the fallback takes it only if no click ever arrived.

**The row is laid out across all formats.** On an iPhone and an iPad the back arrow owns the left end,
the forward arrow the right end, and the page numbers sit together in the middle - it used to spread
four items with a 136px hole between the back arrow and the first number. Every control is a 44px
target, the page you are on is the cyan number between the arrows, and tapping a number is a jump:
page 1 and the last page are always one tap away.

**No more listener pile-up.** Every keystroke in the search field re-bound the pager and added another
touch listener without removing the old one. The pager is bound once now.

**Screen readers hear the page change** ("Page 2 of 174"). Nothing new is printed on screen and the
stations line above still carries only the count.

**The bundled page is the current one**, byte for byte - the same file Android 1.7.1 carries.

## Verified

- the suite that drives the real page, against this page: 251 checks, 0 failed - including the new
  checks: one tap advances exactly one page, a turn from the bottom pager brings the reader to the
  results, the two arrows own the two ends of the row, every pager control is a 44px target, and
  tapping a page number jumps to it
- the same suite against what moddys.net serves: 251 checks, 0 failed
- `tools/shim_harness.py --only ios` over the iOS bridge: 35 checks, 0 failed - including the three
  pager checks inside the app; the harness is now the same file Android runs (the two had drifted)
- the pager measured directly in WebKit, the engine this app uses, at phone, tablet, desktop and
  landscape sizes
- the bundled `index.html` is byte-identical to the one this release puts on the site, and
  `scripts/verify_bundle.py` reads that out of the published `.app` itself

## Install

Sideload the unsigned `.ipa` with Sideloadly (or an on-device signer) and your own Apple ID - see the
download page for the two steps. Your stations and favourites stay.

## Cheers Moddy !
