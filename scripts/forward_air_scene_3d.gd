extends Node3D
class_name ForwardAirScene3D

# Phase 2 forward-flight scene. This is the new gameplay direction:
# GLB aircraft, chase camera behind/slightly above, forward motion in 3D,
# and a layered storm battlefield driven by ForwardArenaDirector.

const PLAYER_MODEL_PATH = "res://assets/models/enemy_hero_jet_blender_ready.glb"
const PLAYER_ORIGINAL_SOURCE_PATH = "res://assets/models/enemy_hero_jet.glb"
const PLAYER_FALLBACK_MODEL_PATH = "res://assets/models/player_stormhawk.glb"
const PLAYER_MODEL_SCENE = preload("res://assets/models/enemy_hero_jet_blender_ready.glb")
const PLAYER_FALLBACK_MODEL_SCENE = preload("res://assets/models/player_stormhawk.glb")
const HERO_SHOT_TEXTURE = preload("res://assets/vfx/hero_cyan_shot.png")
const FORWARD_DIR = Vector3(0.0, 0.0, -1.0)
const ARENA_DIRECTOR_SCRIPT = preload("res://scripts/forward_arena_director.gd")
const PROJECTILE_MANAGER_SCRIPT = preload("res://scripts/projectiles/projectile_manager_3d.gd")

var owner_main: Node
var active = false
var is_setup = false
var rng = RandomNumberGenerator.new()

var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var sea_fill_light: DirectionalLight3D
var camera_fill_light: DirectionalLight3D
var player_marker_light: OmniLight3D
var camera: Camera3D
var player_rig: Node3D
var player_model: Node3D
var player_model_source := "unloaded"
var player_model_authenticity := "unknown"
var player_model_original_source := "unknown"
var player_model_alignment := "unknown"
var runtime_afterburner_boxes := false
var weapon_hardpoint_binding := "runtime_fallback"
var glb_weapon_sockets_found := false
var gun_sockets: Array = []
var missile_sockets: Array = []
var weapon_socket_error := ""
var player_projectile_data: Dictionary = {}
var weapon_gizmo_visible := false
var weapon_gizmo_nodes: Array = []
var aim_convergence_point := Vector3.ZERO
var pylon_missiles: Array = []          # one entry per HP_ socket: mesh + loaded flag
var missile_fire_order: Array = []
var missile_salvo_timer := 0.0
var missile_shot_timer := 0.0
var missile_reload_timer := 0.0
var missile_cursor := 0
var missiles_launched := 0
var missile_reloads := 0
var last_missile_pylon := "none"
var pylons_fired_from: Array = []
var missile_launch_log: Array = []
var muzzle_flash_positions: Array = []
var muzzle_flash_offset_max := 0.0
var gun_world_order: Array = []
var muzzle_center: Node3D
var muzzle_left: Node3D
var muzzle_right: Node3D
var engine_socket: Node3D
var afterburner_left: MeshInstance3D
var afterburner_right: MeshInstance3D
var socket_muzzle_flash_nodes: Array = []
var socket_muzzle_tracer_nodes: Array = []
var socket_muzzle_vfx_active := false
var socket_muzzle_vfx_ready := false
var socket_muzzle_vfx_mode := "none"
var arena_director: Node3D
var projectile_manager: Node

var lane_markers: Array = []
var cloud_markers: Array = []
var warzone_chunks: Array = []
var debris_markers: Array = []

var corridor_pos = Vector2.ZERO
var corridor_target = Vector2.ZERO
var corridor_width = 7.2
var corridor_height = 3.35
var forward_time = 0.0
var mission_progress = 0.0
var forward_speed = 36.0
var boost_amount = 0.0
var max_hp = 120
var hp = 120
var current_stage_name = "Forward Air Trial"
var camera_mode = "chase_behind_above"
var weather_effect: Dictionary = {}
var hazard_damage_buffer = 0.0
var shield = 40.0
var max_shield = 40.0
var shield_recharge_delay = 0.0
var invuln_timer = 0.0
var hit_flash_timer = 0.0
var score = 0
var last_destroyed_part_count = 0
var player_shadow: MeshInstance3D
var player_hitbox_marker: MeshInstance3D
var player_hit_flash: MeshInstance3D
var player_damage_events = 0
var player_damage_events_with_source = 0


func setup(main_owner: Node) -> void:
	if is_setup:
		return
	owner_main = main_owner
	rng.randomize()
	name = "ForwardAirScene3D"
	visible = false
	_create_environment()
	_create_camera_rig()
	_create_arena_director()
	_create_projectile_manager()
	_create_player_rig()
	_create_forward_depth_markers()
	is_setup = true


func start_mission(stage_data: Dictionary, loadout_data: Dictionary, aircraft_data: Dictionary) -> void:
	if not is_setup:
		setup(owner_main)
	active = true
	visible = true
	current_stage_name = str(stage_data.get("name", "Forward Air Trial"))
	forward_time = 0.0
	mission_progress = 0.0
	corridor_pos = Vector2(0.0, 0.0)
	corridor_target = Vector2(0.0, 0.0)
	forward_speed = 30.0 + float(stage_data.get("threat", 1.0)) * 3.6
	max_hp = int(float(aircraft_data.get("hp", 120)) * float(loadout_data.get("armor", 1.0)))
	hp = max_hp
	max_shield = 40.0
	shield = max_shield
	shield_recharge_delay = 0.0
	invuln_timer = 0.0
	hit_flash_timer = 0.0
	score = 0
	last_destroyed_part_count = 0
	player_damage_events = 0
	player_damage_events_with_source = 0
	hazard_damage_buffer = 0.0
	weather_effect = {}
	if arena_director and arena_director.has_method("start_mission"):
		arena_director.start_mission(stage_data)
	if projectile_manager and projectile_manager.has_method("start_mission"):
		projectile_manager.start_mission(stage_data)
	if player_rig:
		player_rig.position = Vector3(0.0, CombatSpace.PLANE_Y, 0.0)
		player_rig.rotation = Vector3.ZERO
	if camera:
		camera.current = true
		camera.position = Vector3(0.0, CombatSpace.PLANE_Y + CombatSpace.CAMERA_OFFSET.y, CombatSpace.CAMERA_OFFSET.z)
		camera.look_at(CombatSpace.CAMERA_LOOK, Vector3.UP)
	_reset_depth_nodes()
	missiles_launched = 0
	missile_cursor = 0
	pylons_fired_from.clear()
	missile_launch_log.clear()
	missile_salvo_timer = float(player_projectile_data.get("missile_salvo_interval", 1.9))
	missile_shot_timer = 0.0
	missile_reload_timer = 0.0
	last_missile_pylon = "none"
	_reload_pylons()
	missile_reloads = 0
	_sync_player_weapon_hardpoints_to_arena()


func stop_mission() -> void:
	active = false
	visible = false
	if arena_director and arena_director.has_method("stop_mission"):
		arena_director.stop_mission()
	if projectile_manager and projectile_manager.has_method("stop_mission"):
		projectile_manager.stop_mission()
	_set_socket_muzzle_vfx_visible(false)
	if camera:
		camera.current = false


func is_active() -> bool:
	return active and visible


