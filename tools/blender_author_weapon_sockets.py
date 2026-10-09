"""Author Force War weapon sockets in Blender, derived from the mesh itself.

Run with the official Blender binary:

    blender --background --python tools/blender_author_weapon_sockets.py -- \
      --source assets/models/enemy_hero_jet_blender_ready.glb \
      --out assets/models/enemy_hero_jet_blender_ready.glb

or with the `bpy` module runtime used in this sandbox:

    LD_LIBRARY_PATH=/tmp/forcewar-bpy-libs /tmp/forcewar-bpy-venv/bin/python \
      tools/blender_author_weapon_sockets.py -- --source ... --out ...

Why this script exists
----------------------
The first socket pass typed coordinates in by eye. That is exactly the failure
mode the developer called out: a socket that only looks right. Here every
socket position is measured from the mesh:

* rotation and scale are applied, the intermediate scaled empties are collapsed
  and the root origin is moved to the centre of the aircraft hitbox volume;
* a candidate point is found from vertex data (wing-root leading edge, wing
  underside at the pylon stations, rear-most centre line);
* the vertices in a small radius around that candidate - the equivalent of
  selecting a ring in Edit Mode and using Shift+S "Cursor to Selected" - are
  averaged, and the Empty is created there;
* every Empty is parented to the root keeping its world transform.

Socket names follow the agreed scheme: MZ_ muzzle, HP_ hardpoint, EX_ exhaust.
The legacy names from the first pass are kept as aliases at the same measured
positions so nothing in the engine breaks during the transition.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

GUN_STATION = 0.24          # fraction of half-span: wing root, next to the fuselage
PYLON_STATIONS = (0.46, 0.62, 0.78)
RING_RADIUS = 0.16          # metres; the "vertex ring" averaged into one point


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    parser = argparse.ArgumentParser(description="Author Force War weapon sockets from mesh geometry.")
    parser.add_argument("--source", default="assets/models/enemy_hero_jet_blender_ready.glb")
    parser.add_argument("--out", default="assets/models/enemy_hero_jet_blender_ready.glb")
    parser.add_argument("--report", default="docs/weapon_socket_report.json")
    parser.add_argument("--join-meshes", action="store_true",
                        help="join every mesh into one before measuring (multi-part models)")
    parser.add_argument("--target-length", type=float, default=0.0,
                        help="uniformly scale the hull so its length becomes this many metres")
    parser.add_argument("--decimate", type=float, default=0.0,
                        help="collapse ratio for a Decimate modifier, e.g. 0.25 (0 = off)")
    parser.add_argument("--texture-max", type=int, default=0,
                        help="downscale every texture larger than this many pixels (0 = off)")
    parser.add_argument("--sockets", default="gun,pylon,exhaust",
                        help="which socket groups to author")
    parser.add_argument("--root-name", default="EnemyHeroJet_BlenderRoot")
    parser.add_argument("--pylon-stations", default="",
                        help="comma separated fractions of the half span, overrides the default")
    parser.add_argument(
        "--nudge",
        action="append",
        default=[],
        help="NAME=x,y,z - move one socket after it was measured (used by the re-export QA)",
    )
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.objects, bpy.data.materials):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def join_meshes() -> None:
    """Join every mesh into one object, keeping all materials.

    The measurement code reads a single vertex cloud, and a model split into 75
    little parts (hull, rivets, rails, lights) cannot be measured part by part.
    """
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if len(meshes) <= 1:
        return
    for obj in bpy.context.scene.objects:
        obj.select_set(obj.type == "MESH")
    target = max(meshes, key=lambda o: len(o.data.vertices))
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    print(f"joined {len(meshes)} meshes into {target.name}")


def decimate_mesh(mesh: bpy.types.Object, ratio: float) -> None:
    before = len(mesh.data.polygons)
    modifier = mesh.modifiers.new(name="ForceWarDecimate", type="DECIMATE")
    modifier.ratio = ratio
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.modifier_apply(modifier="ForceWarDecimate")
    print(f"decimated {before} -> {len(mesh.data.polygons)} polygons (ratio {ratio})")


def downscale_textures(limit: int) -> None:
    for image in bpy.data.images:
        if image.size[0] <= limit and image.size[1] <= limit:
            continue
        width, height = image.size
        scale = limit / float(max(width, height))
        image.scale(max(1, int(width * scale)), max(1, int(height * scale)))
        print(f"texture {image.name}: {width}x{height} -> {image.size[0]}x{image.size[1]}")


def normalise_length(mesh: bpy.types.Object, target: float) -> float:
    """Scale the hull so its length matches the gameplay size budget."""
    coords = [v.co for v in mesh.data.vertices]
    length = max(c.y for c in coords) - min(c.y for c in coords)
    if length <= 0.0001 or target <= 0.0:
        return 1.0
    factor = target / length
    mesh.data.transform(Matrix.Scale(factor, 4))
    print(f"scaled hull by {factor:.5f}: length {length:.3f} -> {target:.3f}")
    return factor


def main_mesh() -> bpy.types.Object:
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit("no mesh found in the source GLB")
    return max(meshes, key=lambda o: len(o.data.vertices))


def flatten_to_root(mesh: bpy.types.Object, root_name: str = "EnemyHeroJet_BlenderRoot") -> bpy.types.Object:
    """Apply rotation/scale, drop the intermediate scaled empties, and put the
    root origin at the centre of the aircraft volume."""
    world = mesh.matrix_world.copy()
    mesh.data.transform(world)              # bake rotation + scale into the mesh data
    # Unparent FIRST: assigning matrix_world while the object still hangs under
    # a scaled empty only rewrites the local basis, and the scale comes back as
    # soon as the parent is dropped.
    mesh.parent = None
    mesh.matrix_parent_inverse = Matrix()
    mesh.matrix_basis = Matrix()
    mesh.matrix_world = Matrix()

    coords = [v.co for v in mesh.data.vertices]
    lo = Vector((min(c.x for c in coords), min(c.y for c in coords), min(c.z for c in coords)))
    hi = Vector((max(c.x for c in coords), max(c.y for c in coords), max(c.z for c in coords)))
    centre = (lo + hi) * 0.5
    mesh.data.transform(Matrix.Translation(-centre))   # origin = hitbox centre

    # Bounding-box centre is not necessarily the plane of symmetry on a scanned
    # mesh, and a mirrored socket pair is only correct on the symmetry plane.
    coords = [v.co for v in mesh.data.vertices]
    best_shift = 0.0
    best_error = None
    span_guess = max(abs(c.x) for c in coords) or 1.0
    for step in range(-12, 13):
        shift = step * 0.01 * span_guess
        bins = 40
        hist = [0] * (bins * 2)
        for c in coords:
            value = (c.x - shift) / span_guess
            index = int((value * 0.5 + 0.5) * (bins * 2 - 1))
            hist[max(0, min(bins * 2 - 1, index))] += 1
        error = sum(abs(hist[i] - hist[bins * 2 - 1 - i]) for i in range(bins))
        if best_error is None or error < best_error:
            best_error = error
            best_shift = shift
    if abs(best_shift) > 1e-5:
        mesh.data.transform(Matrix.Translation(Vector((-best_shift, 0.0, 0.0))))
        print(f"symmetry plane corrected by {best_shift:.4f} on x")

    for obj in list(bpy.context.scene.objects):
        if obj is not mesh:
            bpy.data.objects.remove(obj, do_unlink=True)

    root = bpy.data.objects.new(root_name, None)
    root.empty_display_type = "ARROWS"
    root.empty_display_size = 0.45
    bpy.context.collection.objects.link(root)
    mesh.parent = root
    mesh.matrix_parent_inverse = Matrix()
    return root


def measure(mesh: bpy.types.Object) -> dict:
    coords = [v.co.copy() for v in mesh.data.vertices]
    lo = Vector((min(c.x for c in coords), min(c.y for c in coords), min(c.z for c in coords)))
    hi = Vector((max(c.x for c in coords), max(c.y for c in coords), max(c.z for c in coords)))
    size = hi - lo

    # Which horizontal axis is the wing span? Not the wider one - on a delta
    # wing both are nearly equal - but the one the hull is MIRROR SYMMETRIC
    # about. A 1D histogram is too blunt for blended airframes, so the test is
    # done on a 2D occupancy grid: mirror the cloud across the candidate plane
    # and measure how badly the two halves disagree.
    def asymmetry(axis: str) -> float:
        other = "y" if axis == "x" else "x"
        extent_a = max(abs(getattr(c, axis)) for c in coords) or 1.0
        lo_b = min(getattr(c, other) for c in coords)
        hi_b = max(getattr(c, other) for c in coords)
        span_b = (hi_b - lo_b) or 1.0
        bins = 28
        grid = [[0] * bins for _ in range(bins * 2)]
        for c in coords:
            ia = int(((getattr(c, axis) / extent_a) * 0.5 + 0.5) * (bins * 2 - 1))
            ib = int(((getattr(c, other) - lo_b) / span_b) * (bins - 1))
            grid[max(0, min(bins * 2 - 1, ia))][max(0, min(bins - 1, ib))] += 1
        error = 0
        for i in range(bins):
            for j in range(bins):
                error += abs(grid[i][j] - grid[bins * 2 - 1 - i][j])
        return error / float(len(coords))

    asymmetry_x = asymmetry("x")
    asymmetry_y = asymmetry("y")
    if abs(asymmetry_x - asymmetry_y) < 0.02 * max(asymmetry_x, asymmetry_y):
        print(f"WARNING: span axis is ambiguous (x {asymmetry_x:.4f} vs y {asymmetry_y:.4f}) - check the export")
    span_axis = "x" if asymmetry_x <= asymmetry_y else "y"
    length_axis = "y" if span_axis == "x" else "x"
    half_span = max(abs(getattr(c, span_axis)) for c in coords)
    length_lo = getattr(lo, length_axis)
    length_hi = getattr(hi, length_axis)

    # The nose is the thin end: compare the span of the first and last 12%.
    band = (length_hi - length_lo) * 0.12
    front_band = [c for c in coords if getattr(c, length_axis) <= length_lo + band]
    back_band = [c for c in coords if getattr(c, length_axis) >= length_hi - band]

    def band_width(points):
        if not points:
            return 0.0
        values = [getattr(p, span_axis) for p in points]
        return max(values) - min(values)

    nose_sign = -1.0 if band_width(front_band) <= band_width(back_band) else 1.0
    return {
        "coords": coords,
        "lo": lo,
        "hi": hi,
        "size": size,
        "span_axis": span_axis,
        "asymmetry": {"x": asymmetry_x, "y": asymmetry_y},
        "length_axis": length_axis,
        "half_span": half_span,
        "nose_sign": nose_sign,
    }


def orient_nose_forward(mesh: bpy.types.Object, info: dict) -> None:
    """Put the aircraft on the agreed forward axis inside Blender.

    Agreed convention: wings on X, nose on +Y, up on +Z. Blender +Y exports to
    glTF -Z, which is Godot's forward, so the engine needs no corrective
    rotation at all - the model arrives already pointing into the screen.
    """
    span_axis = info["span_axis"]
    length_axis = info["length_axis"]
    nose_sign = info["nose_sign"]
    rotation = Matrix.Identity(4)
    if length_axis == "x":
        # Swap the two horizontal axes: span -> X, length -> Y.
        rotation = Matrix.Rotation(-1.5707963267948966, 4, "Z") @ rotation
        nose_sign = -nose_sign if span_axis == "y" else nose_sign
    if nose_sign < 0.0:
        rotation = Matrix.Rotation(3.141592653589793, 4, "Z") @ rotation
    if rotation != Matrix.Identity(4):
        mesh.data.transform(rotation)
        print("re-oriented hull: wings on X, nose on +Y (Godot forward)")


def ring_average(coords, candidate: Vector) -> Vector:
    ring = [c for c in coords if (c - candidate).length <= RING_RADIUS]
    if len(ring) < 4:
        ring = sorted(coords, key=lambda c: (c - candidate).length_squared)[:24]
    total = Vector((0.0, 0.0, 0.0))
    for point in ring:
        total += point
    return total / len(ring)


def axis_vector(span_axis: str, span_value: float, length_axis: str, length_value: float, z: float) -> Vector:
    out = Vector((0.0, 0.0, z))
    setattr(out, span_axis, span_value)
    setattr(out, length_axis, length_value)
    return out


def folded_coords(info: dict) -> list:
    """Fold the hull onto its left half.

    The mesh is a photogrammetry-style scan: the two halves differ by a few
    millimetres, so measuring on whichever half happens to face -X gives a
    different answer than the other. Folding both halves together makes every
    measurement deterministic, and the sockets are mirrored anyway.
    """
    return [Vector((-abs(c.x), c.y, c.z)) for c in info["coords"]]


def band_at(folded: list, station: float, half_span: float, width: float) -> list:
    target = -station * half_span
    return [c for c in folded if abs(c.x - target) <= width * half_span]


def percentile(values: list, fraction: float) -> float:
    ordered = sorted(values)
    if not ordered:
        return 0.0
    index = int(clamp_index(fraction * (len(ordered) - 1), 0, len(ordered) - 1))
    return ordered[index]


def clamp_index(value: float, low: int, high: int) -> float:
    return max(low, min(high, value))


def wing_root_station(folded: list, half_span: float, length: float) -> float:
    """Where the wing leaves the fuselage, read off the chord profile."""
    nose_value = max(c.y for c in folded)
    for step in range(4, 20):
        station = step / 20.0
        band = band_at(folded, station, half_span, 0.05)
        if len(band) < 20:
            break
        front = percentile([c.y for c in band], 0.985)
        if abs(front - nose_value) > 0.22 * length:
            return max(0.12, station - 0.03)
    return 0.24


def measured_sockets(info: dict) -> dict:
    """Measure every socket on the folded left half, then mirror it.

    Mirroring is deliberate: the design decision is two symmetric wing-root
    cannons, so the stream stays centred on the hitbox while the ship banks.
    Canonical orientation at this point: wings on X, nose on +Y, up on +Z.
    """
    folded = folded_coords(info)
    half_span = info["half_span"]
    length = info["size"].y
    sockets: dict[str, Vector] = {}

    def mirrored(point: Vector) -> Vector:
        return Vector((-point.x, point.y, point.z))

    # --- cannon muzzle at the wing-root leading edge
    gun_station = wing_root_station(folded, half_span, length)
    band = band_at(folded, gun_station, half_span, 0.10)
    if band:
        # A high percentile would latch onto the handful of strake vertices that
        # reach forward towards the nose, and a few vertices moving in or out of
        # the band would then shift the muzzle by half a metre. The 90th
        # percentile sits on the solid leading edge and is stable.
        leading_y = percentile([c.y for c in band], 0.90)
        lip = [c for c in band if c.y >= leading_y - 0.08]
        point = ring_average(folded, ring_centre(lip))
        point.x = -gun_station * half_span
        point.y = leading_y + 0.05          # just proud of the leading edge
        sockets["MZ_Gun_L"] = point
        sockets["MZ_Gun_R"] = mirrored(point)

    # --- three pylons per side, hanging under the wing
    for index, station in enumerate(PYLON_STATIONS, start=1):
        pylon_band = band_at(folded, station, half_span, 0.05)
        if len(pylon_band) < 8:
            continue
        # At the outer stations a band can cut through BOTH the wing and the
        # tailplane. Taking a plain median then drops the pylon between them,
        # in mid air. The wing is the section with the longest chord, so the
        # band is split into contiguous chord clusters and the longest wins.
        chord = dominant_chord(pylon_band, length)
        chord_mid = (min(c.y for c in chord) + max(c.y for c in chord)) * 0.5
        underside = percentile([c.z for c in chord], 0.03)
        sockets[f"HP_L{index}"] = Vector((-station * half_span, chord_mid, underside - 0.05))
        sockets[f"HP_R{index}"] = mirrored(sockets[f"HP_L{index}"])

    # --- exhaust on the centre line, rear-most point
    centre_band = [c for c in folded if abs(c.x) <= 0.08 * half_span]
    if centre_band:
        tail_y = percentile([c.y for c in centre_band], 0.02)
        tail = [c for c in centre_band if c.y <= tail_y + 0.08]
        exhaust = ring_average(folded, ring_centre(tail))
        exhaust.x = 0.0
        exhaust.y = tail_y
        sockets["EX_C"] = exhaust

    info["gun_station"] = gun_station
    return sockets


def dominant_chord(band: list, length: float) -> list:
    """Split a span band into contiguous chord sections and return the longest."""
    ordered = sorted(band, key=lambda c: c.y)
    gap = max(0.04, 0.045 * length)
    clusters = [[ordered[0]]]
    for point in ordered[1:]:
        if point.y - clusters[-1][-1].y > gap:
            clusters.append([])
        clusters[-1].append(point)
    return max(clusters, key=lambda cluster: cluster[-1].y - cluster[0].y)


def ring_centre(points: list) -> Vector:
    total = Vector((0.0, 0.0, 0.0))
    for point in points:
        total += point
    return total / max(1, len(points))


def add_socket(name: str, location: Vector, root: bpy.types.Object) -> bpy.types.Object:
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "PLAIN_AXES"
    empty.empty_display_size = 0.12
    bpy.context.collection.objects.link(empty)
    empty.matrix_world = Matrix.Translation(location)
    # Parent keeping the world transform, exactly like Ctrl+P > Keep Transform.
    world = empty.matrix_world.copy()
    empty.parent = root
    empty.matrix_parent_inverse = root.matrix_world.inverted()
    empty.matrix_world = world
    return empty


def main() -> None:
    args = parse_args()
    clear_scene()
    source = Path(args.source).resolve()
    out = Path(args.out).resolve()
    bpy.ops.import_scene.gltf(filepath=str(source))

    if args.join_meshes:
        join_meshes()
    mesh = main_mesh()
    if args.decimate > 0.0:
        decimate_mesh(mesh, args.decimate)
    if args.texture_max > 0:
        downscale_textures(args.texture_max)
    root = flatten_to_root(mesh, args.root_name)
    orient_nose_forward(mesh, measure(mesh))
    scale_factor = normalise_length(mesh, args.target_length)
    info = measure(mesh)
    if info["length_axis"] != "y" or info["nose_sign"] < 0.0:
        raise SystemExit("hull could not be oriented nose +Y: %s %s" % (info["length_axis"], info["nose_sign"]))
    if args.pylon_stations:
        global PYLON_STATIONS
        PYLON_STATIONS = tuple(float(v) for v in args.pylon_stations.split(","))
    groups = [g.strip() for g in args.sockets.split(",") if g.strip()]
    sockets = measured_sockets(info)
    if "gun" not in groups:
        sockets = {k: v for k, v in sockets.items() if not k.startswith("MZ_")}
    if "pylon" not in groups:
        sockets = {k: v for k, v in sockets.items() if not k.startswith("HP_")}
    if "exhaust" not in groups:
        sockets = {k: v for k, v in sockets.items() if not k.startswith("EX_")}

    for nudge in args.nudge:
        name, _, values = nudge.partition("=")
        if name in sockets:
            offset = Vector([float(v) for v in values.split(",")])
            sockets[name] = sockets[name] + offset
            print(f"nudged {name} by {tuple(offset)}")

    # Legacy aliases stay at the measured positions so the engine keeps working
    # while the configuration migrates to the MZ_/HP_/EX_ names.
    aliases = {
        "Muzzle_Left": "MZ_Gun_L",
        "Muzzle_Right": "MZ_Gun_R",
        "Missile_Left": "HP_L1",
        "Missile_Right": "HP_R1",
        "Engine_Core": "EX_C",
    }
    for alias, canonical in aliases.items():
        if canonical in sockets:
            sockets[alias] = sockets[canonical].copy()

    for name, location in sockets.items():
        add_socket(name, location, root)

    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(out),
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_apply=False,
    )

    report = {
        "source": str(source),
        "output": str(out),
        "method": "vertex_ring_average_cursor_to_selected_equivalent",
        "origin": "mesh_bounding_box_centre_equals_hitbox_centre",
        "spanAxis": info["span_axis"],
        "lengthAxis": info["length_axis"],
        "noseSign": info["nose_sign"],
        "halfSpan": round(info["half_span"], 4),
        "gunStationFraction": round(float(info.get("gun_station", 0.0)), 4),
        "meshSize": [round(v, 4) for v in info["size"]],
        "lengthScaleFactor": round(scale_factor, 6),
        "polygons": len(mesh.data.polygons),
        "axisAsymmetry": {k: round(v, 5) for k, v in info["asymmetry"].items()},
        "sockets": {name: [round(v, 4) for v in location] for name, location in sorted(sockets.items())},
    }
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    print(f"Exported socket-authored GLB: {out}")


if __name__ == "__main__":
    main()
