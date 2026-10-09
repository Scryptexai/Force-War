extends Node3D
class_name BossEntity3D

# Authoritative boss entity.
#
# Correction brief, section 2 point 1: presentation is derived from state owned by
# the entity that lives in the world. This node owns the visible Dreadnought
# Leviathan, its destructible parts, their hitboxes, their muzzles and their
# damage/destruction visuals. The phase/HP store (BossPhaseController) is a CHILD
# component of this entity, so there is no boss health floating in a manager that
# the HUD can read without a boss existing in the world.
#
# Nothing else in the project is allowed to mutate boss health: damage only enters
# through apply_hit(), which is only reachable after query_hit() resolved a real
# part hitbox in world space.

const BOSS_MODEL_PATH := "res://assets/models/boss_battleship_leviathan.glb"
const PHASE_CONTROLLER_SCRIPT := preload("res://scripts/boss/boss_phase_controller.gd")
const EXPLOSION_TEXTURE_PATH := "res://assets/vfx/explosion_fireball.png"
const SMOKE_TEXTURE_PATH := "res://assets/vfx/smoke_plume.png"

const WEAPON_PARTS: Array = ["turret_left", "turret_right", "core"]

var phase_controller: Node
var hull_root: Node3D
var model_loaded := false
var model_scale := 1.0
var rng := RandomNumberGenerator.new()

# part_name -> {
#   "anchor": Node3D, "meshes": Array, "glows": Array, "muzzles": Array,
#   "extents": Vector3, "flash": float, "telegraph": float,
#   "destroyed_visual": bool, "smoke": MeshInstance3D }
var part_visuals: Dictionary = {}
var shield_shell: MeshInstance3D
var impact_pool: Array = []
var impact_cursor := 0
var muzzle_flashes: Array = []

var attack_state := "idle"
var attack_timer := 0.0
var volley_index := 0
var active_pattern := "shield_lane_sweep_pool_v1"
var telegraph_part := ""
var telegraph_ratio := 0.0
var fire_events: Array = []
var fire_event_count := 0
var telegraph_count := 0
var boss_time := 0.0
var active := false
var sockets_bound := false

var hull_mat: StandardMaterial3D
var armor_mat: StandardMaterial3D
var threat_glow_mat: StandardMaterial3D
var core_mat: StandardMaterial3D
var shield_mat: StandardMaterial3D
var burnt_mat: StandardMaterial3D
var explosion_texture: Texture2D
var smoke_texture: Texture2D


func setup() -> void:
	rng.randomize()
	name = "BossEntity_DreadnoughtLeviathan"
	model_scale = CombatSpace.BOSS_MODEL_SCALE
	explosion_texture = load(EXPLOSION_TEXTURE_PATH)
	smoke_texture = load(SMOKE_TEXTURE_PATH)
	_create_materials()
	phase_controller = PHASE_CONTROLLER_SCRIPT.new()
	phase_controller.name = "BossStateStore"
	add_child(phase_controller)
	if phase_controller.has_method("setup"):
		phase_controller.setup()
	_build_hull()
	_build_parts()
	_build_impact_pool()


func start_mission(stage_data: Dictionary) -> void:
	active = true
	visible = true
	_bind_runtime_transforms()
	boss_time = 0.0
	attack_state = "idle"
	attack_timer = 0.55
	volley_index = 0
	telegraph_part = ""
	telegraph_ratio = 0.0
	fire_events.clear()
	fire_event_count = 0
	telegraph_count = 0
	if phase_controller and phase_controller.has_method("start_mission"):
		phase_controller.start_mission(stage_data)
	for key in part_visuals.keys():
		var part: Dictionary = part_visuals[key]
		part["flash"] = 0.0
		part["telegraph"] = 0.0
		part["destroyed_visual"] = false
		part_visuals[key] = part
		_restore_part_visual(key)
	for impact in impact_pool:
		impact.visible = false
	for flash_node in muzzle_flashes:
		flash_node.visible = false


func stop_mission() -> void:
	active = false
	fire_events.clear()
	if phase_controller and phase_controller.has_method("stop_mission"):
		phase_controller.stop_mission()
	for impact in impact_pool:
		impact.visible = false
	for flash_node in muzzle_flashes:
		flash_node.visible = false


