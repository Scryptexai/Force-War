"""Create the Force War dreadnought boss as an actual Blender-authored GLB asset.

This replaces unclear runtime primitive overlays with a reusable 3D asset.
Run through the same Blender/bpy runtime used by the enemy animation pipeline:

    FORCE_WAR_BPY_PYTHON=/tmp/forcewar-bpy-venv/bin/python \
    LD_LIBRARY_PATH=/tmp/forcewar-bpy-libs \
    python tools/blender_create_dreadnought_boss.py --out assets/models/boss_dreadnought_leviathan.glb
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
    parser.add_argument("--out", default="assets/models/boss_dreadnought_leviathan.glb")
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def mat(name: str, color: tuple[float, float, float, float], emission=None, strength: float = 0.0, metallic: float = 0.0, roughness: float = 0.45) -> bpy.types.Material:
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


def cube(name: str, loc, scale, material: bpy.types.Material, parent=None) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    return obj


def cyl(name: str, loc, radius: float, depth: float, material: bpy.types.Material, parent=None, rot=(0.0, 0.0, 0.0), vertices: int = 32) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    return obj


def sphere(name: str, loc, radius: float, material: bpy.types.Material, parent=None) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=radius, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    return obj


def add_socket(name: str, loc, parent) -> bpy.types.Object:
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "SPHERE"
    empty.empty_display_size = 0.25
    empty.location = loc
    empty.parent = parent
    bpy.context.collection.objects.link(empty)
    return empty


def key(obj: bpy.types.Object, frame: int, loc=None, rot=None) -> None:
    bpy.context.scene.frame_set(frame)
    if loc is not None:
        obj.location = loc
        obj.keyframe_insert(data_path="location", frame=frame)
    if rot is not None:
        obj.rotation_euler = rot
        obj.keyframe_insert(data_path="rotation_euler", frame=frame)


def animate(root: bpy.types.Object, core: bpy.types.Object) -> None:
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 120
    for frame, z, roll in [(1, 0.0, -1.0), (40, 0.24, 0.8), (80, -0.12, 1.2), (120, 0.0, -1.0)]:
        key(root, frame, loc=(0.0, 0.0, z), rot=(0.0, 0.0, math.radians(roll)))
    if root.animation_data and root.animation_data.action:
        root.animation_data.action.name = "BossDreadnought_IdleHover"
        for curve in root.animation_data.action.fcurves:
            for point in curve.keyframe_points:
                point.interpolation = "LINEAR"

    for frame, scale in [(1, 1.0), (30, 1.28), (60, 0.92), (90, 1.20), (120, 1.0)]:
        bpy.context.scene.frame_set(frame)
        core.scale = (scale, scale, scale)
        core.keyframe_insert(data_path="scale", frame=frame)
    if core.animation_data and core.animation_data.action:
        core.animation_data.action.name = "BossCore_ChargePulse"
        for curve in core.animation_data.action.fcurves:
            for point in curve.keyframe_points:
                point.interpolation = "LINEAR"


def main() -> None:
    args = parse_args()
    out = Path(args.out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    clear_scene()

    hull = mat("Leviathan_Dark_Naval_Hull", (0.045, 0.060, 0.080, 1.0), metallic=0.62)
    armor = mat("Leviathan_Gunmetal_Armor", (0.16, 0.18, 0.22, 1.0), metallic=0.72)
    edge = mat("Leviathan_Cyan_Edge_Lights", (0.06, 0.65, 0.95, 1.0), emission=(0.04, 0.85, 1.0, 1.0), strength=2.4)
    hot = mat("Leviathan_Orange_Core", (1.0, 0.28, 0.04, 1.0), emission=(1.0, 0.16, 0.02, 1.0), strength=3.2)
    red = mat("Leviathan_Red_Turret_Ports", (0.85, 0.07, 0.025, 1.0), emission=(1.0, 0.05, 0.01, 1.0), strength=2.0)

    root = bpy.data.objects.new("BossDreadnought_Leviathan_Root", None)
    root.empty_display_type = "ARROWS"
    root.empty_display_size = 1.2
    bpy.context.collection.objects.link(root)

    cube("MainCarrierHull", (0, 0, 0), (24.0, 7.5, 1.8), hull, root)
    cube("ArmoredUpperDeck", (0, -0.35, 1.45), (17.0, 5.0, 1.2), armor, root)
    cube("ForwardBowPlate", (0, -4.2, 0.55), (11.2, 1.4, 1.05), armor, root)
    cube("LeftFlightSponson", (-12.8, -0.1, 0.1), (3.6, 6.4, 0.9), hull, root)
    cube("RightFlightSponson", (12.8, -0.1, 0.1), (3.6, 6.4, 0.9), hull, root)
    cube("LeftWingArmor", (-8.8, 1.9, 0.65), (7.2, 1.2, 0.8), armor, root)
    cube("RightWingArmor", (8.8, 1.9, 0.65), (7.2, 1.2, 0.8), armor, root)

    for i, x in enumerate([-6.8, -4.5, -2.2, 0.0, 2.2, 4.5, 6.8]):
        cube(f"CommandTower_{i:02d}", (x, 0.6 + (i % 2) * 0.3, 3.0 + (i % 3) * 0.36), (0.85, 0.85, 3.0 + (i % 3) * 0.45), armor, root)
        cube(f"TowerBlueBeacon_{i:02d}", (x, 0.6 + (i % 2) * 0.3, 4.8 + (i % 3) * 0.55), (0.24, 0.24, 0.20), edge, root)

    for i, x in enumerate([-8.5, -6.8, -5.1, -3.4, -1.7, 0.0, 1.7, 3.4, 5.1, 6.8, 8.5]):
        cube(f"ForwardBlueWindow_{i:02d}", (x, -4.98, 0.55), (0.48, 0.10, 0.18), edge, root)
        if i % 2 == 0:
            cube(f"RedMuzzlePort_{i:02d}", (x + 0.42, -5.06, 1.04), (0.35, 0.12, 0.20), red, root)

    core = sphere("LeviathanCoreCannon", (0, -5.22, 0.82), 0.72, hot, root)
    cyl("CoreBarrel", (0, -5.92, 0.82), 0.20, 1.1, hot, root, rot=(math.radians(90), 0, 0), vertices=32)
    for i, x in enumerate([-7.2, -3.6, 3.6, 7.2]):
        cyl(f"DeckTurret_{i:02d}", (x, -3.6, 1.45), 0.28, 0.95, armor, root, rot=(math.radians(90), 0, 0), vertices=24)
        sphere(f"TurretGlow_{i:02d}", (x, -4.08, 1.45), 0.18, red, root)

    for name, loc in [
        ("Boss_Muzzle_Core", (0, -6.6, 0.82)),
        ("Boss_Muzzle_Left", (-4.2, -5.7, 1.28)),
        ("Boss_Muzzle_Right", (4.2, -5.7, 1.28)),
        ("Boss_WeakPoint_Core", (0, -5.25, 0.82)),
    ]:
        add_socket(name, loc, root)

    animate(root, core)

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
    print(f"Exported Blender dreadnought boss: {out}")


if __name__ == "__main__":
    main()
