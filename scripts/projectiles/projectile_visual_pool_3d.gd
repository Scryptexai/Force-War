extends Node3D
class_name ProjectileVisualPool3D

# Renderer-facing projectile pool for forward-air bullet-hell visuals.
# Gameplay collision can stay logical/data-driven; this node batches repeated bolt
# meshes through MultiMeshInstance3D so a dense field does not require one Node3D
# per projectile. This is the first runtime step toward the architecture target.

var pool_label := "projectile_pool"
var active := false
var toward_camera := true
var z_near := 8.0
var z_far := -120.0
var y_min := 1.0
var y_max := 5.0
var bolt_size := Vector2(0.35, 1.45)
var rng := RandomNumberGenerator.new()

var lanes: Array = []
var positions: Array = []
var base_lanes: Array = []
var phases: Array = []
var spawn_origins: Array = []
var spawn_from_hardpoints := false
var wobble_rates: Array = []
var speeds: Array = []

var multimesh := MultiMesh.new()
var instance_node := MultiMeshInstance3D.new()


func setup(
	label: String,
	texture: Texture2D,
	tint: Color,
	count: int,
	size: Vector2,
	lane_positions: Array,
	min_y: float,
	max_y: float,
	near_z: float,
	far_z: float,
	moves_toward_camera: bool,
	min_speed: float,
	max_speed: float
) -> void:
	pool_label = label
	name = "ProjectileVisualPool3D_" + label
	rng.randomize()
	toward_camera = moves_toward_camera
	z_near = near_z
	z_far = far_z
	y_min = min_y
	y_max = max_y
	bolt_size = size
	lanes = lane_positions.duplicate()
	if lanes.is_empty():
		lanes = [0.0]

	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = max(0, count)

	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Foundation correction: no billboarding for gameplay bolts. The long axis is
	# aligned through world depth so shots read as forward fire, not vertical UI streaks.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = Color(tint.r, tint.g, tint.b, 1.0)
	material.emission_texture = texture
	material.emission_energy_multiplier = 2.6

	instance_node = MultiMeshInstance3D.new()
	instance_node.name = "BatchedBoltMultimesh_" + label
	instance_node.multimesh = multimesh
	instance_node.material_override = material
	add_child(instance_node)

	positions.clear()
	base_lanes.clear()
	phases.clear()
	wobble_rates.clear()
	speeds.clear()
	for i in range(multimesh.instance_count):
		_reset_instance(i, true, min_speed, max_speed)
	active = multimesh.instance_count > 0


func update_pool(delta: float, wind_drift: float, time_seconds: float) -> void:
	if not active:
		return
	for i in range(multimesh.instance_count):
		var pos: Vector3 = positions[i]
		var speed := float(speeds[i])
		if toward_camera:
			pos.z += speed * delta
			if pos.z > z_near:
				pos.z = z_far - rng.randf_range(0.0, 18.0)
				pos.y = rng.randf_range(y_min, y_max)
				base_lanes[i] = float(lanes[i % lanes.size()])
		else:
			pos.z -= speed * delta
			if pos.z < z_far:
				if spawn_from_hardpoints and not spawn_origins.is_empty():
					var origin: Vector3 = spawn_origins[i % spawn_origins.size()]
					pos = origin
					base_lanes[i] = origin.x
				else:
					pos.z = z_near + rng.randf_range(0.0, 3.5)
					pos.y = rng.randf_range(y_min, y_max)
					base_lanes[i] = float(lanes[i % lanes.size()])
		pos.x = float(base_lanes[i]) + sin(time_seconds * float(wobble_rates[i]) + float(phases[i])) * 0.09 + wind_drift * 0.10
		positions[i] = pos
		_write_transform(i, pos)


func get_pool_count() -> int:
	return multimesh.instance_count if active else 0


func set_spawn_origins(hardpoint_state: Dictionary) -> void:
	spawn_origins.clear()
	spawn_from_hardpoints = bool(hardpoint_state.get("sockets_found", false)) and not toward_camera
	if not spawn_from_hardpoints:
		return
	for key in ["left", "right", "center"]:
		if hardpoint_state.has(key):
			var value = hardpoint_state[key]
			if value is Vector3:
				spawn_origins.append(value)
	if spawn_origins.is_empty():
		spawn_from_hardpoints = false


func _reset_instance(i: int, randomize_z: bool, min_speed: float, max_speed: float) -> void:
	var lane := float(lanes[i % lanes.size()])
	var z := z_far
	if randomize_z:
		z = lerp(z_near, z_far, rng.randf())
	else:
		z = z_far if toward_camera else z_near
	var pos := Vector3(lane, rng.randf_range(y_min, y_max), z)
	positions.append(pos)
	base_lanes.append(lane)
	phases.append(rng.randf_range(0.0, TAU))
	wobble_rates.append(rng.randf_range(2.8, 7.4))
	speeds.append(rng.randf_range(min_speed, max_speed))
	_write_transform(i, pos)


func _write_transform(i: int, pos: Vector3) -> void:
	var basis := Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(bolt_size.x, bolt_size.y, 1.0))
	multimesh.set_instance_transform(i, Transform3D(basis, pos))