func update_boss(delta: float, overcharged: bool, player_pressure: float) -> void:
	if not active:
		return
	boss_time += delta
	if phase_controller and phase_controller.has_method("update_boss"):
		phase_controller.update_boss(delta, overcharged, player_pressure)
	_sync_part_damage_visuals(delta)
	_update_attack_cycle(delta)
	_update_impact_visuals(delta)
	_update_muzzle_flashes(delta)


# ---------------------------------------------------------------- hit resolution

func query_hit(world_pos: Vector3, radius: float) -> String:
	# Real spatial test against the visible part geometry. Returns "" when the shot
	# passed through empty air, so a bullet can never damage a boss it did not touch.
	if not active:
		return ""
	var best := ""
	var best_depth := -1.0
	for key in part_visuals.keys():
		if not _part_hittable(key):
			continue
		var part: Dictionary = part_visuals[key]
		var anchor: Node3D = part.get("anchor")
		if anchor == null or not anchor.is_inside_tree():
			continue
		var center: Vector3 = anchor.global_position
		var extents: Vector3 = part.get("extents", Vector3.ONE)
		var delta_vec := world_pos - center
		var dx: float = extents.x + radius - absf(delta_vec.x)
		var dy: float = extents.y + radius - absf(delta_vec.y)
		var dz: float = extents.z + radius - absf(delta_vec.z)
		if dx <= 0.0 or dy <= 0.0 or dz <= 0.0:
			continue
		var depth: float = minf(dx, minf(dy, dz))
		if depth > best_depth:
			best_depth = depth
			best = key
	return best


func apply_hit(part_name: String, damage: float, world_pos: Vector3) -> float:
	if not active or phase_controller == null:
		return 0.0
	var applied: float = float(phase_controller.apply_projectile_damage(part_name, damage))
	if applied <= 0.0:
		return 0.0
	var resolved := part_name
	if phase_controller.has_method("get_last_damaged_part"):
		resolved = str(phase_controller.get_last_damaged_part())
	if part_visuals.has(resolved):
		var part: Dictionary = part_visuals[resolved]
		part["flash"] = 0.16
		part_visuals[resolved] = part
	_spawn_impact(world_pos)
	return applied


func get_part_world_position(part_name: String) -> Vector3:
	if part_visuals.has(part_name):
		var anchor: Node3D = part_visuals[part_name].get("anchor")
		if anchor != null and anchor.is_inside_tree():
			return anchor.global_position
	return global_position


func get_weakpoint_world_position() -> Vector3:
	return get_part_world_position(get_targetable_part())


func get_targetable_part() -> String:
	if phase_controller != null:
		return str(phase_controller.current_target_part)
	return "core"


func get_phase() -> int:
	if phase_controller != null:
		return int(phase_controller.phase)
	return 1


# ------------------------------------------------------------------ boss weapons

func consume_fire_events() -> Array:
	var events: Array = fire_events.duplicate(true)
	fire_events.clear()
	return events


func get_live_muzzle_positions() -> Array:
	var positions: Array = []
	for key in WEAPON_PARTS:
		if not _part_alive(key):
			continue
		for muzzle in part_visuals[key].get("muzzles", []):
			var node: Node3D = muzzle
			if node != null and node.is_inside_tree():
				positions.append(node.global_position)
	return positions