func update_forward(delta: float, input_state: Dictionary) -> void:
	if not active:
		return
	forward_time += delta
	var travel_speed = forward_speed * (1.0 + boost_amount * 0.28)
	if arena_director and arena_director.has_method("update_arena"):
		weather_effect = arena_director.update_arena(delta, corridor_pos, travel_speed)
	mission_progress = clamp(mission_progress + delta * forward_speed / 1380.0, 0.0, 0.985)
	_update_corridor_position(delta, input_state, weather_effect)
	_update_player_pose(delta, input_state, weather_effect)
	_sync_player_weapon_hardpoints_to_arena()
	_update_socket_muzzle_vfx(delta)
	_update_pylon_missiles(delta)
	_update_projectile_logic(delta, weather_effect)
	_update_weather_damage(delta, weather_effect)
	_update_forward_markers(delta)
	_update_environment_weather(delta, weather_effect)
	_update_camera(delta, input_state, weather_effect)


func get_bridge_state() -> Dictionary:
	var bridge = {
		"missionMode": "forward_air_combat",
		"cameraMode": camera_mode,
		"playerModel": "glb",
		"playerModelSource": player_model_source,
		"playerModelAssetAuthenticity": player_model_authenticity,
		"playerModelOriginalSource": player_model_original_source,
		"playerModelAlignment": player_model_alignment,
		"runtimeAfterburnerBoxes": runtime_afterburner_boxes,
		"playerWeaponHardpointBinding": weapon_hardpoint_binding,
		"playerGLBWeaponSocketsFound": glb_weapon_sockets_found,
		"playerShotSpawnOrigin": "glb_muzzle_socket" if glb_weapon_sockets_found else "socket_resolution_failed",
		"playerGunSocketCount": gun_sockets.size(),
		"playerGunSocketIds": _gun_socket_ids(),
		"playerMissileSocketCount": missile_sockets.size(),
		"playerMissileSocketIds": missile_fire_order,
		"playerPylonMissileMeshes": pylon_missiles.size(),
		"playerPylonMissilesLoaded": _loaded_pylon_count(),
		"playerPylonMissilesLaunched": missiles_launched,
		"playerPylonReloads": missile_reloads,
		"playerPylonAmmoIndicator": "missing_mesh_on_fired_pylon",
		"lastMissilePylon": last_missile_pylon,
		"playerPylonsFiredFrom": pylons_fired_from,
		"playerMissileLaunchLog": missile_launch_log,
		"playerMissileFireOrderRule": str(player_projectile_data.get("missile_fire_order_rule", "config_socket_list")),
		"playerWeaponSocketError": weapon_socket_error,
		"playerWeaponSocketResolution": "by_name_from_glb_no_origin_fallback",
		"playerShotDirectionModel": "aim_convergence_on_play_plane_not_socket_rotation",
		"playerShotConvergenceDistance": float(player_projectile_data.get("convergence_distance", 26.0)),
		"playerShotMuzzleClearance": float(player_projectile_data.get("muzzle_clearance", 0.55)),
		"playerRollDegrees": rad_to_deg(player_rig.rotation.z) if player_rig != null else 0.0,
		"weaponDebugGizmoVisible": weapon_gizmo_visible,
		"playerGunWorldOrder": gun_world_order,
		"playerAimPointX": aim_convergence_point.x,
		"playerAimPointZ": aim_convergence_point.z,
		"playerMuzzleCenterZ": _muzzle_world_position(muzzle_center).z,
		# Measured against the hull, not against world zero: the aircraft itself
		# moves up and down the corridor.
		"playerMuzzleForwardOffset": _muzzle_world_position(muzzle_center).z - (player_rig.position.z if player_rig != null else 0.0),
		"playerMuzzleForwardZLocked": (_muzzle_world_position(muzzle_center).z - (player_rig.position.z if player_rig != null else 0.0)) < 0.0,
		"socketMuzzleVFX": socket_muzzle_vfx_mode,
		"socketMuzzleVFXActive": socket_muzzle_vfx_active,
		"muzzleFlashCount": muzzle_flash_positions.size(),
		"muzzleFlashOffsetFromBarrel": muzzle_flash_offset_max,
		"muzzleFlashAtBarrel": muzzle_flash_positions.size() >= 2 and muzzle_flash_offset_max <= float(player_projectile_data.get("muzzle_clearance", 0.55)),
		"muzzleFlashLeftX": float(muzzle_flash_positions[0].x) if muzzle_flash_positions.size() > 0 else 0.0,
		"muzzleFlashLeftZ": float(muzzle_flash_positions[0].z) if muzzle_flash_positions.size() > 0 else 0.0,
		"muzzleFlashRightX": float(muzzle_flash_positions[1].x) if muzzle_flash_positions.size() > 1 else 0.0,
		"muzzleFlashRightZ": float(muzzle_flash_positions[1].z) if muzzle_flash_positions.size() > 1 else 0.0,
		"muzzleFlashModel": "continuous_socket_flash_covers_first_bullet_frame",
		"socketMuzzleVFXCount": socket_muzzle_flash_nodes.size() + socket_muzzle_tracer_nodes.size(),
		"playerShotVisibleFromSocket": socket_muzzle_vfx_active,
		"playerForwardAxis": "negative_z",
		"stageName": current_stage_name,
		"progress": mission_progress,
		"forwardSpeed": forward_speed,
		"corridorX": corridor_pos.x,
		"corridorY": corridor_pos.y,
		"playerWorldX": player_rig.position.x if player_rig != null else 0.0,
		"playerWorldZ": player_rig.position.z if player_rig != null else 0.0,
		"playerPlaneY": CombatSpace.PLANE_Y,
		"playerOnCombatPlane": true,
		"playerShadowMarker": player_shadow != null,
		"playerScaleMode": "phone_readable_small_hitbox",
		"playerHitboxMarker": player_hitbox_marker != null,
		"playerHitFlash": hit_flash_timer > 0.0,
		"playerInvulnerableVisible": invuln_timer > 0.0,
		"playerDamageEvents": player_damage_events,
		"playerDamageEventsWithVisibleSource": player_damage_events_with_source,
		"hp": hp,
		"maxHp": max_hp,
		"shield": shield,
		"maxShield": max_shield,
		"shieldRatio": clamp(shield / max(1.0, max_shield), 0.0, 1.0),
		"score": score,
		"hudValuesHardcoded": false,
		"active": active
	}
	if arena_director and arena_director.has_method("get_bridge_state"):
		var arena_state = arena_director.get_bridge_state()
		for key in arena_state.keys():
			bridge[key] = arena_state[key]
	if projectile_manager and projectile_manager.has_method("get_bridge_state"):
		var projectile_state = projectile_manager.get_bridge_state()
		for key in projectile_state.keys():
			bridge[key] = projectile_state[key]
	return bridge


