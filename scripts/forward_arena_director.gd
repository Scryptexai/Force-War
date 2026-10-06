extends Node3D
class_name ForwardArenaDirector

# Phase 2 battlefield director: layered storm arena, warzone depth, and weather volumes
# that affect flight feel. This is runtime 3D geometry/GLB usage, not static photos.

const CLOUD_BANK_PATH = "res://assets/models/air_cloud_cluster.glb"
const ARENA_CHUNK_PATH = "res://assets/models/air_arena_tile.glb"
const ARENA_DECK_CLUSTER_PATH = "res://assets/models/arena_battle_deck_cluster.glb"
const SUPPORT_JET_PATH = "res://assets/models/support_jet.glb"
const BOSS_DREADNOUGHT_PATH = "res://assets/models/boss_dreadnought_leviathan.glb"
const HERO_SHOT_TEXTURE_PATH = "res://assets/vfx/hero_cyan_shot.png"
const ENEMY_SHOT_TEXTURE_PATH = "res://assets/vfx/enemy_orange_shot.png"
const EXPLOSION_TEXTURE_PATH = "res://assets/vfx/explosion_fireball.png"
const SMOKE_TEXTURE_PATH = "res://assets/vfx/smoke_plume.png"
const SHIELD_TEXTURE_PATH = "res://assets/vfx/shield_bubble.png"
const RETICLE_TEXTURE_PATH = "res://assets/vfx/reticle_lock.png"
const ARENA_DECK_TEXTURE_PATH = "res://assets/vfx/arena_deck_panel.png"
const STORM_OCEAN_TEXTURE_PATH = "res://assets/vfx/storm_ocean_material.jpg"
const CINEMATIC_MATTE_TEXTURE_PATH = "res://assets/rendered/forward_air_battlefield_matte.jpg"
const ENEMY_HERO_JET_READY_PATH = "res://assets/models/enemy_hero_jet_blender_ready.glb"
const ENEMY_HERO_JET_PATH = "res://assets/models/enemy_hero_jet.glb"
const DEPTH_LAYER_COUNT = 5
const PROJECTILE_VISUAL_POOL_SCRIPT = preload("res://scripts/projectiles/projectile_visual_pool_3d.gd")
const BOSS_PHASE_CONTROLLER_SCRIPT = preload("res://scripts/boss/boss_phase_controller.gd")

var active = false
var is_setup = false
var rng = RandomNumberGenerator.new()

var stage_weather: Dictionary = {}
var stage_threat = 1.0
var forward_time = 0.0
var lightning_timer = 4.0
var lightning_flash = 0.0
var overcharge_timer = 0.0
var wind_drift = 0.0
var turbulence = Vector2.ZERO
var cloud_cover = 0.0
var cloud_occlusion = false
var rain_visibility = 1.0
var storm_hazard = 0.0
var hazard_push = Vector2.ZERO
var active_weather_kind = "storm"

var far_sky_banks: Array = []
var mid_cloud_banks: Array = []
var warzone_chunks: Array = []
var ocean_floor_planes: Array = []
var smoke_columns: Array = []
var fire_pockets: Array = []
var rain_sheets: Array = []
var debris_streaks: Array = []
var air_traffic: Array = []
var tracer_streaks: Array = []
var boss_anchor: Node3D
var boss_core: MeshInstance3D
var boss_phase_controller: Node
var boss_beams: Array = []
var cinematic_bullets: Array = []
var player_beams: Array = []
var player_shot_pulses: Array = []
var player_projectile_visual_pool: Node3D
var enemy_projectile_visual_pool: Node3D
var enemy_attack_jets: Array = []
var missile_trails: Array = []
var shield_bubbles: Array = []
var explosion_bursts: Array = []
var boss_impact_pool: Array = []
var boss_impact_pool_cursor := 0
var boss_impact_events_seen := 0
var boss_impact_visuals_active := 0
var boss_damage_feedback_mode := "pending"
var boss_visual_target_part := "shield"
var boss_weakpoint_marker: MeshInstance3D
var boss_weakpoint_socket: Node3D
var boss_muzzle_core_socket: Node3D
var boss_muzzle_left_socket: Node3D
var boss_muzzle_right_socket: Node3D
var boss_socket_binding := "runtime_fallback"
var boss_muzzle_socket_binding := "runtime_fallback"
var boss_glb_weakpoint_socket_found := false
var boss_glb_muzzle_sockets_found := false
var boss_socket_fire_nodes: Array = []
var boss_socket_fire_events_seen := 0
var boss_socket_fire_active_count := 0
var boss_socket_fire_mode := "pending"
var boss_socket_fire_non_homing := true
var storm_cells: Array = []
var lightning_nodes: Array = []
var cinematic_matte_plane: MeshInstance3D
var last_player_corridor := Vector2.ZERO
var shot_forward_axis := Vector3(0.0, 0.0, -1.0)
var foundation_visual_mode := true
var background_clutter_mode := "foundation_clean"
var player_weapon_hardpoints: Dictionary = {}

var cloud_scene: PackedScene
var arena_scene: PackedScene
var arena_deck_cluster_scene: PackedScene
var support_scene: PackedScene
var boss_dreadnought_scene: PackedScene
var enemy_hero_jet_scene: PackedScene
var enemy_hero_jet_blender_ready = false
var hero_shot_texture: Texture2D
var enemy_shot_texture: Texture2D
var explosion_texture: Texture2D
var smoke_texture: Texture2D
var shield_texture: Texture2D
var reticle_texture: Texture2D
var arena_deck_texture: Texture2D
var storm_ocean_texture: Texture2D
var cinematic_matte_texture: Texture2D

var storm_cloud_mat: StandardMaterial3D
var deep_cloud_mat: StandardMaterial3D
var ocean_mat: StandardMaterial3D
var city_mat: StandardMaterial3D
var smoke_mat: StandardMaterial3D
var fire_mat: StandardMaterial3D
var rain_mat: StandardMaterial3D
var tracer_red_mat: StandardMaterial3D
var tracer_cyan_mat: StandardMaterial3D
var debris_mat: StandardMaterial3D
var lightning_mat: StandardMaterial3D
var hazard_mat: StandardMaterial3D
var boss_hull_mat: StandardMaterial3D
var boss_armor_mat: StandardMaterial3D
var boss_core_mat: StandardMaterial3D
var player_beam_mat: StandardMaterial3D
var missile_smoke_mat: StandardMaterial3D
var shield_mat: StandardMaterial3D
var explosion_mat: StandardMaterial3D
var arena_deck_mat: StandardMaterial3D
var cinematic_matte_mat: StandardMaterial3D


func setup() -> void:
	if is_setup:
		return
	rng.randomize()
	name = "ForwardArenaDirector"
	visible = false
	_load_scene_assets()
	_create_materials()
	_create_cinematic_matte_layer()
	_create_ocean_battlefield_floor()
	_create_far_sky_layer()
	_create_mid_cloud_layer()
	_create_warzone_layer()
	_create_near_weather_layer()
	_create_distant_battle_layer()
	_create_visual_lock_composition_layer()
	_create_boss_phase_controller()
	_create_storm_hazard_cells()
	is_setup = true


func start_mission(stage_data: Dictionary) -> void:
	if not is_setup:
		setup()
	stage_weather = Dictionary(stage_data.get("weather", {}))
	stage_threat = float(stage_data.get("threat", 1.0))
	active_weather_kind = str(stage_weather.get("kind", "storm"))
	active = true
	visible = true
	forward_time = 0.0
	lightning_flash = 0.0
	overcharge_timer = 0.0
	lightning_timer = rng.randf_range(2.4, 5.2) / max(0.35, float(stage_weather.get("lightning", 0.2)) + 0.25)
	wind_drift = 0.0
	turbulence = Vector2.ZERO
	cloud_cover = 0.0
	cloud_occlusion = false
	rain_visibility = float(stage_weather.get("visibility", 0.8))
	storm_hazard = 0.0
	hazard_push = Vector2.ZERO
	_reset_boss_gameplay_vfx()
	_reset_layers()
	if boss_phase_controller and boss_phase_controller.has_method("start_mission"):
		boss_phase_controller.start_mission(stage_data)


func stop_mission() -> void:
	active = false
	visible = false
	if boss_phase_controller and boss_phase_controller.has_method("stop_mission"):
		boss_phase_controller.stop_mission()


func update_arena(delta: float, player_corridor: Vector2, travel_speed: float) -> Dictionary:
	last_player_corridor = player_corridor
	if not active:
		return get_weather_effect()
	forward_time += delta
	_update_weather_logic(delta, player_corridor)
	_update_far_sky(delta, travel_speed)
	_update_ocean_floor(delta, travel_speed)
	_update_mid_clouds(delta, travel_speed)
	_update_warzone(delta, travel_speed)
	_update_near_weather(delta, travel_speed)
	_update_distant_battle(delta, travel_speed)
	_update_visual_lock_composition(delta, travel_speed)
	_update_boss_phase_logic(delta)
	_update_storm_cells(delta, travel_speed, player_corridor)
	_update_lightning_nodes()
	return _weather_effect_with_boss_state(false)