func _update_attack_cycle(delta: float) -> void:
	active_pattern = str(phase_controller.active_attack_pattern) if phase_controller != null else active_pattern
	attack_timer -= delta
	var config := _pattern_config(active_pattern)
	match attack_state:
		"idle":
			if attack_timer <= 0.0:
				telegraph_part = _pick_firing_part()
				if telegraph_part == "":
					attack_timer = 0.4
					return
				attack_state = "telegraph"
				attack_timer = float(config.get("telegraph", 0.7))
				telegraph_count += 1
		"telegraph":
			var total: float = maxf(0.05, float(config.get("telegraph", 0.7)))
			telegraph_ratio = clampf(1.0 - attack_timer / total, 0.0, 1.0)
			if part_visuals.has(telegraph_part):
				var part: Dictionary = part_visuals[telegraph_part]
				part["telegraph"] = telegraph_ratio
				part_visuals[telegraph_part] = part
			if attack_timer <= 0.0:
				attack_state = "firing"
				attack_timer = 0.0
				volley_index = 0
		"firing":
			if attack_timer <= 0.0:
				_emit_volley(config)
				volley_index += 1
				attack_timer = float(config.get("volley_interval", 0.16))
				if volley_index >= int(config.get("volleys", 4)):
					attack_state = "recover"
					attack_timer = float(config.get("recover", 0.85))
					telegraph_ratio = 0.0
					if part_visuals.has(telegraph_part):
						var fired: Dictionary = part_visuals[telegraph_part]
						fired["telegraph"] = 0.0
						part_visuals[telegraph_part] = fired
					telegraph_part = ""
		"recover":
			if attack_timer <= 0.0:
				attack_state = "idle"
				attack_timer = 0.12


func _emit_volley(config: Dictionary) -> void:
	if telegraph_part == "" or not _part_alive(telegraph_part):
		return
	var part: Dictionary = part_visuals[telegraph_part]
	var muzzles: Array = part.get("muzzles", [])
	if muzzles.is_empty():
		return
	var spread: Array = config.get("spread", [0.0])
	var speed: float = float(config.get("speed", 38.0))
	var damage: float = float(config.get("damage", 9.0))
	for m in range(muzzles.size()):
		var node: Node3D = muzzles[m]
		if node == null or not node.is_inside_tree():
			continue
		var origin: Vector3 = node.global_position
		origin.y = CombatSpace.PLANE_Y
		for s in range(spread.size()):
			var angle_deg: float = float(spread[s]) + _formation_offset(config, m, s)
			var angle: float = deg_to_rad(angle_deg)
			var dir := Vector3(sin(angle), 0.0, cos(angle)).normalized()
			fire_events.append({
				"origin": origin,
				"dir": dir,
				"speed": speed,
				"damage": damage,
				"part": telegraph_part,
				"pattern": active_pattern
			})
			fire_event_count += 1
		_flash_muzzle(origin)


func _formation_offset(config: Dictionary, muzzle_index: int, shot_index: int) -> float:
	var formation := str(config.get("formation", "fan"))
	match formation:
		"chevron":
			return float(shot_index) * 1.6 - float(muzzle_index) * 3.2
		"wall":
			return sin(float(volley_index) * 0.9) * 5.0
		_:
			return sin(float(volley_index) * 0.7 + float(muzzle_index)) * 3.0


func _pattern_config(pattern: String) -> Dictionary:
	match pattern:
		"turret_crossfire_pool_v1":
			return {
				"telegraph": 0.62,
				"volleys": 3,
				"volley_interval": 0.20,
				"recover": 1.05,
				"speed": 30.0,
				"damage": 9.0,
				"formation": "chevron",
				"spread": [-12.0, 0.0, 12.0]
			}
		"core_laser_burst_pool_v1":
			return {
				"telegraph": 1.05,
				"volleys": 4,
				"volley_interval": 0.18,
				"recover": 1.15,
				"speed": 34.0,
				"damage": 11.0,
				"formation": "fan",
				"spread": [-22.0, -11.0, 11.0, 22.0]
			}
		_:
			return {
				"telegraph": 0.70,
				"volleys": 3,
				"volley_interval": 0.24,
				"recover": 1.10,
				"speed": 27.0,
				"damage": 8.0,
				"formation": "wall",
				"spread": [-18.0, -6.0, 6.0, 18.0]
			}


func _pick_firing_part() -> String:
	var candidates: Array = []
	for key in WEAPON_PARTS:
		if _part_alive(key):
			candidates.append(key)
	if candidates.is_empty():
		return ""
	var phase := get_phase()
	if phase >= 3 and candidates.has("core"):
		return "core"
	return str(candidates[telegraph_count % candidates.size()])


# -------------------------------------------------------------------- state sync

