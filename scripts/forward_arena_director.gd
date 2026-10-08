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
const BOSS_ENTITY_SCRIPT = preload("res://scripts/boss/boss_entity_3d.gd")
const ENEMY_SQUADRON_SCRIPT = preload("res://scripts/enemies/enemy_squadron_3d.gd")

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
var boss_entity: Node3D
var enemy_squadron: Node3D
var explosion_pool: Array = []
var explosion_cursor := 0
var missile_visuals: Array = []
var explosion_events_seen := 0
var last_explosion_pos := Vector3.ZERO
var projectile_manager_ref: Node
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
var boss_part_damage_nodes: Dictionary = {}
var boss_destroyed_part_visual_count := 0
var boss_phase_transition_events_seen := 0
var boss_last_phase_transition_count := 0
var boss_part_destruction_events_seen := 0
var boss_last_part_destruction_count := 0
var boss_part_damage_vfx_mode := "pending"
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
var underworld_decor_mat: StandardMaterial3D
var cinematic_matte_mat: StandardMaterial3D


func setup() -> void:
	if is_setup:
		return
	rng.randomize()
	name = "ForwardArenaDirector"
	visible = false
	_load_scene_assets()
	_create_materials()
	_create_ocean_battlefield_floor()
	_create_far_sky_layer()
	_create_mid_cloud_layer()
	_create_warzone_layer()
	_create_near_weather_layer()
	_create_distant_battle_layer()
	_create_boss_entity()
	_create_enemy_squadron()
	_create_explosion_pool()
	_create_missile_visual_pool()
	_create_visual_lock_composition_layer()
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
	if boss_entity != null and boss_entity.has_method("start_mission"):
		boss_entity.start_mission(stage_data)
	if enemy_squadron != null and enemy_squadron.has_method("start_mission"):
		enemy_squadron.start_mission(stage_data)
	_reset_explosions()


