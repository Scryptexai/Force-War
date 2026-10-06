extends Node
class_name ProjectileManager3D

# Logic-facing projectile manager for the forward-air vertical slice.
# It deliberately does NOT create one physics body or one Node3D per bullet.
# Visual density is handled by ProjectileVisualPool3D/MultiMesh; this manager owns
# gameplay bullet data, cheap radius checks, boss hit events, and pattern contracts.

const ENEMY_PROJECTILE_DATA_PATH = "res://data/projectiles/enemy_orange_bolt.json"
const PLAYER_PROJECTILE_DATA_PATH = "res://data/projectiles/player_cyan_plasma.json"

var active := false
var rng := RandomNumberGenerator.new()
var enemy_data: Dictionary = {}
var player_data: Dictionary = {}
var enemy_pool: Array = []
var player_pool: Array = []
var spawn_timer := 0.0
var player_spawn_timer := 0.0
var pattern_clock := 0.0
var hit_cooldown := 0.0
var recent_damage := 0.0
var total_damage_to_player := 0.0
var total_damage_to_boss := 0.0
var player_hit_count := 0
var boss_hit_count := 0
var shots_spawned := 0
var player_shots_spawned := 0
var max_enemy_bullets := 140
var max_player_bullets := 80
var spawn_interval := 0.085
var player_fire_interval := 0.070
var lane_index := 0
var player_lane_index := 0
var logical_collision_radius_scale := 1.0
var active_boss_projectile_pattern := "shield_lane_sweep_pool_v1"
var recent_boss_hits: Array = []
var last_boss_hit_part := "shield"
var player_weapon_hardpoints: Dictionary = {}
var player_hardpoint_binding := "pending"
var player_shot_spawn_origin := "runtime_fallback_socket"
var boss_projectile_origin_mode := "runtime_lane"
var boss_muzzle_socket_logic_spawns := 0
var boss_muzzle_socket_origin_count := 0


func setup() -> void:
	name = "ProjectileManager3D_LogicalPool"
	rng.randomize()
	enemy_data = _load_json(ENEMY_PROJECTILE_DATA_PATH)
	player_data = _load_json(PLAYER_PROJECTILE_DATA_PATH)
	max_enemy_bullets = int(max(80, enemy_data.get("logic_pool_count", 140)))
	max_player_bullets = int(max(48, player_data.get("logic_pool_count", 80)))
	player_fire_interval = float(player_data.get("fire_interval", 0.070))
	_reset_pools()


func start_mission(stage_data: Dictionary) -> void:
	active = true
	pattern_clock = 0.0
	spawn_timer = 0.0
	player_spawn_timer = 0.0
	hit_cooldown = 0.0
	recent_damage = 0.0
	total_damage_to_player = 0.0
	total_damage_to_boss = 0.0
	player_hit_count = 0
	boss_hit_count = 0
	shots_spawned = 0
	player_shots_spawned = 0
	boss_projectile_origin_mode = "runtime_lane"
	boss_muzzle_socket_logic_spawns = 0
	boss_muzzle_socket_origin_count = 0
	lane_index = 0
	player_lane_index = 0
	recent_boss_hits.clear()
	last_boss_hit_part = "shield"
	active_boss_projectile_pattern = "shield_lane_sweep_pool_v1"
	var threat: float = float(stage_data.get("threat", 1.0))
	spawn_interval = clamp(0.105 - threat * 0.014, 0.055, 0.105)
	_reset_pools()


func stop_mission() -> void:
	active = false
	for i in range(enemy_pool.size()):
		enemy_pool[i]["active"] = false
	for i in range(player_pool.size()):
		player_pool[i]["active"] = false
	recent_boss_hits.clear()


func set_player_weapon_hardpoints(state: Dictionary) -> void:
	player_weapon_hardpoints = state.duplicate(true)
	player_hardpoint_binding = str(player_weapon_hardpoints.get("binding", "pending"))
	player_shot_spawn_origin = "glb_muzzle_socket" if bool(player_weapon_hardpoints.get("sockets_found", false)) else "runtime_fallback_socket"


func update_logic(delta: float, player_corridor: Vector2, weather_effect: Dictionary, boost_amount: float) -> float:
	if not active:
		return 0.0
	pattern_clock += delta
	hit_cooldown = max(0.0, hit_cooldown - delta)
	recent_damage = 0.0
	recent_boss_hits.clear()
	var wind: float = float(weather_effect.get("windDrift", 0.0))
	var visibility: float = float(weather_effect.get("rainVisibility", 1.0))
	var overcharged: bool = bool(weather_effect.get("lightningOvercharge", false))
	active_boss_projectile_pattern = str(weather_effect.get("bossAttackPattern", active_boss_projectile_pattern))
	var spawn_budget_mul: float = 0.72 if visibility < 0.72 else 1.0
	spawn_timer -= delta
	while spawn_timer <= 0.0:
		_spawn_enemy_bullet(wind, active_boss_projectile_pattern, weather_effect)
		var pattern_fire_scale: float = _boss_pattern_fire_scale(active_boss_projectile_pattern)
		spawn_timer += spawn_interval / max(0.55, spawn_budget_mul * pattern_fire_scale)
	_update_player_fire(delta, player_corridor, weather_effect, wind, overcharged)
	_update_enemy_bullets(delta, player_corridor, wind, boost_amount, overcharged)
	_update_player_bullets(delta, weather_effect, wind, overcharged)
	return recent_damage