func get_bridge_state() -> Dictionary:
	var state: Dictionary = {}
	if phase_controller != null and phase_controller.has_method("get_bridge_state"):
		state = phase_controller.get_bridge_state()
	state["bossEntity"] = true
	state["bossEntityType"] = "boss_entity_3d_owns_state_and_geometry"
	state["bossStateOwner"] = "BossEntity_DreadnoughtLeviathan/BossStateStore"
	state["bossModelLoaded"] = model_loaded
	state["bossStaticImageEntity"] = false
	state["bossHitboxModel"] = "per_part_world_aabb_from_visible_geometry"
	state["bossPartHitboxes"] = _hitbox_report()
	state["bossAttackState"] = attack_state
	state["bossTelegraphPart"] = telegraph_part
	state["bossTelegraphRatio"] = telegraph_ratio
	state["bossTelegraphEvents"] = telegraph_count
	state["bossFireEventCount"] = fire_event_count
	state["bossLiveMuzzleCount"] = get_live_muzzle_positions().size()
	state["bossWeakpointWorldZ"] = get_weakpoint_world_position().z
	state["bossPlaneY"] = CombatSpace.PLANE_Y
	state["bossWorldZ"] = global_position.z
	return state


func _hitbox_report() -> Dictionary:
	var report: Dictionary = {}
	for key in part_visuals.keys():
		var part: Dictionary = part_visuals[key]
		var anchor: Node3D = part.get("anchor")
		var extents: Vector3 = part.get("extents", Vector3.ZERO)
		report[key] = {
			"x": snappedf(anchor.global_position.x if anchor != null and anchor.is_inside_tree() else 0.0, 0.01),
			"z": snappedf(anchor.global_position.z if anchor != null and anchor.is_inside_tree() else 0.0, 0.01),
			"ex": snappedf(extents.x, 0.01),
			"ez": snappedf(extents.z, 0.01),
			"alive": _part_alive(key)
		}
	return report


func _part_ratio(part_name: String) -> float:
	if phase_controller == null:
		return 0.0
	if not phase_controller.parts.has(part_name):
		return 0.0
	var part: Dictionary = phase_controller.parts[part_name]
	return clampf(float(part.get("hp", 0.0)) / maxf(1.0, float(part.get("max", 1.0))), 0.0, 1.0)


func _part_alive(part_name: String) -> bool:
	return _part_ratio(part_name) > 0.0


func _part_hittable(part_name: String) -> bool:
	if not _part_alive(part_name):
		return false
	if part_name != "shield" and _part_alive("shield"):
		# The shield shell is in front; while it holds, it is the only hittable surface.
		return false
	if phase_controller == null:
		return true
	var required := 1
	if phase_controller.parts.has(part_name):
		required = int(phase_controller.parts[part_name].get("required_phase", 1))
	return required <= get_phase()


# --------------------------------------------------------------------- geometry

func _build_hull() -> void:
	var packed = load(BOSS_MODEL_PATH)
	hull_root = Node3D.new()
	hull_root.name = "BossHullRoot"
	add_child(hull_root)
	if packed is PackedScene:
		var model: Node3D = packed.instantiate()
		model.name = "DreadnoughtLeviathanHullGLB"
		model.scale = Vector3.ONE * model_scale
		# The authored battleship hull points its bow along -Z (away from the
		# camera); turn it around so the bow and its batteries face the player.
		model.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		hull_root.add_child(model)
		model_loaded = true
		_retint_faction_colors(model)
	else:
		model_loaded = false
		_build_fallback_hull()


func _build_fallback_hull() -> void:
	hull_root.add_child(_box("FallbackHull", Vector3(0.0, -1.2, -6.0) * model_scale, Vector3(30.0, 3.0, 11.0) * model_scale, hull_mat))
	hull_root.add_child(_box("FallbackDeck", Vector3(0.0, 0.8, -7.0) * model_scale, Vector3(20.0, 1.4, 7.0) * model_scale, armor_mat))


func _retint_faction_colors(model: Node3D) -> void:
	# Faction colour rule: cyan belongs to the player only. The shipped GLB has cyan
	# beacons and windows, so the enemy hull is retinted to warm threat amber here.
	_retint_recursive(model)