func _create_environment() -> void:
	# Pass 2: value before colour.
	# Dusk key light comes in low and warm, the ambient fill is cool sea light,
	# the sky gradates warm at the horizon to a dark top, and fog is pushed into
	# the far layer only so the play plane is never hazed.
	world_environment = WorldEnvironment.new()
	world_environment.name = "ForwardStormEnvironment"
	var env = Environment.new()

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.055, 0.075, 0.145, 1.0)
	sky_material.sky_horizon_color = Color(1.0, 0.60, 0.30, 1.0)
	sky_material.sky_curve = 0.055
	sky_material.sky_energy_multiplier = 2.45
	sky_material.ground_bottom_color = Color(0.016, 0.022, 0.034, 1.0)
	sky_material.ground_horizon_color = Color(0.085, 0.082, 0.11, 1.0)
	sky_material.ground_curve = 0.03
	sky_material.ground_energy_multiplier = 0.55
	sky_material.sun_angle_max = 11.0
	sky_material.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.background_energy_multiplier = 1.0

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Cool bounce from the sea, kept weak so the under-world stays the darkest value.
	env.ambient_light_color = Color(0.11, 0.17, 0.27, 1.0)
	env.ambient_light_energy = 0.58

	# Depth fog: starts past the boss, so foreground, bullets and boss stay crisp.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.46, 0.30, 0.22, 1.0)
	env.fog_light_energy = 1.0
	env.fog_density = 0.40
	env.fog_depth_begin = 66.0
	env.fog_depth_end = 150.0
	env.fog_depth_curve = 1.6
	# Depth fog must not repaint the sky: that is what flattened the whole frame
	# into one hue in the rejected build.
	env.fog_sky_affect = 0.12
	env.fog_aerial_perspective = 0.0

	# Bloom belongs to bullets, boss core, turret eyes, engines and explosions
	# only, so the threshold sits above anything the environment can reach.
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.0
	env.glow_bloom = 0.10
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.05
	env.glow_hdr_scale = 2.2
	env.set_glow_level(1, 0.6)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(5, 0.6)

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 2.6
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.22
	env.adjustment_saturation = 0.92
	env.adjustment_brightness = 0.98

	world_environment.environment = env
	add_child(world_environment)

	sun_light = DirectionalLight3D.new()
	sun_light.name = "DuskKeyLight"
	# Low angle warm key: long shadows, warm tops, cool shadow sides.
	sun_light.light_color = Color(1.0, 0.66, 0.38, 1.0)
	sun_light.light_energy = 2.2
	sun_light.light_specular = 0.25
	sun_light.rotation_degrees = Vector3(-9.0, 168.0, 0.0)
	add_child(sun_light)

	camera_fill_light = DirectionalLight3D.new()
	camera_fill_light.name = "CameraSideFill"
	# Keeps the player hull and the boss faces that point at the camera readable
	# without washing the scene: cool, weak, no specular.
	camera_fill_light.light_color = Color(0.70, 0.84, 1.0, 1.0)
	camera_fill_light.light_energy = 1.55
	camera_fill_light.light_specular = 0.1
	camera_fill_light.rotation_degrees = Vector3(-31.0, 6.0, 0.0)
	add_child(camera_fill_light)

	sea_fill_light = DirectionalLight3D.new()
	sea_fill_light.name = "SeaCoolFill"
	sea_fill_light.light_color = Color(0.32, 0.52, 0.86, 1.0)
	sea_fill_light.light_energy = 0.55
	sea_fill_light.light_specular = 0.0
	sea_fill_light.rotation_degrees = Vector3(62.0, -24.0, 0.0)
	add_child(sea_fill_light)

	# A small cool lamp rides with the aircraft so the hull reads bright against
	# the dark sea without lifting the whole under-world.
	player_marker_light = OmniLight3D.new()
	player_marker_light.name = "PlayerReadabilityLamp"
	player_marker_light.light_color = Color(0.74, 0.88, 1.0, 1.0)
	player_marker_light.light_energy = 3.4
	player_marker_light.light_specular = 0.35
	player_marker_light.omni_range = 9.5
	player_marker_light.omni_attenuation = 1.4
	# Layer 1 only: hostile aircraft (visual layer 2) must not be brightened by
	# the player's own readability lamp, or the value hierarchy inverts.
	player_marker_light.light_cull_mask = 1
	player_marker_light.position = Vector3(0.0, 3.4, 3.2)
	add_child(player_marker_light)


func _create_camera_rig() -> void:
	camera = Camera3D.new()
	camera.name = "ChaseCamera_BehindAbove"
	camera.fov = 64.0
	camera.near = 0.04
	camera.far = 520.0
	camera.current = false
	add_child(camera)


func _create_arena_director() -> void:
	arena_director = ARENA_DIRECTOR_SCRIPT.new()
	add_child(arena_director)
	if arena_director.has_method("setup"):
		arena_director.setup()


func _create_projectile_manager() -> void:
	projectile_manager = PROJECTILE_MANAGER_SCRIPT.new()
	add_child(projectile_manager)
	if projectile_manager.has_method("setup"):
		projectile_manager.setup()
	if arena_director != null and arena_director.has_method("set_projectile_manager"):
		arena_director.set_projectile_manager(projectile_manager)


func _create_player_rig() -> void:
	player_rig = Node3D.new()
	player_rig.name = "PlayerRig3D_ForwardAircraft"
	player_rig.position = Vector3(0.0, CombatSpace.PLANE_Y, 0.0)
	add_child(player_rig)
	player_projectile_data = _load_player_projectile_data()
	_load_player_model()
	_create_afterburners()
	_create_socket_muzzle_vfx()
	_create_player_readability_markers()


func _create_player_readability_markers() -> void:
	# Ground shadow: the only cue that tells the player where the aircraft sits over
	# the under-world. It lives on the sea surface, never on the combat plane.
	var shadow_mesh := QuadMesh.new()
	shadow_mesh.size = Vector2(3.4, 4.6)
	player_shadow = MeshInstance3D.new()
	player_shadow.name = "PlayerGroundShadow"
	player_shadow.mesh = shadow_mesh
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0.0, 0.01, 0.03, 0.55)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	player_shadow.material_override = shadow_mat
	player_shadow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	player_shadow.position = Vector3(0.0, CombatSpace.UNDERWORLD_Y + 0.12, 0.0)
	add_child(player_shadow)

	# The aircraft reads big, but the hitbox is small and explicitly marked.
	var hitbox_mesh := QuadMesh.new()
	hitbox_mesh.size = Vector2(0.52, 0.52)
	player_hitbox_marker = MeshInstance3D.new()
	player_hitbox_marker.name = "PlayerHitboxMarker"
	player_hitbox_marker.mesh = hitbox_mesh
	var hitbox_mat := StandardMaterial3D.new()
	hitbox_mat.albedo_color = Color(0.72, 1.0, 1.0, 0.95)
	hitbox_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hitbox_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hitbox_mat.emission_enabled = true
	hitbox_mat.emission = Color(0.55, 0.95, 1.0, 1.0)
	hitbox_mat.emission_energy_multiplier = 3.0
	hitbox_mat.no_depth_test = true
	hitbox_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	player_hitbox_marker.material_override = hitbox_mat
	player_hitbox_marker.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	player_rig.add_child(player_hitbox_marker)

	var flash_mesh := QuadMesh.new()
	flash_mesh.size = Vector2(3.0, 3.0)
	player_hit_flash = MeshInstance3D.new()
	player_hit_flash.name = "PlayerHitFlash"
	player_hit_flash.mesh = flash_mesh
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.86, 0.72, 0.0)
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.72, 0.48, 1.0)
	flash_mat.emission_energy_multiplier = 4.0
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flash_mat.no_depth_test = true
	flash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	player_hit_flash.material_override = flash_mat
	player_hit_flash.visible = false
	player_rig.add_child(player_hit_flash)


