"""Create reusable Blender-authored arena deck modules for Force War.

The forward arena should not be filled with anonymous runtime boxes. This tool creates a
small GLB battlefield/deck cluster with turrets, antennae, service structures, and emissive
markers that Godot can instance below the flight path.

Run with the same Blender/bpy runtime used for the boss/enemy pipeline:

    LD_LIBRARY_PATH=/tmp/forcewar-bpy-libs:$LD_LIBRARY_PATH \
      /tmp/forcewar-bpy-venv/bin/python tools/blender_create_arena_deck_cluster.py \
      --out assets/models/arena_battle_deck_cluster.glb
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="assets/models/arena_battle_deck_cluster.glb")
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def mat(
    name: str,
    color: tuple[float, float, float, float],
    emission: tuple[float, float, float, float] | None = None,
    strength: float = 0.0,
    metallic: float = 0.0,
    roughness: float = 0.48,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if emission is not None:
            bsdf.inputs["Emission Color"].default_value = emission
            bsdf.inputs["Emission Strength"].default_value = strength
    return material


def cube(name: str, loc, scale, material: bpy.types.Material, parent=None, rot=(0.0, 0.0, 0.0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    return obj


def cyl(name: str, loc, radius: float, depth: float, material: bpy.types.Material, parent=None, rot=(0.0, 0.0, 0.0), vertices: int = 24) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    return obj


def sphere(name: str, loc, radius: float, material: bpy.types.Material, parent=None) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=radius, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    return obj


def cone(name: str, loc, r1: float, r2: float, depth: float, material: bpy.types.Material, parent=None, rot=(0.0, 0.0, 0.0), vertices: int = 24) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    return obj


def add_socket(name: str, loc, parent) -> bpy.types.Object:
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "CUBE"
    empty.empty_display_size = 0.18
    empty.location = loc
    empty.parent = parent
    bpy.context.collection.objects.link(empty)
    return empty


def key_scale(obj: bpy.types.Object, frame: int, value: float) -> None:
    bpy.context.scene.frame_set(frame)
    obj.scale = (value, value, value)
    obj.keyframe_insert(data_path="scale", frame=frame)


def animate(beacons: list[bpy.types.Object]) -> None:
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 96
    for index, beacon in enumerate(beacons):
        phase = index * 8
        for frame, value in [(1 + phase, 1.0), (24 + phase, 1.45), (48 + phase, 0.9), (72 + phase, 1.25), (96, 1.0)]:
            key_scale(beacon, min(frame, 96), value)
        if beacon.animation_data and beacon.animation_data.action:
            beacon.animation_data.action.name = f"ArenaDeckBeaconPulse_{index:02d}"
            for curve in beacon.animation_data.action.fcurves:
                for point in curve.keyframe_points:
                    point.interpolation = "LINEAR"


def main() -> None:
    args = parse_args()
    out = Path(args.out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    clear_scene()

    deck = mat("Arena_Deck_Dark_Steel", (0.045, 0.075, 0.105, 1.0), metallic=0.50, roughness=0.42)
    armor = mat("Arena_Module_Gunmetal", (0.13, 0.16, 0.19, 1.0), metallic=0.58, roughness=0.38)
    cyan = mat("Arena_Cyan_Service_Lights", (0.08, 0.75, 0.95, 1.0), emission=(0.05, 0.95, 1.0, 1.0), strength=2.6)
    amber = mat("Arena_Amber_Warning_Lights", (1.0, 0.45, 0.08, 1.0), emission=(1.0, 0.24, 0.02, 1.0), strength=2.2)
    red = mat("Arena_Red_AA_Muzzles", (0.95, 0.06, 0.02, 1.0), emission=(1.0, 0.04, 0.01, 1.0), strength=2.0)

    root = bpy.data.objects.new("ArenaBattleDeckCluster_Root", None)
    root.empty_display_type = "ARROWS"
    root.empty_display_size = 0.8
    bpy.context.collection.objects.link(root)

    # Thin base deck with angled armor so it reads as a model, not a random box.
    cube("DeckClusterBase", (0.0, 0.0, 0.05), (5.2, 4.0, 0.10), deck, root)
    cube("LeftSlopedArmor", (-2.45, 0.0, 0.23), (0.20, 3.5, 0.36), armor, root, rot=(0.0, math.radians(0.0), math.radians(10.0)))
    cube("RightSlopedArmor", (2.45, 0.0, 0.23), (0.20, 3.5, 0.36), armor, root, rot=(0.0, math.radians(0.0), math.radians(-10.0)))
    cube("RearServiceRail", (0.0, 1.82, 0.28), (4.4, 0.16, 0.35), armor, root)
    cube("ForwardServiceRail", (0.0, -1.82, 0.28), (4.4, 0.16, 0.35), armor, root)

    # Recognizable battlefield modules: two AA turrets, a radar mast, and equipment pods.
    for i, x in enumerate([-1.62, 1.62]):
        cyl(f"AATurretBase_{i:02d}", (x, -1.05, 0.35), 0.34, 0.24, armor, root, vertices=28)
        cyl(f"AATurretBarrel_{i:02d}", (x, -1.36, 0.52), 0.055, 0.84, red, root, rot=(math.radians(90), 0.0, 0.0), vertices=16)
        sphere(f"AAMuzzleGlow_{i:02d}", (x, -1.80, 0.52), 0.105, red, root)
        add_socket(f"Deck_AA_Muzzle_{i:02d}", (x, -1.82, 0.52), root)

    cube("ServiceTowerLower", (-0.45, 0.66, 0.64), (0.74, 0.64, 1.08), armor, root)
    cube("ServiceTowerUpper", (-0.45, 0.66, 1.34), (0.52, 0.46, 0.46), armor, root)
    cyl("RadarMast", (0.34, 0.82, 1.18), 0.045, 1.42, cyan, root, vertices=12)
    cone("RadarDish", (0.34, 0.82, 1.96), 0.42, 0.10, 0.18, cyan, root, rot=(math.radians(90), 0.0, 0.0), vertices=32)

    for i, (x, y) in enumerate([(-1.75, 0.85), (-1.05, 1.22), (1.0, 0.74), (1.82, 1.30)]):
        cube(f"EquipmentPod_{i:02d}", (x, y, 0.34), (0.56, 0.38, 0.42), armor, root)
        cube(f"PodCyanMarker_{i:02d}", (x, y - 0.205, 0.58), (0.22, 0.035, 0.065), cyan, root)

    beacons = [
        sphere("DeckBeaconCyan_A", (-2.18, -1.58, 0.42), 0.09, cyan, root),
        sphere("DeckBeaconCyan_B", (2.18, -1.58, 0.42), 0.09, cyan, root),
        sphere("DeckBeaconAmber_A", (-2.18, 1.58, 0.42), 0.09, amber, root),
        sphere("DeckBeaconAmber_B", (2.18, 1.58, 0.42), 0.09, amber, root),
    ]
    add_socket("Deck_Smoke_Anchor", (0.0, 1.92, 0.62), root)
    animate(beacons)

    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=str(out),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_frame_range=True,
        export_apply=True,
    )
    print(f"Exported Blender arena deck cluster: {out}")


if __name__ == "__main__":
    main()
