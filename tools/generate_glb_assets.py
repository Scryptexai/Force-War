#!/usr/bin/env python3
"""Generate lightweight GLB models used by the ground-chase phase.

These are intentionally simple low-poly Godot-ready assets, not screenshots or
static photos. They give the ground phase real 3D models that can be lit and
viewed by a perspective camera before the game transitions into the 2D/top-down
air mode.
"""

from __future__ import annotations

import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "models"


def align4(data: bytearray) -> None:
    while len(data) % 4:
        data.append(0)


class GlbBuilder:
    def __init__(self, materials: list[tuple[str, tuple[float, float, float, float]]]):
        self.bin = bytearray()
        self.buffer_views = []
        self.accessors = []
        self.primitives = []
        self.materials = [
            {
                "name": name,
                "doubleSided": True,
                "pbrMetallicRoughness": {
                    "baseColorFactor": list(color),
                    "metallicFactor": 0.35,
                    "roughnessFactor": 0.55,
                },
            }
            for name, color in materials
        ]

    def add_accessor(self, raw: bytes, component_type: int, type_name: str, count: int, target: int, minv=None, maxv=None) -> int:
        align4(self.bin)
        offset = len(self.bin)
        self.bin.extend(raw)
        self.buffer_views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(raw), "target": target})
        acc = {"bufferView": len(self.buffer_views) - 1, "componentType": component_type, "count": count, "type": type_name}
        if minv is not None:
            acc["min"] = list(minv)
        if maxv is not None:
            acc["max"] = list(maxv)
        self.accessors.append(acc)
        return len(self.accessors) - 1

    def add_primitive(self, positions, normals, indices, material: int) -> None:
        pos_raw = b"".join(struct.pack("<3f", *p) for p in positions)
        nor_raw = b"".join(struct.pack("<3f", *n) for n in normals)
        idx_raw = b"".join(struct.pack("<H", i) for i in indices)
        minv = [min(p[i] for p in positions) for i in range(3)]
        maxv = [max(p[i] for p in positions) for i in range(3)]
        pos_acc = self.add_accessor(pos_raw, 5126, "VEC3", len(positions), 34962, minv, maxv)
        nor_acc = self.add_accessor(nor_raw, 5126, "VEC3", len(normals), 34962)
        idx_acc = self.add_accessor(idx_raw, 5123, "SCALAR", len(indices), 34963)
        self.primitives.append({"attributes": {"POSITION": pos_acc, "NORMAL": nor_acc}, "indices": idx_acc, "material": material})

    def write(self, path: Path) -> None:
        gltf = {
            "asset": {"version": "2.0", "generator": "Force War procedural GLB generator"},
            "scene": 0,
            "scenes": [{"nodes": [0]}],
            "nodes": [{"name": path.stem, "mesh": 0}],
            "meshes": [{"name": path.stem + "Mesh", "primitives": self.primitives}],
            "materials": self.materials,
            "buffers": [{"byteLength": len(self.bin)}],
            "bufferViews": self.buffer_views,
            "accessors": self.accessors,
        }
        json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
        while len(json_bytes) % 4:
            json_bytes += b" "
        align4(self.bin)
        length = 12 + 8 + len(json_bytes) + 8 + len(self.bin)
        out = bytearray()
        out.extend(struct.pack("<4sII", b"glTF", 2, length))
        out.extend(struct.pack("<I4s", len(json_bytes), b"JSON"))
        out.extend(json_bytes)
        out.extend(struct.pack("<I4s", len(self.bin), b"BIN\0"))
        out.extend(self.bin)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(out)


def box(cx, cy, cz, sx, sy, sz):
    x0, x1 = cx - sx / 2, cx + sx / 2
    y0, y1 = cy - sy / 2, cy + sy / 2
    z0, z1 = cz - sz / 2, cz + sz / 2
    faces = [
        ([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], (0, 0, 1)),
        ([(x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0)], (0, 0, -1)),
        ([(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)], (-1, 0, 0)),
        ([(x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1)], (1, 0, 0)),
        ([(x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)], (0, 1, 0)),
        ([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], (0, -1, 0)),
    ]
    positions, normals, indices = [], [], []
    for verts, normal in faces:
        base = len(positions)
        positions.extend(verts)
        normals.extend([normal] * 4)
        indices.extend([base, base + 1, base + 2, base, base + 2, base + 3])
    return positions, normals, indices


