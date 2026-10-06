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
const FORWARD_DIR = Vector3(0.0, 0.0, -1.0)
const ARENA_DIRECTOR_SCRIPT = preload("res://scripts/forward_arena_director.gd")
const PROJECTILE_MANAGER_SCRIPT = preload("res://scripts/projectiles/projectile_manager_3d.gd")

var owner_main: Node
var active = false
var is_setup = false
var rng = RandomNumberGenerator.new()

var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
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
var muzzle_center: Node3D
var muzzle_left: Node3D
var muzzle_right: Node3D
var engine_socket: Node3D
var afterburner_left: MeshInstance3D
var afterburner_right: MeshInstance3D
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
	corridor_pos = Vector2.ZERO
	corridor_target = Vector2.ZERO
	forward_speed = 30.0 + float(stage_data.get("threat", 1.0)) * 3.6
	max_hp = int(float(aircraft_data.get("hp", 120)) * float(loadout_data.get("armor", 1.0)))
	hp = max_hp
	hazard_damage_buffer = 0.0
	weather_effect = {}
	if arena_director and arena_director.has_method("start_mission"):
		arena_director.start_mission(stage_data)
	if projectile_manager and projectile_manager.has_method("start_mission"):
		projectile_manager.start_mission(stage_data)
	if player_rig:
		player_rig.position = Vector3(0.0, 1.5, 0.0)
		player_rig.rotation = Vector3.ZERO
	if camera:
		camera.current = true
		camera.position = Vector3(0.0, 4.9, 12.2)
		camera.look_at(Vector3(0.0, 2.15, -24.0), Vector3.UP)
	_reset_depth_nodes()
	_sync_player_weapon_hardpoints_to_arena()


func stop_mission() -> void:
	active = false
	visible = false
	if arena_director and arena_director.has_method("stop_mission"):
		arena_director.stop_mission()
	if projectile_manager and projectile_manager.has_method("stop_mission"):
		projectile_manager.stop_mission()
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
		"playerShotSpawnOrigin": "glb_muzzle_socket" if glb_weapon_sockets_found else "runtime_fallback_socket",
		"playerMuzzleCenterZ": _muzzle_world_position(muzzle_center).z,
		"playerForwardAxis": "negative_z",
		"stageName": current_stage_name,
		"progress": mission_progress,
		"forwardSpeed": forward_speed,
		"corridorX": corridor_pos.x,
		"corridorY": corridor_pos.y,
		"hp": hp,
		"maxHp": max_hp,
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
	world_environment = WorldEnvironment.new()
	world_environment.name = "ForwardStormEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.03, 0.075, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.20, 0.34, 1.0)
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.20, 0.33, 0.48, 1.0)
	env.fog_density = 0.018
	world_environment.environment = env
	add_child(world_environment)

	sun_light = DirectionalLight3D.new()
	sun_light.name = "StormKeyLight"
	sun_light.light_color = Color(0.65, 0.82, 1.0, 1.0)
	sun_light.light_energy = 1.65
	sun_light.rotation_degrees = Vector3(-46.0, -28.0, 0.0)
	add_child(sun_light)


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


func _create_player_rig() -> void:
	player_rig = Node3D.new()
	player_rig.name = "PlayerRig3D_ForwardAircraft"
	player_rig.position = Vector3(0.0, 1.5, 0.0)
	add_child(player_rig)
	_load_player_model()
	_create_afterburners()


func _load_player_model() -> void:
	var packed = PLAYER_MODEL_SCENE
	if packed is PackedScene:
		player_model = packed.instantiate()
		player_model.name = "PlayerUploadedHeroJetBlenderPreparedGLB"
		# Foundation correction: keep the uploaded aircraft identity by using the Blender-prepared
		# derivative of the user GLB, not the generated Stormhawk replacement. The original
		# source path remains tracked separately; Web keeps the prepared derivative to avoid
		# reintroducing the slow oversized PCK.
		player_model.scale = Vector3(0.44, 0.44, 0.44)
		player_model.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		player_model_alignment = "uploaded_glb_local_negative_y_to_world_negative_z"
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


func _bind_glb_weapon_hardpoints() -> void:
	if player_model == null:
		return
	muzzle_left = _find_node3d(player_model, "Muzzle_Left")
	muzzle_right = _find_node3d(player_model, "Muzzle_Right")
	engine_socket = _find_node3d(player_model, "Engine_Core")
	if muzzle_left != null and muzzle_right != null:
		glb_weapon_sockets_found = true
		weapon_hardpoint_binding = "glb_socket_runtime"
		muzzle_center = Node3D.new()
		muzzle_center.name = "MuzzleForward_Center_FromGLBSockets"
		muzzle_center.position = (muzzle_left.position + muzzle_right.position) * 0.5
		muzzle_left.get_parent().add_child(muzzle_center)


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
	var move = Vector2(input_state.get("move", Vector2.ZERO))
	var pointer_on = bool(input_state.get("pointer_active", false))
	if pointer_on:
		var target = Vector2(input_state.get("pointer", Vector2(360.0, 840.0)))
		var view = Vector2(input_state.get("viewport", Vector2(720.0, 1280.0)))
		corridor_target.x = clamp((target.x / max(1.0, view.x) - 0.5) * corridor_width * 2.0, -corridor_width, corridor_width)
		corridor_target.y = clamp((0.64 - target.y / max(1.0, view.y)) * corridor_height * 2.4, -corridor_height, corridor_height)
		corridor_pos = corridor_pos.lerp(corridor_target, min(1.0, delta * 7.5))
	else:
		corridor_pos += Vector2(move.x, -move.y) * delta * 5.2
	var turbulence_vec = Vector2(effect.get("turbulence", Vector2.ZERO))
	var wind_push = float(effect.get("windDrift", 0.0))
	var hazard_vec = Vector2(float(effect.get("hazardPushX", 0.0)), float(effect.get("hazardPushY", 0.0)))
	corridor_pos += Vector2(wind_push * 0.52 + turbulence_vec.x * 0.8, turbulence_vec.y * 0.9) * delta
	# Storm-cell volumes push the aircraft away, making weather a lane-choice hazard.
	corridor_pos += hazard_vec * delta * 1.35
	corridor_pos.x = clamp(corridor_pos.x, -corridor_width, corridor_width)
	corridor_pos.y = clamp(corridor_pos.y, -corridor_height, corridor_height)


