# MODDYS World Radio for iOS v1.0.2

**The player bar now fits your phone.** The same row of controls, laid out to survive a narrow
screen instead of running off the right edge.

`MODDYSWorldRadio-v1.0.2-unsigned.ipa` is **unsigned** and installs on nothing by itself - iOS
refuses an unsigned app. It is here so you can sign it on your side (Sideloadly with your own
Apple ID, an on-device signer, or your own certificate). Details on the downloads page.

## What was wrong

Three separate faults in one row, measured across 14 device shapes:

- **Nothing could give way.** The volume slider's own minimum width (about 129px) was wider than
  the box it sat in, so it painted across the Pop-out button; and because the buttons were
  shrinkable, a tight row squeezed Pop-out until its label wrapped onto three lines and the text
  was cut off.
- **A phone rule was hiding an element that does not exist** (it named `#barStop`; the button is
  `#bStop`), so Stop stayed on screen taking room the row did not have.
- **The page reserved no space for the bar**, and the station grid's 320px minimum column was
  wider than a 320px phone's content width - which pushed the document past the screen edge and
  made the whole page scale down.

## What changed

- Nothing in the bar can be squeezed any more, and the slider shrinks properly.
- On phones the bar drops Stop, Website, the volume percentage, the badge, the meta line and the
  visualiser toggle (its canvas is already switched off below 900px, so on a phone it was a
  button that could do nothing visible).
- The Pop-out button keeps its icon and its accessible name; only the word is dropped on the
  narrowest screens.
- The page now reserves the bar's measured height, so the last station cards are no longer
  sitting underneath it, and the back-to-top button and toasts clear it.
- Controls are at least 40px on touch, and the bar respects the side safe areas as well as the
  bottom one.

## Verified

- **The bar, on 14 device profiles** including iPhone SE, iPhone 15, iPhone 15 Pro Max, iPad
  mini, iPad Pro and a landscape phone: nothing clipped, nothing overlapping, and the page never
  wider than the device. 6 profiles were broken before this.
- **46 shell checks** still pass on the iOS bridge, and the page inside the .ipa is
  byte-identical to the one moddys.net serves.

## Install

iPhone and iPad, iOS 15 or newer to install - tuned for iOS 18 or newer. Easiest route needs no
computer: open moddys.net in Safari, then Share > **Add to Home Screen**. For the real app shell,
sign this `.ipa` yourself.

**Privacy & safety:** the app talks to one thing only, the radio directory and the streams you
play. No analytics, no accounts, no tracking, nothing collected, nothing sent anywhere.
Cleartext `http://` streams are allowed because 8,330 of the 47,994 stations are still plain
HTTP; certificate checks are never bypassed.

Cheers Moddy !
