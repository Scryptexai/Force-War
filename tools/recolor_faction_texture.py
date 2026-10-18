#!/usr/bin/env python3
"""Recolour player-blue pixels in an environment texture to the threat/neutral code.

Correction brief, faction colour rule: blue/cyan belongs to the player only.
The arena deck panel ships with blue edge lights baked into the albedo, so the
scrolling sea platforms glow in the player's colour. This rewrites those pixels
in place, keeping their luminance (the lights stay lights, they just stop being
player-coded) and leaving the rest of the texture untouched.

Stdlib only - this sandbox has no numpy or PIL.

Usage:
  python3 tools/recolor_faction_texture.py <in.png> <out.png> [--tint r,g,b]
"""
import struct
import sys
import zlib


def read_png(path):
    data = open(path, 'rb').read()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise SystemExit('not a png: %s' % path)
    pos = 8
    idat = bytearray()
    width = height = depth = color_type = 0
    while pos < len(data):
        length = struct.unpack('>I', data[pos:pos + 4])[0]
        ctype = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        if ctype == b'IHDR':
            width, height, depth, color_type = struct.unpack('>IIBB', chunk[:10])
        elif ctype == b'IDAT':
            idat += chunk
        elif ctype == b'IEND':
            break
        pos += 12 + length
    if depth != 8 or color_type not in (2, 6):
        raise SystemExit('unsupported png depth=%d color=%d' % (depth, color_type))
    channels = 3 if color_type == 2 else 4
    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    out = bytearray(height * stride)
    prev = bytearray(stride)
    pos = 0
    for y in range(height):
        filt = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if filt == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif filt == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif filt == 3:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif filt == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return width, height, channels, bytearray(out)


def write_png(path, width, height, channels, pixels):
    color_type = 2 if channels == 3 else 6
    stride = width * channels
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw += pixels[y * stride:(y + 1) * stride]

    def chunk(tag, payload):
        return (struct.pack('>I', len(payload)) + tag + payload
                + struct.pack('>I', zlib.crc32(tag + payload) & 0xFFFFFFFF))

    body = (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, color_type, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(bytes(raw), 9))
            + chunk(b'IEND', b''))
    open(path, 'wb').write(body)


def recolor_palette(src, dst, tint):
    """Palette PNG: only the PLTE entries need rewriting, pixels stay as-is."""
    data = bytearray(open(src, 'rb').read())
    pos = 8
    changed = 0
    while pos < len(data):
        length = struct.unpack('>I', data[pos:pos + 4])[0]
        tag = bytes(data[pos + 4:pos + 8])
        start = pos + 8
        if tag == b'PLTE':
            for i in range(start, start + length, 3):
                r, g, b = data[i], data[i + 1], data[i + 2]
                # Only the baked light pixels and their halo: a clear blue
                # cast AND real saturation. Blue grey steel (b - r under ~45,
                # low saturation) stays steel, or the whole deck turns rusty.
                hi, lo = max(r, g, b), min(r, g, b)
                sat = 0.0 if hi == 0 else (hi - lo) / float(hi)
                if b - r >= 55 and sat >= 0.25:
                    lum = (0.299 * r + 0.587 * g + 0.114 * b) * 0.85
                    data[i] = min(255, int(lum * tint[0] + 0.5))
                    data[i + 1] = min(255, int(lum * tint[1] + 0.5))
                    data[i + 2] = min(255, int(lum * tint[2] + 0.5))
                    changed += 1
            crc = zlib.crc32(bytes(data[pos + 4:start + length])) & 0xFFFFFFFF
            data[start + length:start + length + 4] = struct.pack('>I', crc)
        if tag == b'IEND':
            break
        pos += 12 + length
    open(dst, 'wb').write(bytes(data))
    return changed


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]
    tint = (1.00, 0.63, 0.26)
    for arg in sys.argv[3:]:
        if arg.startswith('--tint'):
            tint = tuple(float(v) for v in arg.split('=', 1)[1].split(','))
    header = open(src, 'rb').read(26)
    if header[25] == 3:
        changed = recolor_palette(src, dst, tint)
        print('%s -> %s: %d palette entries recoloured off the player blue'
              % (src, dst, changed))
        return
    width, height, channels, px = read_png(src)
    changed = 0
    for i in range(0, len(px), channels):
        r, g, b = px[i], px[i + 1], px[i + 2]
        # Player-coded pixel: blue clearly dominant and bright enough to glow.
        if b > r + 28 and b > g + 14 and b > 70:
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            px[i] = min(255, int(lum * tint[0] + 0.5))
            px[i + 1] = min(255, int(lum * tint[1] + 0.5))
            px[i + 2] = min(255, int(lum * tint[2] + 0.5))
            changed += 1
    write_png(dst, width, height, channels, px)
    print('%s -> %s: %d of %d pixels recoloured off the player blue'
          % (src, dst, changed, width * height))


if __name__ == '__main__':
    main()
