extends Node3D
class_name EnemySquadron3D

# Pass 3, item 1: real air enemies.
#
# Every unit here is a full entity, not decoration: it owns its own Health, a
# world-space hitbox the player's logical bullets test against, visible muzzle
# points its bullets are spawned from, and a death event that drives the
# explosion pool. Two silhouettes are used so the player can tell them apart at
# a glance: a small fast DRONE and a wide slow GUNSHIP. Both carry a red eye,
# the threat marker required by the faction colour code.
#
# Everything lives on the single combat plane (CombatSpace.PLANE_Y).

const ENEMY_MODEL_PATH := "res://assets/models/enemy_hero_jet_blender_ready.glb"

const ENEMY_VISUAL_LAYER := 1 << 1

const DRONE := "drone"
const GUNSHIP := "gunship"

var units: Array = []
var fire_events: Array = []
var death_events: Array = []
var hit_events: Array = []

var rng := RandomNumberGenerator.new()
var active := false
var squad_time := 0.0
var spawn_timer := 2.2
var wave_index := 0
var spawned_count := 0
var killed_count := 0
var fire_event_count := 0
var escaped_count := 0
var max_units := 6
var density_scale := 1.0

var hull_mat: StandardMaterial3D
var eye_mat: StandardMaterial3D
var thruster_mat: StandardMaterial3D
var burnt_mat: StandardMaterial3D
var model_loaded := false


func setup() -> void:
	name = "EnemySquadron3D"
	rng.randomize()
	_create_materials()
	for i in range(max_units):
		units.append(_create_unit(i))


func start_mission(_stage_data: Dictionary) -> void:
	active = true
	visible = true
	squad_time = 0.0
	spawn_timer = 2.0
	wave_index = 0
	spawned_count = 0
	killed_count = 0
	escaped_count = 0
	fire_event_count = 0
	fire_events.clear()
	death_events.clear()
	hit_events.clear()
	for unit in units:
		_retire_unit(unit, false)


func stop_mission() -> void:
	active = false
	visible = false
	for unit in units:
		_retire_unit(unit, false)


func set_density_scale(value: float) -> void:
	# Pass 3 rule: when FPS drops, reduce density instead of keeping the load.
	density_scale = clampf(value, 0.25, 1.0)


# ------------------------------------------------------------------- runtime
func update_squadron(delta: float, player_xz: Vector2, pressure: float) -> void:
	if not active:
		return
	squad_time += delta
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_wave(pressure)
		var gap: float = lerpf(5.4, 3.4, clampf(pressure, 0.0, 1.0)) / density_scale
		spawn_timer = gap
	for unit in units:
		if bool(unit["alive"]):
			_update_unit(unit, delta, player_xz)
		else:
			_update_wreck(unit, delta)


func _update_unit(unit: Dictionary, delta: float, player_xz: Vector2) -> void:
	var root: Node3D = unit["root"]
	unit["life_time"] = float(unit["life_time"]) + delta
	var t: float = float(unit["life_time"])
	var pos: Vector3 = root.position
	pos.z += float(unit["speed"]) * delta
	# Readable lateral weave; never a homing chase.
	pos.x = float(unit["lane_x"]) + sin(t * float(unit["weave_rate"]) + float(unit["weave_phase"])) * float(unit["weave_width"])
	pos.y = CombatSpace.PLANE_Y
	root.position = pos
	root.rotation.z = lerpf(root.rotation.z, -cos(t * float(unit["weave_rate"]) + float(unit["weave_phase"])) * 0.42, minf(1.0, delta * 4.0))

	unit["hit_flash"] = maxf(0.0, float(unit["hit_flash"]) - delta * 4.5)
	var eye: MeshInstance3D = unit["eye"]
	if eye != null:
		var eye_material := eye.material_override as StandardMaterial3D
		if eye_material != null:
			var pulse: float = 0.72 + 0.28 * sin(t * 6.4)
			eye_material.emission_energy_multiplier = 1.5 * pulse + float(unit["hit_flash"]) * 5.0

	# Telegraph then fire from the visible muzzle points.
	unit["fire_timer"] = float(unit["fire_timer"]) - delta
	if float(unit["fire_timer"]) <= float(unit["telegraph"]) and not bool(unit["telegraphing"]):
		unit["telegraphing"] = true
	if float(unit["fire_timer"]) <= 0.0 and pos.z < 2.0:
		_fire(unit, player_xz)
		unit["fire_timer"] = float(unit["fire_interval"])
		unit["telegraphing"] = false

	if pos.z > 9.0:
		escaped_count += 1
		_retire_unit(unit, false)