func _retint_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node
		var node_name := str(mesh_node.name)
		if node_name.contains("Cyan") or node_name.contains("Beacon") or node_name.contains("Window") or node_name.contains("Antenna"):
			mesh_node.material_override = threat_glow_mat
		elif node_name.contains("Glow") or node_name.contains("RedWeaponPort"):
			mesh_node.material_override = threat_glow_mat
	for child in node.get_children():
		_retint_recursive(child)


func _build_parts() -> void:
	part_visuals.clear()
	var turret_left_nodes := _collect_sockets(["LargeAATurret_00", "LargeAATurret_01"])
	var turret_right_nodes := _collect_sockets(["LargeAATurret_02", "LargeAATurret_03"])
	# Fallback stations are measured on the authored battleship hull
	# (docs/boss_battleship_report.json): the wide mid-deck wings, Blender
	# (x +-5.0, y -2.0, deck top z ~0.0) mapped to Godot and turned 180 deg.
	_register_turret_part("turret_left", turret_left_nodes, [Vector3(-5.0, 0.45, -2.0), Vector3(-3.0, 0.45, -4.6)])
	_register_turret_part("turret_right", turret_right_nodes, [Vector3(5.0, 0.45, -2.0), Vector3(3.0, 0.45, -4.6)])
	_register_core_part()
	_register_shield_part()


func _collect_sockets(names: Array) -> Array:
	var found: Array = []
	for socket_name in names:
		var node := _find_node3d(hull_root, str(socket_name))
		if node != null:
			found.append(node)
	return found


func _register_turret_part(part_name: String, nodes: Array, fallback_locals: Array) -> void:
	var anchor := Node3D.new()
	anchor.name = "BossPartAnchor_" + part_name
	add_child(anchor)
	var fallback_center := Vector3.ZERO
	for station in fallback_locals:
		fallback_center += Vector3(station)
	fallback_center /= float(maxi(1, fallback_locals.size()))
	anchor.position = fallback_center * model_scale
	var muzzles: Array = []
	var glows: Array = []
	var meshes: Array = []
	var assemblies: Array = []
	var assembly_count: int = nodes.size() if nodes.size() > 0 else fallback_locals.size()
	assembly_count = maxi(1, assembly_count)
	for i in range(assembly_count):
		var assembly := _build_turret_assembly(part_name, i)
		if nodes.is_empty() and i < fallback_locals.size():
			# Two batteries per side on the authored hull: the anchor keeps the
			# part hitbox, each assembly sits on its own measured deck station.
			assembly.position = (Vector3(fallback_locals[i]) - fallback_center) * model_scale
		anchor.add_child(assembly)
		assemblies.append(assembly)
		meshes.append(assembly)
		muzzles.append(assembly.get_node("Muzzle"))
		glows.append(assembly.get_node("TurretEye"))
	var smoke := _build_smoke_marker("BossSmoke_" + part_name)
	anchor.add_child(smoke)
	part_visuals[part_name] = {
		"anchor": anchor,
		"meshes": meshes,
		"glows": glows,
		"muzzles": muzzles,
		"assemblies": assemblies,
		"sockets": nodes,
		"extents": Vector3(4.6, 3.0, 4.4) * model_scale,
		"flash": 0.0,
		"telegraph": 0.0,
		"destroyed_visual": false,
		"smoke": smoke
	}


func _bind_runtime_transforms() -> void:
	# Socket transforms can only be resolved once the entity is inside the tree.
	# The GLB is slid so Boss_WeakPoint_Core lands on the entity origin (the combat
	# plane), then every turret part anchor is snapped onto its real GLB socket so
	# the hitbox used by query_hit() is the geometry the player can see.
	if sockets_bound or not is_inside_tree():
		return
	if hull_root != null and hull_root.get_child_count() > 0:
		var model := hull_root.get_child(0) as Node3D
		if model != null:
			var weak := _find_node3d(model, "Boss_WeakPoint_Core")
			if weak != null and weak.is_inside_tree():
				model.position -= to_local(weak.global_position)
	for part_name in ["turret_left", "turret_right"]:
		if not part_visuals.has(part_name):
			continue
		var part: Dictionary = part_visuals[part_name]
		var sockets: Array = part.get("sockets", [])
		var assemblies: Array = part.get("assemblies", [])
		if sockets.is_empty():
			continue
		var anchor: Node3D = part.get("anchor")
		var sum := Vector3.ZERO
		var local_points: Array = []
		for socket in sockets:
			var socket_node: Node3D = socket
			if socket_node == null or not socket_node.is_inside_tree():
				continue
			var local_point := to_local(socket_node.global_position)
			local_points.append(local_point)
			sum += local_point
		if local_points.is_empty():
			continue
		anchor.position = sum / float(local_points.size())
		for i in range(mini(local_points.size(), assemblies.size())):
			var assembly: Node3D = assemblies[i]
			assembly.position = Vector3(local_points[i]) - anchor.position
	sockets_bound = true