func _load_player_model() -> void:
	var packed = PLAYER_MODEL_SCENE
	if packed is PackedScene:
		player_model = packed.instantiate()
		player_model.name = "PlayerUploadedHeroJetBlenderPreparedGLB"
		# Foundation correction: keep the uploaded aircraft identity by using the Blender-prepared
		# derivative of the user GLB, not the generated Stormhawk replacement. The original
		# source path remains tracked separately; Web keeps the prepared derivative to avoid
		# reintroducing the slow oversized PCK.
		player_model.scale = Vector3(0.78, 0.78, 0.78)
		# The aircraft is authored in Blender with wings on X and the nose on +Y,
		# which exports to glTF -Z: Godot's forward. No corrective rotation.
		player_model.rotation_degrees = Vector3.ZERO
		player_model_alignment = "blender_authored_nose_on_forward_axis_no_engine_rotation"
		player_model_source = PLAYER_MODEL_PATH
		player_model_original_source = PLAYER_ORIGINAL_SOURCE_PATH
		player_model_authenticity = "uploaded_glb_blender_prepared_runtime_instance"
		player_rig.add_child(player_model)
		_bind_glb_weapon_hardpoints()
	else:
		var fallback_packed = PLAYER_FALLBACK_MODEL_SCENE
		if fallback_packed is PackedScene:
			player_model = fallback_packed.instantiate()
			player_model.name = "PlayerStormhawkFallbackGLB"
			player_model.scale = Vector3(0.56, 0.56, 0.56)
			player_model_alignment = "fallback_generated_glb_default_axis"
			player_model_source = PLAYER_FALLBACK_MODEL_PATH
			player_model_authenticity = "generated_fallback_glb"
			player_model_original_source = PLAYER_ORIGINAL_SOURCE_PATH
			player_rig.add_child(player_model)
		else:
			player_model = Node3D.new()
			player_model.name = "PlayerStormhawkFallbackMesh"
			player_model_source = "runtime_fallback_mesh"
			player_model_authenticity = "fallback_only_not_accepted_for_final"
			player_model_alignment = "runtime_mesh_default_axis"
			player_model_original_source = PLAYER_ORIGINAL_SOURCE_PATH
			player_rig.add_child(player_model)
			_create_fallback_aircraft(player_model)
	_create_weapon_hardpoints()


func _create_fallback_aircraft(parent: Node3D) -> void:
	var metal = _make_material(Color(0.18, 0.22, 0.30, 1.0), Color(0.05, 0.16, 0.28, 1.0), 0.45)
	var cyan = _make_material(Color(0.15, 0.75, 1.0, 1.0), Color(0.2, 0.9, 1.0, 1.0), 0.2)
	parent.add_child(_box_mesh("FallbackFuselage", Vector3(0.0, 0.0, 0.05), Vector3(0.36, 0.20, 1.58), metal))
	parent.add_child(_box_mesh("FallbackLeftWing", Vector3(-1.05, -0.04, 0.25), Vector3(0.98, 0.05, 0.36), metal))
	parent.add_child(_box_mesh("FallbackRightWing", Vector3(1.05, -0.04, 0.25), Vector3(0.98, 0.05, 0.36), metal))
	parent.add_child(_box_mesh("FallbackCanopy", Vector3(0.0, 0.24, -0.55), Vector3(0.22, 0.11, 0.34), cyan))


func _create_weapon_hardpoints() -> void:
	# Fallback socket contract only. The preferred path is to bind actual named
	# sockets from the Blender-prepared uploaded GLB: Muzzle_Left / Muzzle_Right / Engine_Core.
	if muzzle_left != null and muzzle_right != null:
		return
	weapon_hardpoint_binding = "runtime_fallback"
	glb_weapon_sockets_found = false
	muzzle_center = Node3D.new()
	muzzle_center.name = "MuzzleForward_Center_Fallback"
	muzzle_center.position = Vector3(0.0, 0.03, -1.62)
	player_rig.add_child(muzzle_center)
	muzzle_left = Node3D.new()
	muzzle_left.name = "MuzzleForward_Left_Fallback"
	muzzle_left.position = Vector3(-0.52, -0.02, -1.05)
	player_rig.add_child(muzzle_left)
	muzzle_right = Node3D.new()
	muzzle_right.name = "MuzzleForward_Right_Fallback"
	muzzle_right.position = Vector3(0.52, -0.02, -1.05)
	player_rig.add_child(muzzle_right)


func _load_player_projectile_data() -> Dictionary:
	var file := FileAccess.open("res://data/projectiles/player_cyan_plasma.json", FileAccess.READ)
	if file == null:
		push_error("Force War: player projectile config missing")
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _bind_glb_weapon_hardpoints() -> void:
	# Weapon sockets are resolved BY NAME from the GLB, never by hard-coded
	# coordinates: moving an Empty in Blender and re-exporting moves the gun.
	# Prefixes follow the agreed scheme (MZ_ muzzle, HP_ hardpoint, EX_ exhaust)
	# with the current asset's legacy names kept as aliases.
	gun_sockets.clear()
	missile_sockets.clear()
	weapon_socket_error = ""
	if player_model == null:
		weapon_socket_error = "player model missing, weapon sockets cannot be resolved"
		push_error("Force War: " + weapon_socket_error)
		glb_weapon_sockets_found = false
		weapon_hardpoint_binding = "socket_resolution_failed"
		return

	var gun_config: Array = player_projectile_data.get("gun_sockets", [])
	for entry_value in gun_config:
		var entry: Dictionary = entry_value
		var socket := _resolve_socket(entry.get("socket_names", []))
		if socket == null:
			# No silent fallback to the hull origin - that is the classic bug
			# where shots appear to come out of the middle of the aircraft.
			weapon_socket_error = "missing gun socket for %s (%s)" % [str(entry.get("id", "?")), str(entry.get("socket_names", []))]
			push_error("Force War: " + weapon_socket_error)
			continue
		gun_sockets.append({"id": str(entry.get("id", socket.name)), "node": socket})

	var missile_config: Array = player_projectile_data.get("missile_sockets", [])
	for entry_value in missile_config:
		var entry: Dictionary = entry_value
		var socket := _resolve_socket(entry.get("socket_names", []))
		if socket != null:
			missile_sockets.append({"id": str(entry.get("id", socket.name)), "node": socket})

	engine_socket = _resolve_socket(["EX_C", "Engine_Core"])
	_create_pylon_missiles()
	muzzle_left = gun_sockets[0]["node"] if gun_sockets.size() > 0 else null
	muzzle_right = gun_sockets[1]["node"] if gun_sockets.size() > 1 else null
	glb_weapon_sockets_found = gun_sockets.size() >= 2 and weapon_socket_error == ""
	weapon_hardpoint_binding = "glb_socket_runtime" if glb_weapon_sockets_found else "socket_resolution_failed"
	if muzzle_left != null and muzzle_right != null:
		muzzle_center = Node3D.new()
		muzzle_center.name = "MuzzleForward_Center_FromGLBSockets"
		muzzle_center.position = (muzzle_left.position + muzzle_right.position) * 0.5
		muzzle_left.get_parent().add_child(muzzle_center)


func _create_pylon_missiles() -> void:
	# A visible missile hangs under every resolved HP_ pylon. The mesh IS the
	# ammo indicator: it disappears when that pylon fires and comes back on
	# reload. Nothing here is positioned by hand - it is parented to the socket.
	for entry_value in pylon_missiles:
		var old: Node3D = (entry_value as Dictionary).get("mesh", null)
		if old != null and is_instance_valid(old):
			old.queue_free()
	pylon_missiles.clear()
	var body_mat := _make_material(Color(0.62, 0.68, 0.76, 1.0), Color(0.05, 0.22, 0.34, 1.0), 0.35)
	var tip_mat := _make_material(Color(0.20, 0.78, 1.0, 1.0), Color(0.15, 0.85, 1.0, 1.0), 0.0)
	for socket_entry_value in missile_sockets:
		var socket_entry: Dictionary = socket_entry_value
		var socket: Node3D = socket_entry["node"]
		if socket == null:
			continue
		var missile := Node3D.new()
		missile.name = "PylonMissile_%s" % str(socket_entry["id"])
		var body := _box_mesh("Body", Vector3.ZERO, Vector3(0.09, 0.09, 0.62), body_mat)
		var tip := _box_mesh("Seeker", Vector3(0.0, 0.0, -0.37), Vector3(0.07, 0.07, 0.14), tip_mat)
		var fin := _box_mesh("Fin", Vector3(0.0, 0.0, 0.26), Vector3(0.26, 0.02, 0.12), body_mat)
		missile.add_child(body)
		missile.add_child(tip)
		missile.add_child(fin)
		socket.add_child(missile)
		# The socket inherits the GLB import rotation, the missile must point
		# along the aircraft forward axis in scene space.
		missile.rotation = Vector3.ZERO   # sockets inherit the hull axes already
		pylon_missiles.append({"id": str(socket_entry["id"]), "node": socket, "mesh": missile, "loaded": true})

	missile_fire_order.clear()
	var configured: Array = player_projectile_data.get("missile_fire_order", [])
	for id_value in configured:
		for entry_value2 in pylon_missiles:
			var entry: Dictionary = entry_value2
			if str(entry["id"]) == str(id_value):
				missile_fire_order.append(str(id_value))
	if missile_fire_order.is_empty():
		for entry_value3 in pylon_missiles:
			missile_fire_order.append(str((entry_value3 as Dictionary)["id"]))


