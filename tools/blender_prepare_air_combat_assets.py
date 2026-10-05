"""Blender pipeline for Force War forward-air assets.

Run with a Blender executable:

    blender --background --python tools/blender_prepare_air_combat_assets.py -- \
      --enemy-source assets/models/enemy_hero_jet.glb \
      --enemy-out assets/models/enemy_hero_jet_blender_ready.glb

Or with the official Blender Python module (`bpy`) when the sandbox has no
`blender` binary:

    python tools/blender_prepare_air_combat_assets.py -- \
      --enemy-source assets/models/enemy_hero_jet.glb \
      --enemy-out assets/models/enemy_hero_jet_blender_ready.glb

Purpose:
- normalize uploaded aircraft GLB scale/origin for Godot;
- add named hardpoint/muzzle/socket empties;
- add reusable Blender-authored attack-pass, muzzle-flash, and engine-pulse
  animation keyframes;
- export a GLB that Godot imports and plays for enemy placeholder animation.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        # Running via plain Python/bpy: ignore the script name and parse direct args.
        argv = argv[1:]
    parser = argparse.ArgumentParser(description="Prepare Force War air-combat GLB assets in Blender.")
    parser.add_argument("--enemy-source", default="assets/models/enemy_hero_jet.glb")
    parser.add_argument("--enemy-out", default="assets/models/enemy_hero_jet_blender_ready.glb")
    parser.add_argument("--target-width", type=float, default=3.2)
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def scene_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    mins = Vector((math.inf, math.inf, math.inf))
    maxs = Vector((-math.inf, -math.inf, -math.inf))
    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            mins.x = min(mins.x, world.x)
            mins.y = min(mins.y, world.y)
            mins.z = min(mins.z, world.z)
            maxs.x = max(maxs.x, world.x)
            maxs.y = max(maxs.y, world.y)
            maxs.z = max(maxs.z, world.z)
    return mins, maxs


def normalize_geometry(geometry_root: bpy.types.Object, target_width: float) -> None:
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    mins, maxs = scene_bounds(meshes)
    size = maxs - mins
    width = max(size.x, size.z, 0.001)
    scale = target_width / width
    geometry_root.scale = (scale, scale, scale)
    geometry_root.location = (-(mins.x + maxs.x) * 0.5 * scale, -mins.y * scale, -(mins.z + maxs.z) * 0.5 * scale)
    bpy.context.view_layer.update()


def add_socket(name: str, loc: tuple[float, float, float], parent: bpy.types.Object) -> bpy.types.Object:
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "SPHERE"
    empty.empty_display_size = 0.08
    empty.location = loc
    empty.parent = parent
    bpy.context.collection.objects.link(empty)
    return empty


def make_emissive_material(name: str, color: tuple[float, float, float, float], strength: float) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def add_emissive_marker(name: str, loc: tuple[float, float, float], parent: bpy.types.Object, color: tuple[float, float, float, float], size: float = 0.09) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name + "Mesh")
    s = size
    verts = [(-s, -s, -s), (s, -s, -s), (s, s, -s), (-s, s, -s),
             (-s, -s, s), (s, -s, s), (s, s, s), (-s, s, s)]
    faces = [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    obj.parent = parent
    obj.data.materials.append(make_emissive_material(name + "Material", color, 3.2))
    bpy.context.collection.objects.link(obj)
    return obj


def set_linear_interpolation(obj: bpy.types.Object) -> None:
    if not obj.animation_data or not obj.animation_data.action:
        return
    for curve in obj.animation_data.action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "LINEAR"


def keyframe_transform(obj: bpy.types.Object, frame: int, loc=None, rot=None, scale=None) -> None:
    bpy.context.scene.frame_set(frame)
    if loc is not None:
        obj.location = loc
        obj.keyframe_insert(data_path="location", frame=frame)
    if rot is not None:
        obj.rotation_euler = rot
        obj.keyframe_insert(data_path="rotation_euler", frame=frame)
    if scale is not None:
        obj.scale = scale
        obj.keyframe_insert(data_path="scale", frame=frame)


def animate_enemy(root: bpy.types.Object, left_flash: bpy.types.Object, right_flash: bpy.types.Object, engine: bpy.types.Object) -> None:
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 96

    attack_frames = [
        (1, (-1.35, 0.10, 1.05), (0.0, math.radians(180), math.radians(-10))),
        (32, (-0.25, -0.04, 0.10), (math.radians(-2), math.radians(180), math.radians(7))),
        (64, (0.45, 0.05, -0.55), (math.radians(2), math.radians(180), math.radians(-6))),
        (96, (1.35, 0.10, -1.05), (0.0, math.radians(180), math.radians(-10))),
    ]
    for frame, loc, rot in attack_frames:
        keyframe_transform(root, frame, loc=loc, rot=rot)
    if root.animation_data and root.animation_data.action:
        root.animation_data.action.name = "EnemyJet_AttackPass_Loop"

    for obj, offset in [(left_flash, 0), (right_flash, 4)]:
        for frame in [1, 16 + offset, 22 + offset, 28 + offset, 48 + offset, 54 + offset, 60 + offset, 96]:
            pulse = frame in {22 + offset, 54 + offset}
            keyframe_transform(obj, frame, scale=(1.8, 1.8, 1.8) if pulse else (0.08, 0.08, 0.08))
        if obj.animation_data and obj.animation_data.action:
            obj.animation_data.action.name = obj.name + "_PulseLoop"

    for frame, scale in [(1, 0.75), (24, 1.18), (48, 0.88), (72, 1.26), (96, 0.75)]:
        keyframe_transform(engine, frame, scale=(scale, scale, scale))
    if engine.animation_data and engine.animation_data.action:
        engine.animation_data.action.name = "Engine_Core_PulseLoop"

    for obj in [root, left_flash, right_flash, engine]:
        set_linear_interpolation(obj)


def main() -> None:
    args = parse_args()
    clear_scene()
    source = Path(args.enemy_source).resolve()
    out = Path(args.enemy_out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.import_scene.gltf(filepath=str(source))
    imported = [obj for obj in bpy.context.scene.objects]

    root = bpy.data.objects.new("EnemyHeroJet_BlenderRoot", None)
    root.empty_display_type = "ARROWS"
    root.empty_display_size = 0.45
    bpy.context.collection.objects.link(root)

    geometry_root = bpy.data.objects.new("Geometry_Normalized", None)
    geometry_root.empty_display_type = "CUBE"
    geometry_root.empty_display_size = 0.35
    geometry_root.parent = root
    bpy.context.collection.objects.link(geometry_root)

    for obj in imported:
        if obj.parent is None:
            obj.parent = geometry_root

    normalize_geometry(geometry_root, args.target_width)

    add_socket("Muzzle_Left", (-0.42, 0.12, -1.25), root)
    add_socket("Muzzle_Right", (0.42, 0.12, -1.25), root)
    add_socket("Missile_Left", (-1.10, -0.03, -0.28), root)
    add_socket("Missile_Right", (1.10, -0.03, -0.28), root)
    add_socket("Engine_Core", (0.0, 0.04, 1.35), root)
    left_flash = add_emissive_marker("MuzzleFlash_Left", (-0.42, 0.12, -1.35), root, (1.0, 0.22, 0.05, 1.0))
    right_flash = add_emissive_marker("MuzzleFlash_Right", (0.42, 0.12, -1.35), root, (1.0, 0.22, 0.05, 1.0))
    engine = add_emissive_marker("EnginePulse_Core", (0.0, 0.04, 1.42), root, (0.05, 0.85, 1.0, 1.0), size=0.12)
    animate_enemy(root, left_flash, right_flash, engine)

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
        export_apply=False,
    )
    print(f"Exported Blender-authored animated enemy jet: {out}")
    print("Animation frames: 1-96, clips include attack pass, muzzle flash pulse, and engine pulse")


if __name__ == "__main__":
    main()