func get_weather_effect() -> Dictionary:
	return {
		"arenaPhase": "storm_battlefield",
		"depthLayerCount": DEPTH_LAYER_COUNT,
		"weatherGameplay": true,
		"activeWeatherKind": active_weather_kind,
		"windDrift": wind_drift,
		"turbulence": turbulence,
		"turbulenceX": turbulence.x,
		"turbulenceY": turbulence.y,
		"cloudCover": cloud_cover,
		"cloudOcclusion": cloud_occlusion,
		"rainVisibility": rain_visibility,
		"lightningFlash": lightning_flash,
		"lightningOvercharge": overcharge_timer > 0.0,
		"overchargeSeconds": overcharge_timer,
		"stormHazard": storm_hazard,
		"bossAnchor": boss_anchor != null,
		"bossName": "Dreadnought Leviathan",
		"bossPhaseController": boss_phase_controller != null,
		"visualLockComposition": "dreadnought_forward_battle",
		"phase3GameplayVFXPass": "boss_weakpoint_hit_feedback",
		"bossDamageFeedbackMode": boss_damage_feedback_mode,
		"bossWeakpointVisual": boss_weakpoint_marker != null,
		"bossWeakpointVisualTarget": boss_visual_target_part,
		"bossWeakpointSocketBinding": boss_socket_binding,
		"bossGLBWeakpointSocketFound": boss_glb_weakpoint_socket_found,
		"bossMuzzleSocketBinding": boss_muzzle_socket_binding,
		"bossGLBMuzzleSocketsFound": boss_glb_muzzle_sockets_found,
		"bossMuzzleSocketCount": _boss_muzzle_world_positions().size(),
		"bossSocketFireVFX": boss_socket_fire_mode,
		"bossSocketFireVFXActive": boss_socket_fire_active_count > 0,
		"bossSocketFireVFXCount": boss_socket_fire_nodes.size(),
		"bossSocketFireEvents": boss_socket_fire_events_seen,
		"bossHardpointFireNonHoming": boss_socket_fire_non_homing,
		"bossMuzzleOrigins": _boss_muzzle_world_positions(),
		"bossImpactVFXPool": boss_impact_pool.size(),
		"bossImpactEvents": boss_impact_events_seen,
		"bossImpactVFXActive": _active_boss_impact_count() > 0,
		"bossImpactVFXActiveCount": _active_boss_impact_count(),
		"blenderPipeline": "bpy_4_5_14_generated_glb",
		"enemyHeroJetModel": enemy_hero_jet_scene != null,
		"enemyHeroJetSource": "blender_ready_glb" if enemy_hero_jet_blender_ready else "uploaded_source_glb",
		"enemyHeroJetAnimation": "EnemyJet_AttackPass_Loop" if enemy_hero_jet_blender_ready else "runtime_motion_only",
		"bossArenaAsset": "boss_dreadnought_leviathan_glb" if boss_dreadnought_scene != null else "runtime_fallback",
		"arenaAssetDeckCluster": arena_deck_cluster_scene != null,
		"stormOceanTextureAsset": storm_ocean_texture != null,
		"texturedBlenderAssets": arena_deck_cluster_scene != null and boss_dreadnought_scene != null and storm_ocean_texture != null,
		"cinematicMatteAsset": cinematic_matte_texture != null,
		"projectileAssetSprites": hero_shot_texture != null and enemy_shot_texture != null,
		"projectileVisualPool": player_projectile_visual_pool != null and enemy_projectile_visual_pool != null,
		"projectilePoolCount": _projectile_pool_count(),
		"projectileArchitecture": "pooled_multimesh_visuals_logical_collision_target",
		"cleanArenaOverlay": true,
		"shotAnimation": "asset_sprite_hero_enemy_lanes",
		"shotDirectionMode": "forward_depth_negative_z",
		"shotVisualOrientation": "forward_aligned_xz_not_billboard_vertical",
		"playerShotFromHardpoint": true,
		"playerWeaponHardpointBinding": str(player_weapon_hardpoints.get("binding", "pending")),
		"playerShotSpawnOrigin": "glb_muzzle_socket" if bool(player_weapon_hardpoints.get("sockets_found", false)) else "runtime_fallback_socket",
		"playerGLBWeaponSocketsFound": bool(player_weapon_hardpoints.get("sockets_found", false)),
		"foundationCorrectionPass": "phase_2_glb_socket_binding",
		"foundationVisualMode": foundation_visual_mode,
		"backgroundClutterMode": background_clutter_mode,
		"legacyVerticalShotColumns": false,
		"playerScaleMode": "reduced_mobile_readable",
		"cloudGeometry": false,
		"hazardPushX": hazard_push.x,
		"hazardPushY": hazard_push.y,
		"distantTraffic": air_traffic.size(),
		"arenaDirector": "ForwardArenaDirector"
	}


func get_bridge_state() -> Dictionary:
	return _weather_effect_with_boss_state(true)


func set_player_weapon_hardpoints(state: Dictionary) -> void:
	player_weapon_hardpoints = state.duplicate(true)
	if player_projectile_visual_pool != null and player_projectile_visual_pool.has_method("set_spawn_origins"):
		player_projectile_visual_pool.set_spawn_origins(player_weapon_hardpoints)


func apply_player_projectile_hits(hits: Array) -> void:
	if boss_phase_controller == null or not boss_phase_controller.has_method("apply_projectile_damage"):
		return
	for hit in hits:
		if not (hit is Dictionary):
			continue
		var part_name: String = str(hit.get("part", "shield"))
		var damage: float = float(hit.get("damage", 0.0))
		boss_phase_controller.apply_projectile_damage(part_name, damage)
		_spawn_boss_impact_visual(hit, part_name)


func _weather_effect_with_boss_state(strip_runtime_vectors: bool) -> Dictionary:
	var effect = get_weather_effect()
	if boss_phase_controller and boss_phase_controller.has_method("get_bridge_state"):
		var boss_state = boss_phase_controller.get_bridge_state()
		for key in boss_state.keys():
			effect[key] = boss_state[key]
	if strip_runtime_vectors:
		effect.erase("turbulence")
		effect.erase("bossMuzzleOrigins")
	return effect


func _load_scene_assets() -> void:
	var cloud_resource = load(CLOUD_BANK_PATH)
	if cloud_resource is PackedScene:
		cloud_scene = cloud_resource
	var arena_resource = load(ARENA_CHUNK_PATH)
	if arena_resource is PackedScene:
		arena_scene = arena_resource
	var arena_deck_cluster_resource = load(ARENA_DECK_CLUSTER_PATH)
	if arena_deck_cluster_resource is PackedScene:
		arena_deck_cluster_scene = arena_deck_cluster_resource
	var support_resource = load(SUPPORT_JET_PATH)
	if support_resource is PackedScene:
		support_scene = support_resource
	var boss_resource = load(BOSS_DREADNOUGHT_PATH)
	if boss_resource is PackedScene:
		boss_dreadnought_scene = boss_resource
	hero_shot_texture = load(HERO_SHOT_TEXTURE_PATH)
	enemy_shot_texture = load(ENEMY_SHOT_TEXTURE_PATH)
	explosion_texture = load(EXPLOSION_TEXTURE_PATH)
	smoke_texture = load(SMOKE_TEXTURE_PATH)
	shield_texture = load(SHIELD_TEXTURE_PATH)
	reticle_texture = load(RETICLE_TEXTURE_PATH)
	arena_deck_texture = load(ARENA_DECK_TEXTURE_PATH)
	storm_ocean_texture = load(STORM_OCEAN_TEXTURE_PATH)
	cinematic_matte_texture = load(CINEMATIC_MATTE_TEXTURE_PATH)
	var enemy_resource = load(ENEMY_HERO_JET_READY_PATH)
	if enemy_resource is PackedScene:
		enemy_hero_jet_scene = enemy_resource
		enemy_hero_jet_blender_ready = true
	else:
		enemy_resource = load(ENEMY_HERO_JET_PATH)
		if enemy_resource is PackedScene:
			enemy_hero_jet_scene = enemy_resource
			enemy_hero_jet_blender_ready = false


func _create_materials() -> void:
	storm_cloud_mat = _make_material(Color(0.48, 0.61, 0.76, 0.26), Color(0.05, 0.11, 0.18, 1.0), 0.0, 0.26)
	deep_cloud_mat = _make_material(Color(0.16, 0.22, 0.32, 0.38), Color(0.03, 0.08, 0.14, 1.0), 0.0, 0.38)
	if storm_ocean_texture != null:
		ocean_mat = _make_textured_material(storm_ocean_texture, Color(0.72, 0.86, 0.98, 0.92), Color(0.00, 0.06, 0.10, 1.0), 0.92, false, false, 0.35)
	else:
		ocean_mat = _make_material(Color(0.02, 0.09, 0.15, 1.0), Color(0.00, 0.04, 0.08, 1.0), 0.05, 1.0)
	city_mat = _make_material(Color(0.10, 0.13, 0.18, 1.0), Color(0.03, 0.06, 0.10, 1.0), 0.18, 1.0)
	smoke_mat = _make_material(Color(0.22, 0.24, 0.26, 0.42), Color(0.02, 0.02, 0.02, 1.0), 0.0, 0.42)
	fire_mat = _make_material(Color(1.0, 0.32, 0.06, 0.92), Color(1.0, 0.20, 0.02, 1.0), 0.0, 0.92)
	rain_mat = _make_material(Color(0.50, 0.78, 1.0, 0.16), Color(0.20, 0.50, 0.90, 1.0), 0.0, 0.16)
	tracer_red_mat = _make_material(Color(1.0, 0.22, 0.08, 0.82), Color(1.0, 0.12, 0.02, 1.0), 0.0, 0.82)
	tracer_cyan_mat = _make_material(Color(0.15, 0.88, 1.0, 0.80), Color(0.1, 0.85, 1.0, 1.0), 0.0, 0.80)
	debris_mat = _make_material(Color(0.72, 0.64, 0.52, 0.82), Color(0.10, 0.08, 0.05, 1.0), 0.0, 0.82)
	lightning_mat = _make_material(Color(0.75, 0.92, 1.0, 0.86), Color(0.45, 0.85, 1.0, 1.0), 0.0, 0.86)
	hazard_mat = _make_material(Color(0.78, 0.18, 1.0, 0.055), Color(0.48, 0.10, 1.0, 1.0), 0.0, 0.055)
	boss_hull_mat = _make_material(Color(0.13, 0.15, 0.19, 1.0), Color(0.035, 0.055, 0.08, 1.0), 0.55, 1.0)
	boss_armor_mat = _make_material(Color(0.28, 0.31, 0.37, 1.0), Color(0.045, 0.10, 0.16, 1.0), 0.62, 1.0)
	boss_core_mat = _make_material(Color(1.0, 0.38, 0.08, 0.96), Color(1.0, 0.20, 0.02, 1.0), 0.0, 0.96)
	player_beam_mat = _make_material(Color(0.10, 0.82, 1.0, 0.76), Color(0.05, 0.82, 1.0, 1.0), 0.0, 0.76)
	missile_smoke_mat = _make_material(Color(0.70, 0.76, 0.82, 0.46), Color(0.08, 0.10, 0.12, 1.0), 0.0, 0.46)
	shield_mat = _make_material(Color(0.18, 0.75, 1.0, 0.20), Color(0.12, 0.68, 1.0, 1.0), 0.0, 0.20)
	explosion_mat = _make_material(Color(1.0, 0.52, 0.08, 0.90), Color(1.0, 0.22, 0.02, 1.0), 0.0, 0.90)
	arena_deck_mat = _make_textured_material(arena_deck_texture, Color(0.25, 0.55, 0.72, 0.95), Color(0.02, 0.11, 0.18, 1.0), 0.95, false, false)
	cinematic_matte_mat = _make_textured_material(cinematic_matte_texture, Color(1.0, 1.0, 1.0, 0.92), Color(0.04, 0.10, 0.15, 1.0), 0.38, true, true)