func stop_mission() -> void:
	active = false
	visible = false
	if boss_entity != null and boss_entity.has_method("stop_mission"):
		boss_entity.stop_mission()
	if player_projectile_visual_pool != null and player_projectile_visual_pool.has_method("clear_pool"):
		player_projectile_visual_pool.clear_pool()
	if enemy_projectile_visual_pool != null and enemy_projectile_visual_pool.has_method("clear_pool"):
		enemy_projectile_visual_pool.clear_pool()


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
	_update_air_enemies(delta)
	_update_missile_feedback()
	_update_explosions(delta)
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
		"rainGeometryMode": "haze_only_no_vertical_columns",
		"nearRainSheetCount": rain_sheets.size(),
		"lightningFlash": lightning_flash,
		"lightningOvercharge": overcharge_timer > 0.0,
		"overchargeSeconds": overcharge_timer,
		"stormHazard": storm_hazard,
		"bossAnchor": boss_entity != null,
		"bossName": "Dreadnought Leviathan",
		"combatPlaneY": CombatSpace.PLANE_Y,
		"underworldY": CombatSpace.UNDERWORLD_Y,
		"singlePlayfieldPlane": true,
		"missileVisualPoolSize": missile_visuals.size(),
		"missileTrailModel": "pooled_white_smoke_puffs_behind_fire_head",
		"explosionPoolSize": explosion_pool.size(),
		"explosionEvents": explosion_events_seen,
		"explosionVisibleCount": _visible_explosion_count(),
		"lastExplosionX": last_explosion_pos.x,
		"lastExplosionY": last_explosion_pos.y,
		"lastExplosionZ": last_explosion_pos.z,
		"explosionDynamicLights": 0,
		"pass3VFXPass": "air_enemies_and_emissive_explosions",
		"staticMatteBackdrop": false,
		"decorativeBulletNodes": 0,
		"enemyPoolRendered": (enemy_projectile_visual_pool.rendered_count if enemy_projectile_visual_pool != null else -1),
		"playerPoolRendered": (player_projectile_visual_pool.rendered_count if player_projectile_visual_pool != null else -1),
		"unhittableMidfieldEntities": 0,
		"pass1CausalityContract": "boss_entity_owns_state_bullets_from_visible_muzzles",
		"phase3DebugStatus": _phase3_debug_status(),
		"phase3QAContract": "pass1_combat_causality_v1",
		"phase3VisualSafety": "clean_hud_no_vertical_columns_no_cloud_geometry",
		"bossDamageFeedbackMode": boss_damage_feedback_mode,
		"bossImpactFeedbackSource": "boss_entity_part_hitbox_hits",
		"bossWeakpointVisual": boss_weakpoint_marker != null,
		"bossWeakpointVisualTarget": boss_visual_target_part,
		"bossWeakpointSocketBinding": boss_socket_binding,
		"bossMuzzleSocketBinding": boss_muzzle_socket_binding,
		"bossMuzzleSocketCount": _boss_muzzle_world_positions().size(),
		"bossMuzzleSocketNames": _boss_muzzle_socket_names(),
		"bossMuzzleSpreadX": _boss_muzzle_spread_x(),
		"bossSocketFireVFX": boss_socket_fire_mode,
		"bossPartDamageVFX": boss_part_damage_vfx_mode,
		"bossDestroyedPartVFXCount": boss_destroyed_part_visual_count,
		"bossPhaseTransitionEventsSeen": boss_phase_transition_events_seen,
		"bossPartDestructionEventsSeen": boss_part_destruction_events_seen,
		"bossImpactEvents": boss_impact_events_seen,
		"blenderPipeline": "bpy_4_5_14_generated_glb",
		"bossArenaAsset": "boss_dreadnought_leviathan_glb",
		"arenaAssetDeckCluster": arena_deck_cluster_scene != null,
		"stormOceanTextureAsset": storm_ocean_texture != null,
		"texturedBlenderAssets": storm_ocean_texture != null and arena_deck_texture != null and hero_shot_texture != null and enemy_shot_texture != null,
		"projectileAssetSprites": hero_shot_texture != null and enemy_shot_texture != null,
		"projectileVisualPool": player_projectile_visual_pool != null and enemy_projectile_visual_pool != null,
		"projectilePoolCount": _projectile_pool_count(),
		"projectileArchitecture": "pooled_multimesh_bound_to_logical_bullets",
		"cleanArenaOverlay": true,
		"shotDirectionMode": "xz_plane_velocity_aligned",
		"shotVisualOrientation": "velocity_aligned_flat_on_combat_plane",
		"playerShotFromHardpoint": true,
		"playerWeaponHardpointBinding": str(player_weapon_hardpoints.get("binding", "pending")),
		"playerShotSpawnOrigin": "glb_muzzle_socket" if bool(player_weapon_hardpoints.get("sockets_found", false)) else "runtime_fallback_socket",
		"playerGLBWeaponSocketsFound": bool(player_weapon_hardpoints.get("sockets_found", false)),
		"foundationCorrectionPass": "pass_1_combat_causality_and_playfield",
		"foundationVisualMode": foundation_visual_mode,
		"backgroundClutterMode": background_clutter_mode,
		"legacyVerticalShotColumns": false,
		"legacyNearCameraCyanPulseNodes": player_shot_pulses.size(),
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


func render_projectiles(enemy_bullets: Array, player_bullets: Array) -> void:
	# Bullets on screen are the logical bullets, one instance each.
	if enemy_projectile_visual_pool != null and enemy_projectile_visual_pool.has_method("render_bullets"):
		enemy_projectile_visual_pool.render_bullets(enemy_bullets)
	if player_projectile_visual_pool != null and player_projectile_visual_pool.has_method("render_bullets"):
		player_projectile_visual_pool.render_bullets(player_bullets)


func note_boss_hits(hits: Array) -> void:
	boss_impact_events_seen += hits.size()


func get_air_enemy_state() -> Dictionary:
	if enemy_squadron != null and enemy_squadron.has_method("get_bridge_state"):
		return Dictionary(enemy_squadron.get_bridge_state())
	return {"airEnemyEntities": false}


