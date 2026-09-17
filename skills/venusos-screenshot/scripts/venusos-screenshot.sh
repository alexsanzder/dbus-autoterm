#!/bin/sh
# Capture the Venus OS GUI framebuffer (/dev/fb0) over SSH and save it as PNG.
#
# Usage: venusos-screenshot.sh [user@host] [output.png]
# Target: first arg, else $VENUS_TARGET, else root@einstein (matches scripts/deploy-dbus-autoterm.sh).
# Output: second arg, else ./venusos-screen-<timestamp>.png

set -eu

target="${1:-${VENUS_TARGET:-root@einstein}}"
out="${2:-./venusos-screen-$(date +%Y%m%d-%H%M%S).png}"
tmp_raw="$(mktemp /tmp/venusos-fb.XXXXXX.raw.gz)"
trap 'rm -f "$tmp_raw"' EXIT

geo="$(ssh "$target" 'cat /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/bits_per_pixel /sys/class/graphics/fb0/stride')"
width="$(printf '%s' "$geo" | sed -n '1s/,.*//p')"
height="$(printf '%s' "$geo" | sed -n '1s/.*,//p')"
bpp="$(printf '%s' "$geo" | sed -n '2p')"
stride="$(printf '%s' "$geo" | sed -n '3p')"

if [ "$bpp" != "32" ]; then
	echo "Unsupported framebuffer depth: ${bpp}bpp (only 32bpp supported)" >&2
	exit 1
fi

echo "Capturing ${width}x${height} (${bpp}bpp, stride ${stride}) from ${target} ..."
ssh "$target" "dd if=/dev/fb0 bs=${stride} count=${height} 2>/dev/null | gzip" > "$tmp_raw"

python3 - "$tmp_raw" "$out" "$width" "$height" <<'PY'
import gzip
import struct
import sys
import zlib

raw_path, out_path, width, height = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])

raw = gzip.open(raw_path, "rb").read()
expected = width * height * 4
if len(raw) < expected:
    sys.exit(f"short framebuffer read: {len(raw)} < {expected}")

# Little-endian 32bpp BGRA (Cerbo GX /fb0 layout).
rgb = bytearray(width * height * 3)
src = memoryview(raw)
j = 0
for i in range(0, expected, 4):
    b, g, r = src[i], src[i + 1], src[i + 2]
    rgb[j] = r
    rgb[j + 1] = g
    rgb[j + 2] = b
    j += 3

def chunk(tag, data):
    c = struct.pack(">I", len(data)) + tag + data
    return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
row = width * 3
idat = zlib.compress(b"".join(b"\x00" + bytes(rgb[y * row:(y + 1) * row]) for y in range(height)))

png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", ihdr)
       + chunk(b"IDAT", idat)
       + chunk(b"IEND", b""))

with open(out_path, "wb") as f:
    f.write(png)
print(f"Saved {out_path} ({len(png)} bytes)")
PY