def cylinder_x(cx, cy, cz, length, radius, segments=18):
    positions, normals, indices = [], [], []
    x0, x1 = cx - length / 2, cx + length / 2
    for i in range(segments):
        a0 = i / segments * math.tau
        a1 = (i + 1) / segments * math.tau
        y0, z0 = cy + math.cos(a0) * radius, cz + math.sin(a0) * radius
        y1, z1 = cy + math.cos(a1) * radius, cz + math.sin(a1) * radius
        base = len(positions)
        positions.extend([(x0, y0, z0), (x1, y0, z0), (x1, y1, z1), (x0, y1, z1)])
        normals.extend([(0, math.cos(a0), math.sin(a0)), (0, math.cos(a0), math.sin(a0)), (0, math.cos(a1), math.sin(a1)), (0, math.cos(a1), math.sin(a1))])
        indices.extend([base, base + 1, base + 2, base, base + 2, base + 3])
    # caps
    center0 = len(positions)
    positions.append((x0, cy, cz)); normals.append((-1, 0, 0))
    center1 = len(positions)
    positions.append((x1, cy, cz)); normals.append((1, 0, 0))
    for i in range(segments):
        a0 = i / segments * math.tau
        a1 = (i + 1) / segments * math.tau
        p0 = (cy + math.cos(a0) * radius, cz + math.sin(a0) * radius)
        p1 = (cy + math.cos(a1) * radius, cz + math.sin(a1) * radius)
        b = len(positions)
        positions.extend([(x0, p1[0], p1[1]), (x0, p0[0], p0[1]), (x1, p0[0], p0[1]), (x1, p1[0], p1[1])])
        normals.extend([(-1, 0, 0), (-1, 0, 0), (1, 0, 0), (1, 0, 0)])
        indices.extend([center0, b, b + 1, center1, b + 2, b + 3])
    return positions, normals, indices


def flat_triangles(tris, normal=(0, 1, 0)):
    positions, normals, indices = [], [], []
    for tri in tris:
        base = len(positions)
        positions.extend(tri)
        normals.extend([normal] * 3)
        indices.extend([base, base + 1, base + 2])
    return positions, normals, indices


def add(builder: GlbBuilder, geom, mat: int):
    builder.add_primitive(*geom, material=mat)


def build_car(path: Path, body=(0.1, 0.35, 0.95, 1), accent=(0.0, 0.9, 1.0, 1), hostile=False):
    mats = [
        ("body", body),
        ("glass", accent),
        ("rubber", (0.02, 0.02, 0.025, 1)),
        ("metal", (0.35, 0.36, 0.38, 1)),
        ("light", (1.0, 0.82, 0.25, 1) if not hostile else (1.0, 0.08, 0.04, 1)),
    ]
    b = GlbBuilder(mats)
    add(b, box(0, 0.38, 0, 1.55, 0.42, 3.1), 0)
    add(b, box(0, 0.72, -0.25, 1.05, 0.48, 1.25), 1)
    add(b, box(0, 0.58, -1.42, 1.25, 0.18, 0.22), 4)
    add(b, box(0, 0.55, 1.42, 1.15, 0.16, 0.20), 3)
    for x in (-0.88, 0.88):
        for z in (-1.05, 1.05):
            add(b, cylinder_x(x, 0.24, z, 0.22, 0.33, 18), 2)
    if hostile:
        add(b, box(0, 1.05, -0.1, 0.38, 0.22, 0.72), 3)
        add(b, box(0, 1.08, -0.82, 0.18, 0.18, 0.95), 4)
    b.write(path)


def build_jet(path: Path, body=(0.12, 0.18, 0.32, 1), glow=(0.0, 0.95, 1.0, 1)):
    mats = [
        ("body", body),
        ("wing", (0.55, 0.63, 0.72, 1)),
        ("glass", glow),
        ("engine", (1.0, 0.45, 0.1, 1)),
    ]
    b = GlbBuilder(mats)
    add(b, box(0, 0.42, 0, 0.58, 0.42, 3.2), 0)
    add(b, box(0, 0.67, -0.72, 0.42, 0.22, 0.72), 2)
    # triangular swept wings and tail fins, oriented to -Z forward.
    wing_tris = [
        [(-0.22, 0.38, -0.25), (-2.25, 0.28, 0.72), (-0.28, 0.32, 0.92)],
        [(0.22, 0.38, -0.25), (0.28, 0.32, 0.92), (2.25, 0.28, 0.72)],
        [(-0.18, 0.42, 1.10), (-1.02, 0.35, 1.65), (-0.22, 0.35, 1.72)],
        [(0.18, 0.42, 1.10), (0.22, 0.35, 1.72), (1.02, 0.35, 1.65)],
    ]
    add(b, flat_triangles(wing_tris, (0, 1, 0)), 1)
    add(b, box(-0.22, 0.42, 1.65, 0.22, 0.22, 0.38), 3)
    add(b, box(0.22, 0.42, 1.65, 0.22, 0.22, 0.38), 3)
    b.write(path)



def sphere(cx, cy, cz, rx, ry, rz, segments=14, rings=7):
    positions, normals, indices = [], [], []
    for r in range(rings + 1):
        v = r / rings
        theta = v * math.pi
        st, ct = math.sin(theta), math.cos(theta)
        for i in range(segments):
            u = i / segments
            phi = u * math.tau
            cp, sp = math.cos(phi), math.sin(phi)
            x = cx + cp * st * rx
            y = cy + ct * ry
            z = cz + sp * st * rz
            positions.append((x, y, z))
            normals.append((cp * st, ct, sp * st))
    for r in range(rings):
        for i in range(segments):
            a = r * segments + i
            b = r * segments + (i + 1) % segments
            c = (r + 1) * segments + i
            d = (r + 1) * segments + (i + 1) % segments
            indices.extend([a, c, b, b, c, d])
    return positions, normals, indices