func consume_boss_damage_events() -> Array:
	var events: Array = recent_boss_hits.duplicate(true)
	recent_boss_hits.clear()
	return events


func get_bridge_state() -> Dictionary:
	return {
		"logicalProjectileManager": true,
		"projectileCollisionMode": "pooled_logical_radius_no_physics_body",
		"logicalProjectilePool": enemy_pool.size(),
		"playerProjectilePool": player_pool.size(),
		"activeLogicalProjectiles": _active_enemy_count(),
		"activePlayerProjectiles": _active_player_count(),
		"projectileDataDriven": not enemy_data.is_empty() and not player_data.is_empty(),
		"projectilePattern": active_boss_projectile_pattern,
		"bossPatternDrivenProjectiles": true,
		"phase3ProjectileDebugStatus": "boss_socket_forward_fire_non_homing" if boss_projectile_origin_mode == "glb_boss_muzzle_socket" else "waiting_for_boss_socket_spawn",
		"bossProjectileAimingModel": "non_homing_forward_depth_lanes",
		"bossProjectileTracking": false,
		"bossProjectileVelocityMode": "positive_z_no_player_tracking",
		"playerProjectileVelocityMode": "negative_z_socket_origin",
		"logicalBossProjectileOrigin": boss_projectile_origin_mode,
		"logicalBossMuzzleSocketSpawns": boss_muzzle_socket_logic_spawns,
		"logicalBossMuzzleSocketCount": boss_muzzle_socket_origin_count,
		"bossHardpointFireNonHoming": true,
		"projectileHitsTaken": player_hit_count,
		"projectileDamageTaken": total_damage_to_player,
		"projectileShotsSpawned": shots_spawned,
		"playerProjectileShotsSpawned": player_shots_spawned,
		"logicalPlayerHardpointBinding": player_hardpoint_binding,
		"logicalPlayerShotOrigin": player_shot_spawn_origin,
		"playerProjectileHits": boss_hit_count,
		"playerBossDamage": total_damage_to_boss,
		"playerProjectileHitModel": "pooled_logical_boss_parts",
		"lastBossHitPart": last_boss_hit_part
	}


func _reset_pools() -> void:
	enemy_pool.clear()
	for i in range(max_enemy_bullets):
		enemy_pool.append({
			"active": false,
			"pos": Vector3.ZERO,
			"vel": Vector3.ZERO,
			"life": 0.0,
			"radius": float(enemy_data.get("radius", 0.28)),
			"damage": float(enemy_data.get("damage", 8.0)),
			"lane": 0.0,
			"phase": rng.randf_range(0.0, TAU),
			"pattern": "shield_lane_sweep_pool_v1"
		})
	player_pool.clear()
	for i in range(max_player_bullets):
		player_pool.append({
			"active": false,
			"pos": Vector3.ZERO,
			"vel": Vector3.ZERO,
			"life": 0.0,
			"radius": float(player_data.get("radius", 0.34)),
			"damage": float(player_data.get("damage", 18.0)),
			"lane": 0.0,
			"part": "shield"
		})