func _register_core_part() -> void:
	var anchor := Node3D.new()
	anchor.name = "BossPartAnchor_core"
	add_child(anchor)
	# In front of the battleship superstructure so the weak point is visible and
	# shootable from the play plane instead of buried inside the hull.
	anchor.position = Vector3(0.0, 1.15, 2.15) * model_scale
	var core_shell := MeshInstance3D.new()
	core_shell.name = "BossCoreWeakPoint"
	var sphere := SphereMesh.new()
	sphere.radius = 0.72 * model_scale
	sphere.height = 1.44 * model_scale
	core_shell.mesh = sphere
	core_shell.material_override = core_mat
	anchor.add_child(core_shell)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.0, 2.1)
	anchor.add_child(muzzle)
	var smoke := _build_smoke_marker("BossSmoke_core")
	anchor.add_child(smoke)
	part_visuals["core"] = {
		"anchor": anchor,
		"meshes": [core_shell],
		"glows": [core_shell],
		"muzzles": [muzzle],
		"extents": Vector3(1.8, 1.8, 1.8) * model_scale,
		"flash": 0.0,
		"telegraph": 0.0,
		"destroyed_visual": false,
		"smoke": smoke
	}


func _register_shield_part() -> void:
	var anchor := Node3D.new()
	anchor.name = "BossPartAnchor_shield"
	add_child(anchor)
	anchor.position = Vector3(0.0, 0.0, 2.0)
	shield_shell = MeshInstance3D.new()
	shield_shell.name = "BossShieldShell"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	shield_shell.mesh = sphere
	shield_shell.scale = Vector3(12.6, 4.2, 8.4)
	shield_shell.material_override = shield_mat
	anchor.add_child(shield_shell)
	part_visuals["shield"] = {
		"anchor": anchor,
		"meshes": [shield_shell],
		"glows": [],
		"muzzles": [],
		"extents": Vector3(17.0, 5.6, 10.5),
		"flash": 0.0,
		"telegraph": 0.0,
		"destroyed_visual": false,
		"smoke": null
	}


func _hull_offset() -> Vector3:
	if hull_root == null or hull_root.get_child_count() == 0:
		return Vector3.ZERO
	var model := hull_root.get_child(0) as Node3D
	if model == null:
		return Vector3.ZERO
	return model.position


func _build_turret_assembly(part_name: String, index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "BossTurret_%s_%02d" % [part_name, index]
	var base := MeshInstance3D.new()
	base.name = "TurretBase"
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 1.05
	base_mesh.bottom_radius = 1.35
	base_mesh.height = 1.25
	base.mesh = base_mesh
	base.material_override = armor_mat
	root.add_child(base)
	var barrel := MeshInstance3D.new()
	barrel.name = "TurretBarrel"
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.42, 0.42, 3.1)
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0.0, 0.52, 1.55)
	barrel.material_override = hull_mat
	root.add_child(barrel)
	var eye := MeshInstance3D.new()
	eye.name = "TurretEye"
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.45
	eye_mesh.height = 0.9
	eye.mesh = eye_mesh
	eye.position = Vector3(0.0, 0.62, 0.35)
	eye.material_override = threat_glow_mat
	root.add_child(eye)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.52, 3.2)
	root.add_child(muzzle)
	return root


func _build_smoke_marker(node_name: String) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(5.0, 6.5)
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = smoke_texture
	mat.albedo_color = Color(0.26, 0.24, 0.23, 0.82)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	node.visible = false
	node.position = Vector3(0.0, 2.4, 0.0)
	return node