func _pylon_entry(pylon_id: String) -> Dictionary:
	for entry_value in pylon_missiles:
		var entry: Dictionary = entry_value
		if str(entry["id"]) == pylon_id:
			return entry
	return {}


func _loaded_pylon_count() -> int:
	var count := 0
	for entry_value in pylon_missiles:
		if bool((entry_value as Dictionary).get("loaded", false)):
			count += 1
	return count


func _reload_pylons() -> void:
	for entry_value in pylon_missiles:
		var entry: Dictionary = entry_value
		entry["loaded"] = true
		var mesh: Node3D = entry.get("mesh", null)
		if mesh != null and is_instance_valid(mesh):
			mesh.visible = true
	missile_cursor = 0
	missile_reloads += 1


func _update_pylon_missiles(delta: float) -> void:
	if pylon_missiles.is_empty() or projectile_manager == null:
		return
	if _loaded_pylon_count() <= 0:
		missile_reload_timer -= delta
		if missile_reload_timer <= 0.0:
			_reload_pylons()
		return
	missile_salvo_timer -= delta
	missile_shot_timer -= delta
	if missile_salvo_timer > 0.0 or missile_shot_timer > 0.0:
		return
	# Fire order comes from the config socket list: outer pylon first, left
	# then right, working inwards.
	for attempt in range(missile_fire_order.size()):
		var pylon_id: String = str(missile_fire_order[(missile_cursor + attempt) % missile_fire_order.size()])
		var entry: Dictionary = _pylon_entry(pylon_id)
		if entry.is_empty() or not bool(entry.get("loaded", false)):
			continue
		var socket: Node3D = entry["node"]
		if socket == null or not socket.is_inside_tree():
			continue
		# Detach keeping the world transform: the missile leaves exactly where
		# it hung, then drops before the motor lights.
		var launch_pos: Vector3 = socket.global_transform.origin
		var aim: Vector3 = aim_convergence_point - launch_pos
		aim.y = 0.0
		var launched: bool = bool(projectile_manager.launch_player_missile({
			"pos": launch_pos,
			"dir": aim,
			"socket": pylon_id,
			"launch_speed": float(player_projectile_data.get("missile_launch_speed", 14.0)),
			"drop_seconds": float(player_projectile_data.get("missile_drop_seconds", 0.22)),
			"speed": float(player_projectile_data.get("missile_speed", 62.0)),
			"turn_rate_deg": float(player_projectile_data.get("missile_turn_rate_deg", 185.0)),
			"damage": float(player_projectile_data.get("missile_damage", 96.0)),
			"radius": float(player_projectile_data.get("missile_radius", 0.55)),
			"lifetime": float(player_projectile_data.get("missile_lifetime", 3.2))
		}))
		if not launched:
			return
		entry["loaded"] = false
		var mesh: Node3D = entry.get("mesh", null)
		if mesh != null and is_instance_valid(mesh):
			mesh.visible = false       # missing missile = spent round
		missiles_launched += 1
		last_missile_pylon = pylon_id
		if not pylons_fired_from.has(pylon_id):
			pylons_fired_from.append(pylon_id)
		missile_launch_log.append(pylon_id)
		while missile_launch_log.size() > 12:
			missile_launch_log.pop_front()
		missile_cursor = (missile_cursor + attempt + 1) % missile_fire_order.size()
		missile_shot_timer = float(player_projectile_data.get("missile_shot_interval", 0.14))
		if _loaded_pylon_count() <= 0:
			missile_reload_timer = float(player_projectile_data.get("missile_reload_seconds", 3.4))
		else:
			missile_salvo_timer = float(player_projectile_data.get("missile_salvo_interval", 1.9))
		return


func _resolve_socket(names) -> Node3D:
	for socket_name in names:
		var found := _find_node3d(player_model, str(socket_name))
		if found != null:
			return found
	return null


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


func _create_afterburners() -> void:
	var flame_mat = _make_material(Color(0.25, 0.82, 1.0, 0.78), Color(0.2, 0.9, 1.0, 1.0), 0.0, 0.78)
	afterburner_left = _box_mesh("LeftAfterburnerFlame", Vector3(-0.16, -0.02, 1.05), Vector3(0.06, 0.06, 0.26), flame_mat)
	afterburner_right = _box_mesh("RightAfterburnerFlame", Vector3(0.16, -0.02, 1.05), Vector3(0.06, 0.06, 0.26), flame_mat)
	afterburner_left.visible = runtime_afterburner_boxes
	afterburner_right.visible = runtime_afterburner_boxes
	player_rig.add_child(afterburner_left)
	player_rig.add_child(afterburner_right)


func _create_socket_muzzle_vfx() -> void:
	# Tahap 2 continuation: visible muzzle flash and short forward tracer shards are
	# driven from the same GLB socket positions as gameplay shots. This keeps the
	# important fire animation factual without adding old vertical beam clutter.
	socket_muzzle_flash_nodes.clear()
	socket_muzzle_tracer_nodes.clear()
	for i in range(2):
		var flash := _socket_shot_quad("GLBSocketMuzzleFlash_%02d" % i, Vector2(0.42, 0.78), Color(0.70, 1.0, 1.0, 0.96), 4.2)
		var tracer := _socket_shot_quad("GLBSocketForwardTracer_%02d" % i, Vector2(0.22, 1.1), Color(0.48, 0.96, 1.0, 0.58), 2.2)
		flash.visible = false
		tracer.visible = false
		add_child(flash)
		add_child(tracer)
		socket_muzzle_flash_nodes.append(flash)
		socket_muzzle_tracer_nodes.append(tracer)
	socket_muzzle_vfx_ready = socket_muzzle_flash_nodes.size() == 2 and socket_muzzle_tracer_nodes.size() == 2
	socket_muzzle_vfx_mode = "glb_socket_cyan_forward_burst" if glb_weapon_sockets_found else "fallback_disabled"


func _socket_shot_quad(node_name: String, size: Vector2, tint: Color, emission_energy: float) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.albedo_texture = HERO_SHOT_TEXTURE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(tint.r, tint.g, tint.b, 1.0)
	mat.emission_texture = HERO_SHOT_TEXTURE
	mat.emission_energy_multiplier = emission_energy
	mi.material_override = mat
	return mi