func _create_cinematic_matte_layer() -> void:
	if cinematic_matte_texture == null:
		return
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(120.0, 214.0)
	cinematic_matte_plane = MeshInstance3D.new()
	cinematic_matte_plane.name = "CinematicBattlefieldMatteAsset"
	cinematic_matte_plane.mesh = mesh
	cinematic_matte_plane.position = Vector3(0.0, 17.5, -164.0)
	cinematic_matte_plane.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	cinematic_matte_plane.material_override = cinematic_matte_mat
	add_child(cinematic_matte_plane)


func _create_ocean_battlefield_floor() -> void:
	# Runtime image-textured ocean floor. This is a real texture asset on Godot planes,
	# used only as storm sea material under Blender deck/ship GLBs, not as a fake aircraft photo.
	if ocean_mat == null:
		return
	for i in range(5):
		var ocean = _plane_mesh("StormOceanTexturePlane_%02d" % i, Vector3(0.0, -9.45, -24.0 - i * 44.0), Vector2(58.0, 44.0), ocean_mat)
		ocean.set_meta("speed_mul", 0.52)
		add_child(ocean)
		ocean_floor_planes.append(ocean)


func _create_far_sky_layer() -> void:
	# User direction: no continuous cloud banks; only thin atmospheric fog remains.
	for i in range(0):
		var bank = _cloud_bank_node("FarStormWall_%02d" % i, 3, true)
		bank.position = Vector3(rng.randf_range(-26.0, 26.0), rng.randf_range(9.0, 16.0), -72.0 - i * 34.0)
		bank.scale = Vector3(rng.randf_range(1.6, 3.0), rng.randf_range(0.8, 1.4), rng.randf_range(1.4, 2.6))
		bank.set_meta("speed_mul", rng.randf_range(0.10, 0.18))
		add_child(bank)
		far_sky_banks.append(bank)


func _create_mid_cloud_layer() -> void:
	# No recurring cloud volumes; target reference has thin haze, not solid clouds.
	for i in range(0):
		var bank = _cloud_bank_node("GameplayCloudVolume_%02d" % i, 2, false)
		bank.position = Vector3(rng.randf_range(-13.5, 13.5), rng.randf_range(3.0, 8.2), -36.0 - rng.randf_range(0.0, 130.0))
		bank.scale = Vector3(rng.randf_range(0.9, 1.8), rng.randf_range(0.45, 0.9), rng.randf_range(0.8, 1.5))
		bank.set_meta("speed_mul", rng.randf_range(0.45, 0.68))
		bank.set_meta("radius", rng.randf_range(2.7, 5.6))
		add_child(bank)
		mid_cloud_banks.append(bank)


func _create_warzone_layer() -> void:
	for i in range(8):
		var chunk = Node3D.new()
		chunk.name = "ForwardWarzoneChunk_%02d" % i
		chunk.position = Vector3(0.0, -9.0, -24.0 - i * 22.0)
		chunk.set_meta("speed_mul", 0.88)
		chunk.add_child(_plane_mesh("ArenaDeckPanelLeft", Vector3(-8.5, 0.0, 0.0), Vector2(8.5, 13.0), arena_deck_mat))
		chunk.add_child(_plane_mesh("ArenaDeckPanelRight", Vector3(8.5, 0.0, 0.0), Vector2(8.5, 13.0), arena_deck_mat))
		for b in range(4):
			var bx = rng.randf_range(-10.3, -5.5) if b % 2 == 0 else rng.randf_range(5.5, 10.3)
			var bz = rng.randf_range(-5.2, 5.2)
			if arena_deck_cluster_scene:
				var deck_cluster = arena_deck_cluster_scene.instantiate()
				deck_cluster.name = "ArenaBattleDeckClusterGLB_%02d" % b
				deck_cluster.position = Vector3(bx, 0.08, bz)
				var cluster_scale = rng.randf_range(0.72, 1.02)
				deck_cluster.scale = Vector3(cluster_scale, cluster_scale, cluster_scale)
				deck_cluster.rotation_degrees = Vector3(0.0, rng.randf_range(-10.0, 10.0), 0.0)
				chunk.add_child(deck_cluster)
				_play_first_animation(deck_cluster)
			else:
				var by = rng.randf_range(0.35, 1.1)
				chunk.add_child(_box_mesh("FallbackDeckModule_%02d" % b, Vector3(bx, by * 0.5, bz), Vector3(rng.randf_range(0.45, 0.95), by, rng.randf_range(0.45, 1.0)), city_mat))
		for f in range(4):
			var fire = _vfx_quad("GroundFirePocket_%02d" % f, Vector3(rng.randf_range(-10.0, -4.8) if f % 2 == 0 else rng.randf_range(4.8, 10.0), 0.80, rng.randf_range(-5.6, 5.6)), Vector2(rng.randf_range(1.0, 1.7), rng.randf_range(1.0, 1.9)), explosion_texture, Color(1.0, 0.55, 0.18, 0.82), 1.9)
			chunk.add_child(fire)
			fire_pockets.append(fire)
		for s in range(3):
			var smoke = _smoke_column("SmokeColumn_%02d" % s, Vector3(rng.randf_range(-10.5, -5.0) if s % 2 == 0 else rng.randf_range(5.0, 10.5), 1.0, rng.randf_range(-5.8, 5.8)))
			chunk.add_child(smoke)
			smoke_columns.append(smoke)
		add_child(chunk)
		warzone_chunks.append(chunk)


func _create_near_weather_layer() -> void:
	for i in range(7):
		var sheet = _box_mesh("RainSheet_%02d" % i, Vector3.ZERO, Vector3(rng.randf_range(0.025, 0.055), rng.randf_range(3.6, 8.4), rng.randf_range(0.025, 0.055)), rain_mat)
		sheet.position = Vector3(rng.randf_range(-8.5, 8.5), rng.randf_range(0.5, 6.0), -5.0 - rng.randf_range(0.0, 78.0))
		sheet.rotation_degrees = Vector3(rng.randf_range(-18.0, -8.0), 0.0, rng.randf_range(-15.0, 15.0))
		sheet.set_meta("speed_mul", rng.randf_range(1.18, 1.48))
		add_child(sheet)
		rain_sheets.append(sheet)
	for i in range(4):
		var debris = _box_mesh("NearDebrisStreak_%02d" % i, Vector3.ZERO, Vector3(rng.randf_range(0.06, 0.13), rng.randf_range(0.03, 0.08), rng.randf_range(0.8, 2.2)), debris_mat)
		debris.position = Vector3(rng.randf_range(-10.0, 10.0), rng.randf_range(-1.8, 4.7), -8.0 - rng.randf_range(0.0, 95.0))
		debris.rotation_degrees = Vector3(rng.randf_range(-4.0, 4.0), rng.randf_range(-12.0, 12.0), rng.randf_range(-24.0, 24.0))
		debris.set_meta("speed_mul", rng.randf_range(1.10, 1.55))
		add_child(debris)
		debris_streaks.append(debris)