func _update_wreck(unit: Dictionary, delta: float) -> void:
	if not bool(unit["wreck"]):
		return
	var root: Node3D = unit["root"]
	unit["wreck_timer"] = float(unit["wreck_timer"]) - delta
	root.position.y -= delta * 5.6
	root.rotation.x += delta * 2.1
	root.rotation.z += delta * 1.4
	if float(unit["wreck_timer"]) <= 0.0 or root.position.y < CombatSpace.UNDERWORLD_Y:
		_retire_unit(unit, false)


func _fire(unit: Dictionary, player_xz: Vector2) -> void:
	var root: Node3D = unit["root"]
	var muzzles: Array = unit["muzzles"]
	# Aim is locked at the moment of firing and never updated again.
	var to_player := Vector2(player_xz.x - root.position.x, player_xz.y - root.position.z)
	var angle: float = clampf(atan2(to_player.x, maxf(1.0, to_player.y)), -0.42, 0.42)
	var spread: Array = unit["spread"]
	for muzzle_value in muzzles:
		var muzzle: Node3D = muzzle_value
		if muzzle == null or not muzzle.is_inside_tree():
			continue
		var origin: Vector3 = muzzle.global_position
		origin.y = CombatSpace.PLANE_Y
		for offset_value in spread:
			var shot_angle: float = angle + deg_to_rad(float(offset_value))
			fire_events.append({
				"origin": origin,
				"dir": Vector3(sin(shot_angle), 0.0, cos(shot_angle)),
				"speed": float(unit["bullet_speed"]),
				"damage": float(unit["bullet_damage"]),
				"part": str(unit["kind"])
			})
			fire_event_count += 1
	unit["muzzle_flash"] = 0.12


# ------------------------------------------------------------------ gameplay
func query_hit(world_pos: Vector3, radius: float) -> int:
	for i in range(units.size()):
		var unit: Dictionary = units[i]
		if not bool(unit["alive"]):
			continue
		var root: Node3D = unit["root"]
		var box: Vector3 = unit["hitbox"]
		var local := world_pos - root.position
		if absf(local.x) <= box.x + radius and absf(local.z) <= box.z + radius:
			return i
	return -1


func apply_hit(index: int, damage: float, world_pos: Vector3) -> float:
	if index < 0 or index >= units.size():
		return 0.0
	var unit: Dictionary = units[index]
	if not bool(unit["alive"]):
		return 0.0
	var before: float = float(unit["hp"])
	var after: float = maxf(0.0, before - damage)
	unit["hp"] = after
	unit["hit_flash"] = 1.0
	hit_events.append({"kind": str(unit["kind"]), "damage": before - after, "pos": world_pos})
	if after <= 0.0:
		_destroy_unit(unit)
	return before - after


func consume_fire_events() -> Array:
	var events := fire_events.duplicate()
	fire_events.clear()
	return events


func consume_death_events() -> Array:
	var events := death_events.duplicate()
	death_events.clear()
	return events


func consume_hit_events() -> Array:
	var events := hit_events.duplicate()
	hit_events.clear()
	return events


func live_unit_count() -> int:
	var count := 0
	for unit in units:
		if bool(unit["alive"]):
			count += 1
	return count


func get_live_muzzle_positions() -> Array:
	var positions: Array = []
	for unit in units:
		if not bool(unit["alive"]):
			continue
		for muzzle_value in unit["muzzles"]:
			var muzzle: Node3D = muzzle_value
			if muzzle != null and muzzle.is_inside_tree():
				positions.append(muzzle.global_position)
	return positions


func _nearest_unit_z() -> float:
	var nearest := -999.0
	for unit in units:
		if bool(unit["alive"]):
			var root: Node3D = unit["root"]
			nearest = maxf(nearest, root.position.z)
	return nearest


func get_bridge_state() -> Dictionary:
	var live := live_unit_count()
	var kinds: Array = []
	for unit in units:
		if bool(unit["alive"]) and not kinds.has(str(unit["kind"])):
			kinds.append(str(unit["kind"]))
	return {
		"airEnemyEntities": true,
		"airEnemyModelLoaded": model_loaded,
		"airEnemyTypes": [DRONE, GUNSHIP],
		"airEnemyLiveCount": live,
		"airEnemyNearestZ": _nearest_unit_z(),
		"airEnemyLiveKinds": kinds,
		"airEnemyPoolSize": units.size(),
		"airEnemySpawned": spawned_count,
		"airEnemyKilled": killed_count,
		"airEnemyEscaped": escaped_count,
		"airEnemyFireEvents": fire_event_count,
		"airEnemyMuzzleCount": get_live_muzzle_positions().size(),
		"airEnemyHitboxModel": "per_unit_world_box_on_combat_plane",
		"airEnemyThreatMarker": "red_eye_emissive",
		"airEnemyHomingBullets": false,
		"airEnemyDensityScale": density_scale
	}