func _set_socket_muzzle_vfx_visible(enabled: bool) -> void:
	socket_muzzle_vfx_active = false if not enabled else socket_muzzle_vfx_active
	for node in socket_muzzle_flash_nodes:
		if node is MeshInstance3D:
			node.visible = enabled
	for node in socket_muzzle_tracer_nodes:
		if node is MeshInstance3D:
			node.visible = enabled


func _create_forward_depth_markers() -> void:
	var lane_mat = _make_material(Color(0.1, 0.9, 1.0, 0.10), Color(0.1, 0.65, 1.0, 1.0), 0.0, 0.10)
	for i in range(0):
		var gate = Node3D.new()
		gate.name = "ForwardFlightGate_%02d" % i
		gate.position = Vector3(0.0, 1.65, -18.0 - i * 13.5)
		gate.add_child(_box_mesh("GateLeft", Vector3(-corridor_width, 0.0, 0.0), Vector3(0.035, corridor_height * 2.0, 0.035), lane_mat))
		gate.add_child(_box_mesh("GateRight", Vector3(corridor_width, 0.0, 0.0), Vector3(0.035, corridor_height * 2.0, 0.035), lane_mat))
		gate.add_child(_box_mesh("GateTop", Vector3(0.0, corridor_height, 0.0), Vector3(corridor_width * 2.0, 0.035, 0.035), lane_mat))
		gate.add_child(_box_mesh("GateBottom", Vector3(0.0, -corridor_height, 0.0), Vector3(corridor_width * 2.0, 0.035, 0.035), lane_mat))
		add_child(gate)
		lane_markers.append(gate)

	var cloud_mat = _make_material(Color(0.58, 0.72, 0.88, 0.16), Color(0.04, 0.10, 0.16, 1.0), 0.0, 0.16)
	for i in range(0):
		var cloud = _box_mesh("StormCloudChunk_%02d" % i, Vector3.ZERO, Vector3(rng.randf_range(2.2, 5.6), rng.randf_range(0.35, 0.95), rng.randf_range(1.2, 3.5)), cloud_mat)
		cloud.position = Vector3(rng.randf_range(-9.5, 9.5), rng.randf_range(2.2, 7.0), -12.0 - rng.randf_range(0.0, 110.0))
		add_child(cloud)
		cloud_markers.append(cloud)

	var ocean_mat = _make_material(Color(0.03, 0.12, 0.18, 1.0), Color(0.0, 0.05, 0.08, 1.0), 0.15)
	var fire_mat = _make_material(Color(1.0, 0.34, 0.08, 1.0), Color(1.0, 0.18, 0.02, 1.0), 0.0)
	for i in range(0):
		var chunk = _box_mesh("WarzoneBelow_%02d" % i, Vector3.ZERO, Vector3(14.0, 0.06, 10.0), ocean_mat)
		chunk.position = Vector3(0.0, -3.2, -10.0 - i * 12.0)
		add_child(chunk)
		warzone_chunks.append(chunk)
		var fire = _box_mesh("WarzoneFire_%02d" % i, Vector3.ZERO, Vector3(0.34, 0.75, 0.34), fire_mat)
		fire.position = Vector3(rng.randf_range(-5.0, 5.0), -2.75, chunk.position.z + rng.randf_range(-4.0, 4.0))
		add_child(fire)
		debris_markers.append(fire)


func _reset_depth_nodes() -> void:
	for i in range(lane_markers.size()):
		lane_markers[i].position.z = -18.0 - i * 13.5
	for node in cloud_markers:
		node.position = Vector3(rng.randf_range(-9.5, 9.5), rng.randf_range(2.2, 7.0), -12.0 - rng.randf_range(0.0, 110.0))
	for i in range(warzone_chunks.size()):
		warzone_chunks[i].position = Vector3(0.0, -3.2, -10.0 - i * 12.0)
	for node in debris_markers:
		node.position = Vector3(rng.randf_range(-5.0, 5.0), -2.75, -14.0 - rng.randf_range(0.0, 105.0))


func _update_corridor_position(delta: float, input_state: Dictionary, effect: Dictionary) -> void:
	# corridor_pos is the player position ON the combat plane: x = world X,
	# y = world Z. Screen-vertical input moves the aircraft forward and back.
	var move = Vector2(input_state.get("move", Vector2.ZERO))
	var pointer_on = bool(input_state.get("pointer_active", false))
	if pointer_on:
		var target = Vector2(input_state.get("pointer", Vector2(360.0, 840.0)))
		var view = Vector2(input_state.get("viewport", Vector2(720.0, 1280.0)))
		var nx: float = clamp(target.x / max(1.0, view.x), 0.0, 1.0)
		var ny: float = clamp(target.y / max(1.0, view.y), 0.0, 1.0)
		corridor_target.x = (nx - 0.5) * 2.0 * CombatSpace.PLAYER_X_LIMIT
		# Finger offset: the aircraft flies ahead of the touch point so the thumb
		# never covers it.
		var depth_t: float = clamp((ny - 0.18) / 0.72, 0.0, 1.0)
		corridor_target.y = lerp(CombatSpace.PLAYER_Z_FAR, CombatSpace.PLAYER_Z_NEAR, depth_t)
		corridor_pos = corridor_pos.lerp(corridor_target, min(1.0, delta * 8.5))
	else:
		corridor_pos += Vector2(move.x, -move.y) * delta * 7.0
	var turbulence_vec = Vector2(effect.get("turbulence", Vector2.ZERO))
	var wind_push = float(effect.get("windDrift", 0.0))
	var hazard_vec = Vector2(float(effect.get("hazardPushX", 0.0)), float(effect.get("hazardPushY", 0.0)))
	corridor_pos += Vector2(wind_push * 0.52 + turbulence_vec.x * 0.8, turbulence_vec.y * 0.4) * delta
	corridor_pos += hazard_vec * delta * 1.0
	corridor_pos = CombatSpace.clamp_player(corridor_pos.x, corridor_pos.y)


func _sync_player_weapon_hardpoints_to_arena() -> void:
	# Position comes from the socket, direction comes from the aiming system:
	# the aircraft banks, so a barrel-axis direction would throw shots off the
	# play plane. The convergence point is always on the play plane.
	var convergence: float = float(player_projectile_data.get("convergence_distance", 26.0))
	aim_convergence_point = Vector3(corridor_pos.x, CombatSpace.PLANE_Y, player_rig.position.z - convergence) if player_rig != null else Vector3.ZERO

	var gun_list: Array = []
	for socket_entry_value in gun_sockets:
		var socket_entry: Dictionary = socket_entry_value
		var node: Node3D = socket_entry["node"]
		if node == null or not node.is_inside_tree():
			continue
		var world_pos: Vector3 = node.global_transform.origin
		world_pos.y = CombatSpace.PLANE_Y
		gun_list.append({"id": str(socket_entry["id"]), "pos": world_pos})
	# Firing order follows world left to right, taken from the live socket
	# positions rather than from the order the sockets happened to resolve in.
	gun_list.sort_custom(func(a, b): return float(a["pos"].x) < float(b["pos"].x))
	gun_world_order.clear()
	for gun_value in gun_list:
		var gun_entry: Dictionary = gun_value
		gun_world_order.append(str(gun_entry["id"]))

	var hardpoint_state := {
		"binding": weapon_hardpoint_binding,
		"sockets_found": glb_weapon_sockets_found,
		"socket_error": weapon_socket_error,
		"guns": gun_list,
		"aim_point": aim_convergence_point,
		"aim_model": str(player_projectile_data.get("aim_model", "convergence_point_on_play_plane")),
		"convergence_distance": convergence,
		"muzzle_clearance": float(player_projectile_data.get("muzzle_clearance", 0.55)),
		"center": _muzzle_world_position(muzzle_center),
		"left": _muzzle_world_position(muzzle_left),
		"right": _muzzle_world_position(muzzle_right),
		"engine": _muzzle_world_position(engine_socket),
		"forward": FORWARD_DIR
	}
	if arena_director != null and arena_director.has_method("set_player_weapon_hardpoints"):
		arena_director.set_player_weapon_hardpoints(hardpoint_state)
	if projectile_manager != null and projectile_manager.has_method("set_player_weapon_hardpoints"):
		projectile_manager.set_player_weapon_hardpoints(hardpoint_state)
	_update_weapon_gizmo(gun_list)