func _create_distant_battle_layer() -> void:
	for i in range(5):
		var traffic = Node3D.new()
		traffic.name = "DistantAirTraffic_%02d" % i
		traffic.position = Vector3(rng.randf_range(-18.0, 18.0), rng.randf_range(3.0, 10.0), -45.0 - rng.randf_range(0.0, 130.0))
		traffic.set_meta("speed_mul", rng.randf_range(0.30, 0.56))
		traffic.set_meta("side_speed", rng.randf_range(-1.6, 1.6))
		if enemy_hero_jet_scene:
			var jet = enemy_hero_jet_scene.instantiate()
			jet.name = "EnemyHeroJetDistantGLB"
			jet.scale = Vector3(0.016, 0.016, 0.016)
			jet.rotation_degrees = Vector3(0.0, 180.0 + rng.randf_range(-22.0, 22.0), 0.0)
			traffic.add_child(jet)
			_play_first_animation(jet)
		elif support_scene:
			var jet = support_scene.instantiate()
			jet.name = "DistantJetSilhouetteGLB"
			jet.scale = Vector3(0.55, 0.55, 0.55)
			jet.rotation_degrees = Vector3(0.0, 180.0 + rng.randf_range(-22.0, 22.0), 0.0)
			traffic.add_child(jet)
			_play_first_animation(jet)
		else:
			traffic.add_child(_box_mesh("DistantJetFallback", Vector3.ZERO, Vector3(0.8, 0.08, 0.55), city_mat))
		add_child(traffic)
		air_traffic.append(traffic)
	for i in range(4):
		var tracer_texture = hero_shot_texture if i % 2 == 0 else enemy_shot_texture
		var tracer = _vfx_forward_projectile_quad("DistantForwardTracer_%02d" % i, Vector3.ZERO, Vector2(0.14, rng.randf_range(2.8, 5.8)), tracer_texture, Color(0.78, 0.92, 1.0, 0.42), 0.75)
		tracer.position = Vector3(rng.randf_range(-14.0, 14.0), rng.randf_range(2.2, 8.8), -48.0 - rng.randf_range(0.0, 105.0))
		tracer.set_meta("speed_mul", rng.randf_range(0.42, 0.68))
		add_child(tracer)
		tracer_streaks.append(tracer)


func _create_visual_lock_composition_layer() -> void:
	# Recenter the arena around the reference composition: readable player path,
	# a massive boss carrier in the upper half, ordered projectile lanes, smoke,
	# shielded support craft, and explosions over the warzone below.
	boss_anchor = Node3D.new()
	boss_anchor.name = "DreadnoughtLeviathanBossAnchor"
	boss_anchor.position = Vector3(0.0, 12.5, -96.0)
	boss_anchor.set_meta("base_z", -96.0)
	if boss_dreadnought_scene:
		var boss_model = boss_dreadnought_scene.instantiate()
		boss_model.name = "BossDreadnoughtLeviathanGLB"
		boss_model.scale = Vector3(1.0, 1.0, 1.0)
		boss_model.rotation_degrees = Vector3(0.0, 0.0, 0.0)
		boss_anchor.add_child(boss_model)
		_bind_boss_glb_sockets(boss_model)
		_play_first_animation(boss_model)
		boss_core = null
	else:
		boss_anchor.add_child(_box_mesh("LeviathanMainHull", Vector3(0.0, 0.0, 0.0), Vector3(24.0, 2.4, 8.2), boss_hull_mat))
		boss_anchor.add_child(_box_mesh("LeviathanUpperDeck", Vector3(0.0, 1.65, -0.3), Vector3(17.0, 0.95, 5.9), boss_armor_mat))
		boss_anchor.add_child(_box_mesh("LeviathanBowPlate", Vector3(0.0, -0.15, 5.1), Vector3(11.5, 1.3, 0.9), boss_armor_mat))
		boss_anchor.add_child(_box_mesh("LeftFlightSponson", Vector3(-12.7, -0.15, 0.6), Vector3(3.8, 0.65, 5.8), boss_hull_mat))
		boss_anchor.add_child(_box_mesh("RightFlightSponson", Vector3(12.7, -0.15, 0.6), Vector3(3.8, 0.65, 5.8), boss_hull_mat))
		for i in range(7):
			var tx = -7.8 + i * 2.6
			var tower = _box_mesh("CommandTower_%02d" % i, Vector3(tx, 2.8 + rng.randf_range(0.0, 1.0), rng.randf_range(-2.8, 2.5)), Vector3(0.75, rng.randf_range(2.2, 4.8), 0.75), boss_armor_mat)
			boss_anchor.add_child(tower)
			var light = _box_mesh("TowerBlueBeacon_%02d" % i, tower.position + Vector3(0.0, tower.mesh.size.y * 0.55 + 0.10, 0.0), Vector3(0.20, 0.12, 0.20), player_beam_mat)
			boss_anchor.add_child(light)
		for i in range(11):
			var sx = -7.5 + i * 1.5
			boss_anchor.add_child(_box_mesh("LeviathanBlueWindow_%02d" % i, Vector3(sx, -0.45, 5.68), Vector3(0.45, 0.16, 0.08), player_beam_mat))
			if i % 2 == 0:
				boss_anchor.add_child(_box_mesh("LeviathanRedPort_%02d" % i, Vector3(sx + 0.7, 0.20, 5.75), Vector3(0.34, 0.14, 0.08), tracer_red_mat))
		boss_core = _sphere_mesh("LeviathanCoreCannon", Vector3(0.0, -0.20, 5.92), 0.92, boss_core_mat)
		boss_anchor.add_child(boss_core)
	add_child(boss_anchor)
	_create_boss_gameplay_vfx_layer()

	for i in range(0):
		var x = -4.4 + i * 2.2
		var beam = _vfx_quad("BossLaserLance_%02d" % i, Vector3(x, 5.8 - abs(float(i) - 2.0) * 0.30, -54.0 + i * 1.4), Vector2(0.42, 9.8), enemy_shot_texture, Color(1.0, 0.42, 0.12, 0.88), 1.8)
		beam.rotation_degrees = Vector3(0.0, -x * 1.6, x * 2.0)
		beam.set_meta("base_x", x)
		add_child(beam)
		boss_beams.append(beam)

	var lanes = [-3.4, -2.15, -0.9, 0.9, 2.15, 3.4]
	for i in range(14):
		var lane = lanes[i % lanes.size()]
		var bullet = _vfx_forward_projectile_quad("ReadableEnemyForwardBolt_%02d" % i, Vector3(lane, rng.randf_range(1.6, 5.0), -38.0 - i * 6.2), Vector2(0.30, 1.95), enemy_shot_texture, Color(1.0, 0.48, 0.20, 0.78), 1.35)
		bullet.set_meta("lane", lane)
		bullet.set_meta("speed_mul", rng.randf_range(1.20, 1.55))
		add_child(bullet)
		cinematic_bullets.append(bullet)

	for i in range(0):
		var beam_x = -0.78 + float(i) * 0.78
		var player_beam = _vfx_forward_projectile_quad("PlayerCyanForwardFireLane_%02d" % i, Vector3(beam_x, 1.78, -34.0), Vector2(0.62, 18.0), hero_shot_texture, Color(0.58, 0.98, 1.0, 0.92), 3.2)
		player_beam.set_meta("beam_x", beam_x)
		add_child(player_beam)
		player_beams.append(player_beam)

	for i in range(30):
		var lane_x = -0.62 + float(i % 3) * 0.62
		var pulse = _vfx_forward_projectile_quad("PlayerCyanForwardShotPulse_%02d" % i, Vector3(lane_x, 1.78, -5.5 - float(i) * 3.35), Vector2(0.52, 3.25), hero_shot_texture, Color(0.74, 1.0, 1.0, 1.0), 3.6)
		pulse.set_meta("lane_x", lane_x)
		pulse.set_meta("phase", float(i) * 0.13)
		add_child(pulse)
		player_shot_pulses.append(pulse)

	_create_projectile_visual_pools()

	for i in range(4):
		var enemy = Node3D.new()
		enemy.name = "EnemyHeroJetAttack_%02d" % i
		var side = -1.0 if i % 2 == 0 else 1.0
		enemy.position = Vector3(side * rng.randf_range(4.8, 8.8), rng.randf_range(2.8, 7.2), -34.0 - float(i) * 12.5)
		enemy.set_meta("side", side)
		enemy.set_meta("speed_mul", rng.randf_range(0.88, 1.20))
		enemy.set_meta("base_y", enemy.position.y)
		if enemy_hero_jet_scene:
			var model = enemy_hero_jet_scene.instantiate()
			model.name = "EnemyHeroJetGLB"
			model.scale = Vector3(0.022, 0.022, 0.022)
			model.rotation_degrees = Vector3(0.0, 180.0 + side * 18.0, 0.0)
			enemy.add_child(model)
			_play_first_animation(model)
		else:
			enemy.add_child(_box_mesh("EnemyHeroJetFallback", Vector3.ZERO, Vector3(1.4, 0.16, 1.1), boss_armor_mat))
		add_child(enemy)
		enemy_attack_jets.append(enemy)

	for i in range(0):
		var trail = _vfx_quad("MissileSmokeTrail_%02d" % i, Vector3(rng.randf_range(-11.0, 11.0), rng.randf_range(-0.7, 3.5), -14.0 - rng.randf_range(0.0, 94.0)), Vector2(rng.randf_range(1.0, 1.8), rng.randf_range(2.0, 4.8)), smoke_texture, Color(0.82, 0.88, 0.92, 0.46), 0.45)
		trail.rotation_degrees = Vector3(rng.randf_range(-10.0, 10.0), rng.randf_range(-26.0, 26.0), rng.randf_range(-18.0, 18.0))
		trail.set_meta("speed_mul", rng.randf_range(0.72, 1.05))
		add_child(trail)
		missile_trails.append(trail)

	for i in range(0):
		var explosion = _vfx_quad("WarzoneExplosionBurst_%02d" % i, Vector3(rng.randf_range(-9.5, 9.5), rng.randf_range(-2.4, 1.4), -24.0 - rng.randf_range(0.0, 86.0)), Vector2(rng.randf_range(1.3, 2.8), rng.randf_range(1.3, 2.8)), explosion_texture, Color(1.0, 0.65, 0.26, 0.88), 2.0)
		explosion.set_meta("base_radius", explosion.scale.x)
		explosion.set_meta("speed_mul", rng.randf_range(0.78, 1.05))
		add_child(explosion)
		explosion_bursts.append(explosion)

	for i in range(0):
		var shield_x = -8.8 if i == 0 else 8.6
		var shield = _vfx_quad("WingmanShieldBubble_%02d" % i, Vector3(shield_x, 2.0 + i * 0.45, -34.0 - i * 18.0), Vector2(3.5, 3.5), shield_texture, Color(0.64, 0.95, 1.0, 0.62), 1.4)
		shield.set_meta("speed_mul", 0.66 + i * 0.06)
		add_child(shield)
		shield_bubbles.append(shield)