# -------------------------------------------------------------------- spawns
func _spawn_wave(pressure: float) -> void:
	wave_index += 1
	var want: int = 2 if wave_index % 2 == 1 else 3
	want = int(round(float(want) * density_scale))
	want = max(1, want)
	var kind: String = DRONE if wave_index % 2 == 1 else GUNSHIP
	var spread_x: float = 4.6
	for i in range(want):
		var unit := _free_unit()
		if unit.is_empty():
			return
		var lane: float = (float(i) - float(want - 1) * 0.5) * spread_x
		_deploy(unit, kind, lane, pressure)


func _free_unit() -> Dictionary:
	for unit in units:
		if not bool(unit["alive"]) and not bool(unit["wreck"]):
			return unit
	return {}


func _deploy(unit: Dictionary, kind: String, lane_x: float, pressure: float) -> void:
	var root: Node3D = unit["root"]
	unit["kind"] = kind
	unit["alive"] = true
	unit["wreck"] = false
	unit["life_time"] = 0.0
	unit["hit_flash"] = 0.0
	unit["lane_x"] = clampf(lane_x, -CombatSpace.PLAYER_X_LIMIT, CombatSpace.PLAYER_X_LIMIT)
	unit["weave_phase"] = rng.randf_range(0.0, TAU)
	if kind == DRONE:
		unit["hp"] = 56.0
		unit["speed"] = 9.2 + pressure * 2.4
		unit["weave_rate"] = 1.9
		unit["weave_width"] = 2.3
		unit["fire_interval"] = 1.55
		unit["telegraph"] = 0.34
		unit["bullet_speed"] = 30.0
		unit["bullet_damage"] = 7.0
		unit["spread"] = [0.0]
		unit["hitbox"] = Vector3(1.0, 0.6, 1.15)
	else:
		unit["hp"] = 128.0
		unit["speed"] = 5.6 + pressure * 1.4
		unit["weave_rate"] = 1.05
		unit["weave_width"] = 1.4
		unit["fire_interval"] = 2.05
		unit["telegraph"] = 0.52
		unit["bullet_speed"] = 25.0
		unit["bullet_damage"] = 9.0
		unit["spread"] = [-9.0, 9.0]
		unit["hitbox"] = Vector3(1.7, 0.7, 1.5)
	unit["max_hp"] = float(unit["hp"])
	unit["fire_timer"] = float(unit["fire_interval"]) * 0.65
	unit["telegraphing"] = false
	root.position = Vector3(float(unit["lane_x"]), CombatSpace.PLANE_Y, CombatSpace.BOSS_Z + 11.0 - rng.randf_range(0.0, 4.0))
	root.rotation = Vector3.ZERO
	root.scale = Vector3.ONE * (0.34 if kind == DRONE else 0.60)
	root.visible = true
	_apply_kind_visual(unit, kind)
	spawned_count += 1


func _destroy_unit(unit: Dictionary) -> void:
	var root: Node3D = unit["root"]
	killed_count += 1
	death_events.append({
		"pos": root.position,
		"kind": str(unit["kind"]),
		"scale": 0.85 if str(unit["kind"]) == DRONE else 1.3
	})
	unit["alive"] = false
	unit["wreck"] = true
	unit["wreck_timer"] = 1.15
	var body: Node3D = unit["body"]
	if body != null:
		_force_material(body, burnt_mat)
	var eye: MeshInstance3D = unit["eye"]
	if eye != null:
		eye.visible = false
	for thruster_value in unit["thrusters"]:
		var thruster: MeshInstance3D = thruster_value
		thruster.visible = false


func _retire_unit(unit: Dictionary, _killed: bool) -> void:
	unit["alive"] = false
	unit["wreck"] = false
	unit["wreck_timer"] = 0.0
	var root: Node3D = unit["root"]
	root.visible = false
	root.position = Vector3(0.0, CombatSpace.PLANE_Y, CombatSpace.BOSS_Z + 24.0)
	var eye: MeshInstance3D = unit["eye"]
	if eye != null:
		eye.visible = true
	for thruster_value in unit["thrusters"]:
		var thruster: MeshInstance3D = thruster_value
		thruster.visible = true