func _weather_effect_with_boss_state(strip_runtime_vectors: bool) -> Dictionary:
	var effect = get_weather_effect()
	if boss_entity != null and boss_entity.has_method("get_bridge_state"):
		var boss_state = boss_entity.get_bridge_state()
		for key in boss_state.keys():
			effect[key] = boss_state[key]
	var air_state := get_air_enemy_state()
	for air_key in air_state.keys():
		effect[air_key] = air_state[air_key]
	if strip_runtime_vectors:
		effect.erase("turbulence")
		effect.erase("bossPartHitboxes")
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
		ocean_mat = _make_textured_material(storm_ocean_texture, Color(0.135, 0.175, 0.235, 1.0), Color(0.0, 0.012, 0.025, 1.0), 1.0, false, false, 0.14)
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
	underworld_decor_mat = _make_material(Color(0.095, 0.115, 0.145, 1.0), Color.BLACK, 0.25, 1.0)
	arena_deck_mat = _make_textured_material(arena_deck_texture, Color(0.052, 0.072, 0.098, 1.0), Color(0.01, 0.03, 0.05, 1.0), 1.0, false, false)
	cinematic_matte_mat = _make_textured_material(cinematic_matte_texture, Color(1.0, 1.0, 1.0, 0.92), Color(0.04, 0.10, 0.15, 1.0), 0.38, true, true)


func _create_ocean_battlefield_floor() -> void:
	# Under-world layer: the sea sits far below the combat plane so it can never be
	# confused with a platform the player shares space with.
	if ocean_mat == null:
		return
	for i in range(5):
		var ocean = _plane_mesh("StormOceanTexturePlane_%02d" % i, Vector3(0.0, CombatSpace.UNDERWORLD_Y, -24.0 - i * 44.0), Vector2(78.0, 46.0), ocean_mat)
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
		chunk.position = Vector3(0.0, CombatSpace.UNDERWORLD_DECOR_Y, -24.0 - i * 22.0)
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
				_neutralize_underworld_decor(deck_cluster)
			else:
				var by = rng.randf_range(0.35, 1.1)
				chunk.add_child(_box_mesh("FallbackDeckModule_%02d" % b, Vector3(bx, by * 0.5, bz), Vector3(rng.randf_range(0.45, 0.95), by, rng.randf_range(0.45, 1.0)), city_mat))
		for f in range(2):
			var fire = _vfx_quad("GroundFirePocket_%02d" % f, Vector3(rng.randf_range(-10.0, -4.8) if f % 2 == 0 else rng.randf_range(4.8, 10.0), 0.80, rng.randf_range(-5.6, 5.6)), Vector2(rng.randf_range(0.5, 0.9), rng.randf_range(0.5, 1.0)), explosion_texture, Color(0.55, 0.20, 0.07, 0.42), 0.45)
			chunk.add_child(fire)
			fire_pockets.append(fire)
		for s in range(2):
			var smoke = _smoke_column("SmokeColumn_%02d" % s, Vector3(rng.randf_range(-10.5, -5.0) if s % 2 == 0 else rng.randf_range(5.0, 10.5), 1.0, rng.randf_range(-5.8, 5.8)))
			chunk.add_child(smoke)
			smoke_columns.append(smoke)
		add_child(chunk)
		warzone_chunks.append(chunk)


func _neutralize_underworld_decor(node: Node) -> void:
	# Under-world decoration must not use the player faction colour and must not
	# look like something that can be shot. Cyan radar balls, masts and pod markers
	# from the deck GLB are hidden; everything else is pushed down in value.
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node
		if str(mesh_node.name).contains("Cyan"):
			mesh_node.visible = false
		else:
			mesh_node.material_override = underworld_decor_mat
	for child in node.get_children():
		_neutralize_underworld_decor(child)