func _bind_boss_glb_sockets(root: Node) -> void:
	boss_weakpoint_socket = _find_node3d(root, "Boss_WeakPoint_Core")
	boss_muzzle_core_socket = _find_node3d(root, "Boss_Muzzle_Core")
	boss_muzzle_left_socket = _find_node3d(root, "Boss_Muzzle_Left")
	boss_muzzle_right_socket = _find_node3d(root, "Boss_Muzzle_Right")
	boss_glb_weakpoint_socket_found = boss_weakpoint_socket != null
	boss_glb_muzzle_sockets_found = boss_muzzle_core_socket != null and boss_muzzle_left_socket != null and boss_muzzle_right_socket != null
	boss_socket_binding = "glb_boss_socket_runtime" if boss_glb_weakpoint_socket_found else "runtime_fallback"
	boss_muzzle_socket_binding = "glb_boss_muzzle_socket_runtime" if boss_glb_muzzle_sockets_found else "runtime_fallback"


func _find_node3d(root: Node, node_name: String) -> Node3D:
	if root == null:
		return null
	if root.name == node_name and root is Node3D:
		return root
	for child in root.get_children():
		var found := _find_node3d(child, node_name)
		if found != null:
			return found
	return null


func _create_boss_gameplay_vfx_layer() -> void:
	boss_damage_feedback_mode = "pooled_sprite_impacts_target_reticle"
	if reticle_texture != null:
		boss_weakpoint_marker = _vfx_quad("BossWeakpointReticle_GLBSocket", Vector3.ZERO, Vector2(5.8, 5.8), reticle_texture, Color(0.68, 0.98, 1.0, 0.74), 2.8)
	else:
		boss_weakpoint_marker = _vfx_quad("BossWeakpointReticleFallback", Vector3.ZERO, Vector2(4.6, 4.6), hero_shot_texture, Color(0.68, 0.98, 1.0, 0.68), 2.2)
	if boss_weakpoint_marker != null:
		boss_weakpoint_marker.visible = false
		var marker_mat := boss_weakpoint_marker.material_override as StandardMaterial3D
		if marker_mat != null:
			marker_mat.no_depth_test = true
		add_child(boss_weakpoint_marker)
	boss_impact_pool.clear()
	for i in range(10):
		var impact := _vfx_quad("BossSocketImpactBurst_%02d" % i, Vector3.ZERO, Vector2(2.4, 2.4), explosion_texture, Color(1.0, 0.72, 0.24, 0.88), 3.4)
		impact.visible = false
		impact.set_meta("life", 0.0)
		impact.set_meta("max_life", 0.42)
		impact.set_meta("base_scale", 1.0)
		var impact_mat := impact.material_override as StandardMaterial3D
		if impact_mat != null:
			impact_mat.no_depth_test = true
		add_child(impact)
		boss_impact_pool.append(impact)
	boss_socket_fire_nodes.clear()
	for i in range(3):
		var fire_lane := _vfx_forward_projectile_quad("BossGLBMuzzleForwardFire_%02d" % i, Vector3.ZERO, Vector2(0.34, 9.4), enemy_shot_texture, Color(1.0, 0.46, 0.16, 0.68), 2.4)
		fire_lane.visible = false
		fire_lane.set_meta("socket_index", i)
		fire_lane.set_meta("phase", float(i) * 0.37)
		var fire_mat := fire_lane.material_override as StandardMaterial3D
		if fire_mat != null:
			fire_mat.no_depth_test = true
		add_child(fire_lane)
		boss_socket_fire_nodes.append(fire_lane)
	boss_socket_fire_mode = "glb_boss_muzzle_forward_lanes" if boss_glb_muzzle_sockets_found else "runtime_fallback"


func _reset_boss_gameplay_vfx() -> void:
	boss_impact_events_seen = 0
	boss_impact_pool_cursor = 0
	boss_impact_visuals_active = 0
	boss_socket_fire_events_seen = 0
	boss_socket_fire_active_count = 0
	boss_visual_target_part = "shield"
	boss_damage_feedback_mode = "pooled_sprite_impacts_target_reticle" if boss_weakpoint_marker != null else boss_damage_feedback_mode
	if boss_weakpoint_marker != null:
		boss_weakpoint_marker.visible = false
	for impact in boss_impact_pool:
		if impact is MeshInstance3D:
			impact.visible = false
			impact.set_meta("life", 0.0)


func _spawn_boss_impact_visual(hit: Dictionary, part_name: String) -> void:
	if boss_impact_pool.is_empty():
		return
	var impact: MeshInstance3D = boss_impact_pool[boss_impact_pool_cursor % boss_impact_pool.size()]
	boss_impact_pool_cursor += 1
	var target := _boss_weakpoint_world_position(part_name)
	var hit_x: float = clamp(float(hit.get("x", 0.0)) * 0.30, -3.8, 3.8)
	var part_offset := Vector3(hit_x, rng.randf_range(-0.45, 0.62), rng.randf_range(-0.55, 0.55))
	if part_name == "left_wing":
		part_offset.x -= 3.2
	elif part_name == "right_wing":
		part_offset.x += 3.2
	elif part_name == "turrets":
		part_offset.y += 1.0
	elif part_name == "core":
		part_offset *= 0.45
	impact.global_position = target + part_offset
	impact.visible = true
	impact.set_meta("life", 0.46)
	impact.set_meta("max_life", 0.46)
	impact.set_meta("base_scale", rng.randf_range(0.82, 1.35))
	impact.set_meta("part", part_name)
	boss_impact_events_seen += 1
	boss_visual_target_part = part_name


func _update_boss_gameplay_vfx(delta: float) -> void:
	if boss_phase_controller != null and boss_phase_controller.has_method("get_bridge_state"):
		var boss_state: Dictionary = boss_phase_controller.get_bridge_state()
		boss_visual_target_part = str(boss_state.get("bossTargetablePart", boss_visual_target_part))
	if boss_weakpoint_marker != null:
		boss_weakpoint_marker.visible = active
		if active:
			boss_weakpoint_marker.global_position = _boss_weakpoint_world_position(boss_visual_target_part)
			var marker_pulse: float = 1.0 + sin(forward_time * 5.6) * 0.08 + lightning_flash * 0.10
			boss_weakpoint_marker.scale = Vector3.ONE * marker_pulse
	_update_boss_socket_fire_vfx(delta)
	boss_impact_visuals_active = 0
	for impact in boss_impact_pool:
		if not (impact is MeshInstance3D):
			continue
		var life := float(impact.get_meta("life", 0.0))
		if life <= 0.0:
			impact.visible = false
			continue
		life = max(0.0, life - delta)
		impact.set_meta("life", life)
		if life <= 0.0:
			impact.visible = false
			continue
		boss_impact_visuals_active += 1
		var max_life: float = max(0.01, float(impact.get_meta("max_life", 0.46)))
		var fade: float = clamp(life / max_life, 0.0, 1.0)
		var grow: float = 0.72 + (1.0 - fade) * 1.28
		var base_scale: float = float(impact.get_meta("base_scale", 1.0))
		impact.scale = Vector3.ONE * base_scale * grow
		var mat := impact.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(1.0, 0.70 + fade * 0.18, 0.18, fade * 0.90)
			mat.emission_energy_multiplier = 1.4 + fade * 3.2


func _boss_weakpoint_world_position(part_name: String) -> Vector3:
	if boss_weakpoint_socket != null and boss_weakpoint_socket.is_inside_tree():
		var socket_pos := boss_weakpoint_socket.global_transform.origin
		if part_name == "left_wing":
			return socket_pos + Vector3(-5.0, -0.2, -0.6)
		if part_name == "right_wing":
			return socket_pos + Vector3(5.0, -0.2, -0.6)
		if part_name == "turrets":
			return socket_pos + Vector3(0.0, 1.25, -1.1)
		return socket_pos
	if boss_anchor != null and boss_anchor.is_inside_tree():
		var offset := Vector3(0.0, 0.0, 5.85)
		if part_name == "left_wing":
			offset = Vector3(-6.2, -0.1, 1.2)
		elif part_name == "right_wing":
			offset = Vector3(6.2, -0.1, 1.2)
		elif part_name == "turrets":
			offset = Vector3(0.0, 2.6, -0.4)
		elif part_name == "core":
			offset = Vector3(0.0, -0.1, 5.9)
		return boss_anchor.global_position + offset
	return Vector3(0.0, 12.0, -90.0)


