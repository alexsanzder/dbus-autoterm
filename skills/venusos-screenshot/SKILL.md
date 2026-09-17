---
name: venusos-screenshot
description: Use when taking a screenshot of the Venus OS GUI (gui-v2) as shown on a Cerbo GX or Raspberry Pi display. Captures the /dev/fb0 framebuffer over SSH, converts it to PNG locally, and can save it into the repo (e.g. docs/screenshots/). Works even when the device IP is not routable from the workstation, as long as SSH works.
metadata:
  domain: venusos
  platforms:
    - cerbo-gx
    - raspberry-pi
    - victron
allowed-tools: bash read
---

# Venus OS Screenshot

Capture the on-device Venus OS display over SSH and save it as a PNG.

## Use this skill when

- the user asks for a screenshot of the heater page or any other Venus OS GUI page
- the device web GUI is unreachable from the workstation (`ERR_ADDRESS_UNREACHABLE`) but SSH works
- a UI change needs visual proof committed to the repo

## How it works

The Venus OS GUI renders to `/dev/fb0`. The script:

1. Reads framebuffer geometry from `/sys/class/graphics/fb0/` (`virtual_size`, `bits_per_pixel`, `stride`) on the device.
2. Dumps the framebuffer with `dd` piped through `gzip` (BusyBox-safe).
3. Converts raw pixels to PNG locally with a stdlib-only Python encoder (no PIL/numpy needed).
4. 32bpp framebuffers are decoded as little-endian BGRA, which matches Cerbo GX.

## Usage

```sh
# Basic capture (host from VENUS_TARGET, else root@einstein as in scripts/deploy-dbus-autoterm.sh)
skills/venusos-screenshot/scripts/venusos-screenshot.sh

# Explicit host and output path
skills/venusos-screenshot/scripts/venusos-screenshot.sh root@10.129.2.246 /tmp/screen.png

# Save straight into the repo
skills/venusos-screenshot/scripts/venusos-screenshot.sh root@10.129.2.246 docs/screenshots/heater-page-$(date +%F).png
```

Target resolution order: first argument, else `$VENUS_TARGET`, else `root@einstein`.

## Constraints

- Captures whatever is on screen; it cannot navigate the GUI. Ask the user to open the target page on the device first, or verify the captured content before saving into the repo.
- The device framebuffer is typically 800x480 (GX Touch 50) — captured PNGs are that size.
- Requires `python3` locally for conversion; uses only the standard library.