func _create_near_weather_layer() -> void:
	# Phase 3 debug lock: rain still affects visibility/gameplay through
	# rainVisibility, but the old tall near-camera blue sheets read like rejected
	# vertical shot columns in mobile screenshots. Keep the weather as haze/fog and
	# disable continuous vertical rain geometry for this forward-combat view.
	for i in range(0):
		var sheet = _box_mesh("RainSheet_%02d" % i, Vector3.ZERO, Vector3(rng.randf_range(0.025, 0.055), rng.randf_range(3.6, 8.4), rng.randf_range(0.025, 0.055)), rain_mat)
		sheet.position = Vector3(rng.randf_range(-8.5, 8.5), rng.randf_range(0.5, 6.0), -5.0 - rng.randf_range(0.0, 78.0))
		sheet.rotation_degrees = Vector3(rng.randf_range(-18.0, -8.0), 0.0, rng.randf_range(-15.0, 15.0))
		sheet.set_meta("speed_mul", rng.randf_range(1.18, 1.48))
		add_child(sheet)
		rain_sheets.append(sheet)
	for i in range(4):
		var debris = _box_mesh("NearDebrisStreak_%02d" % i, Vector3.ZERO, Vector3(rng.randf_range(0.06, 0.13), rng.randf_range(0.03, 0.08), rng.randf_range(0.8, 2.2)), debris_mat)
		debris.position = Vector3(rng.randf_range(-12.0, 12.0), CombatSpace.UNDERWORLD_DECOR_Y + rng.randf_range(0.5, 3.5), -8.0 - rng.randf_range(0.0, 95.0))
		debris.rotation_degrees = Vector3(rng.randf_range(-4.0, 4.0), rng.randf_range(-12.0, 12.0), rng.randf_range(-24.0, 24.0))
		debris.set_meta("speed_mul", rng.randf_range(1.10, 1.55))
		add_child(debris)
		debris_streaks.append(debris)


func _create_distant_battle_layer() -> void:
	# Pass 1: no unhittable jets or sourceless tracers inside the combat frame.
	for i in range(0):
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
	for i in range(0):
		var tracer_texture = hero_shot_texture if i % 2 == 0 else enemy_shot_texture
		var tracer = _vfx_forward_projectile_quad("DistantForwardTracer_%02d" % i, Vector3.ZERO, Vector2(0.14, rng.randf_range(2.8, 5.8)), tracer_texture, Color(0.78, 0.92, 1.0, 0.42), 0.75)
		tracer.position = Vector3(rng.randf_range(-14.0, 14.0), rng.randf_range(2.2, 8.8), -48.0 - rng.randf_range(0.0, 105.0))
		tracer.set_meta("speed_mul", rng.randf_range(0.42, 0.68))
		add_child(tracer)
		tracer_streaks.append(tracer)


func _create_visual_lock_composition_layer() -> void:
	# Pass 1 correction: no decorative bullets, no unhittable mid-field jets and no
	# static matte standing in for an entity. Only real systems are built here.
	_create_boss_gameplay_vfx_layer()
	_create_projectile_visual_pools()


func _create_boss_entity() -> void:
	boss_entity = BOSS_ENTITY_SCRIPT.new()
	add_child(boss_entity)
	if boss_entity.has_method("setup"):
		boss_entity.setup()
	boss_entity.position = Vector3(0.0, CombatSpace.PLANE_Y, CombatSpace.BOSS_Z)
	boss_anchor = boss_entity
	boss_phase_controller = boss_entity.phase_controller
	boss_glb_weakpoint_socket_found = bool(boss_entity.model_loaded)
	boss_glb_muzzle_sockets_found = bool(boss_entity.model_loaded)
	boss_socket_binding = "boss_entity_weakpoint_anchor"
	boss_muzzle_socket_binding = "boss_entity_live_turret_muzzles"


func set_projectile_manager(manager: Node) -> void:
	projectile_manager_ref = manager
	if manager != null and manager.has_method("set_boss_entity"):
		manager.set_boss_entity(boss_entity)
	if manager != null and manager.has_method("set_enemy_squadron"):
		manager.set_enemy_squadron(enemy_squadron)