func _update_boss_socket_fire_vfx(delta: float) -> void:
	boss_socket_fire_mode = "glb_boss_muzzle_forward_lanes" if boss_glb_muzzle_sockets_found else "runtime_fallback"
	var origins := _boss_muzzle_world_positions()
	boss_socket_fire_active_count = 0
	if origins.is_empty():
		for node in boss_socket_fire_nodes:
			if node is MeshInstance3D:
				node.visible = false
		return
	for i in range(boss_socket_fire_nodes.size()):
		var lane: MeshInstance3D = boss_socket_fire_nodes[i]
		var origin: Vector3 = origins[i % origins.size()]
		var phase := float(lane.get_meta("phase", 0.0))
		var pulse: float = 0.5 + 0.5 * sin(forward_time * 9.4 + phase * TAU)
		lane.visible = active
		if not lane.visible:
			continue
		boss_socket_fire_active_count += 1
		lane.global_position = origin + Vector3(sin(forward_time * 1.7 + phase) * 0.18, -0.08 - pulse * 0.12, 4.2 + pulse * 0.55)
		lane.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		lane.scale = Vector3(0.72 + pulse * 0.20, 0.84 + pulse * 0.36 + lightning_flash * 0.16, 1.0)
		var mat := lane.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(1.0, 0.42 + pulse * 0.18, 0.12, 0.40 + pulse * 0.38)
			mat.emission_energy_multiplier = 1.8 + pulse * 2.4 + lightning_flash * 0.8
	if active and boss_socket_fire_active_count > 0:
		boss_socket_fire_events_seen += 1


func _boss_muzzle_world_positions() -> Array:
	var positions: Array = []
	for socket in [boss_muzzle_left_socket, boss_muzzle_core_socket, boss_muzzle_right_socket]:
		if socket != null and socket.is_inside_tree():
			positions.append(socket.global_transform.origin)
	if positions.is_empty() and boss_anchor != null and boss_anchor.is_inside_tree():
		positions.append(boss_anchor.global_position + Vector3(-4.2, 0.0, 5.4))
		positions.append(boss_anchor.global_position + Vector3(0.0, 0.3, 5.8))
		positions.append(boss_anchor.global_position + Vector3(4.2, 0.0, 5.4))
	return positions


func _active_boss_impact_count() -> int:
	var count := 0
	for impact in boss_impact_pool:
		if impact is MeshInstance3D and impact.visible and float(impact.get_meta("life", 0.0)) > 0.0:
			count += 1
	return count


func _create_projectile_visual_pools() -> void:
	# Architecture pass: high-count projectile visuals are pooled and batched through MultiMesh.
	# The current gameplay damage logic stays separate; this is the renderer-aware bullet field.
	if hero_shot_texture != null:
		player_projectile_visual_pool = PROJECTILE_VISUAL_POOL_SCRIPT.new()
		add_child(player_projectile_visual_pool)
		player_projectile_visual_pool.setup(
			"player_cyan_plasma",
			hero_shot_texture,
			Color(0.62, 1.0, 1.0, 0.92),
			36,
			Vector2(0.42, 2.45),
			[-0.98, -0.32, 0.32, 0.98],
			1.65,
			3.65,
			-5.5,
			-118.0,
			false,
			54.0,
			84.0
		)
	if enemy_shot_texture != null:
		enemy_projectile_visual_pool = PROJECTILE_VISUAL_POOL_SCRIPT.new()
		add_child(enemy_projectile_visual_pool)
		enemy_projectile_visual_pool.setup(
			"enemy_orange_bolts",
			enemy_shot_texture,
			Color(1.0, 0.48, 0.18, 0.86),
			48,
			Vector2(0.30, 1.75),
			[-4.1, -2.55, -1.05, 1.05, 2.55, 4.1],
			1.8,
			5.7,
			8.0,
			-126.0,
			true,
			34.0,
			56.0
		)


func _projectile_pool_count() -> int:
	var count = 0
	if player_projectile_visual_pool != null and player_projectile_visual_pool.has_method("get_pool_count"):
		count += int(player_projectile_visual_pool.get_pool_count())
	if enemy_projectile_visual_pool != null and enemy_projectile_visual_pool.has_method("get_pool_count"):
		count += int(enemy_projectile_visual_pool.get_pool_count())
	return count

func _create_boss_phase_controller() -> void:
	boss_phase_controller = BOSS_PHASE_CONTROLLER_SCRIPT.new()
	add_child(boss_phase_controller)
	if boss_phase_controller.has_method("setup"):
		boss_phase_controller.setup()


func _update_boss_phase_logic(delta: float) -> void:
	if boss_phase_controller == null or not boss_phase_controller.has_method("update_boss"):
		return
	var overcharged: bool = overcharge_timer > 0.0
	var pressure: float = 1.0 + (0.30 if overcharged else 0.0) + lightning_flash * 0.22
	boss_phase_controller.update_boss(delta, overcharged, pressure)
	if boss_core and boss_phase_controller.has_method("get_hp_ratio"):
		var wounded := 1.0 - float(boss_phase_controller.get_hp_ratio())
		boss_core.scale = Vector3.ONE * (1.0 + wounded * 0.20 + lightning_flash * 0.25)


func _play_first_animation(root: Node) -> void:
	for child in root.get_children():
		if child is AnimationPlayer:
			var animations = child.get_animation_list()
			if animations.size() > 0:
				var selected = StringName("EnemyJet_AttackPass_Loop") if child.has_animation(StringName("EnemyJet_AttackPass_Loop")) else animations[0]
				child.play(selected)
				child.speed_scale = 1.0
		_play_first_animation(child)


func _create_storm_hazard_cells() -> void:
	# Storm-cell gameplay will return later with designed meshes; hidden for current visual lock.
	for i in range(0):
		var cell = _cloud_bank_node("StormCellHazard_%02d" % i, 5, false)
		cell.position = Vector3(rng.randf_range(-5.0, 5.0), rng.randf_range(0.4, 3.8), -35.0 - i * 42.0)
		cell.scale = Vector3(2.1, 1.4, 2.1)
		cell.set_meta("speed_mul", 0.54)
		cell.set_meta("radius", 3.9)
		cell.add_child(_box_mesh("StormHazardCore", Vector3.ZERO, Vector3(4.2, 3.0, 4.2), hazard_mat))
		add_child(cell)
		storm_cells.append(cell)
	for i in range(2):
		var bolt = _box_mesh("LightningFork_%02d" % i, Vector3.ZERO, Vector3(0.05, rng.randf_range(5.0, 10.0), 0.05), lightning_mat)
		bolt.position = Vector3(rng.randf_range(-10.0, 10.0), rng.randf_range(4.0, 8.0), -22.0 - rng.randf_range(0.0, 100.0))
		bolt.rotation_degrees = Vector3(rng.randf_range(-12.0, 12.0), 0.0, rng.randf_range(-28.0, 28.0))
		bolt.visible = false
		add_child(bolt)
		lightning_nodes.append(bolt)


func _reset_layers() -> void:
	for i in range(far_sky_banks.size()):
		far_sky_banks[i].position = Vector3(rng.randf_range(-26.0, 26.0), rng.randf_range(9.0, 16.0), -72.0 - i * 34.0)
	for cloud in mid_cloud_banks:
		cloud.position = Vector3(rng.randf_range(-13.5, 13.5), rng.randf_range(3.0, 8.2), -36.0 - rng.randf_range(0.0, 130.0))
	for i in range(ocean_floor_planes.size()):
		ocean_floor_planes[i].position = Vector3(0.0, -9.45, -24.0 - i * 44.0)
	for i in range(warzone_chunks.size()):
		warzone_chunks[i].position = Vector3(0.0, -9.0, -24.0 - i * 22.0)
	for rain in rain_sheets:
		rain.position = Vector3(rng.randf_range(-8.5, 8.5), rng.randf_range(0.5, 6.0), -5.0 - rng.randf_range(0.0, 78.0))
	for debris in debris_streaks:
		debris.position = Vector3(rng.randf_range(-10.0, 10.0), rng.randf_range(-1.8, 4.7), -8.0 - rng.randf_range(0.0, 95.0))
	for traffic in air_traffic:
		traffic.position = Vector3(rng.randf_range(-18.0, 18.0), rng.randf_range(3.0, 10.0), -45.0 - rng.randf_range(0.0, 130.0))
	for tracer in tracer_streaks:
		tracer.position = Vector3(rng.randf_range(-18.0, 18.0), rng.randf_range(1.0, 10.5), -24.0 - rng.randf_range(0.0, 145.0))
	if boss_anchor:
		boss_anchor.position = Vector3(0.0, 12.5, -96.0)
	for i in range(enemy_attack_jets.size()):
		var side = -1.0 if i % 2 == 0 else 1.0
		enemy_attack_jets[i].position = Vector3(side * rng.randf_range(4.8, 8.8), rng.randf_range(2.8, 7.2), -34.0 - float(i) * 12.5)
	for i in range(player_shot_pulses.size()):
		var lane_x: float = float(player_shot_pulses[i].get_meta("lane_x", 0.0))
		var origin: Vector3 = _player_shot_origin(i, lane_x)
		player_shot_pulses[i].position = Vector3(origin.x, origin.y, origin.z - float(i) * 3.35)
	for bullet in cinematic_bullets:
		bullet.position.z = -18.0 - rng.randf_range(0.0, 112.0)
		bullet.position.y = rng.randf_range(1.1, 4.5)
	for trail in missile_trails:
		trail.position = Vector3(rng.randf_range(-11.0, 11.0), rng.randf_range(-0.7, 3.5), -14.0 - rng.randf_range(0.0, 94.0))
	for explosion in explosion_bursts:
		explosion.position = Vector3(rng.randf_range(-9.5, 9.5), rng.randf_range(-2.4, 1.4), -24.0 - rng.randf_range(0.0, 86.0))
	for i in range(shield_bubbles.size()):
		shield_bubbles[i].position = Vector3(-8.8 if i == 0 else 8.6, 2.0 + i * 0.45, -34.0 - i * 18.0)
	for i in range(storm_cells.size()):
		storm_cells[i].position = Vector3(rng.randf_range(-5.0, 5.0), rng.randf_range(0.4, 3.8), -35.0 - i * 42.0)