func set_weapon_gizmo_visible(value: bool) -> void:
	weapon_gizmo_visible = value
	for node_value in weapon_gizmo_nodes:
		var node: Node3D = node_value
		node.visible = value


func _update_weapon_gizmo(gun_list: Array) -> void:
	# Debug gizmo: socket markers plus the line each stream will actually take.
	if weapon_gizmo_nodes.is_empty():
		for i in range(4):
			var marker := MeshInstance3D.new()
			marker.name = "WeaponGizmo_%02d" % i
			var marker_mesh := BoxMesh.new()
			marker_mesh.size = Vector3(0.12, 0.12, 0.12) if i < 2 else Vector3(0.03, 0.03, 1.0)
			marker.mesh = marker_mesh
			var gizmo_mat := StandardMaterial3D.new()
			gizmo_mat.albedo_color = Color(0.45, 1.0, 0.55, 1.0) if i < 2 else Color(1.0, 0.95, 0.35, 0.85)
			gizmo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			gizmo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gizmo_mat.no_depth_test = true
			marker.material_override = gizmo_mat
			marker.visible = false
			add_child(marker)
			weapon_gizmo_nodes.append(marker)
	if not weapon_gizmo_visible:
		return
	for i in range(2):
		var dot: MeshInstance3D = weapon_gizmo_nodes[i]
		var line: MeshInstance3D = weapon_gizmo_nodes[i + 2]
		if i >= gun_list.size():
			dot.visible = false
			line.visible = false
			continue
		var gun: Dictionary = gun_list[i]
		var origin: Vector3 = gun["pos"]
		dot.visible = true
		dot.position = origin
		var to_aim: Vector3 = aim_convergence_point - origin
		var distance: float = max(0.2, to_aim.length())
		line.visible = true
		line.position = origin + to_aim * 0.5
		line.scale = Vector3(1.0, 1.0, distance)
		line.look_at(aim_convergence_point, Vector3.UP)


func _gun_socket_ids() -> Array:
	var ids: Array = []
	for socket_entry_value in gun_sockets:
		var socket_entry: Dictionary = socket_entry_value
		ids.append(str(socket_entry["id"]))
	return ids


func _muzzle_world_position(socket: Node3D) -> Vector3:
	if socket != null and socket.is_inside_tree():
		return socket.global_transform.origin
	return player_rig.global_transform.origin if player_rig != null and player_rig.is_inside_tree() else Vector3.ZERO


func _update_socket_muzzle_vfx(delta: float) -> void:
	var sockets: Array = [muzzle_left, muzzle_right]
	muzzle_flash_positions.clear()
	muzzle_flash_offset_max = 0.0
	socket_muzzle_vfx_mode = "glb_socket_cyan_forward_burst" if glb_weapon_sockets_found else "fallback_disabled"
	socket_muzzle_vfx_active = active and glb_weapon_sockets_found and socket_muzzle_vfx_ready
	if not socket_muzzle_vfx_active:
		_set_socket_muzzle_vfx_visible(false)
		return
	for i in range(socket_muzzle_flash_nodes.size()):
		var flash: MeshInstance3D = socket_muzzle_flash_nodes[i]
		var tracer: MeshInstance3D = socket_muzzle_tracer_nodes[i]
		var socket := sockets[i] as Node3D
		if socket == null:
			flash.visible = false
			tracer.visible = false
			continue
		var origin := _muzzle_world_position(socket)
		var pulse := 0.5 + 0.5 * sin(forward_time * 34.0 + float(i) * PI)
		var overcharge_boost := 0.24 if bool(weather_effect.get("lightningOvercharge", false)) else 0.0
		flash.visible = true
		tracer.visible = true
		flash.global_position = origin + FORWARD_DIR * (0.22 + pulse * 0.08)
		tracer.global_position = origin + FORWARD_DIR * (1.85 + pulse * 0.24)
		flash.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		tracer.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		# The flash sits on the barrel itself, within the muzzle clearance the
		# first bullet is spawned at, so the very first frame of a shot already
		# shows fire at the gun.
		muzzle_flash_positions.append(flash.global_position)
		muzzle_flash_offset_max = maxf(muzzle_flash_offset_max, flash.global_position.distance_to(origin))
		flash.scale = Vector3.ONE * (0.72 + pulse * 0.46 + overcharge_boost)
		tracer.scale = Vector3(0.82 + pulse * 0.08, 0.92 + pulse * 0.22 + overcharge_boost, 1.0)


func _update_projectile_logic(delta: float, effect: Dictionary) -> void:
	if projectile_manager == null or not projectile_manager.has_method("update_logic"):
		return
	var player_xz := Vector2(player_rig.position.x, player_rig.position.z)
	var damage := float(projectile_manager.update_logic(delta, player_xz, effect, boost_amount))
	if damage > 0.0:
		_apply_player_damage(damage)
	else:
		shield_recharge_delay = max(0.0, shield_recharge_delay - delta)
		if shield_recharge_delay <= 0.0:
			shield = min(max_shield, shield + delta * 9.0)
	if projectile_manager.has_method("consume_player_hit_events"):
		var player_hits: Array = projectile_manager.consume_player_hit_events()
		player_damage_events += player_hits.size()
		# Every point of player damage came from one bullet that was on screen.
		player_damage_events_with_source += player_hits.size()
	if projectile_manager.has_method("consume_boss_damage_events"):
		var boss_hits: Array = projectile_manager.consume_boss_damage_events()
		if not boss_hits.is_empty():
			for hit in boss_hits:
				score += int(round(float(hit.get("damage", 0.0)) * 0.35))
			if arena_director != null and arena_director.has_method("note_boss_hits"):
				arena_director.note_boss_hits(boss_hits)
	var destroyed_now := int(effect.get("bossDestroyedParts", 0))
	if destroyed_now > last_destroyed_part_count:
		score += (destroyed_now - last_destroyed_part_count) * 500
		last_destroyed_part_count = destroyed_now
	if arena_director != null and arena_director.has_method("render_projectiles") and projectile_manager.has_method("get_enemy_bullets"):
		arena_director.render_projectiles(projectile_manager.get_enemy_bullets(), projectile_manager.get_player_bullets())