func _update_air_enemies(delta: float) -> void:
	if enemy_squadron == null or not enemy_squadron.has_method("update_squadron"):
		return
	enemy_squadron.update_squadron(delta, last_player_corridor, stage_threat * 0.5 + storm_hazard * 0.3)
	# Every destroyed unit becomes one explosion: no visual without a state change.
	if enemy_squadron.has_method("consume_death_events"):
		for event_value in enemy_squadron.consume_death_events():
			var event: Dictionary = event_value
			spawn_explosion(event.get("pos", Vector3.ZERO), float(event.get("scale", 1.0)))


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
	# Only the target reticle lives here now. Impact sparks, muzzle flashes, damage
	# smoke and destruction visuals are owned by BossEntity3D, next to the state
	# that causes them.
	boss_damage_feedback_mode = "boss_entity_part_flash_and_impact_sparks"
	if reticle_texture != null:
		boss_weakpoint_marker = _vfx_quad("BossWeakpointReticle_Entity", Vector3.ZERO, Vector2(5.2, 5.2), reticle_texture, Color(0.68, 0.98, 1.0, 0.62), 2.2)
	else:
		boss_weakpoint_marker = _vfx_quad("BossWeakpointReticleFallback", Vector3.ZERO, Vector2(4.4, 4.4), hero_shot_texture, Color(0.68, 0.98, 1.0, 0.56), 2.0)
	if boss_weakpoint_marker != null:
		boss_weakpoint_marker.visible = false
		var marker_mat := boss_weakpoint_marker.material_override as StandardMaterial3D
		if marker_mat != null:
			marker_mat.no_depth_test = true
		add_child(boss_weakpoint_marker)
	boss_part_damage_vfx_mode = "boss_entity_owned_part_smoke"
	boss_socket_fire_mode = "boss_entity_muzzle_flash"


func _reset_boss_gameplay_vfx() -> void:
	boss_impact_events_seen = 0
	boss_destroyed_part_visual_count = 0
	boss_phase_transition_events_seen = 0
	boss_last_phase_transition_count = 0
	boss_part_destruction_events_seen = 0
	boss_last_part_destruction_count = 0
	boss_visual_target_part = "shield"
	if boss_weakpoint_marker != null:
		boss_weakpoint_marker.visible = false


func _update_boss_gameplay_vfx(delta: float) -> void:
	var boss_state: Dictionary = {}
	if boss_entity != null and boss_entity.has_method("get_bridge_state"):
		boss_state = boss_entity.get_bridge_state()
		boss_visual_target_part = str(boss_state.get("bossTargetablePart", boss_visual_target_part))
		var transition_count: int = int(boss_state.get("bossPhaseTransitionCount", 0))
		if transition_count > boss_last_phase_transition_count:
			boss_phase_transition_events_seen += transition_count - boss_last_phase_transition_count
			boss_last_phase_transition_count = transition_count
		var destruction_count: int = int(boss_state.get("bossPartDestructionEvents", 0))
		if destruction_count > boss_last_part_destruction_count:
			boss_part_destruction_events_seen += destruction_count - boss_last_part_destruction_count
			boss_last_part_destruction_count = destruction_count
		boss_destroyed_part_visual_count = int(boss_state.get("bossDestroyedParts", 0))
	if boss_weakpoint_marker != null:
		boss_weakpoint_marker.visible = active
		if active:
			boss_weakpoint_marker.global_position = _boss_weakpoint_world_position(boss_visual_target_part) + Vector3(0.0, 0.0, 2.2)
			boss_weakpoint_marker.rotation_degrees = Vector3(74.0, 0.0, 0.0)
			var marker_pulse: float = 1.0 + sin(forward_time * 5.6) * 0.07
			boss_weakpoint_marker.scale = Vector3.ONE * marker_pulse


func _boss_weakpoint_world_position(part_name: String) -> Vector3:
	if boss_entity != null and boss_entity.has_method("get_part_world_position"):
		return boss_entity.get_part_world_position(part_name)
	return Vector3(0.0, CombatSpace.PLANE_Y, CombatSpace.BOSS_Z)


func _boss_muzzle_world_positions() -> Array:
	if boss_entity != null and boss_entity.has_method("get_live_muzzle_positions"):
		return boss_entity.get_live_muzzle_positions()
	return []


func _boss_muzzle_socket_names() -> Array:
	return ["LargeAATurret_00", "LargeAATurret_01", "LargeAATurret_02", "LargeAATurret_03", "Boss_Muzzle_Core"]


func _boss_muzzle_spread_x() -> float:
	var origins: Array = _boss_muzzle_world_positions()
	if origins.size() < 2:
		return 0.0
	var min_x := 99999.0
	var max_x := -99999.0
	for origin_value in origins:
		if origin_value is Vector3:
			var origin: Vector3 = origin_value
			min_x = min(min_x, origin.x)
			max_x = max(max_x, origin.x)
	return max(0.0, max_x - min_x)


func _phase3_debug_status() -> String:
	if boss_entity != null and boss_impact_events_seen > 0:
		return "boss_entity_causality_locked"
	return "phase3_debug_waiting_for_runtime_events"


