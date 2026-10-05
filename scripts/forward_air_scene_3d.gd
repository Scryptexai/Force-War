extends Node3D
class_name ForwardAirScene3D

# Phase 1 forward-flight scene. This is the new gameplay direction:
# GLB aircraft, chase camera behind/slightly above, and forward motion in 3D.

const PLAYER_MODEL_PATH = "res://assets/models/player_stormhawk.glb"
const FORWARD_DIR = Vector3(0.0, 0.0, -1.0)

var owner_main: Node
var active = false
var is_setup = false
var rng = RandomNumberGenerator.new()

var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var camera: Camera3D
var player_rig: Node3D
var player_model: Node3D
var afterburner_left: MeshInstance3D
var afterburner_right: MeshInstance3D

var lane_markers: Array = []
var cloud_markers: Array = []
var warzone_chunks: Array = []
var debris_markers: Array = []

var corridor_pos = Vector2.ZERO
var corridor_target = Vector2.ZERO
var corridor_width = 5.4
var corridor_height = 2.6
var forward_time = 0.0
var mission_progress = 0.0
var forward_speed = 36.0
var boost_amount = 0.0
var max_hp = 120
var hp = 120
var current_stage_name = "Forward Air Trial"
var camera_mode = "chase_behind_above"


func setup(main_owner: Node) -> void:
	if is_setup:
		return
	owner_main = main_owner
	rng.randomize()
	name = "ForwardAirScene3D"
	visible = false
	_create_environment()
	_create_camera_rig()
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
	forward_speed = 34.0 + float(stage_data.get("threat", 1.0)) * 4.0
	max_hp = int(float(aircraft_data.get("hp", 120)) * float(loadout_data.get("armor", 1.0)))
	hp = max_hp
	if player_rig:
		player_rig.position = Vector3(0.0, 1.5, 0.0)
		player_rig.rotation = Vector3.ZERO
	if camera:
		camera.current = true
		camera.position = Vector3(0.0, 4.8, 9.0)
		camera.look_at(Vector3(0.0, 2.2, -18.0), Vector3.UP)
	_reset_depth_nodes()


func stop_mission() -> void:
	active = false
	visible = false
	if camera:
		camera.current = false


func is_active() -> bool:
	return active and visible


func update_forward(delta: float, input_state: Dictionary) -> void:
	if not active:
		return
	forward_time += delta
	mission_progress = clamp(mission_progress + delta * forward_speed / 1250.0, 0.0, 0.985)
	_update_corridor_position(delta, input_state)
	_update_player_pose(delta, input_state)
	_update_forward_markers(delta)
	_update_camera(delta, input_state)


func get_bridge_state() -> Dictionary:
	return {
		"missionMode": "forward_air_combat",
		"cameraMode": camera_mode,
		"playerModel": "glb",
		"stageName": current_stage_name,
		"progress": mission_progress,
		"forwardSpeed": forward_speed,
		"corridorX": corridor_pos.x,
		"corridorY": corridor_pos.y,
		"hp": hp,
		"maxHp": max_hp,
		"active": active
	}


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
	camera.fov = 58.0
	camera.near = 0.04
	camera.far = 420.0
	camera.current = false
	add_child(camera)


func _create_player_rig() -> void:
	player_rig = Node3D.new()
	player_rig.name = "PlayerRig3D_ForwardAircraft"
	player_rig.position = Vector3(0.0, 1.5, 0.0)
	add_child(player_rig)
	_load_player_model()
	_create_afterburners()


func _load_player_model() -> void:
	var packed = load(PLAYER_MODEL_PATH)
	if packed is PackedScene:
		player_model = packed.instantiate()
		player_model.name = "PlayerStormhawkGLB"
		player_model.scale = Vector3(1.0, 1.0, 1.0)
		player_rig.add_child(player_model)
	else:
		player_model = Node3D.new()
		player_model.name = "PlayerStormhawkFallbackMesh"
		player_rig.add_child(player_model)
		_create_fallback_aircraft(player_model)


func _create_fallback_aircraft(parent: Node3D) -> void:
	var metal = _make_material(Color(0.18, 0.22, 0.30, 1.0), Color(0.05, 0.16, 0.28, 1.0), 0.45)
	var cyan = _make_material(Color(0.15, 0.75, 1.0, 1.0), Color(0.2, 0.9, 1.0, 1.0), 0.2)
	parent.add_child(_box_mesh("FallbackFuselage", Vector3(0.0, 0.0, 0.05), Vector3(0.62, 0.34, 2.8), metal))
	parent.add_child(_box_mesh("FallbackLeftWing", Vector3(-1.05, -0.04, 0.25), Vector3(1.75, 0.08, 0.62), metal))
	parent.add_child(_box_mesh("FallbackRightWing", Vector3(1.05, -0.04, 0.25), Vector3(1.75, 0.08, 0.62), metal))
	parent.add_child(_box_mesh("FallbackCanopy", Vector3(0.0, 0.24, -0.55), Vector3(0.38, 0.18, 0.58), cyan))