func _spawn_enemy_bullet(wind: float, attack_pattern: String, weather_effect: Dictionary) -> void:
	var index: int = _first_inactive_enemy_index()
	if index < 0:
		return
	var lanes: Array = enemy_data.get("lanes", [-4.1, -2.55, -1.05, 1.05, 2.55, 4.1])
	if lanes.is_empty():
		lanes = [-2.5, 2.5]
	var sequence := lane_index
	var lane: float = float(lanes[sequence % lanes.size()])
	lane_index += 1
	var speed: float = float(enemy_data.get("speed", 46.0)) * rng.randf_range(0.86, 1.18)
	var y: float = rng.randf_range(1.7, 5.6)
	var z: float = -112.0 - rng.randf_range(0.0, 18.0)
	var socket_origins: Array = weather_effect.get("bossMuzzleOrigins", [])
	boss_muzzle_socket_origin_count = socket_origins.size()
	var socket_spawn := false
	if str(weather_effect.get("bossMuzzleSocketBinding", "")) == "glb_boss_muzzle_socket_runtime" and not socket_origins.is_empty():
		var origin_value = socket_origins[sequence % socket_origins.size()]
		if origin_value is Vector3:
			var origin: Vector3 = origin_value
			lane = origin.x
			y = origin.y
			z = origin.z + 1.8
			socket_spawn = true
	var side_sweep: float = sin(pattern_clock * 0.8 + float(lane_index) * 0.53) * 0.45
	var x_velocity: float = wind * 0.18
	if attack_pattern == "turret_crossfire_pool_v1":
		if not socket_spawn:
			lane = -4.6 if lane_index % 2 == 0 else 4.6
			y = rng.randf_range(1.2, 4.8)
		x_velocity = -sign(lane) * 1.10 + wind * 0.12
		speed *= 1.10
	elif attack_pattern == "core_laser_burst_pool_v1":
		if not socket_spawn:
			lane = sin(float(lane_index) * 1.74) * 2.8
			y = rng.randf_range(1.6, 3.8)
		x_velocity = wind * 0.09
		speed *= 1.22
	if socket_spawn:
		boss_projectile_origin_mode = "glb_boss_muzzle_socket"
		boss_muzzle_socket_logic_spawns += 1
	else:
		boss_projectile_origin_mode = "runtime_lane"
	var bullet: Dictionary = enemy_pool[index]
	bullet["active"] = true
	bullet["pos"] = Vector3(lane + side_sweep, y, z)
	bullet["vel"] = Vector3(x_velocity, -3.6 if socket_spawn else 0.0, speed)
	bullet["life"] = float(enemy_data.get("lifetime", 3.1))
	bullet["radius"] = float(enemy_data.get("radius", 0.28)) * logical_collision_radius_scale
	bullet["damage"] = float(enemy_data.get("damage", 8.0))
	bullet["lane"] = lane
	bullet["phase"] = rng.randf_range(0.0, TAU)
	bullet["pattern"] = attack_pattern
	enemy_pool[index] = bullet
	shots_spawned += 1


func _update_player_fire(delta: float, player_corridor: Vector2, weather_effect: Dictionary, wind: float, overcharged: bool) -> void:
	var visibility: float = float(weather_effect.get("rainVisibility", 1.0))
	var rain_penalty: float = 1.10 if visibility < 0.72 else 1.0
	var overcharge_bonus: float = 0.72 if overcharged else 1.0
	player_spawn_timer -= delta
	while player_spawn_timer <= 0.0:
		_spawn_player_bullet(player_corridor, weather_effect, wind, overcharged)
		player_spawn_timer += player_fire_interval * rain_penalty * overcharge_bonus


func _spawn_player_bullet(player_corridor: Vector2, weather_effect: Dictionary, wind: float, overcharged: bool) -> void:
	var index: int = _first_inactive_player_index()
	if index < 0:
		return
	var lanes: Array = player_data.get("lanes", [-0.98, -0.32, 0.32, 0.98])
	if lanes.is_empty():
		lanes = [0.0]
	var shot_sequence := player_lane_index
	var lane: float = float(lanes[shot_sequence % lanes.size()])
	player_lane_index += 1
	var shot_origin := _player_hardpoint_origin(shot_sequence, lane, player_corridor)
	var speed: float = float(player_data.get("speed", 88.0)) * (1.12 if overcharged else 1.0)
	var part: String = _choose_boss_hit_part(shot_origin, weather_effect)
	var bullet: Dictionary = player_pool[index]
	bullet["active"] = true
	bullet["pos"] = shot_origin
	bullet["vel"] = Vector3(wind * 0.16, 0.0, -speed)
	bullet["life"] = float(player_data.get("lifetime", 1.65))
	bullet["radius"] = float(player_data.get("radius", 0.34))
	bullet["damage"] = float(player_data.get("damage", 18.0)) * (1.45 if overcharged else 1.0)
	bullet["lane"] = lane
	bullet["part"] = part
	player_pool[index] = bullet
	player_shots_spawned += 1


func _player_hardpoint_origin(sequence: int, fallback_lane: float, player_corridor: Vector2) -> Vector3:
	var key := "center"
	if sequence % 3 == 0:
		key = "left"
	elif sequence % 3 == 1:
		key = "right"
	if player_weapon_hardpoints.has(key):
		var value = player_weapon_hardpoints[key]
		if value is Vector3:
			return value
	if player_weapon_hardpoints.has("center"):
		var center_value = player_weapon_hardpoints["center"]
		if center_value is Vector3:
			return center_value
	return Vector3(player_corridor.x + fallback_lane * 0.55, 1.55 + player_corridor.y * 0.32, -5.5)