func _build_impact_pool() -> void:
	impact_pool.clear()
	for i in range(14):
		var quad := QuadMesh.new()
		quad.size = Vector2(2.6, 2.6)
		var node := MeshInstance3D.new()
		node.name = "BossImpactSpark_%02d" % i
		node.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = explosion_texture
		mat.albedo_color = Color(1.0, 0.86, 0.52, 1.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.72, 0.30, 1.0)
		mat.emission_energy_multiplier = 3.6
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.material_override = mat
		node.visible = false
		add_child(node)
		node.set_meta("life", 0.0)
		impact_pool.append(node)
	muzzle_flashes.clear()
	for i in range(10):
		var flash_quad := QuadMesh.new()
		flash_quad.size = Vector2(2.2, 2.2)
		var flash_node := MeshInstance3D.new()
		flash_node.name = "BossMuzzleFlash_%02d" % i
		flash_node.mesh = flash_quad
		var flash_mat := StandardMaterial3D.new()
		flash_mat.albedo_texture = explosion_texture
		flash_mat.albedo_color = Color(1.0, 0.68, 0.26, 1.0)
		flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		flash_mat.emission_enabled = true
		flash_mat.emission = Color(1.0, 0.55, 0.16, 1.0)
		flash_mat.emission_energy_multiplier = 4.2
		flash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		flash_node.material_override = flash_mat
		flash_node.visible = false
		flash_node.set_meta("life", 0.0)
		add_child(flash_node)
		muzzle_flashes.append(flash_node)


func _create_materials() -> void:
	hull_mat = _solid(Color(0.13, 0.14, 0.17, 1.0), Color.BLACK, 0.55)
	armor_mat = _solid(Color(0.24, 0.25, 0.29, 1.0), Color.BLACK, 0.5)
	threat_glow_mat = _solid(Color(1.0, 0.42, 0.12, 1.0), Color(1.0, 0.30, 0.05, 1.0), 0.0)
	core_mat = _solid(Color(0.95, 0.24, 0.06, 1.0), Color(0.95, 0.17, 0.03, 1.0), 0.0)
	burnt_mat = _solid(Color(0.07, 0.07, 0.08, 1.0), Color.BLACK, 0.2)
	shield_mat = StandardMaterial3D.new()
	# Enemy shields must not use the player's cyan. Violet reads as hostile cover.
	shield_mat.albedo_color = Color(0.62, 0.22, 0.86, 0.17)
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.emission_enabled = true
	shield_mat.emission = Color(0.56, 0.16, 0.90, 1.0)
	shield_mat.emission_energy_multiplier = 1.1
	shield_mat.cull_mode = BaseMaterial3D.CULL_BACK