func _create_afterburners() -> void:
	var flame_mat = _make_material(Color(0.25, 0.82, 1.0, 0.78), Color(0.2, 0.9, 1.0, 1.0), 0.0, 0.78)
	afterburner_left = _box_mesh("LeftAfterburnerFlame", Vector3(-0.28, -0.03, 1.78), Vector3(0.18, 0.18, 0.92), flame_mat)
	afterburner_right = _box_mesh("RightAfterburnerFlame", Vector3(0.28, -0.03, 1.78), Vector3(0.18, 0.18, 0.92), flame_mat)
	player_rig.add_child(afterburner_left)
	player_rig.add_child(afterburner_right)


func _create_forward_depth_markers() -> void:
	var lane_mat = _make_material(Color(0.1, 0.9, 1.0, 0.38), Color(0.1, 0.65, 1.0, 1.0), 0.0, 0.38)
	for i in range(8):
		var gate = Node3D.new()
		gate.name = "ForwardFlightGate_%02d" % i
		gate.position = Vector3(0.0, 1.65, -18.0 - i * 13.5)
		gate.add_child(_box_mesh("GateLeft", Vector3(-corridor_width, 0.0, 0.0), Vector3(0.035, corridor_height * 2.0, 0.035), lane_mat))
		gate.add_child(_box_mesh("GateRight", Vector3(corridor_width, 0.0, 0.0), Vector3(0.035, corridor_height * 2.0, 0.035), lane_mat))
		gate.add_child(_box_mesh("GateTop", Vector3(0.0, corridor_height, 0.0), Vector3(corridor_width * 2.0, 0.035, 0.035), lane_mat))
		gate.add_child(_box_mesh("GateBottom", Vector3(0.0, -corridor_height, 0.0), Vector3(corridor_width * 2.0, 0.035, 0.035), lane_mat))
		add_child(gate)
		lane_markers.append(gate)

	var cloud_mat = _make_material(Color(0.58, 0.72, 0.88, 0.35), Color(0.04, 0.10, 0.16, 1.0), 0.0, 0.35)
	for i in range(18):
		var cloud = _box_mesh("StormCloudChunk_%02d" % i, Vector3.ZERO, Vector3(rng.randf_range(2.2, 5.6), rng.randf_range(0.35, 0.95), rng.randf_range(1.2, 3.5)), cloud_mat)
		cloud.position = Vector3(rng.randf_range(-9.5, 9.5), rng.randf_range(2.2, 7.0), -12.0 - rng.randf_range(0.0, 110.0))
		add_child(cloud)
		cloud_markers.append(cloud)

	var ocean_mat = _make_material(Color(0.03, 0.12, 0.18, 1.0), Color(0.0, 0.05, 0.08, 1.0), 0.15)
	var fire_mat = _make_material(Color(1.0, 0.34, 0.08, 1.0), Color(1.0, 0.18, 0.02, 1.0), 0.0)
	for i in range(10):
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


func _update_corridor_position(delta: float, input_state: Dictionary) -> void:
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
	corridor_pos.x = clamp(corridor_pos.x, -corridor_width, corridor_width)
	corridor_pos.y = clamp(corridor_pos.y, -corridor_height, corridor_height)


func _update_player_pose(delta: float, input_state: Dictionary) -> void:
	var boost = bool(input_state.get("boost", false))
	boost_amount = lerp(boost_amount, 1.0 if boost else 0.0, min(1.0, delta * 4.0))
	var bob = sin(forward_time * 4.2) * 0.04
	player_rig.position = Vector3(corridor_pos.x, 1.55 + corridor_pos.y + bob, 0.0)
	var roll = -corridor_pos.x / corridor_width * 0.32
	var pitch = corridor_pos.y / corridor_height * 0.12 - boost_amount * 0.06
	player_rig.rotation = player_rig.rotation.lerp(Vector3(pitch, 0.0, roll), min(1.0, delta * 6.0))
	var flame_scale = 1.0 + boost_amount * 0.65 + sin(forward_time * 18.0) * 0.08
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


func _update_camera(delta: float, input_state: Dictionary) -> void:
	var player_pos = player_rig.global_position
	var target_camera = player_pos + Vector3(corridor_pos.x * 0.08, 3.25, 8.7 - boost_amount * 0.9)
	camera.position = camera.position.lerp(target_camera, min(1.0, delta * 5.0))
	var look_target = player_pos + Vector3(corridor_pos.x * 0.04, 0.85, -19.0)
	camera.look_at(look_target, Vector3.UP)
	camera.fov = lerp(camera.fov, 63.0 if bool(input_state.get("boost", false)) else 58.0, min(1.0, delta * 3.5))


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