func _update_weather_logic(delta: float, player_corridor: Vector2) -> void:
	var wind = float(stage_weather.get("wind", 0.0))
	var rain = float(stage_weather.get("rain", 0.0))
	var cloud = float(stage_weather.get("cloud", 0.0))
	var lightning = float(stage_weather.get("lightning", 0.0))
	var base_visibility = float(stage_weather.get("visibility", 0.84))
	var gust = sin(forward_time * 0.77) * 0.35 + sin(forward_time * 1.83 + 1.7) * 0.18
	wind_drift = wind * (0.70 + gust * 0.24)
	turbulence = Vector2(wind_drift * 0.42 + sin(forward_time * 2.4) * cloud * 0.11, sin(forward_time * 1.65 + 0.8) * (rain + cloud) * 0.08)

	# Thin haze only. No recurring visible cloud volumes so the boss/projectile lanes stay readable.
	cloud_cover = clamp(cloud * 0.08, 0.0, 0.16)
	cloud_occlusion = false
	rain_visibility = clamp(base_visibility - rain * 0.06 - cloud_cover * 0.035 - storm_hazard * 0.04 + lightning_flash * 0.10, 0.68, 1.0)

	lightning_timer -= delta
	if lightning > 0.05 and lightning_timer <= 0.0:
		lightning_flash = 1.0
		overcharge_timer = max(overcharge_timer, 2.2 + lightning * 2.4)
		lightning_timer = rng.randf_range(2.6, 6.8) / max(0.35, lightning + 0.25)
	lightning_flash = max(0.0, lightning_flash - delta * 2.6)
	overcharge_timer = max(0.0, overcharge_timer - delta)


func _update_far_sky(delta: float, travel_speed: float) -> void:
	for bank in far_sky_banks:
		bank.position.z += travel_speed * float(bank.get_meta("speed_mul", 0.12)) * delta
		bank.position.x += wind_drift * delta * 0.35
		bank.rotation_degrees.y += delta * 1.1
		if bank.position.z > 34.0:
			bank.position = Vector3(rng.randf_range(-30.0, 30.0), rng.randf_range(7.0, 13.5), -190.0 - rng.randf_range(0.0, 42.0))


func _update_ocean_floor(delta: float, travel_speed: float) -> void:
	for ocean in ocean_floor_planes:
		ocean.position.z += travel_speed * float(ocean.get_meta("speed_mul", 0.52)) * delta
		ocean.position.x = sin(forward_time * 0.18 + ocean.position.z * 0.05) * 0.55 + wind_drift * 0.35
		if ocean.position.z > 26.0:
			ocean.position.z -= 220.0


func _update_mid_clouds(delta: float, travel_speed: float) -> void:
	for bank in mid_cloud_banks:
		bank.position.z += travel_speed * float(bank.get_meta("speed_mul", 0.55)) * delta
		bank.position.x += wind_drift * delta * 0.95
		bank.position.y += sin(forward_time * 0.7 + bank.position.z) * delta * 0.18
		bank.rotation_degrees.y += delta * (2.0 + abs(wind_drift) * 1.5)
		if bank.position.z > 18.0:
			bank.position = Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(0.7, 5.9), -145.0 - rng.randf_range(0.0, 28.0))


func _update_warzone(delta: float, travel_speed: float) -> void:
	for chunk in warzone_chunks:
		chunk.position.z += travel_speed * float(chunk.get_meta("speed_mul", 0.88)) * delta
		if chunk.position.z > 20.0:
			chunk.position.z -= 148.0
	for fire in fire_pockets:
		fire.scale.y = 1.0 + sin(forward_time * 10.0 + fire.position.x * 0.8) * 0.30
	for smoke in smoke_columns:
		smoke.rotation_degrees.y += delta * 10.0
		smoke.scale.x = 1.0 + sin(forward_time * 1.4 + smoke.position.z) * 0.05


func _update_near_weather(delta: float, travel_speed: float) -> void:
	var rain = float(stage_weather.get("rain", 0.0))
	for sheet in rain_sheets:
		sheet.visible = rain > 0.05
		sheet.position.z += travel_speed * float(sheet.get_meta("speed_mul", 1.28)) * delta
		sheet.position.x += wind_drift * delta * 1.4
		if sheet.position.z > 8.0:
			sheet.position = Vector3(rng.randf_range(-8.5, 8.5), rng.randf_range(0.5, 6.0), -86.0 - rng.randf_range(0.0, 28.0))
	for debris in debris_streaks:
		debris.position.z += travel_speed * float(debris.get_meta("speed_mul", 1.25)) * delta
		debris.position.x += wind_drift * delta * 0.55
		debris.rotation_degrees.z += delta * 80.0
		if debris.position.z > 10.0:
			debris.position = Vector3(rng.randf_range(-10.0, 10.0), rng.randf_range(-1.8, 4.7), -100.0 - rng.randf_range(0.0, 35.0))


func _update_distant_battle(delta: float, travel_speed: float) -> void:
	for traffic in air_traffic:
		traffic.position.z += travel_speed * float(traffic.get_meta("speed_mul", 0.42)) * delta
		traffic.position.x += float(traffic.get_meta("side_speed", 0.0)) * delta + wind_drift * delta * 0.22
		traffic.rotation_degrees.z = sin(forward_time * 1.4 + traffic.position.x) * 8.0
		if traffic.position.z > 18.0 or abs(traffic.position.x) > 24.0:
			traffic.position = Vector3(rng.randf_range(-18.0, 18.0), rng.randf_range(3.0, 10.0), -155.0 - rng.randf_range(0.0, 45.0))
			traffic.set_meta("side_speed", rng.randf_range(-1.6, 1.6))
	for tracer in tracer_streaks:
		tracer.position.z += travel_speed * float(tracer.get_meta("speed_mul", 0.72)) * delta
		tracer.position.x += wind_drift * delta * 0.4
		if tracer.position.z > 14.0:
			tracer.position = Vector3(rng.randf_range(-18.0, 18.0), rng.randf_range(1.0, 10.5), -145.0 - rng.randf_range(0.0, 45.0))


func _update_visual_lock_composition(delta: float, travel_speed: float) -> void:
	if boss_anchor:
		boss_anchor.position.z = lerp(boss_anchor.position.z, -96.0 + sin(forward_time * 0.22) * 2.0, min(1.0, delta * 0.7))
		boss_anchor.position.x = sin(forward_time * 0.17) * 1.0
		boss_anchor.rotation_degrees.z = sin(forward_time * 0.19) * 1.5
	_update_boss_gameplay_vfx(delta)
	if boss_core:
		var core_pulse = 1.0 + sin(forward_time * 7.5) * 0.10 + lightning_flash * 0.32
		boss_core.scale = Vector3.ONE * core_pulse
	for beam in boss_beams:
		beam.visible = true
		beam.position.x = float(beam.get_meta("base_x", 0.0)) + sin(forward_time * 0.9 + beam.position.z) * 0.22
		beam.scale.z = 1.0 + lightning_flash * 0.18
	for bullet in cinematic_bullets:
		bullet.position.z += travel_speed * float(bullet.get_meta("speed_mul", 1.35)) * delta
		bullet.position.x = float(bullet.get_meta("lane", 0.0)) + sin(forward_time * 1.15 + bullet.position.z * 0.05) * 0.18
		bullet.rotation_degrees.x = 90.0
		if bullet.position.z > 6.0:
			bullet.position.z = -112.0 - rng.randf_range(0.0, 28.0)
			bullet.position.y = rng.randf_range(1.1, 4.5)
	for beam in player_beams:
		var beam_lane: float = float(beam.get_meta("beam_x", 0.0))
		beam.position.x = last_player_corridor.x + beam_lane * 0.45 + sin(forward_time * 12.0) * 0.025
		beam.position.y = 1.55 + last_player_corridor.y * 0.35
		beam.position.z = -34.0
		beam.scale.y = 1.0 + (0.22 if overcharge_timer > 0.0 else 0.0) + sin(forward_time * 14.0) * 0.02
	for i in range(player_shot_pulses.size()):
		var pulse: MeshInstance3D = player_shot_pulses[i]
		pulse.position.z -= (72.0 + (18.0 if overcharge_timer > 0.0 else 0.0)) * delta
		var pulse_lane: float = float(pulse.get_meta("lane_x", 0.0))
		var origin: Vector3 = _player_shot_origin(i, pulse_lane)
		pulse.position.x = origin.x + sin(forward_time * 6.0 + float(pulse.get_meta("phase", 0.0))) * 0.035
		pulse.position.y = origin.y
		pulse.scale.y = 1.0 + sin(forward_time * 18.0 + pulse.position.z) * 0.10
		if pulse.position.z < -112.0:
			pulse.position = origin
	if player_projectile_visual_pool != null and player_projectile_visual_pool.has_method("update_pool"):
		player_projectile_visual_pool.update_pool(delta, wind_drift, forward_time)
	if enemy_projectile_visual_pool != null and enemy_projectile_visual_pool.has_method("update_pool"):
		enemy_projectile_visual_pool.update_pool(delta, wind_drift, forward_time)
	for enemy in enemy_attack_jets:
		var side = float(enemy.get_meta("side", 1.0))
		enemy.position.z += travel_speed * float(enemy.get_meta("speed_mul", 1.0)) * 0.62 * delta
		enemy.position.x += -side * delta * 0.45 + wind_drift * delta * 0.18
		enemy.position.y = float(enemy.get_meta("base_y", 4.0)) + sin(forward_time * 1.4 + enemy.position.z * 0.05) * 0.30
		enemy.rotation_degrees.z = -side * 8.0 + sin(forward_time * 1.8 + enemy.position.z) * 5.0
		if enemy.position.z > -4.0 or abs(enemy.position.x) > 11.5:
			enemy.position = Vector3(side * rng.randf_range(4.8, 8.8), rng.randf_range(2.8, 7.2), -126.0 - rng.randf_range(0.0, 32.0))
			enemy.set_meta("base_y", enemy.position.y)
	for trail in missile_trails:
		trail.position.z += travel_speed * float(trail.get_meta("speed_mul", 0.9)) * delta
		trail.position.x += wind_drift * delta * 0.72
		trail.scale.z = 1.0 + sin(forward_time * 1.7 + trail.position.x) * 0.06
		if trail.position.z > 12.0:
			trail.position = Vector3(rng.randf_range(-11.0, 11.0), rng.randf_range(-0.7, 3.5), -112.0 - rng.randf_range(0.0, 28.0))
	for explosion in explosion_bursts:
		explosion.position.z += travel_speed * float(explosion.get_meta("speed_mul", 0.86)) * delta
		var pulse = 1.0 + sin(forward_time * 9.0 + explosion.position.x) * 0.18
		explosion.scale = Vector3.ONE * float(explosion.get_meta("base_radius", 1.0)) * pulse
		if explosion.position.z > 10.0:
			explosion.position = Vector3(rng.randf_range(-9.5, 9.5), rng.randf_range(-2.4, 1.4), -112.0 - rng.randf_range(0.0, 36.0))
	for shield in shield_bubbles:
		shield.position.z += travel_speed * float(shield.get_meta("speed_mul", 0.66)) * delta
		shield.rotation_degrees.y += delta * 22.0
		shield.scale = Vector3.ONE * (1.0 + sin(forward_time * 2.5 + shield.position.x) * 0.045)
		if shield.position.z > 10.0:
			shield.position = Vector3(rng.randf_range(-9.5, 9.5), rng.randf_range(1.5, 3.1), -105.0 - rng.randf_range(0.0, 44.0))