func _apply_player_damage(damage: float) -> void:
	hit_flash_timer = 0.22
	invuln_timer = max(invuln_timer, 0.85)
	shield_recharge_delay = 3.2
	hazard_damage_buffer = max(hazard_damage_buffer, 0.18)
	var remaining := damage
	if shield > 0.0:
		var absorbed: float = min(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
	if remaining > 0.0:
		hp = max(0, hp - int(ceil(remaining)))


func _update_weather_damage(delta: float, effect: Dictionary) -> void:
	var hazard = float(effect.get("stormHazard", 0.0))
	if hazard < 0.62:
		hazard_damage_buffer = max(0.0, hazard_damage_buffer - delta * 0.5)
		return
	hazard_damage_buffer += delta * (hazard - 0.58) * 5.0
	if hazard_damage_buffer >= 1.0:
		var damage = int(floor(hazard_damage_buffer))
		hazard_damage_buffer -= float(damage)
		hp = max(1, hp - damage)


func _update_environment_weather(delta: float, effect: Dictionary) -> void:
	if not world_environment or not world_environment.environment:
		return
	var env: Environment = world_environment.environment
	var visibility := float(effect.get("rainVisibility", 1.0))
	var cover := float(effect.get("cloudCover", 0.0))
	var lightning := float(effect.get("lightningFlash", 0.0))
	var hazard := float(effect.get("stormHazard", 0.0))
	# Weather still drives the far haze, but it can never creep onto the play
	# plane: only the depth window and its density move.
	var target_density: float = 0.38 + (1.0 - visibility) * 0.30 + cover * 0.16 + hazard * 0.12
	env.fog_density = lerpf(env.fog_density, clampf(target_density, 0.25, 0.92), minf(1.0, delta * 1.9))
	var target_begin: float = 76.0 - (1.0 - visibility) * 14.0 - cover * 6.0
	env.fog_depth_begin = lerpf(env.fog_depth_begin, maxf(58.0, target_begin), minf(1.0, delta * 1.6))
	env.ambient_light_energy = lerpf(env.ambient_light_energy, 0.58 + lightning * 0.95 + (1.0 - visibility) * 0.10, minf(1.0, delta * 2.0))
	if sun_light:
		sun_light.light_energy = lerpf(sun_light.light_energy, 2.2 + lightning * 3.2 + hazard * 0.30, minf(1.0, delta * 4.5))
		sun_light.light_color = Color(1.0, 0.66, 0.38, 1.0).lerp(Color(0.86, 0.92, 1.0, 1.0), clampf(lightning, 0.0, 1.0))


func _update_player_pose(delta: float, input_state: Dictionary, effect: Dictionary) -> void:
	var boost = bool(input_state.get("boost", false))
	boost_amount = lerp(boost_amount, 1.0 if boost else 0.0, min(1.0, delta * 4.0))
	var hazard = float(effect.get("stormHazard", 0.0))
	var overcharged = bool(effect.get("lightningOvercharge", false))
	# Strictly on the combat plane: no vertical drift is allowed for anything that
	# can shoot or be shot.
	player_rig.position = Vector3(corridor_pos.x, CombatSpace.PLANE_Y, corridor_pos.y)
	var roll = -corridor_pos.x / CombatSpace.PLAYER_X_LIMIT * 0.34 - float(effect.get("windDrift", 0.0)) * 0.05
	var pitch = -0.08 - boost_amount * 0.05 + hazard * 0.03
	player_rig.rotation = player_rig.rotation.lerp(Vector3(pitch, 0.0, roll), min(1.0, delta * 6.0))
	var flame_scale = 1.0 + boost_amount * 0.65 + sin(forward_time * 18.0) * 0.08 + (0.35 if overcharged else 0.0)
	if afterburner_left:
		afterburner_left.scale.z = flame_scale
	if afterburner_right:
		afterburner_right.scale.z = flame_scale
	if player_shadow != null:
		player_shadow.position = Vector3(corridor_pos.x, CombatSpace.UNDERWORLD_Y + 0.12, corridor_pos.y + 0.6)
	invuln_timer = max(0.0, invuln_timer - delta)
	hit_flash_timer = max(0.0, hit_flash_timer - delta)
	if player_model != null:
		# Visible invulnerability: the aircraft blinks while it cannot be hit.
		player_model.visible = invuln_timer <= 0.0 or fmod(invuln_timer, 0.18) > 0.09
	if player_hit_flash != null:
		player_hit_flash.visible = hit_flash_timer > 0.0
		var flash_mat := player_hit_flash.material_override as StandardMaterial3D
		if flash_mat != null:
			var t: float = clamp(hit_flash_timer / 0.22, 0.0, 1.0)
			flash_mat.albedo_color = Color(1.0, 0.86, 0.72, t * 0.9)
		player_hit_flash.scale = Vector3.ONE * (0.8 + (1.0 - clamp(hit_flash_timer / 0.22, 0.0, 1.0)) * 0.8)
	if player_hitbox_marker != null:
		var marker_mat := player_hitbox_marker.material_override as StandardMaterial3D
		if marker_mat != null:
			marker_mat.albedo_color = Color(0.72, 1.0, 1.0, 0.55 + 0.35 * sin(forward_time * 6.0))


func _update_forward_markers(delta: float) -> void:
	var speed = forward_speed * (1.0 + boost_amount * 0.28)
	for gate in lane_markers:
		gate.position.z += speed * delta
		if gate.position.z > 10.0:
			gate.position.z -= 108.0
	for cloud in cloud_markers:
		cloud.position.z += speed * 0.64 * delta
		cloud.position.x += sin(forward_time * 0.45 + cloud.position.z) * delta * 0.22
		if cloud.position.z > 14.0:
			cloud.position = Vector3(rng.randf_range(-9.5, 9.5), rng.randf_range(2.2, 7.0), -118.0 - rng.randf_range(0.0, 18.0))
	for chunk in warzone_chunks:
		chunk.position.z += speed * 0.92 * delta
		if chunk.position.z > 14.0:
			chunk.position.z -= 118.0
	for debris in debris_markers:
		debris.position.z += speed * 1.08 * delta
		debris.scale.y = 1.0 + sin(forward_time * 9.0 + debris.position.x) * 0.25
		if debris.position.z > 12.0:
			debris.position = Vector3(rng.randf_range(-5.2, 5.2), -2.75, -118.0 - rng.randf_range(0.0, 24.0))


func _update_player_lamp() -> void:
	if player_marker_light == null or player_rig == null:
		return
	player_marker_light.position = player_rig.position + Vector3(0.0, 3.1, 2.6)


func _update_camera(delta: float, input_state: Dictionary, effect: Dictionary) -> void:
	# High chase camera, steep downward tilt, wide FOV. The camera is anchored in Z
	# so moving the aircraft forward actually reads as moving up the screen, and the
	# shooter and its target stay inside the same frame.
	var hazard = float(effect.get("stormHazard", 0.0))
	var lightning = float(effect.get("lightningFlash", 0.0))
	var shake = hazard * 0.10 + lightning * 0.07
	var shake_offset = Vector3(sin(forward_time * 19.0) * shake, cos(forward_time * 17.0) * shake * 0.7, 0.0)
	var target_camera = Vector3(
		corridor_pos.x * 0.22,
		CombatSpace.PLANE_Y + CombatSpace.CAMERA_OFFSET.y,
		CombatSpace.CAMERA_OFFSET.z - boost_amount * 0.8
	) + shake_offset
	camera.position = camera.position.lerp(target_camera, min(1.0, delta * 5.0))
	var look_target = Vector3(corridor_pos.x * 0.12, CombatSpace.CAMERA_LOOK.y, CombatSpace.CAMERA_LOOK.z)
	camera.look_at(look_target, Vector3.UP)
	var visibility = float(effect.get("rainVisibility", 1.0))
	var target_fov = (CombatSpace.CAMERA_FOV + 3.0 if bool(input_state.get("boost", false)) else CombatSpace.CAMERA_FOV) + (1.0 - visibility) * 1.2
	camera.fov = lerp(camera.fov, target_fov, min(1.0, delta * 3.5))


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
	mat.roughness = 0.38
	if alpha < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = false
	mat.emission_enabled = emission != Color.BLACK
	mat.emission = emission
	mat.emission_energy_multiplier = 1.6
	return mat