func _update_enemy_bullets(delta: float, player_corridor: Vector2, wind: float, boost_amount: float, overcharged: bool) -> void:
	var player_hit_pos: Vector2 = Vector2(player_corridor.x, 1.5 + player_corridor.y)
	var z_hit_window: float = 3.2 + boost_amount * 0.8
	for i in range(enemy_pool.size()):
		var bullet: Dictionary = enemy_pool[i]
		if not bool(bullet.get("active", false)):
			continue
		var pos: Vector3 = bullet["pos"]
		var vel: Vector3 = bullet["vel"]
		var phase: float = float(bullet.get("phase", 0.0))
		var pattern: String = str(bullet.get("pattern", "shield_lane_sweep_pool_v1"))
		if pattern == "turret_crossfire_pool_v1":
			vel.x = vel.x + sin(pattern_clock * 1.7 + phase) * 0.02
		elif pattern == "core_laser_burst_pool_v1":
			vel.x = wind * 0.12 + sin(pattern_clock * 2.1 + phase) * 0.06
		else:
			vel.x = wind * 0.22 + sin(pattern_clock * 1.35 + phase) * 0.12
		pos += vel * delta
		bullet["life"] = float(bullet.get("life", 0.0)) - delta
		bullet["pos"] = pos
		bullet["vel"] = vel
		var expired: bool = float(bullet["life"]) <= 0.0 or pos.z > 9.0
		if not expired and abs(pos.z) <= z_hit_window and hit_cooldown <= 0.0:
			var dist_sq: float = Vector2(pos.x, pos.y).distance_squared_to(player_hit_pos)
			var radius: float = float(bullet.get("radius", 0.28)) + 0.42
			if dist_sq <= radius * radius:
				var damage: float = float(bullet.get("damage", 8.0)) * (0.72 if overcharged else 1.0)
				recent_damage += damage
				total_damage_to_player += damage
				player_hit_count += 1
				hit_cooldown = 0.32
				expired = true
		if expired:
			bullet["active"] = false
		enemy_pool[i] = bullet


func _update_player_bullets(delta: float, weather_effect: Dictionary, wind: float, overcharged: bool) -> void:
	var boss_hit_z: float = float(player_data.get("boss_hit_z", -96.0))
	for i in range(player_pool.size()):
		var bullet: Dictionary = player_pool[i]
		if not bool(bullet.get("active", false)):
			continue
		var pos: Vector3 = bullet["pos"]
		var vel: Vector3 = bullet["vel"]
		vel.x = lerp(vel.x, wind * 0.18, min(1.0, delta * 1.8))
		pos += vel * delta
		bullet["life"] = float(bullet.get("life", 0.0)) - delta
		bullet["pos"] = pos
		bullet["vel"] = vel
		var expired: bool = float(bullet["life"]) <= 0.0 or pos.z < -126.0
		if not expired and pos.z <= boss_hit_z:
			var part: String = _choose_boss_hit_part(pos, weather_effect)
			var hit_window_x: float = 5.8 if part == "shield" else 4.2
			var hit_window_y: float = 4.5
			if abs(pos.x) <= hit_window_x and abs(pos.y - 3.0) <= hit_window_y:
				var damage: float = float(bullet.get("damage", 18.0))
				_register_boss_hit(part, damage, pos)
				expired = true
		if expired:
			bullet["active"] = false
		player_pool[i] = bullet


func _register_boss_hit(part: String, damage: float, hit_pos: Vector3) -> void:
	boss_hit_count += 1
	total_damage_to_boss += damage
	last_boss_hit_part = part
	recent_boss_hits.append({
		"part": part,
		"damage": damage,
		"x": hit_pos.x,
		"y": hit_pos.y,
		"z": hit_pos.z
	})


func _choose_boss_hit_part(pos: Vector3, weather_effect: Dictionary) -> String:
	var phase: int = int(weather_effect.get("bossPhase", 1))
	var targetable: String = str(weather_effect.get("bossTargetablePart", "shield"))
	if phase <= 1:
		return "shield"
	if phase >= 3:
		return "core"
	if targetable != "" and targetable != "shield":
		return targetable
	if pos.x < -0.45:
		return "left_wing"
	if pos.x > 0.45:
		return "right_wing"
	return "turrets"


func _boss_pattern_fire_scale(pattern: String) -> float:
	if pattern == "turret_crossfire_pool_v1":
		return 1.28
	if pattern == "core_laser_burst_pool_v1":
		return 1.45
	return 1.0


func _first_inactive_enemy_index() -> int:
	for i in range(enemy_pool.size()):
		if not bool(enemy_pool[i].get("active", false)):
			return i
	return -1


func _first_inactive_player_index() -> int:
	for i in range(player_pool.size()):
		if not bool(player_pool[i].get("active", false)):
			return i
	return -1


func _active_enemy_count() -> int:
	var count := 0
	for bullet in enemy_pool:
		if bool(bullet.get("active", false)):
			count += 1
	return count


func _active_player_count() -> int:
	var count := 0
	for bullet in player_pool:
		if bool(bullet.get("active", false)):
			count += 1
	return count


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}
