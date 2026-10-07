#!/usr/bin/env python3
"""Pass 2 value/colour measurement.

Correction brief, section 6: the acceptance numbers are measured on the game
area of a phone screenshot (no status bar, no browser chrome). The Playwright
captures are exactly that - a 720x1280 canvas - so the whole frame is measured.

Method from the brief: luminance from a grayscale conversion, hue from HSV,
warm = hue 0-60 or 330-360, cool = hue 180-260, counted only on pixels whose
saturation and value are both above 0.25.

Stdlib only (this sandbox has no numpy/PIL).
"""
import colorsys
import json
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
        raise SystemExit('unsupported png format depth=%d color=%d' % (depth, color_type))
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
    return width, height, channels, bytes(out)


def measure(path, step=2):
    width, height, channels, pixels = read_png(path)
    stride = width * channels
    lum_hist = [0] * 256
    total = 0
    warm = 0
    cool = 0
    saturated = 0
    sat_sum = 0.0
    for y in range(0, height, step):
        base = y * stride
        for x in range(0, width, step):
            i = base + x * channels
            r = pixels[i]
            g = pixels[i + 1]
            b = pixels[i + 2]
            lum = int(0.299 * r + 0.587 * g + 0.114 * b)
            lum_hist[lum] += 1
            total += 1
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            sat_sum += s
            if s > 0.25 and v > 0.25:
                saturated += 1
                deg = h * 360.0
                if deg <= 60.0 or deg >= 330.0:
                    warm += 1
                elif 180.0 <= deg <= 260.0:
                    cool += 1

    mean = sum(i * c for i, c in enumerate(lum_hist)) / total
    var = sum(c * (i - mean) ** 2 for i, c in enumerate(lum_hist)) / total
    std = var ** 0.5

    def percentile(p):
        want = total * p
        run = 0
        for i, c in enumerate(lum_hist):
            run += c
            if run >= want:
                return i
        return 255

    p5 = percentile(0.05)
    p95 = percentile(0.95)
    highlights = sum(lum_hist[221:]) / total * 100.0
    darks = sum(lum_hist[:30]) / total * 100.0
    gradient = 0
    # Detail density: 8-bit luminance gradient between neighbouring sampled pixels.
    for y in range(0, height - step, step):
        base = y * stride
        nextbase = (y + step) * stride
        for x in range(0, width - step, step):
            i = base + x * channels
            j = base + (x + step) * channels
            k = nextbase + x * channels
            l0 = 0.299 * pixels[i] + 0.587 * pixels[i + 1] + 0.114 * pixels[i + 2]
            l1 = 0.299 * pixels[j] + 0.587 * pixels[j + 1] + 0.114 * pixels[j + 2]
            l2 = 0.299 * pixels[k] + 0.587 * pixels[k + 1] + 0.114 * pixels[k + 2]
            if max(abs(l0 - l1), abs(l0 - l2)) > 25:
                gradient += 1

    return {
        'file': path,
        'size': [width, height],
        'sampled': total,
        'contrastStd': round(std, 1),
        'p5': p5,
        'p95': p95,
        'range': p95 - p5,
        'highlightsPct': round(highlights, 2),
        'darksPct': round(darks, 2),
        'warmPct': round(warm / total * 100.0, 2),
        'coolPct': round(cool / total * 100.0, 2),
        'saturatedPct': round(saturated / total * 100.0, 2),
        'meanSaturation': round(sat_sum / total, 3),
        'detailDensityPct': round(gradient / total * 100.0, 2),
        'meanLuminance': round(mean, 1),
    }


TARGETS = {
    'contrastStd': ('>=', 45.0),
    'range': ('>=', 150.0),
    'warmPct': ('>=', 15.0),
    'darksPct': ('>=', 5.0),
}


def verdict(metrics):
    checks = {}
    for key, (op, bound) in TARGETS.items():
        value = metrics[key]
        checks[key] = value >= bound if op == '>=' else value <= bound
    checks['highlightsPct'] = 2.0 <= metrics['highlightsPct'] <= 8.0
    return checks


if __name__ == '__main__':
    results = []
    for path in sys.argv[1:]:
        m = measure(path)
        m['pass2'] = verdict(m)
        m['pass2All'] = all(m['pass2'].values())
        results.append(m)
        print(json.dumps(m))
    if results:
        failed = [r['file'] for r in results if not r['pass2All']]
        print('PASS2 %s (%d/%d frames)' % ('OK' if not failed else 'FAIL', len(results) - len(failed), len(results)))
