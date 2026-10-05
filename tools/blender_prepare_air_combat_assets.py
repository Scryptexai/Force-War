"""Blender pipeline for Force War forward-air assets.

Run inside Blender, for example:

    blender --background --python tools/blender_prepare_air_combat_assets.py -- \
      --enemy-source assets/models/enemy_hero_jet.glb \
      --enemy-out assets/models/enemy_hero_jet_blender_ready.glb

Purpose:
- normalize uploaded aircraft GLB scale/origin for Godot;
- add named hardpoint/muzzle/socket empties;
- add simple looping enemy-flight and muzzle-pulse animation tracks;
- export a GLB that Godot can import as the enemy placeholder until final art is made.

This script intentionally contains no game logic. Runtime shot timing remains in Godot;
Blender owns authored model preparation, sockets, and reusable animation clips.
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
        argv = []
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
        if obj.type not in {"MESH", "EMPTY"}:
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


def normalize_to_width(root: bpy.types.Object, target_width: float) -> None:
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    mins, maxs = scene_bounds(meshes)
    size = maxs - mins
    width = max(size.x, size.z, 0.001)
    scale = target_width / width
    root.scale = (scale, scale, scale)
    root.location = (-(mins.x + maxs.x) * 0.5 * scale, -mins.y * scale, -(mins.z + maxs.z) * 0.5 * scale)
    bpy.context.view_layer.update()


def add_socket(name: str, loc: tuple[float, float, float], parent: bpy.types.Object) -> bpy.types.Object:
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "SPHERE"
    empty.empty_display_size = 0.08
    empty.location = loc
    empty.parent = parent
    bpy.context.collection.objects.link(empty)
    return empty


def add_emissive_marker(name: str, loc: tuple[float, float, float], parent: bpy.types.Object, color: tuple[float, float, float, float]) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name + "Mesh")
    verts = [(-0.05, -0.05, -0.05), (0.05, -0.05, -0.05), (0.05, 0.05, -0.05), (-0.05, 0.05, -0.05),
             (-0.05, -0.05, 0.05), (0.05, -0.05, 0.05), (0.05, 0.05, 0.05), (-0.05, 0.05, 0.05)]
    faces = [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    obj.parent = parent
    mat = bpy.data.materials.new(name + "Material")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = 2.5
    obj.data.materials.append(mat)
    bpy.context.collection.objects.link(obj)
    return obj


def animate_enemy(root: bpy.types.Object) -> None:
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 96
    for frame, loc, rot_z in [
        (1, (-1.8, 0.2, 1.2), math.radians(-12)),
        (48, (0.0, 0.0, -0.2), math.radians(8)),
        (96, (1.8, 0.2, -1.2), math.radians(-10)),
    ]:
        bpy.context.scene.frame_set(frame)
        root.location = loc
        root.rotation_euler = (0.0, math.radians(180), rot_z)
        root.keyframe_insert(data_path="location", frame=frame)
        root.keyframe_insert(data_path="rotation_euler", frame=frame)
    if root.animation_data and root.animation_data.action:
        root.animation_data.action.name = "EnemyJet_AttackPass_Loop"


def main() -> None:
    args = parse_args()
    clear_scene()
    source = Path(args.enemy_source).resolve()
    out = Path(args.enemy_out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.import_scene.gltf(filepath=str(source))
    imported = [obj for obj in bpy.context.scene.objects]
    root = bpy.data.objects.new("EnemyHeroJet_BlenderRoot", None)
    bpy.context.collection.objects.link(root)
    for obj in imported:
        if obj.parent is None:
            obj.parent = root

    normalize_to_width(root, args.target_width)
    add_socket("Muzzle_Left", (-0.42, 0.12, -1.25), root)
    add_socket("Muzzle_Right", (0.42, 0.12, -1.25), root)
    add_socket("Missile_Left", (-1.10, -0.03, -0.28), root)
    add_socket("Missile_Right", (1.10, -0.03, -0.28), root)
    add_socket("Engine_Core", (0.0, 0.04, 1.35), root)
    add_emissive_marker("MuzzleFlash_Left", (-0.42, 0.12, -1.35), root, (1.0, 0.22, 0.05, 1.0))
    add_emissive_marker("MuzzleFlash_Right", (0.42, 0.12, -1.35), root, (1.0, 0.22, 0.05, 1.0))
    animate_enemy(root)

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
    print(f"Exported {out}")


if __name__ == "__main__":
    main()
