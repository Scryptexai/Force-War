"""Build Force War's current forward-air production asset pass in Blender.

This script intentionally replaces code-looking primitive-only models with reusable
textured GLB assets that Godot can import directly:

- player_stormhawk.glb: textured GLB player aircraft, hardpoint sockets
- boss_dreadnought_leviathan.glb: textured GLB boss carrier, sockets, animation clips
- arena_battle_deck_cluster.glb: textured GLB carrier deck/building module, sockets, animation

The texture sources live in assets/source_textures and are excluded from Godot import
with .gdignore; the exported GLB files embed the textures.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TEXTURE_DIR = ROOT / "assets" / "source_textures"


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = argv[1:]
    parser = argparse.ArgumentParser(description="Create textured Blender GLB assets for Force War.")
    parser.add_argument("--texture-dir", default=str(DEFAULT_TEXTURE_DIR))
    parser.add_argument("--player-out", default=str(ROOT / "assets/models/player_stormhawk.glb"))
    parser.add_argument("--boss-out", default=str(ROOT / "assets/models/boss_dreadnought_leviathan.glb"))
    parser.add_argument("--deck-out", default=str(ROOT / "assets/models/arena_battle_deck_cluster.glb"))
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for datablock in list(bpy.data.meshes):
        if datablock.users == 0:
            bpy.data.meshes.remove(datablock)
    for datablock in list(bpy.data.materials):
        if datablock.users == 0:
            bpy.data.materials.remove(datablock)
    for datablock in list(bpy.data.images):
        if datablock.users == 0:
            bpy.data.images.remove(datablock)


def textured_mat(name: str, image_path: Path, metallic: float = 0.45, roughness: float = 0.34, emission=None, emission_strength: float = 0.0) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    image = bpy.data.images.load(str(image_path.resolve()))
    image.name = image_path.stem
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    if bsdf:
        material.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if emission is not None:
            bsdf.inputs["Emission Color"].default_value = emission
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    return material


def solid_mat(name: str, color, metallic: float = 0.0, roughness: float = 0.45, emission=None, emission_strength: float = 0.0) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if emission is not None:
            bsdf.inputs["Emission Color"].default_value = emission
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    return material


def smart_uv(obj: bpy.types.Object) -> None:
    if obj.type != "MESH":
        return
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    try:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
    except Exception:
        try:
            bpy.ops.object.mode_set(mode="OBJECT")
        except Exception:
            pass


def cube(name: str, loc, scale, material: bpy.types.Material, parent=None, rot=(0.0, 0.0, 0.0), uv: bool = True) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if uv:
        smart_uv(obj)
    if parent:
        obj.parent = parent
    return obj


def cyl(name: str, loc, radius: float, depth: float, material: bpy.types.Material, parent=None, rot=(0.0, 0.0, 0.0), vertices: int = 32, uv: bool = True) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    if uv:
        smart_uv(obj)
    if parent:
        obj.parent = parent
    return obj


def cone(name: str, loc, radius1: float, radius2: float, depth: float, material: bpy.types.Material, parent=None, rot=(0.0, 0.0, 0.0), vertices: int = 32, uv: bool = True) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    if uv:
        smart_uv(obj)
    if parent:
        obj.parent = parent
    return obj


def sphere(name: str, loc, radius: float, material: bpy.types.Material, parent=None, uv: bool = True) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=radius, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    if uv:
        smart_uv(obj)
    if parent:
        obj.parent = parent
    return obj


def add_socket(name: str, loc, parent, display="SPHERE", size: float = 0.18) -> bpy.types.Object:
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = display
    empty.empty_display_size = size
    empty.location = loc
    empty.parent = parent
    bpy.context.collection.objects.link(empty)
    return empty


def animate_location(obj: bpy.types.Object, frames) -> None:
    for frame, loc, rot in frames:
        bpy.context.scene.frame_set(frame)
        obj.location = loc
        obj.rotation_euler = rot
        obj.keyframe_insert(data_path="location", frame=frame)
        obj.keyframe_insert(data_path="rotation_euler", frame=frame)
    if obj.animation_data and obj.animation_data.action:
        for curve in obj.animation_data.action.fcurves:
            for point in curve.keyframe_points:
                point.interpolation = "BEZIER"


def animate_scale(obj: bpy.types.Object, frames) -> None:
    for frame, value in frames:
        bpy.context.scene.frame_set(frame)
        obj.scale = (value, value, value)
        obj.keyframe_insert(data_path="scale", frame=frame)
    if obj.animation_data and obj.animation_data.action:
        for curve in obj.animation_data.action.fcurves:
            for point in curve.keyframe_points:
                point.interpolation = "BEZIER"


def export_selected(root: bpy.types.Object, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=str(out.resolve()),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_frame_range=True,
        export_apply=True,
        export_image_format="AUTO",
    )
    print(f"Exported {out}")


def create_player(texture_dir: Path, out: Path) -> None:
    clear_scene()
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 96
    livery = textured_mat("Stormhawk_Textured_Wet_Carbon_Livery", texture_dir / "production_stormhawk_livery_texture.jpg", metallic=0.58, roughness=0.28)
    dark = solid_mat("Stormhawk_Dark_Composite_Edges", (0.025, 0.032, 0.040, 1.0), metallic=0.62, roughness=0.32)
    canopy = solid_mat("Stormhawk_Blue_Glass_Canopy", (0.08, 0.42, 0.72, 0.72), metallic=0.05, roughness=0.08, emission=(0.02, 0.32, 0.62, 1.0), emission_strength=0.7)
    cyan = solid_mat("Stormhawk_Cyan_Emissive_Strips", (0.05, 0.88, 1.0, 1.0), metallic=0.0, roughness=0.15, emission=(0.02, 0.92, 1.0, 1.0), emission_strength=3.0)
    heat = solid_mat("Stormhawk_Engine_Blue_Heat", (0.15, 0.85, 1.0, 1.0), metallic=0.0, roughness=0.12, emission=(0.06, 0.82, 1.0, 1.0), emission_strength=4.0)

    root = bpy.data.objects.new("PlayerStormhawk_TexturedBlenderRoot", None)
    root.empty_display_type = "ARROWS"
    root.empty_display_size = 0.8
    bpy.context.collection.objects.link(root)

    cube("FuselageArmoredBody_Textured", (0.0, 0.0, 0.05), (0.52, 0.24, 2.15), livery, root)
    cone("NeedleNoseCone_Textured", (0.0, 0.0, -1.32), 0.28, 0.045, 0.72, livery, root, rot=(math.radians(90), 0, 0), vertices=48)
    cube("CockpitCanopy_Glass", (0.0, 0.16, -0.58), (0.34, 0.15, 0.48), canopy, root, rot=(0.0, 0.0, 0.0))
    cube("CyanSpineStrip_Emissive", (0.0, 0.285, 0.05), (0.08, 0.035, 1.55), cyan, root, uv=False)

    for side, sx in [("Left", -1.0), ("Right", 1.0)]:
        cube(f"{side}SweptWing_Textured", (sx * 0.83, -0.02, 0.05), (1.32, 0.075, 0.52), livery, root, rot=(0.0, math.radians(sx * -9.0), math.radians(sx * 2.5)))
        cube(f"{side}ForwardCanard_Textured", (sx * 0.50, 0.015, -0.78), (0.62, 0.055, 0.25), livery, root, rot=(0.0, math.radians(sx * -18.0), math.radians(sx * 3.0)))
        cube(f"{side}TailFin_Textured", (sx * 0.31, 0.26, 0.92), (0.13, 0.50, 0.38), livery, root, rot=(math.radians(sx * 2.0), 0.0, math.radians(sx * 13.0)))
        cyl(f"{side}EngineNozzle", (sx * 0.23, -0.04, 1.20), 0.105, 0.20, dark, root, rot=(math.radians(90), 0.0, 0.0), vertices=32)
        sphere(f"{side}EngineGlow", (sx * 0.23, -0.04, 1.34), 0.105, heat, root, uv=False)
        cube(f"{side}WingCyanEdge", (sx * 0.84, 0.035, -0.12), (0.92, 0.026, 0.055), cyan, root, rot=(0.0, math.radians(sx * -9.0), 0.0), uv=False)
        cyl(f"{side}WeaponHardpoint", (sx * 0.62, -0.075, -0.48), 0.045, 0.34, dark, root, rot=(math.radians(90), 0.0, 0.0), vertices=18)
        add_socket(f"Stormhawk_Muzzle_{side}", (sx * 0.62, -0.11, -0.78), root, size=0.12)
    add_socket("Stormhawk_Muzzle_Center", (0.0, -0.10, -1.34), root, size=0.12)
    add_socket("Stormhawk_Engine_Left", (-0.23, -0.04, 1.36), root, size=0.12)
    add_socket("Stormhawk_Engine_Right", (0.23, -0.04, 1.36), root, size=0.12)

    export_selected(root, out)


def create_boss(texture_dir: Path, out: Path) -> None:
    clear_scene()
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 120
    hull_tex = textured_mat("Leviathan_Textured_Rain_Hull_PBRSource", texture_dir / "production_dreadnought_hull_texture.jpg", metallic=0.70, roughness=0.30)
    deck_tex = textured_mat("Leviathan_Carrier_Deck_Wet_Texture", texture_dir / "production_carrier_deck_texture.jpg", metallic=0.62, roughness=0.24)
    armor = solid_mat("Leviathan_Gunmetal_Armor_Structures", (0.10, 0.12, 0.15, 1.0), metallic=0.74, roughness=0.32)
    cyan = solid_mat("Leviathan_Cyan_Embedded_Lights", (0.04, 0.80, 1.0, 1.0), emission=(0.02, 0.86, 1.0, 1.0), emission_strength=3.2)
    red = solid_mat("Leviathan_Red_Weapon_Ports", (1.0, 0.10, 0.04, 1.0), emission=(1.0, 0.04, 0.01, 1.0), emission_strength=3.0)
    hot = solid_mat("Leviathan_Orange_Core_Cannon", (1.0, 0.34, 0.04, 1.0), emission=(1.0, 0.17, 0.02, 1.0), emission_strength=4.2)

    root = bpy.data.objects.new("BossDreadnought_Leviathan_TexturedRoot", None)
    root.empty_display_type = "ARROWS"
    root.empty_display_size = 1.4
    bpy.context.collection.objects.link(root)

    cube("MainCarrierHull_TexturedRainArmor", (0, 0, 0), (25.8, 7.8, 1.65), hull_tex, root)
    cube("MainFlightDeck_PhotoTexture", (0, -0.18, 1.02), (19.4, 5.8, 0.26), deck_tex, root)
    cube("ForwardBowArmor_Textured", (0, -4.42, 0.55), (12.6, 1.25, 1.0), hull_tex, root)
    cube("LeftFlightSponson_Textured", (-13.3, -0.1, 0.05), (3.9, 6.7, 0.9), hull_tex, root)
    cube("RightFlightSponson_Textured", (13.3, -0.1, 0.05), (3.9, 6.7, 0.9), hull_tex, root)
    cube("RearEngineBlock_Textured", (0, 3.85, 0.58), (10.5, 0.9, 1.05), armor, root)

    for i, x in enumerate([-8.1, -5.4, -2.7, 0.0, 2.7, 5.4, 8.1]):
        h = 2.5 + (i % 3) * 0.44
        cube(f"TexturedCommandTower_{i:02d}", (x, 0.55 + (i % 2) * 0.38, 2.05 + h * 0.5), (0.92, 0.82, h), hull_tex if i % 2 else armor, root)
        cube(f"TowerCyanBeacon_{i:02d}", (x, 0.55 + (i % 2) * 0.38, 3.58 + h * 0.5), (0.26, 0.22, 0.16), cyan, root, uv=False)
        cyl(f"TowerAntenna_{i:02d}", (x + 0.18, 0.32, 4.1 + h * 0.45), 0.025, 0.8, cyan, root, vertices=12, uv=False)

    for i, x in enumerate([-9.2, -7.36, -5.52, -3.68, -1.84, 0.0, 1.84, 3.68, 5.52, 7.36, 9.2]):
        cube(f"ForwardCyanWindow_{i:02d}", (x, -5.08, 0.64), (0.52, 0.08, 0.16), cyan, root, uv=False)
        if i % 2 == 0:
            cube(f"ForwardRedWeaponPort_{i:02d}", (x + 0.42, -5.16, 1.05), (0.36, 0.10, 0.18), red, root, uv=False)

    core = sphere("LeviathanCoreCannon_Animated", (0, -5.36, 0.86), 0.78, hot, root, uv=False)
    cyl("LeviathanCoreBarrel", (0, -6.08, 0.86), 0.20, 1.18, hot, root, rot=(math.radians(90), 0, 0), vertices=32, uv=False)
    for i, x in enumerate([-8.2, -4.2, 4.2, 8.2]):
        cyl(f"LargeAATurret_{i:02d}", (x, -3.64, 1.45), 0.33, 1.1, armor, root, rot=(math.radians(90), 0, 0), vertices=28)
        sphere(f"LargeAATurretGlow_{i:02d}", (x, -4.18, 1.45), 0.18, red, root, uv=False)
    for i, x in enumerate([-11.0, 11.0]):
        for y in [-1.8, 1.8]:
            cyl(f"SideEngineGlow_{i}_{y}", (x, y, -0.10), 0.22, 0.16, cyan, root, vertices=24, uv=False)

    for name, loc in [
        ("Boss_Muzzle_Core", (0, -6.72, 0.86)),
        ("Boss_Muzzle_Left", (-4.2, -5.85, 1.28)),
        ("Boss_Muzzle_Right", (4.2, -5.85, 1.28)),
        ("Boss_WeakPoint_Core", (0, -5.38, 0.86)),
    ]:
        add_socket(name, loc, root, size=0.22)

    animate_location(root, [
        (1, (0, 0, 0.0), (0, 0, math.radians(-1.0))),
        (40, (0, 0, 0.24), (0, 0, math.radians(0.8))),
        (80, (0, 0, -0.10), (0, 0, math.radians(1.2))),
        (120, (0, 0, 0.0), (0, 0, math.radians(-1.0))),
    ])
    if root.animation_data and root.animation_data.action:
        root.animation_data.action.name = "BossDreadnought_IdleHover"
    animate_scale(core, [(1, 1.0), (30, 1.28), (60, 0.92), (90, 1.22), (120, 1.0)])
    if core.animation_data and core.animation_data.action:
        core.animation_data.action.name = "BossCore_ChargePulse"

    export_selected(root, out)


def create_deck_cluster(texture_dir: Path, out: Path) -> None:
    clear_scene()
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 96
    deck = textured_mat("Arena_CarrierDeck_Wet_PhotoTexture", texture_dir / "production_carrier_deck_texture.jpg", metallic=0.62, roughness=0.24)
    hull = textured_mat("Arena_Hull_Modules_Textured", texture_dir / "production_dreadnought_hull_texture.jpg", metallic=0.68, roughness=0.31)
    armor = solid_mat("Arena_Gunmetal_Props", (0.10, 0.12, 0.15, 1.0), metallic=0.65, roughness=0.35)
    cyan = solid_mat("Arena_Cyan_Service_Lights", (0.07, 0.82, 1.0, 1.0), emission=(0.03, 0.90, 1.0, 1.0), emission_strength=3.2)
    amber = solid_mat("Arena_Amber_Warning_Lights", (1.0, 0.52, 0.08, 1.0), emission=(1.0, 0.30, 0.02, 1.0), emission_strength=2.5)
    red = solid_mat("Arena_Red_AA_Muzzles", (1.0, 0.08, 0.03, 1.0), emission=(1.0, 0.04, 0.01, 1.0), emission_strength=3.0)

    root = bpy.data.objects.new("ArenaBattleDeckCluster_TexturedRoot", None)
    root.empty_display_type = "ARROWS"
    root.empty_display_size = 0.8
    bpy.context.collection.objects.link(root)

    cube("DeckClusterBase_PhotoDeck", (0, 0, 0.04), (6.2, 4.8, 0.08), deck, root)
    cube("LeftArmoredEdge_Textured", (-3.05, 0, 0.28), (0.24, 4.5, 0.42), hull, root, rot=(0.0, 0.0, math.radians(8.0)))
    cube("RightArmoredEdge_Textured", (3.05, 0, 0.28), (0.24, 4.5, 0.42), hull, root, rot=(0.0, 0.0, math.radians(-8.0)))
    cube("RearServiceRail_Textured", (0, 2.22, 0.30), (5.4, 0.18, 0.34), hull, root)
    cube("ForwardServiceRail_Textured", (0, -2.22, 0.30), (5.4, 0.18, 0.34), hull, root)

    for i, x in enumerate([-2.0, 2.0]):
        cyl(f"AATurretBase_Textured_{i:02d}", (x, -1.35, 0.36), 0.38, 0.28, hull, root, vertices=32)
        cyl(f"AATurretBarrel_{i:02d}", (x, -1.73, 0.56), 0.06, 0.94, red, root, rot=(math.radians(90), 0, 0), vertices=16, uv=False)
        sphere(f"AAMuzzleGlow_{i:02d}", (x, -2.22, 0.56), 0.115, red, root, uv=False)
        add_socket(f"Deck_AA_Muzzle_{i:02d}", (x, -2.26, 0.56), root, size=0.12)

    cube("ServiceTowerLower_Textured", (-0.60, 0.82, 0.72), (0.88, 0.72, 1.20), hull, root)
    cube("ServiceTowerUpper_Textured", (-0.60, 0.82, 1.50), (0.58, 0.50, 0.52), armor, root)
    cyl("RadarMast_Cyan", (0.46, 1.02, 1.26), 0.045, 1.56, cyan, root, vertices=12, uv=False)
    cone("RadarDish_Cyan", (0.46, 1.02, 2.10), 0.44, 0.10, 0.18, cyan, root, rot=(math.radians(90), 0, 0), vertices=32, uv=False)

    for i, (x, y) in enumerate([(-2.15, 1.05), (-1.18, 1.48), (1.15, 0.85), (2.20, 1.50), (0.9, -0.12)]):
        cube(f"EquipmentPod_Textured_{i:02d}", (x, y, 0.36), (0.62, 0.42, 0.44), hull if i % 2 else armor, root)
        cube(f"PodCyanMarker_{i:02d}", (x, y - 0.225, 0.62), (0.25, 0.035, 0.065), cyan, root, uv=False)

    beacons = [
        sphere("DeckBeaconCyan_A", (-2.58, -1.88, 0.44), 0.10, cyan, root, uv=False),
        sphere("DeckBeaconCyan_B", (2.58, -1.88, 0.44), 0.10, cyan, root, uv=False),
        sphere("DeckBeaconAmber_A", (-2.58, 1.88, 0.44), 0.10, amber, root, uv=False),
        sphere("DeckBeaconAmber_B", (2.58, 1.88, 0.44), 0.10, amber, root, uv=False),
    ]
    add_socket("Deck_Smoke_Anchor", (0, 2.30, 0.62), root, size=0.14)

    for index, beacon in enumerate(beacons):
        phase = index * 8
        animate_scale(beacon, [(min(1 + phase, 96), 1.0), (min(24 + phase, 96), 1.45), (min(48 + phase, 96), 0.92), (min(72 + phase, 96), 1.25), (96, 1.0)])
        if beacon.animation_data and beacon.animation_data.action:
            beacon.animation_data.action.name = f"ArenaDeckBeaconPulse_{index:02d}"

    export_selected(root, out)


def main() -> None:
    args = parse_args()
    texture_dir = Path(args.texture_dir).resolve()
    missing = [p for p in [
        texture_dir / "production_carrier_deck_texture.jpg",
        texture_dir / "production_dreadnought_hull_texture.jpg",
        texture_dir / "production_stormhawk_livery_texture.jpg",
    ] if not p.exists()]
    if missing:
        raise SystemExit("Missing texture source(s): " + ", ".join(str(p) for p in missing))
    create_player(texture_dir, Path(args.player_out))
    create_boss(texture_dir, Path(args.boss_out))
    create_deck_cluster(texture_dir, Path(args.deck_out))
    print("Textured Blender asset pass complete.")


if __name__ == "__main__":
    main()