def plane_rect(cx, cy, cz, sx, sz):
    x0, x1 = cx - sx / 2, cx + sx / 2
    z0, z1 = cz - sz / 2, cz + sz / 2
    return flat_triangles([
        [(x0, cy, z0), (x1, cy, z0), (x1, cy, z1)],
        [(x0, cy, z0), (x1, cy, z1), (x0, cy, z1)],
    ], (0, 1, 0))


def build_air_arena_tile(path: Path):
    """Low-poly 3D terrain tile for the aircraft arena.

    This replaces the old static painted photo layer during gameplay.  It is a
    real GLB scene containing terrain/water/structures that Godot scrolls under
    the aircraft camera.
    """
    mats = [
        ("storm_water", (0.02, 0.11, 0.16, 1)),
        ("wet_land", (0.10, 0.22, 0.13, 1)),
        ("mud", (0.18, 0.13, 0.08, 1)),
        ("runway", (0.08, 0.09, 0.10, 1)),
        ("marking", (0.95, 0.80, 0.22, 1)),
        ("metal", (0.28, 0.33, 0.34, 1)),
        ("hazard_red", (0.70, 0.08, 0.06, 1)),
        ("tree_dark", (0.03, 0.18, 0.09, 1)),
    ]
    b = GlbBuilder(mats)
    add(b, box(0, -0.08, 0, 34.0, 0.12, 44.0), 0)
    add(b, plane_rect(-8.5, 0.02, -3.5, 12.0, 31.0), 1)
    add(b, plane_rect(8.8, 0.025, 5.0, 10.5, 27.0), 1)
    add(b, plane_rect(0.0, 0.035, 0.0, 5.2, 42.0), 3)
    for z in range(-18, 21, 6):
        add(b, box(0.0, 0.08, float(z), 0.22, 0.04, 2.2), 4)
    # Embankments / cliffs.
    for x in (-14.0, -3.2, 3.2, 14.0):
        add(b, box(x, 0.18, -7.0, 1.0, 0.32, 22.0), 2)
    # Hangars, towers, SAM pads as visible 3D battlefield objects below.
    for x, z, sx, sz in [(-9.5, -12, 2.4, 3.4), (-11.2, 8, 2.1, 2.6), (9.8, -2, 2.8, 2.8), (11.5, 14, 1.8, 3.2)]:
        add(b, box(x, 0.55, z, sx, 1.0, sz), 5)
        add(b, box(x, 1.18, z, sx * 0.82, 0.28, sz * 0.82), 6)
    for x, z in [(-6.3, -17.0), (6.8, -16.0), (-6.8, 17.0), (6.4, 17.8), (13.0, -10.0), (-13.0, 13.0)]:
        add(b, cylinder_x(x, 0.28, z, 0.65, 0.55, 16), 2)
        add(b, box(x, 0.82, z, 0.40, 0.65, 0.40), 5)
    # Tree/rock clumps for depth cues.
    for i, (x, z) in enumerate([(-13,-18),(-12,-6),(-13,3),(-10,18),(13,-18),(12,-6),(14,4),(10,19),(-5,13),(5,-10)]):
        add(b, box(float(x), 0.35, float(z), 0.9, 0.55 + (i % 3) * 0.15, 0.9), 7)
    b.write(path)


def build_air_cloud_cluster(path: Path):
    mats = [
        ("cloud_core", (0.78, 0.84, 0.90, 1)),
        ("cloud_shadow", (0.42, 0.50, 0.60, 1)),
        ("storm_glow", (0.65, 0.90, 1.0, 1)),
    ]
    b = GlbBuilder(mats)
    add(b, sphere(0.0, 0.0, 0.0, 2.8, 0.55, 1.25), 0)
    add(b, sphere(-1.9, 0.05, 0.1, 1.6, 0.42, 0.95), 0)
    add(b, sphere(1.75, 0.02, -0.2, 1.7, 0.44, 1.0), 0)
    add(b, sphere(0.4, -0.18, 0.35, 2.2, 0.35, 0.92), 1)
    add(b, box(0.0, -0.26, 0.0, 3.4, 0.045, 0.12), 2)
    b.write(path)

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build_car(OUT / "player_car.glb", body=(0.08, 0.27, 0.85, 1), accent=(0.0, 0.8, 1.0, 1), hostile=False)
    build_car(OUT / "enemy_car.glb", body=(0.75, 0.08, 0.08, 1), accent=(1.0, 0.25, 0.05, 1), hostile=True)
    build_car(OUT / "convoy_car.glb", body=(0.1, 0.45, 0.18, 1), accent=(0.55, 1.0, 0.55, 1), hostile=False)
    build_jet(OUT / "support_jet.glb", body=(0.08, 0.12, 0.22, 1), glow=(0.0, 0.95, 1.0, 1))
    build_air_arena_tile(OUT / "air_arena_tile.glb")
    build_air_cloud_cluster(OUT / "air_cloud_cluster.glb")
    print(f"Generated GLB assets in {OUT}")


if __name__ == "__main__":
    main()