func _sync_player_weapon_hardpoints_to_arena() -> void:
	var hardpoint_state := {
		"binding": weapon_hardpoint_binding,
		"sockets_found": glb_weapon_sockets_found,
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


func _muzzle_world_position(socket: Node3D) -> Vector3:
	if socket != null and socket.is_inside_tree():
		return socket.global_transform.origin
	return player_rig.global_transform.origin if player_rig != null and player_rig.is_inside_tree() else Vector3.ZERO


func _update_projectile_logic(delta: float, effect: Dictionary) -> void:
	if projectile_manager == null or not projectile_manager.has_method("update_logic"):
		return
	var damage := float(projectile_manager.update_logic(delta, corridor_pos, effect, boost_amount))
	if damage > 0.0:
		hp = max(0, hp - int(ceil(damage)))
		hazard_damage_buffer = max(hazard_damage_buffer, 0.18)
	if projectile_manager.has_method("consume_boss_damage_events") and arena_director and arena_director.has_method("apply_player_projectile_hits"):
		var boss_hits: Array = projectile_manager.consume_boss_damage_events()
		if not boss_hits.is_empty():
			arena_director.apply_player_projectile_hits(boss_hits)


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
	var env = world_environment.environment
	var visibility = float(effect.get("rainVisibility", 1.0))
	var cover = float(effect.get("cloudCover", 0.0))
	var lightning = float(effect.get("lightningFlash", 0.0))
	var hazard = float(effect.get("stormHazard", 0.0))
	var target_fog = 0.004 + (1.0 - visibility) * 0.012 + cover * 0.006 + hazard * 0.005
	env.fog_density = lerp(env.fog_density, target_fog, min(1.0, delta * 1.9))
	var storm_color = Color(0.012, 0.026, 0.065, 1.0).lerp(Color(0.06, 0.11, 0.16, 1.0), cover * 0.42)
	env.background_color = storm_color.lerp(Color(0.55, 0.74, 1.0, 1.0), lightning * 0.55)
	env.ambient_light_energy = lerp(env.ambient_light_energy, 0.70 + lightning * 1.6 + (1.0 - visibility) * 0.20, min(1.0, delta * 2.0))
	if sun_light:
		sun_light.light_energy = lerp(sun_light.light_energy, 1.35 + lightning * 4.8 + hazard * 0.55, min(1.0, delta * 4.5))


func _update_player_pose(delta: float, input_state: Dictionary, effect: Dictionary) -> void:
	var boost = bool(input_state.get("boost", false))
	boost_amount = lerp(boost_amount, 1.0 if boost else 0.0, min(1.0, delta * 4.0))
	var hazard = float(effect.get("stormHazard", 0.0))
	var overcharged = bool(effect.get("lightningOvercharge", false))
	var bob = sin(forward_time * 4.2) * 0.04 + sin(forward_time * 15.0) * hazard * 0.045
	player_rig.position = Vector3(corridor_pos.x, 1.55 + corridor_pos.y + bob, 0.0)
	var roll = -corridor_pos.x / corridor_width * 0.32 - float(effect.get("windDrift", 0.0)) * 0.055
	var pitch = corridor_pos.y / corridor_height * 0.12 - boost_amount * 0.06 + hazard * 0.035
	player_rig.rotation = player_rig.rotation.lerp(Vector3(pitch, 0.0, roll), min(1.0, delta * 6.0))
	var flame_scale = 1.0 + boost_amount * 0.65 + sin(forward_time * 18.0) * 0.08 + (0.35 if overcharged else 0.0)
	if afterburner_left:
		afterburner_left.scale.z = flame_scale
	if afterburner_right:
		afterburner_right.scale.z = flame_scale


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


func _update_camera(delta: float, input_state: Dictionary, effect: Dictionary) -> void:
	var player_pos = player_rig.global_position
	var hazard = float(effect.get("stormHazard", 0.0))
	var lightning = float(effect.get("lightningFlash", 0.0))
	var shake = hazard * 0.10 + lightning * 0.07
	var shake_offset = Vector3(sin(forward_time * 19.0) * shake, cos(forward_time * 17.0) * shake * 0.7, 0.0)
	var target_camera = player_pos + Vector3(corridor_pos.x * 0.06, 3.45, 12.0 - boost_amount * 1.1) + shake_offset
	camera.position = camera.position.lerp(target_camera, min(1.0, delta * 5.0))
	var look_target = player_pos + Vector3(corridor_pos.x * 0.035, 0.82, -27.0)
	camera.look_at(look_target, Vector3.UP)
	var visibility = float(effect.get("rainVisibility", 1.0))
	var target_fov = (68.0 if bool(input_state.get("boost", false)) else 64.0) + (1.0 - visibility) * 2.0
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
