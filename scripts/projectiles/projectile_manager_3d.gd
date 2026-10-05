extends Node
class_name ProjectileManager3D

# Logic-facing projectile manager for the forward-air vertical slice.
# It deliberately does NOT create one physics body or one Node3D per bullet.
# Visual density is handled by ProjectileVisualPool3D/MultiMesh; this manager owns
# gameplay bullet data, cheap radius checks, damage events, and future pattern data.

const ENEMY_PROJECTILE_DATA_PATH = "res://data/projectiles/enemy_orange_bolt.json"
const PLAYER_PROJECTILE_DATA_PATH = "res://data/projectiles/player_cyan_plasma.json"

var active := false
var rng := RandomNumberGenerator.new()
var enemy_data: Dictionary = {}
var player_data: Dictionary = {}
var enemy_pool: Array = []
var spawn_timer := 0.0
var pattern_clock := 0.0
var hit_cooldown := 0.0
var recent_damage := 0.0
var total_damage_to_player := 0.0
var player_hit_count := 0
var shots_spawned := 0
var max_enemy_bullets := 140
var spawn_interval := 0.085
var lane_index := 0
var logical_collision_radius_scale := 1.0


func setup() -> void:
	name = "ProjectileManager3D_LogicalPool"
	rng.randomize()
	enemy_data = _load_json(ENEMY_PROJECTILE_DATA_PATH)
	player_data = _load_json(PLAYER_PROJECTILE_DATA_PATH)
	max_enemy_bullets = int(max(80, enemy_data.get("logic_pool_count", 140)))
	_reset_pool()


func start_mission(stage_data: Dictionary) -> void:
	active = true
	pattern_clock = 0.0
	spawn_timer = 0.0
	hit_cooldown = 0.0
	recent_damage = 0.0
	total_damage_to_player = 0.0
	player_hit_count = 0
	shots_spawned = 0
	lane_index = 0
	var threat := float(stage_data.get("threat", 1.0))
	spawn_interval = clamp(0.105 - threat * 0.014, 0.055, 0.105)
	_reset_pool()


func stop_mission() -> void:
	active = false
	for i in range(enemy_pool.size()):
		enemy_pool[i]["active"] = false


func update_logic(delta: float, player_corridor: Vector2, weather_effect: Dictionary, boost_amount: float) -> float:
	if not active:
		return 0.0
	pattern_clock += delta
	hit_cooldown = max(0.0, hit_cooldown - delta)
	recent_damage = 0.0
	var wind := float(weather_effect.get("windDrift", 0.0))
	var visibility := float(weather_effect.get("rainVisibility", 1.0))
	var overcharged := bool(weather_effect.get("lightningOvercharge", false))
	var spawn_budget_mul := 0.72 if visibility < 0.72 else 1.0
	spawn_timer -= delta
	while spawn_timer <= 0.0:
		_spawn_enemy_bullet(wind)
		spawn_timer += spawn_interval / max(0.65, spawn_budget_mul)
	_update_enemy_bullets(delta, player_corridor, wind, boost_amount, overcharged)
	return recent_damage


func get_bridge_state() -> Dictionary:
	return {
		"logicalProjectileManager": true,
		"projectileCollisionMode": "pooled_logical_radius_no_physics_body",
		"logicalProjectilePool": enemy_pool.size(),
		"activeLogicalProjectiles": _active_count(),
		"projectileDataDriven": not enemy_data.is_empty() and not player_data.is_empty(),
		"projectilePattern": "boss_lane_sweep_pool_v1",
		"projectileHitsTaken": player_hit_count,
		"projectileDamageTaken": total_damage_to_player,
		"projectileShotsSpawned": shots_spawned
	}


func _reset_pool() -> void:
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
			"phase": rng.randf_range(0.0, TAU)
		})


func _spawn_enemy_bullet(wind: float) -> void:
	var index := _first_inactive_index()
	if index < 0:
		return
	var lanes: Array = enemy_data.get("lanes", [-4.1, -2.55, -1.05, 1.05, 2.55, 4.1])
	if lanes.is_empty():
		lanes = [-2.5, 2.5]
	var lane := float(lanes[lane_index % lanes.size()])
	lane_index += 1
	var speed := float(enemy_data.get("speed", 46.0)) * rng.randf_range(0.86, 1.18)
	var y := rng.randf_range(1.7, 5.6)
	var z := -112.0 - rng.randf_range(0.0, 18.0)
	var side_sweep := sin(pattern_clock * 0.8 + float(lane_index) * 0.53) * 0.45
	var bullet: Dictionary = enemy_pool[index]
	bullet["active"] = true
	bullet["pos"] = Vector3(lane + side_sweep, y, z)
	bullet["vel"] = Vector3(wind * 0.18, 0.0, speed)
	bullet["life"] = float(enemy_data.get("lifetime", 3.1))
	bullet["radius"] = float(enemy_data.get("radius", 0.28)) * logical_collision_radius_scale
	bullet["damage"] = float(enemy_data.get("damage", 8.0))
	bullet["lane"] = lane
	bullet["phase"] = rng.randf_range(0.0, TAU)
	enemy_pool[index] = bullet
	shots_spawned += 1


func _update_enemy_bullets(delta: float, player_corridor: Vector2, wind: float, boost_amount: float, overcharged: bool) -> void:
	var player_hit_pos := Vector2(player_corridor.x, 1.5 + player_corridor.y)
	var z_hit_window := 3.2 + boost_amount * 0.8
	for i in range(enemy_pool.size()):
		var bullet: Dictionary = enemy_pool[i]
		if not bool(bullet.get("active", false)):
			continue
		var pos: Vector3 = bullet["pos"]
		var vel: Vector3 = bullet["vel"]
		var phase := float(bullet.get("phase", 0.0))
		vel.x = wind * 0.22 + sin(pattern_clock * 1.35 + phase) * 0.12
		pos += vel * delta
		bullet["life"] = float(bullet.get("life", 0.0)) - delta
		bullet["pos"] = pos
		bullet["vel"] = vel
		var expired := float(bullet["life"]) <= 0.0 or pos.z > 9.0
		if not expired and abs(pos.z) <= z_hit_window and hit_cooldown <= 0.0:
			var dist_sq := Vector2(pos.x, pos.y).distance_squared_to(player_hit_pos)
			var radius := float(bullet.get("radius", 0.28)) + 0.42
			if dist_sq <= radius * radius:
				var damage := float(bullet.get("damage", 8.0)) * (0.72 if overcharged else 1.0)
				recent_damage += damage
				total_damage_to_player += damage
				player_hit_count += 1
				hit_cooldown = 0.32
				expired = true
		if expired:
			bullet["active"] = false
		enemy_pool[i] = bullet


func _first_inactive_index() -> int:
	for i in range(enemy_pool.size()):
		if not bool(enemy_pool[i].get("active", false)):
			return i
	return -1


func _active_count() -> int:
	var count := 0
	for bullet in enemy_pool:
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