# -------------------------------------------------------------------- visuals
func _create_unit(index: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "AirEnemy_%02d" % index
	root.visible = false
	add_child(root)

	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)

	var model_scene: PackedScene = load(ENEMY_MODEL_PATH) as PackedScene
	if model_scene != null:
		var model := model_scene.instantiate() as Node3D
		if model != null:
			model.name = "EnemyJetModel"
			# The GLB nose points -Z; these enemies fly toward the player (+Z).
			model.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			# The GLB's Blender root is offset by (-1.35, 1.05, -0.1); zero it so the
			# hull is centred on the unit origin and the eye/thruster/muzzle points line up.
			for inner_child in model.get_children():
				if inner_child is Node3D:
					(inner_child as Node3D).position = Vector3.ZERO
			body.add_child(model)
			_force_material(model, hull_mat)
			model_loaded = true

	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.2
	eye_mesh.height = 0.4
	var eye := MeshInstance3D.new()
	eye.name = "ThreatEye"
	eye.mesh = eye_mesh
	eye.material_override = eye_mat
	eye.layers = ENEMY_VISUAL_LAYER
	eye.position = Vector3(0.0, 0.16, 1.15)
	root.add_child(eye)

	var thrusters: Array = []
	for side in [-1.0, 1.0]:
		var thruster_mesh := SphereMesh.new()
		thruster_mesh.radius = 0.22
		thruster_mesh.height = 0.44
		var thruster := MeshInstance3D.new()
		thruster.name = "HostileThruster_%s" % ("L" if side < 0.0 else "R")
		thruster.mesh = thruster_mesh
		thruster.material_override = thruster_mat
		thruster.layers = ENEMY_VISUAL_LAYER
		thruster.position = Vector3(side * 0.55, 0.02, -1.0)
		thruster.scale = Vector3(1.0, 0.55, 1.6)
		root.add_child(thruster)
		thrusters.append(thruster)

	var muzzles: Array = []
	for side in [-1.0, 1.0]:
		var muzzle := Node3D.new()
		muzzle.name = "Muzzle_%s" % ("L" if side < 0.0 else "R")
		muzzle.position = Vector3(side * 1.25, 0.0, 1.35)
		body.add_child(muzzle)
		muzzles.append(muzzle)

	return {
		"root": root,
		"body": body,
		"eye": eye,
		"thrusters": thrusters,
		"muzzles": muzzles,
		"kind": DRONE,
		"alive": false,
		"wreck": false,
		"wreck_timer": 0.0,
		"hp": 0.0,
		"max_hp": 1.0,
		"speed": 8.0,
		"lane_x": 0.0,
		"weave_rate": 1.6,
		"weave_width": 2.0,
		"weave_phase": 0.0,
		"life_time": 0.0,
		"fire_timer": 1.0,
		"fire_interval": 1.6,
		"telegraph": 0.35,
		"telegraphing": false,
		"muzzle_flash": 0.0,
		"bullet_speed": 28.0,
		"bullet_damage": 7.0,
		"spread": [0.0],
		"hit_flash": 0.0,
		"hitbox": Vector3(0.9, 0.6, 1.0)
	}


func _apply_kind_visual(unit: Dictionary, kind: String) -> void:
	var body: Node3D = unit["body"]
	if body == null:
		return
	_force_material(body, hull_mat)
	var eye: MeshInstance3D = unit["eye"]
	if eye != null:
		eye.visible = true
		# The gunship reads wider and heavier, the drone small and sharp.
		eye.scale = Vector3.ONE * (1.0 if kind == DRONE else 1.35)
		eye.position = Vector3(0.0, 0.16, 1.15 if kind == DRONE else 1.35)
	for thruster_value in unit["thrusters"]:
		var thruster: MeshInstance3D = thruster_value
		var side: float = -1.0 if thruster.name.ends_with("L") else 1.0
		thruster.position = Vector3(side * (0.5 if kind == DRONE else 0.78), 0.02, -1.0)
	body.scale = Vector3(1.0, 1.0, 1.0) if kind == DRONE else Vector3(1.55, 0.86, 1.0)


func _force_material(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node
		# Visual layer 2 keeps hostile hulls out of the player readability lamp,
		# so an enemy drifting past the player never borrows the player's value.
		mesh_node.layers = ENEMY_VISUAL_LAYER
		if mesh_node.name != "ThreatEye" and not mesh_node.name.begins_with("HostileThruster"):
			mesh_node.material_override = material
	for child in node.get_children():
		_force_material(child, material)


func _create_materials() -> void:
	hull_mat = StandardMaterial3D.new()
	# Dark hostile hull: value sits under the player so the hierarchy holds.
	hull_mat.albedo_color = Color(0.17, 0.155, 0.175, 1.0)
	hull_mat.metallic = 0.0
	hull_mat.roughness = 0.95
	hull_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.95, 0.12, 0.06, 1.0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.16, 0.05, 1.0)
	eye_mat.emission_energy_multiplier = 1.5
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	thruster_mat = StandardMaterial3D.new()
	thruster_mat.albedo_color = Color(1.0, 0.42, 0.10, 1.0)
	thruster_mat.emission_enabled = true
	thruster_mat.emission = Color(1.0, 0.40, 0.08, 1.0)
	thruster_mat.emission_energy_multiplier = 1.25
	thruster_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	burnt_mat = StandardMaterial3D.new()
	burnt_mat.albedo_color = Color(0.05, 0.045, 0.045, 1.0)
	burnt_mat.metallic = 0.0
	burnt_mat.roughness = 1.0
	burnt_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