func _create_enemy_squadron() -> void:
	enemy_squadron = ENEMY_SQUADRON_SCRIPT.new()
	add_child(enemy_squadron)
	if enemy_squadron.has_method("setup"):
		enemy_squadron.setup()
	enemy_squadron.position = Vector3.ZERO


func _create_explosion_pool() -> void:
	# Pass 3, item 2: flash + fireball + smoke + debris, emissive only.
	# No dynamic light is created per explosion.
	explosion_pool.clear()
	for i in range(10):
		var root := Node3D.new()
		root.name = "Explosion_%02d" % i
		root.visible = false
		add_child(root)
		var flash := _explosion_quad("ExplosionFlash_%02d" % i, Vector2(1.5, 1.5), explosion_texture, Color(1.0, 0.94, 0.78, 1.0), 5.0)
		var fireball := _explosion_quad("ExplosionFireball_%02d" % i, Vector2(1.5, 1.5), explosion_texture, Color(1.0, 0.44, 0.10, 1.0), 5.0)
		var smoke := _vfx_quad("ExplosionSmoke_%02d" % i, Vector3(0.0, 0.6, 0.0), Vector2(1.8, 1.8), smoke_texture, Color(0.20, 0.17, 0.17, 0.8), 0.0)
		root.add_child(flash)
		root.add_child(fireball)
		root.add_child(smoke)
		var debris: Array = []
		for d in range(5):
			var shard := _explosion_quad("ExplosionDebris_%02d_%d" % [i, d], Vector2(0.22, 0.46), explosion_texture, Color(1.0, 0.62, 0.24, 1.0), 4.0)
			root.add_child(shard)
			debris.append(shard)
		explosion_pool.append({
			"root": root,
			"flash": flash,
			"fireball": fireball,
			"smoke": smoke,
			"debris": debris,
			"timer": 0.0,
			"life": 1.0,
			"scale": 1.0,
			"dirs": []
		})


func _create_missile_visual_pool() -> void:
	# Pass 3, item 3: every logical missile gets a fire head and a white smoke
	# trail. Both are pooled quads - nothing is instanced at fire time.
	missile_visuals.clear()
	for i in range(12):
		var root := Node3D.new()
		root.name = "Missile_%02d" % i
		root.visible = false
		add_child(root)
		var head := _explosion_quad("MissileHead_%02d" % i, Vector2(1.15, 1.15), explosion_texture, Color(1.0, 0.78, 0.34, 1.0), 6.0)
		var flame := _explosion_quad("MissileFlame_%02d" % i, Vector2(0.8, 1.7), explosion_texture, Color(1.0, 0.36, 0.06, 1.0), 4.5)
		flame.position = Vector3(0.0, 0.0, -0.95)
		root.add_child(head)
		root.add_child(flame)
		var puffs: Array = []
		for p in range(12):
			var puff := _vfx_quad("MissileSmoke_%02d_%02d" % [i, p], Vector3.ZERO, Vector2(0.85, 0.85), smoke_texture, Color(0.96, 0.94, 0.92, 0.7), 0.0)
			puff.visible = false
			add_child(puff)
			puffs.append(puff)
		missile_visuals.append({"root": root, "head": head, "flame": flame, "puffs": puffs})


func render_missiles(missiles: Array) -> void:
	for i in range(missile_visuals.size()):
		var entry: Dictionary = missile_visuals[i]
		var root: Node3D = entry["root"]
		var puffs: Array = entry["puffs"]
		if i >= missiles.size() or not bool((missiles[i] as Dictionary).get("active", false)):
			root.visible = false
			for puff_value in puffs:
				(puff_value as MeshInstance3D).visible = false
			continue
		var missile: Dictionary = missiles[i]
		var pos: Vector3 = missile.get("pos", Vector3.ZERO)
		root.position = pos
		root.visible = pos.z <= 2.0
		var head: MeshInstance3D = entry["head"]
		var flame: MeshInstance3D = entry["flame"]
		var flicker: float = 0.82 + 0.18 * sin(forward_time * 26.0 + float(i))
		head.scale = Vector3.ONE * flicker
		flame.scale = Vector3(1.0, 1.0, 1.0) * (0.85 + 0.3 * (1.0 - flicker))
		var trail: Array = missile.get("trail", [])
		for p in range(puffs.size()):
			var puff: MeshInstance3D = puffs[p]
			if p >= trail.size():
				puff.visible = false
				continue
			var fade: float = 1.0 - float(p) / float(puffs.size())
			var puff_pos: Vector3 = trail[p]
			# A puff that drifts past the player would fill the screen as a
			# billboard right in front of the camera: cull it instead.
			if puff_pos.z > 1.0:
				puff.visible = false
				continue
			puff.visible = true
			puff.position = puff_pos
			puff.scale = Vector3.ONE * (0.55 + (1.0 - fade) * 0.95)
			_set_vfx_alpha(puff, fade * 0.72)


