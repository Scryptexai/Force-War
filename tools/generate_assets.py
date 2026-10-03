#!/usr/bin/env python3
"""Generate deterministic vector game assets for Force War: Storm Convoy.

The assets are lightweight SVG files so they stay readable in Git and import
cleanly in Godot/Web builds without external art dependencies.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"


def svg(width: int, height: int, body: str, title: str = "Force War Asset") -> str:
    return f"""<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{width}\" height=\"{height}\" viewBox=\"0 0 {width} {height}\">
<title>{title}</title>
<defs>
  <filter id=\"glow\" x=\"-50%\" y=\"-50%\" width=\"200%\" height=\"200%\">
    <feGaussianBlur stdDeviation=\"2.5\" result=\"blur\"/>
    <feMerge><feMergeNode in=\"blur\"/><feMergeNode in=\"SourceGraphic\"/></feMerge>
  </filter>
  <linearGradient id=\"steel\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"1\">
    <stop offset=\"0\" stop-color=\"#effbff\"/><stop offset=\"0.45\" stop-color=\"#5bc4ff\"/><stop offset=\"1\" stop-color=\"#18305a\"/>
  </linearGradient>
  <linearGradient id=\"enemy\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\">
    <stop offset=\"0\" stop-color=\"#ffb66a\"/><stop offset=\"1\" stop-color=\"#8f1d2d\"/>
  </linearGradient>
  <linearGradient id=\"ground\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"1\">
    <stop offset=\"0\" stop-color=\"#bbcf91\"/><stop offset=\"1\" stop-color=\"#324620\"/>
  </linearGradient>
</defs>
{body}
</svg>
"""


def write_asset(path: str, body: str, size: int = 128, title: str = "Force War Asset") -> None:
    file = ASSETS / path
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(svg(size, size, body, title), encoding="utf-8")


def plane_body(primary: str, secondary: str, cockpit: str, accent: str) -> str:
    return f"""
<path d=\"M64 7 L84 71 L119 93 L78 97 L64 121 L50 97 L9 93 L44 71 Z\" fill=\"{secondary}\" opacity=\"0.95\"/>
<path d=\"M64 16 L76 76 L91 92 L69 88 L64 110 L59 88 L37 92 L52 76 Z\" fill=\"{primary}\"/>
<path d=\"M64 31 L72 70 L64 84 L56 70 Z\" fill=\"{cockpit}\" opacity=\"0.96\"/>
<circle cx=\"64\" cy=\"72\" r=\"6\" fill=\"{accent}\" filter=\"url(#glow)\"/>
<path d=\"M52 96 L64 121 L76 96\" fill=\"#ff7b25\" opacity=\"0.86\"/>
"""


def enemy_interceptor() -> str:
    return """
<path d="M64 113 L18 32 L52 49 L64 14 L76 49 L110 32 Z" fill="url(#enemy)"/>
<path d="M64 100 L44 50 L64 31 L84 50 Z" fill="#4a101c"/>
<circle cx="64" cy="53" r="9" fill="#ffd45a"/>
<path d="M24 36 L4 24 M104 36 L124 24" stroke="#ffeb99" stroke-width="6" stroke-linecap="round"/>
"""


def bomber() -> str:
    return """
<path d="M64 112 L7 62 L32 47 L38 20 L90 20 L96 47 L121 62 Z" fill="#97313b"/>
<path d="M64 99 L37 49 L51 27 L77 27 L91 49 Z" fill="#f09042"/>
<circle cx="48" cy="57" r="8" fill="#1a0c14"/><circle cx="80" cy="57" r="8" fill="#1a0c14"/>
<rect x="56" y="70" width="16" height="30" rx="7" fill="#3b1018"/>
"""


def gunship() -> str:
    return """