func _update_storm_cells(delta: float, travel_speed: float, player_corridor: Vector2) -> void:
	storm_hazard = 0.0
	hazard_push = Vector2.ZERO
	var lightning = float(stage_weather.get("lightning", 0.0))
	for cell in storm_cells:
		cell.position.z += travel_speed * float(cell.get_meta("speed_mul", 0.54)) * delta
		cell.position.x += wind_drift * delta * 0.55
		cell.rotation_degrees.y += delta * 3.0
		if cell.position.z > 8.0:
			cell.position = Vector3(rng.randf_range(-5.0, 5.0), rng.randf_range(0.4, 3.8), -165.0 - rng.randf_range(0.0, 55.0))
		var z_window = clamp(1.0 - abs(cell.position.z + 16.0) / 36.0, 0.0, 1.0)
		if z_window > 0.0:
			var player_world = Vector2(player_corridor.x, 1.55 + player_corridor.y)
			var cell_world = Vector2(cell.position.x, cell.position.y)
			var dist = player_world.distance_to(cell_world)
			var radius = float(cell.get_meta("radius", 4.0))
			var intensity = clamp(1.0 - dist / max(1.0, radius), 0.0, 1.0) * z_window * max(0.35, lightning)
			if intensity > storm_hazard:
				storm_hazard = intensity
				var away = (player_world - cell_world).normalized()
				if away.length() < 0.1:
					away = Vector2(1.0, 0.0)
				hazard_push = away * intensity


func _update_lightning_nodes() -> void:
	for bolt in lightning_nodes:
		bolt.visible = lightning_flash > 0.12
		if bolt.visible:
			bolt.position.x += sin(forward_time * 16.0 + bolt.position.z) * 0.035
			bolt.scale.y = 1.0 + lightning_flash * 0.45
			if rng.randf() < 0.08:
				bolt.position = Vector3(rng.randf_range(-10.0, 10.0), rng.randf_range(4.0, 8.0), -22.0 - rng.randf_range(0.0, 100.0))


func _cloud_bank_node(node_name: String, puff_count: int, deep: bool) -> Node3D:
	var bank = Node3D.new()
	bank.name = node_name
	if cloud_scene:
		for i in range(max(1, puff_count)):
			var cloud = cloud_scene.instantiate()
			cloud.name = "CloudClusterGLB_%02d" % i
			cloud.position = Vector3(rng.randf_range(-2.4, 2.4), rng.randf_range(-0.25, 0.65), rng.randf_range(-1.6, 1.6))
			cloud.scale = Vector3(rng.randf_range(0.9, 1.7), rng.randf_range(0.55, 1.1), rng.randf_range(0.85, 1.6))
			cloud.rotation_degrees = Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(0.0, 360.0), rng.randf_range(-6.0, 6.0))
			bank.add_child(cloud)
	else:
		for i in range(max(1, puff_count * 3)):
			bank.add_child(_box_mesh("ProceduralCloudPuff_%02d" % i, Vector3(rng.randf_range(-2.8, 2.8), rng.randf_range(-0.35, 0.75), rng.randf_range(-1.8, 1.8)), Vector3(rng.randf_range(1.2, 3.5), rng.randf_range(0.45, 1.1), rng.randf_range(1.0, 2.6)), deep_cloud_mat if deep else storm_cloud_mat))
	if deep:
		bank.add_child(_box_mesh("FarCloudTint", Vector3.ZERO, Vector3(7.0, 2.0, 4.8), deep_cloud_mat))
	else:
		bank.add_child(_box_mesh("GameplayCloudVolumeTint", Vector3.ZERO, Vector3(4.2, 1.7, 3.2), storm_cloud_mat))
	return bank


func _smoke_column(node_name: String, pos: Vector3) -> Node3D:
	var root = Node3D.new()
	root.name = node_name
	root.position = pos
	for i in range(5):
		var puff_size = 1.0 + i * 0.34
		var puff = _vfx_quad("SmokePuff_%02d" % i, Vector3(rng.randf_range(-0.28, 0.28), i * 0.62, rng.randf_range(-0.25, 0.25)), Vector2(puff_size, puff_size), smoke_texture, Color(0.74, 0.78, 0.82, 0.30), 0.25)
		puff.rotation_degrees = Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(0.0, 360.0), rng.randf_range(-12.0, 12.0))
		root.add_child(puff)
	return root



func _plane_mesh(node_name: String, pos: Vector3, size: Vector2, material: Material) -> MeshInstance3D:
	var mesh = PlaneMesh.new()
	mesh.size = size
	var mi = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	return mi


func _player_shot_origin(index: int, fallback_lane: float) -> Vector3:
	var key := "center"
	if index % 3 == 0:
		key = "left"
	elif index % 3 == 1:
		key = "right"
	if player_weapon_hardpoints.has(key):
		var value = player_weapon_hardpoints[key]
		if value is Vector3:
			return value
	if player_weapon_hardpoints.has("center") and player_weapon_hardpoints["center"] is Vector3:
		return player_weapon_hardpoints["center"]
	return Vector3(last_player_corridor.x + fallback_lane * 0.45, 1.55 + last_player_corridor.y * 0.35, -5.5)


func _vfx_forward_projectile_quad(node_name: String, pos: Vector3, size: Vector2, texture: Texture2D, tint: Color = Color.WHITE, emission_energy: float = 1.0) -> MeshInstance3D:
	if texture == null:
		return _box_mesh(node_name + "FallbackForwardBolt", pos, Vector3(max(0.08, size.x), max(0.08, size.x), max(0.08, size.y)), player_beam_mat)
	var mesh = QuadMesh.new()
	mesh.size = size
	var mi = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	# QuadMesh is XY by default. Rotate into XZ so its long axis runs in world -Z/+Z,
	# making shots read as forward-depth fire instead of vertical screen columns.
	mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	mi.material_override = _make_textured_material(texture, tint, Color(tint.r, tint.g, tint.b, 1.0), tint.a, false, true, emission_energy)
	return mi


func _vfx_quad(node_name: String, pos: Vector3, size: Vector2, texture: Texture2D, tint: Color = Color.WHITE, emission_energy: float = 1.0) -> MeshInstance3D:
	if texture == null:
		return _box_mesh(node_name + "FallbackBox", pos, Vector3(max(0.08, size.x), max(0.08, size.x), max(0.08, size.y)), player_beam_mat)
	var mesh = QuadMesh.new()
	mesh.size = size
	var mi = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _make_textured_material(texture, tint, Color(tint.r, tint.g, tint.b, 1.0), tint.a, true, true, emission_energy)
	return mi


func _make_textured_material(texture: Texture2D, albedo: Color, emission: Color = Color.BLACK, alpha: float = 1.0, billboard: bool = false, unshaded: bool = false, emission_energy: float = 1.0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(albedo.r, albedo.g, albedo.b, alpha)
	if texture != null:
		mat.albedo_texture = texture
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	if texture != null:
		mat.emission_texture = texture
	mat.emission = emission
	mat.emission_energy_multiplier = emission_energy
	return mat


func _sphere_mesh(node_name: String, pos: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var mi = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	return mi



func _box_mesh(node_name: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var mi = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	return mi


func _make_material(albedo: Color, emission: Color = Color.BLACK, metallic: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(albedo.r, albedo.g, albedo.b, alpha)
	mat.metallic = metallic
	mat.roughness = 0.46
	if alpha < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = false
	mat.emission_enabled = emission != Color.BLACK
	mat.emission = emission
	mat.emission_energy_multiplier = 1.55
	return mat