func _solid(albedo: Color, emission: Color, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.metallic = metallic
	mat.roughness = 0.42
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 1.25
	return mat


# ---------------------------------------------------------------------- visuals

func _sync_part_damage_visuals(delta: float) -> void:
	for key in part_visuals.keys():
		var part: Dictionary = part_visuals[key]
		part["flash"] = maxf(0.0, float(part.get("flash", 0.0)) - delta)
		var ratio := _part_ratio(key)
		var destroyed: bool = ratio <= 0.0
		if destroyed and not bool(part.get("destroyed_visual", false)):
			part["destroyed_visual"] = true
			_apply_destroyed_visual(key, part)
		elif not destroyed and bool(part.get("destroyed_visual", false)):
			part["destroyed_visual"] = false
			part_visuals[key] = part
			_restore_part_visual(key)
			part = part_visuals[key]
		if not destroyed:
			var flash: float = float(part.get("flash", 0.0))
			var telegraph: float = float(part.get("telegraph", 0.0))
			var pulse: float = 1.0 + flash * 5.0 + telegraph * 2.6
			for glow in part.get("glows", []):
				var glow_node: MeshInstance3D = glow
				if glow_node == null:
					continue
				var mat := glow_node.material_override as StandardMaterial3D
				if mat != null:
					mat.emission_energy_multiplier = 1.15 * pulse
				glow_node.scale = Vector3.ONE * (1.0 + telegraph * 0.45 + flash * 0.6)
		if key == "shield" and shield_shell != null:
			shield_shell.visible = ratio > 0.0
			var shield_material := shield_shell.material_override as StandardMaterial3D
			if shield_material != null:
				var flash_value: float = float(part.get("flash", 0.0))
				shield_material.albedo_color = Color(0.62, 0.22, 0.86, 0.10 + ratio * 0.10 + flash_value * 0.55)
		var smoke_node: MeshInstance3D = part.get("smoke")
		if smoke_node != null and smoke_node.visible:
			smoke_node.scale = Vector3.ONE * (1.0 + sin(boss_time * 2.1 + float(key.length())) * 0.12)
		part_visuals[key] = part


func _apply_destroyed_visual(part_name: String, part: Dictionary) -> void:
	for mesh in part.get("meshes", []):
		var node: MeshInstance3D = mesh
		if node != null:
			node.material_override = burnt_mat
	for glow in part.get("glows", []):
		var glow_node: MeshInstance3D = glow
		if glow_node != null:
			glow_node.visible = false
	var smoke_node: MeshInstance3D = part.get("smoke")
	if smoke_node != null:
		smoke_node.visible = true
	var anchor: Node3D = part.get("anchor")
	if anchor != null and anchor.is_inside_tree():
		_spawn_impact(anchor.global_position)
	part_visuals[part_name] = part


func _restore_part_visual(part_name: String) -> void:
	if not part_visuals.has(part_name):
		return
	var part: Dictionary = part_visuals[part_name]
	for mesh in part.get("meshes", []):
		var node: MeshInstance3D = mesh
		if node == null:
			continue
		if part_name == "core":
			node.material_override = core_mat
		elif part_name == "shield":
			node.material_override = shield_mat
		else:
			node.material_override = armor_mat
	for glow in part.get("glows", []):
		var glow_node: MeshInstance3D = glow
		if glow_node != null:
			glow_node.visible = true
			if part_name != "core":
				glow_node.material_override = threat_glow_mat
	var smoke_node: MeshInstance3D = part.get("smoke")
	if smoke_node != null:
		smoke_node.visible = false
	part_visuals[part_name] = part


func _spawn_impact(world_pos: Vector3) -> void:
	if impact_pool.is_empty():
		return
	var node: MeshInstance3D = impact_pool[impact_cursor % impact_pool.size()]
	impact_cursor += 1
	node.global_position = world_pos
	node.visible = true
	node.scale = Vector3.ONE * 0.6
	node.set_meta("life", 0.26)


func _update_impact_visuals(delta: float) -> void:
	for node in impact_pool:
		var mesh_node: MeshInstance3D = node
		var life: float = float(mesh_node.get_meta("life", 0.0))
		if life <= 0.0:
			mesh_node.visible = false
			continue
		life -= delta
		mesh_node.set_meta("life", life)
		var t: float = clampf(1.0 - life / 0.26, 0.0, 1.0)
		mesh_node.scale = Vector3.ONE * (0.6 + t * 1.5)
		var mat := mesh_node.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(1.0, 0.86, 0.52, 1.0 - t)
		if life <= 0.0:
			mesh_node.visible = false


func _flash_muzzle(world_pos: Vector3) -> void:
	for node in muzzle_flashes:
		var mesh_node: MeshInstance3D = node
		if float(mesh_node.get_meta("life", 0.0)) <= 0.0:
			mesh_node.global_position = world_pos
			mesh_node.visible = true
			mesh_node.scale = Vector3.ONE
			mesh_node.set_meta("life", 0.1)
			return


func _update_muzzle_flashes(delta: float) -> void:
	for node in muzzle_flashes:
		var mesh_node: MeshInstance3D = node
		var life: float = float(mesh_node.get_meta("life", 0.0))
		if life <= 0.0:
			mesh_node.visible = false
			continue
		life -= delta
		mesh_node.set_meta("life", life)
		var t: float = clampf(life / 0.1, 0.0, 1.0)
		mesh_node.scale = Vector3.ONE * (0.7 + t * 0.9)
		var mat := mesh_node.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(1.0, 0.68, 0.26, t)
		if life <= 0.0:
			mesh_node.visible = false


func _box(node_name: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	return node


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