<rect x="20" y="31" width="88" height="58" rx="20" fill="#3e2459"/>
<path d="M12 58 L116 58 L99 90 L29 90 Z" fill="#9c56dd"/>
<circle cx="64" cy="59" r="18" fill="#17091f"/>
<circle cx="64" cy="59" r="9" fill="#ff4df0" filter="url(#glow)"/>
<path d="M7 47 H31 M97 47 H121 M42 92 H86" stroke="#f4d7ff" stroke-width="7" stroke-linecap="round"/>
"""


def drone() -> str:
    return """
<circle cx="64" cy="64" r="25" fill="#1e6370"/>
<circle cx="64" cy="64" r="12" fill="#70f5ff" filter="url(#glow)"/>
<path d="M64 19 L74 48 H54 Z M64 109 L54 80 H74 Z M19 64 L48 54 V74 Z M109 64 L80 74 V54 Z" fill="#a7fbff" opacity="0.88"/>
<circle cx="28" cy="28" r="9" fill="#ffeb6b"/><circle cx="100" cy="28" r="9" fill="#ffeb6b"/><circle cx="28" cy="100" r="9" fill="#ffeb6b"/><circle cx="100" cy="100" r="9" fill="#ffeb6b"/>
"""


def tank() -> str:
    return """
<rect x="18" y="37" width="92" height="58" rx="12" fill="url(#ground)"/>
<rect x="28" y="89" width="72" height="14" rx="7" fill="#17210f"/>
<rect x="28" y="25" width="72" height="14" rx="7" fill="#17210f"/>
<circle cx="64" cy="65" r="20" fill="#6f8b3e"/>
<rect x="60" y="9" width="10" height="55" rx="5" fill="#263915"/>
<circle cx="64" cy="65" r="8" fill="#c3d37a"/>
"""


def sam() -> str:
    return """
<rect x="18" y="72" width="92" height="28" rx="9" fill="#293820"/>
<circle cx="42" cy="102" r="10" fill="#111"/><circle cx="86" cy="102" r="10" fill="#111"/>
<path d="M38 69 L77 23 L89 32 L50 78 Z" fill="#809353"/>
<path d="M71 22 L105 14 L92 44 Z" fill="#ff7043"/>
<path d="M33 61 L68 15" stroke="#dff5a5" stroke-width="5"/>
"""


def artillery() -> str:
    return """
<rect x="14" y="78" width="100" height="20" rx="8" fill="#29321f"/>
<circle cx="36" cy="101" r="12" fill="#111"/><circle cx="92" cy="101" r="12" fill="#111"/>
<path d="M46 72 L89 29" stroke="#687a48" stroke-width="14" stroke-linecap="round"/>
<path d="M76 39 L98 17" stroke="#c7d892" stroke-width="7" stroke-linecap="round"/>
<rect x="34" y="55" width="44" height="30" rx="10" fill="#6d8246"/>
"""


def truck(color: str, cargo: str) -> str:
    return f"""
<rect x=\"22\" y=\"20\" width=\"84\" height=\"88\" rx=\"12\" fill=\"{color}\"/>
<rect x=\"30\" y=\"28\" width=\"68\" height=\"28\" rx=\"7\" fill=\"#172331\" opacity=\"0.72\"/>
<rect x=\"32\" y=\"61\" width=\"64\" height=\"34\" rx=\"8\" fill=\"{cargo}\"/>
<circle cx=\"30\" cy=\"22\" r=\"7\" fill=\"#0d1116\"/><circle cx=\"98\" cy=\"22\" r=\"7\" fill=\"#0d1116\"/>
<circle cx=\"30\" cy=\"106\" r=\"7\" fill=\"#0d1116\"/><circle cx=\"98\" cy=\"106\" r=\"7\" fill=\"#0d1116\"/>
"""


def support_pod(kind: str) -> str:
    colors = {
        "repair": ("#25d366", "#eaffef", "+"),
        "smoke": ("#aeb8c2", "#ffffff", "S"),
        "supply": ("#ffcc33", "#3b2a06", "★"),
        "radar": ("#45d8ff", "#081c28", "R"),
        "rod": ("#b46cff", "#fff0ff", "⚡"),
    }
    bg, fg, label = colors[kind]
    return f"""