func _update_missile_feedback() -> void:
	if projectile_manager_ref == null:
		return
	if projectile_manager_ref.has_method("get_missiles"):
		render_missiles(projectile_manager_ref.get_missiles())
	if projectile_manager_ref.has_method("consume_missile_impacts"):
		for impact_value in projectile_manager_ref.consume_missile_impacts():
			var impact: Dictionary = impact_value
			spawn_explosion(Vector3(float(impact.get("x", 0.0)), CombatSpace.PLANE_Y, float(impact.get("z", 0.0))), 0.75)


func _reset_explosions() -> void:
	for entry in explosion_pool:
		entry["timer"] = 0.0
		var root: Node3D = entry["root"]
		root.visible = false


func spawn_explosion(world_pos: Vector3, scale_mul: float = 1.0) -> void:
	if explosion_pool.is_empty():
		return
	var entry: Dictionary = explosion_pool[explosion_cursor % explosion_pool.size()]
	explosion_cursor += 1
	explosion_events_seen += 1
	var root: Node3D = entry["root"]
	root.position = world_pos
	root.visible = true
	last_explosion_pos = world_pos
	entry["timer"] = 0.0
	entry["life"] = 1.55 + scale_mul * 0.45
	entry["scale"] = scale_mul
	var dirs: Array = []
	for i in range(entry["debris"].size()):
		var angle: float = rng.randf_range(0.0, TAU)
		dirs.append(Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(4.5, 9.0) * scale_mul)
	entry["dirs"] = dirs


func _explosion_quad(node_name: String, size: Vector2, texture: Texture2D, tint: Color, emission_energy: float) -> MeshInstance3D:
	# Additive, unshaded, billboarded: an explosion must add light to the frame
	# without any dynamic light being created for it.
	var quad := _vfx_quad(node_name, Vector3.ZERO, size, texture, tint, emission_energy)
	var mat := quad.material_override as StandardMaterial3D
	if mat != null:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.disable_receive_shadows = true
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return quad


func _visible_explosion_count() -> int:
	var count := 0
	for entry in explosion_pool:
		var root: Node3D = entry["root"]
		if root != null and root.visible:
			count += 1
	return count


func _update_explosions(delta: float) -> void:
	for entry in explosion_pool:
		var root: Node3D = entry["root"]
		if not root.visible:
			continue
		entry["timer"] = float(entry["timer"]) + delta
		var life: float = float(entry["life"])
		var t: float = clampf(float(entry["timer"]) / maxf(0.08, life), 0.0, 1.0)
		var scale_mul: float = float(entry["scale"])
		var flash: MeshInstance3D = entry["flash"]
		var fireball: MeshInstance3D = entry["fireball"]
		var smoke: MeshInstance3D = entry["smoke"]
		var flash_t: float = clampf(float(entry["timer"]) / 0.22, 0.0, 1.0)
		flash.visible = flash_t < 1.0
		flash.scale = Vector3.ONE * (0.45 + flash_t * 0.75) * scale_mul
		_set_vfx_alpha(flash, (1.0 - flash_t) * 0.9)
		fireball.scale = Vector3.ONE * (0.40 + t * 1.15) * scale_mul
		_set_vfx_alpha(fireball, pow(1.0 - t, 1.05) * 1.0)
		smoke.scale = Vector3.ONE * (0.5 + t * 1.5) * scale_mul
		smoke.position.y = 0.4 + t * 2.4
		_set_vfx_alpha(smoke, (1.0 - t) * 0.6)
		var dirs: Array = entry["dirs"]
		for i in range(entry["debris"].size()):
			var shard: MeshInstance3D = entry["debris"][i]
			if i >= dirs.size():
				continue
			var dir: Vector3 = dirs[i]
			shard.position = dir * t + Vector3(0.0, 1.4 * t - 3.4 * t * t, 0.0)
			shard.scale = Vector3.ONE * (1.0 - t * 0.5) * scale_mul
			_set_vfx_alpha(shard, (1.0 - t) * 0.9)
		if t >= 1.0:
			root.visible = false


