#!/usr/bin/env python3
"""Render the app icon from tools/icon.html.

The icon is a build input like any other, so it is generated from source rather than being a
binary blob nobody can reproduce. Chromium draws it (no design tool needed, and it is the same
drawing the Android app's vector uses), then the alpha channel is removed - the App Store
rejects a marketing icon that contains transparency, and it is cheaper to get that right here
than to discover it at upload time.

Usage:
    python3 tools/make_icon.py
    python3 tools/make_icon.py --out /tmp/icon.png --size 1024
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
SOURCE = os.path.join(HERE, "icon.html")
DEFAULT_OUT = os.path.join(PROJECT, "Resources", "Assets.xcassets", "AppIcon.appiconset",
                           "icon-1024.png")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--keep-alpha", action="store_true",
                    help="for inspecting the render; never for the shipping icon")
    a = ap.parse_args()

    from playwright.sync_api import sync_playwright
    from PIL import Image

    size = a.size
    scratch = os.path.join(os.environ.get("TEMP", "/tmp"), "wr-icon-render.png")

    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": size, "height": size},
                                device_scale_factor=1)
        page.goto("file:///" + SOURCE.replace("\\", "/"))
        page.wait_for_timeout(200)
        page.screenshot(path=scratch, omit_background=False)
        browser.close()

    image = Image.open(scratch)
    if image.size != (size, size):
        print("render is %s, wanted %dx%d" % (image.size, size, size), file=sys.stderr)
        return 1
    if a.keep_alpha:
        image.save(a.out)
    else:
        image.convert("RGB").save(a.out, "PNG")

    check = Image.open(a.out)
    print("wrote %s" % a.out)
    print("  size   %dx%d" % check.size)
    print("  mode   %s (no alpha channel)" % check.mode)
    print("  bytes  %d" % os.path.getsize(a.out))
    if check.mode != "RGB" and not a.keep_alpha:
        print("expected an RGB image", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