<circle cx=\"64\" cy=\"64\" r=\"46\" fill=\"{bg}\" opacity=\"0.92\"/>
<circle cx=\"64\" cy=\"64\" r=\"34\" fill=\"#101827\" opacity=\"0.72\"/>
<text x=\"64\" y=\"78\" text-anchor=\"middle\" font-size=\"46\" font-family=\"Arial, sans-serif\" font-weight=\"700\" fill=\"{fg}\">{label}</text>
"""


def weather_icon(kind: str) -> str:
    if kind == "storm":
        return """
<path d="M25 72 C11 72 8 48 31 47 C35 24 69 20 80 39 C103 34 118 55 105 73 Z" fill="#5d6e8f"/>
<path d="M67 61 L47 95 H67 L58 119 L91 76 H70 Z" fill="#ffd936" filter="url(#glow)"/>
"""
    if kind == "rain":
        return """
<path d="M24 61 C12 61 10 39 31 39 C37 17 73 18 80 38 C102 35 115 57 102 72 H24 Z" fill="#6c849d"/>
<path d="M37 82 L28 111 M62 82 L53 111 M87 82 L78 111" stroke="#4bd4ff" stroke-width="8" stroke-linecap="round"/>
"""
    if kind == "wind":
        return """
<path d="M13 47 H84 C105 47 105 22 88 22 C78 22 76 31 78 36" fill="none" stroke="#dff8ff" stroke-width="9" stroke-linecap="round"/>
<path d="M23 70 H111 M38 92 H91 C108 92 109 112 93 112" fill="none" stroke="#8ae9ff" stroke-width="9" stroke-linecap="round"/>
"""
    return """
<path d="M19 74 C13 48 30 25 56 23 C85 20 108 41 109 70 C110 98 88 115 63 114 C41 113 24 98 19 74 Z" fill="#d7dce5" opacity="0.74"/>
<circle cx="45" cy="55" r="10" fill="#f7fbff"/><circle cx="76" cy="72" r="14" fill="#f7fbff"/>
"""


def main() -> None:
    write_asset("air/player_stormhawk.svg", plane_body("url(#steel)", "#123d7a", "#e9fbff", "#ffd84d"), title="Stormhawk player aircraft")
    write_asset("air/player_warden.svg", plane_body("#89f7c2", "#1b7057", "#ffffff", "#69ff7a"), title="Warden support aircraft")
    write_asset("air/enemy_interceptor.svg", enemy_interceptor(), title="Enemy interceptor")
    write_asset("air/enemy_bomber.svg", bomber(), title="Enemy dive bomber")
    write_asset("air/enemy_gunship.svg", gunship(), title="Enemy gunship")
    write_asset("air/enemy_storm_drone.svg", drone(), title="Enemy storm drone")

    write_asset("ground/enemy_tank.svg", tank(), title="Enemy tank")
    write_asset("ground/enemy_sam.svg", sam(), title="Enemy SAM launcher")
    write_asset("ground/enemy_artillery.svg", artillery(), title="Enemy artillery")

    write_asset("convoy/command_truck.svg", truck("#386cff", "#9ec2ff"), title="Convoy command truck")
    write_asset("convoy/fuel_tanker.svg", truck("#e59532", "#ffe2a8"), title="Convoy fuel tanker")
    write_asset("convoy/apc.svg", truck("#5f8652", "#a4c781"), title="Convoy APC")
    write_asset("convoy/supply_truck.svg", truck("#7b65d8", "#dac8ff"), title="Convoy supply truck")

    for kind in ["repair", "smoke", "supply", "radar", "rod"]:
        write_asset(f"support/{kind}_pod.svg", support_pod(kind), title=f"{kind} support pod")

    for kind in ["storm", "rain", "wind", "cloud"]:
        write_asset(f"weather/{kind}_icon.svg", weather_icon(kind), title=f"{kind} weather icon")

    print(f"Generated SVG assets under {ASSETS}")


if __name__ == "__main__":
    main()
