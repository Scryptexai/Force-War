#!/usr/bin/env python3
"""Generate the hex shield texture for shielded air enemies (Pass 3, item 6).

Brief: shielded enemies get a hex shield in a non-blue colour. Blue and cyan
are reserved for the player and red/orange for threats, so the cell colour is
violet-magenta: unmistakably "shield", never confused with either faction.

The texture is a flat hex grid with bright cell edges and faint cell fill. It
is mapped onto a sphere, so the alpha also carries a soft radial falloff that
keeps the middle of the bubble readable (you must still see the enemy behind
it) while the rim stays solid.

Stdlib only - this sandbox has no numpy or PIL.

Usage: python3 tools/make_hex_shield_texture.py assets/vfx/hex_shield.png [size]
"""
import math
import struct
import sys
import zlib


def write_png(path, width, height, pixels):
    stride = width * 4
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw += pixels[y * stride:(y + 1) * stride]

    def chunk(tag, payload):
        return (struct.pack('>I', len(payload)) + tag + payload
                + struct.pack('>I', zlib.crc32(tag + payload) & 0xFFFFFFFF))

    out = (b'\x89PNG\r\n\x1a\n'
           + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(bytes(raw), 9))
           + chunk(b'IEND', b''))
    open(path, 'wb').write(out)


def hex_edge_strength(x, y, radius):
    """Voronoi distance to the cell border on a flat-top hex lattice.

    The Voronoi cells of this point lattice are exactly hexagons, so the
    border is simply where the two nearest centres are equidistant. That is
    far more robust than hand-rolling a hexagon distance field.
    """
    w = radius * 1.5
    h = radius * math.sqrt(3.0)
    col = int(math.floor(x / w))
    row = int(math.floor(y / h))
    best = 1e9
    second = 1e9
    for dc in (-1, 0, 1):
        cc = col + dc
        cx = cc * w
        offset = h * 0.5 if cc % 2 else 0.0
        for dr in (-1, 0, 1, 2):
            cy = (row + dr) * h + offset
            d = math.hypot(x - cx, y - cy)
            if d < best:
                second = best
                best = d
            elif d < second:
                second = d
    return second - best


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else 'assets/vfx/hex_shield.png'
    size = int(sys.argv[2]) if len(sys.argv) > 2 else 256
    radius = size / 9.0
    # Violet-magenta: outside both faction codes.
    edge = (0.86, 0.36, 1.00)
    fill = (0.52, 0.16, 0.74)
    px = bytearray(size * size * 4)
    centre = (size - 1) * 0.5
    for y in range(size):
        for x in range(size):
            d = hex_edge_strength(x + 0.5, y + 0.5, radius)
            line = max(0.0, 1.0 - d / (radius * 0.30))   # bright cell border
            line = line * line
            cell = 0.16 + 0.10 * math.sin((x + y) * 0.07)
            # Radial term: rim of the bubble reads solid, middle stays see-through.
            rx = (x - centre) / centre
            ry = (y - centre) / centre
            r = min(1.0, math.hypot(rx, ry))
            rim = r ** 2.4
            alpha = min(1.0, 0.10 + line * 0.85 + rim * 0.45)
            mix = min(1.0, line + rim * 0.35)
            col = tuple(fill[i] + (edge[i] - fill[i]) * mix for i in range(3))
            glow = 0.55 + 0.45 * mix
            i = (y * size + x) * 4
            px[i] = min(255, int(col[0] * 255 * glow))
            px[i + 1] = min(255, int(col[1] * 255 * glow))
            px[i + 2] = min(255, int(col[2] * 255 * glow))
            px[i + 3] = min(255, int(alpha * 255))
    write_png(path, size, size, px)
    print('wrote %s (%dx%d hex shield, violet-magenta, non-blue)' % (path, size, size))


if __name__ == '__main__':
    main()