func _set_vfx_alpha(node: MeshInstance3D, alpha: float) -> void:
	var mat := node.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_color = Color(mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b, clampf(alpha, 0.0, 1.0))


func _create_projectile_visual_pools() -> void:
	# Both pools are bound renderers for the logical bullet arrays.
	# Readability order: enemy bullets are brighter and thicker than player fire.
	if hero_shot_texture != null:
		player_projectile_visual_pool = PROJECTILE_VISUAL_POOL_SCRIPT.new()
		add_child(player_projectile_visual_pool)
		player_projectile_visual_pool.setup_bound(
			"player_cyan_plasma",
			hero_shot_texture,
			Color(0.56, 0.95, 1.0, 0.68),
			80,
			Vector2(0.55, 2.60),
			2.0
		)
	if enemy_shot_texture != null:
		enemy_projectile_visual_pool = PROJECTILE_VISUAL_POOL_SCRIPT.new()
		add_child(enemy_projectile_visual_pool)
		enemy_projectile_visual_pool.setup_bound(
			"enemy_orange_bolts",
			enemy_shot_texture,
			Color(1.0, 0.64, 0.34, 1.0),
			160,
			Vector2(1.05, 3.00),
			4.4
		)


func _projectile_pool_count() -> int:
	var count = 0
	if player_projectile_visual_pool != null and player_projectile_visual_pool.has_method("get_pool_count"):
		count += int(player_projectile_visual_pool.get_pool_count())
	if enemy_projectile_visual_pool != null and enemy_projectile_visual_pool.has_method("get_pool_count"):
		count += int(enemy_projectile_visual_pool.get_pool_count())
	return count

func _update_boss_phase_logic(delta: float) -> void:
	if boss_entity == null or not boss_entity.has_method("update_boss"):
		return
	var overcharged: bool = overcharge_timer > 0.0
	var pressure: float = 1.0 + (0.30 if overcharged else 0.0) + lightning_flash * 0.22
	boss_entity.update_boss(delta, overcharged, pressure)


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
	for i in range(ocean_floor_planes.size()):
		ocean_floor_planes[i].position = Vector3(0.0, CombatSpace.UNDERWORLD_Y, -24.0 - i * 44.0)
	for i in range(warzone_chunks.size()):
		warzone_chunks[i].position = Vector3(0.0, CombatSpace.UNDERWORLD_DECOR_Y, -24.0 - i * 22.0)
	for debris in debris_streaks:
		debris.position = Vector3(rng.randf_range(-12.0, 12.0), CombatSpace.UNDERWORLD_DECOR_Y + rng.randf_range(0.5, 3.5), -8.0 - rng.randf_range(0.0, 95.0))
	if boss_entity:
		boss_entity.position = Vector3(0.0, CombatSpace.PLANE_Y, CombatSpace.BOSS_Z)


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
		ocean.position.y = CombatSpace.UNDERWORLD_Y
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
			debris.position = Vector3(rng.randf_range(-12.0, 12.0), CombatSpace.UNDERWORLD_DECOR_Y + rng.randf_range(0.5, 3.5), -100.0 - rng.randf_range(0.0, 35.0))


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


func _update_visual_lock_composition(delta: float, _travel_speed: float) -> void:
	if boss_entity != null:
		boss_entity.position.x = sin(forward_time * 0.17) * 1.1
		boss_entity.position.z = CombatSpace.BOSS_Z + sin(forward_time * 0.22) * 1.6
		boss_entity.rotation_degrees.z = sin(forward_time * 0.19) * 1.2
	_update_boss_gameplay_vfx(delta)


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
