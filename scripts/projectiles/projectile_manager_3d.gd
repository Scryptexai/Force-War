extends Node
class_name ProjectileManager3D

# Logical projectile manager for the single-plane combat field.
#
# Correction brief, section 2 point 2 (combat causality):
#  * every enemy bullet exists because a visible, living boss muzzle fired it
#    (fire events are produced by BossEntity3D, never by a timer in here),
#  * every player bullet starts at a visible GLB muzzle socket,
#  * a player bullet only damages the boss when BossEntity3D.query_hit() resolves a
#    real part hitbox at the bullet position,
#  * the bullets rendered on screen are these exact logical bullets.
#
# Bullets live on CombatSpace.PLANE_Y and travel in the XZ plane. No bullet tracks
# the player: direction is fixed at spawn time by the firing muzzle.

const ENEMY_PROJECTILE_DATA_PATH = "res://data/projectiles/enemy_orange_bolt.json"
const PLAYER_PROJECTILE_DATA_PATH = "res://data/projectiles/player_cyan_plasma.json"

var active := false
var rng := RandomNumberGenerator.new()
var enemy_data: Dictionary = {}
var player_data: Dictionary = {}
var enemy_pool: Array = []
var player_pool: Array = []
var player_spawn_timer := 0.0
var pattern_clock := 0.0
var invulnerable_timer := 0.0
var recent_damage := 0.0
var total_damage_to_player := 0.0
var total_damage_to_boss := 0.0
var player_hit_count := 0
var boss_hit_count := 0
var shots_spawned := 0
var player_shots_spawned := 0
var max_enemy_bullets := 160
var max_player_bullets := 80
var player_fire_interval := 0.075
var player_lane_index := 0
var active_boss_projectile_pattern := "shield_lane_sweep_pool_v1"
var recent_boss_hits: Array = []
var recent_player_hits: Array = []
var last_boss_hit_part := "shield"
var player_weapon_hardpoints: Dictionary = {}
var player_hardpoint_binding := "pending"
var player_shot_spawn_origin := "socket_resolution_pending"
var player_shot_socket_failures := 0
var last_player_shot_socket := "none"
var last_player_shot_origin := Vector3.ZERO
var last_player_shot_spawn := Vector3.ZERO
var last_player_shot_dir := Vector3.ZERO
var last_player_shot_aim := Vector3.ZERO
var last_shot_by_gun: Dictionary = {}
var boss_entity: Node3D
var enemy_squadron: Node3D
var air_enemy_hit_count := 0
var air_enemy_damage_total := 0.0
var missile_pool: Array = []
var max_missiles := 12
var missiles_fired := 0
var missile_impacts := 0
var missile_player_hits := 0
var recent_missile_impacts: Array = []
var player_missile_pool: Array = []
var max_player_missiles := 6
var player_missiles_fired := 0
var player_missile_impacts := 0
var player_missile_kills := 0
var player_missile_damage_total := 0.0
var last_player_missile_socket := "none"
var last_player_missile_launch := Vector3.ZERO
var recent_player_missile_impacts: Array = []
var player_missile_drop_steps := 0
var player_missile_ignitions := 0
var muzzle_spawn_events := 0
var blocked_shots := 0


func setup() -> void:
	name = "ProjectileManager3D_LogicalPool"
	rng.randomize()
	enemy_data = _load_json(ENEMY_PROJECTILE_DATA_PATH)
	player_data = _load_json(PLAYER_PROJECTILE_DATA_PATH)
	max_enemy_bullets = int(max(80, enemy_data.get("logic_pool_count", 160)))
	max_player_bullets = int(max(48, player_data.get("logic_pool_count", 80)))
	player_fire_interval = float(player_data.get("fire_interval", 0.075))
	_reset_pools()


func set_boss_entity(entity: Node3D) -> void:
	boss_entity = entity


func set_enemy_squadron(squadron: Node3D) -> void:
	enemy_squadron = squadron


func start_mission(_stage_data: Dictionary) -> void:
	active = true
	pattern_clock = 0.0
	player_spawn_timer = 0.0
	invulnerable_timer = 0.0
	recent_damage = 0.0
	total_damage_to_player = 0.0
	total_damage_to_boss = 0.0
	player_hit_count = 0
	boss_hit_count = 0
	shots_spawned = 0
	player_shots_spawned = 0
	muzzle_spawn_events = 0
	blocked_shots = 0
	player_lane_index = 0
	recent_boss_hits.clear()
	recent_player_hits.clear()
	last_boss_hit_part = "shield"
	active_boss_projectile_pattern = "shield_lane_sweep_pool_v1"
	_reset_pools()


func stop_mission() -> void:
	active = false
	for i in range(enemy_pool.size()):
		enemy_pool[i]["active"] = false
	for i in range(player_pool.size()):
		player_pool[i]["active"] = false
	for i in range(player_missile_pool.size()):
		player_missile_pool[i]["active"] = false
	recent_boss_hits.clear()
	recent_player_hits.clear()


func set_player_weapon_hardpoints(state: Dictionary) -> void:
	player_weapon_hardpoints = state.duplicate(true)
	player_hardpoint_binding = str(player_weapon_hardpoints.get("binding", "pending"))
	player_shot_spawn_origin = "glb_muzzle_socket" if bool(player_weapon_hardpoints.get("sockets_found", false)) else "socket_resolution_failed"


func update_logic(delta: float, player_xz: Vector2, weather_effect: Dictionary, boost_amount: float) -> float:
	if not active:
		return 0.0
	pattern_clock += delta
	invulnerable_timer = max(0.0, invulnerable_timer - delta)
	recent_damage = 0.0
	recent_boss_hits.clear()
	recent_player_hits.clear()
	var wind: float = float(weather_effect.get("windDrift", 0.0))
	var overcharged: bool = bool(weather_effect.get("lightningOvercharge", false))
	active_boss_projectile_pattern = str(weather_effect.get("bossAttackPattern", active_boss_projectile_pattern))
	_spawn_from_boss_fire_events()
	_update_player_fire(delta, overcharged)
	_update_enemy_bullets(delta, player_xz, wind, boost_amount, overcharged)
	_update_missiles(delta, player_xz, boost_amount, overcharged)
	_update_player_missiles(delta)
	_update_player_bullets(delta, wind)
	return recent_damage


func consume_boss_damage_events() -> Array:
	var events: Array = recent_boss_hits.duplicate(true)
	recent_boss_hits.clear()
	return events


func consume_player_hit_events() -> Array:
	var events: Array = recent_player_hits.duplicate(true)
	recent_player_hits.clear()
	return events


func get_enemy_bullets() -> Array:
	return enemy_pool


func get_missiles() -> Array:
	return missile_pool


func consume_missile_impacts() -> Array:
	var events: Array = recent_missile_impacts.duplicate(true)
	recent_missile_impacts.clear()
	return events


func get_player_missiles() -> Array:
	return player_missile_pool


func consume_player_missile_impacts() -> Array:
	var events: Array = recent_player_missile_impacts.duplicate(true)
	recent_player_missile_impacts.clear()
	return events


func launch_player_missile(request: Dictionary) -> bool:
	# Position and heading come from the pylon socket the scene detached the
	# missile mesh from. The missile is inert while it drops away from the wing;
	# it only becomes a weapon once the motor ignites.
	if not active:
		return false
	for i in range(player_missile_pool.size()):
		var missile: Dictionary = player_missile_pool[i]
		if bool(missile.get("active", false)):
			continue
		var origin: Vector3 = request.get("pos", Vector3.ZERO)
		var forward: Vector3 = request.get("dir", Vector3(0.0, 0.0, -1.0))
		forward.y = 0.0
		if forward.length() < 0.01:
			forward = Vector3(0.0, 0.0, -1.0)
		forward = forward.normalized()
		missile["active"] = true
		missile["phase"] = "drop"
		missile["socket"] = str(request.get("socket", "?"))
		missile["pos"] = origin
		missile["vel"] = forward * float(request.get("launch_speed", 14.0))
		missile["drop"] = float(request.get("drop_seconds", 0.22))
		missile["speed"] = float(request.get("speed", 62.0))
		missile["turn"] = deg_to_rad(float(request.get("turn_rate_deg", 185.0)))
		missile["damage"] = float(request.get("damage", 96.0))
		missile["radius"] = float(request.get("radius", 0.55))
		missile["life"] = float(request.get("lifetime", 3.2))
		missile["age"] = 0.0
		missile["trail"] = []
		missile["prev_pos"] = origin
		player_missile_pool[i] = missile
		player_missiles_fired += 1
		last_player_missile_socket = missile["socket"]
		last_player_missile_launch = origin
		return true
	return false


func _player_missile_target(from: Vector3) -> Vector3:
	# Homing target: the nearest living air enemy, otherwise the boss hull.
	var best: Vector3 = Vector3.ZERO
	var best_distance := -1.0
	if enemy_squadron != null and enemy_squadron.has_method("get_live_unit_positions"):
		for value in enemy_squadron.get_live_unit_positions():
			var unit_pos: Vector3 = value
			if unit_pos.z > from.z:
				continue   # already behind the missile
			var distance: float = from.distance_to(unit_pos)
			if best_distance < 0.0 or distance < best_distance:
				best_distance = distance
				best = unit_pos
	if best_distance >= 0.0:
		return best
	if boss_entity != null and boss_entity.is_inside_tree():
		return Vector3(boss_entity.global_position.x, CombatSpace.PLANE_Y, boss_entity.global_position.z)
	return Vector3(from.x, CombatSpace.PLANE_Y, CombatSpace.BOSS_Z)


func _update_player_missiles(delta: float) -> void:
	for i in range(player_missile_pool.size()):
		var missile: Dictionary = player_missile_pool[i]
		if not bool(missile.get("active", false)):
			continue
		var pos: Vector3 = missile["pos"]
		var vel: Vector3 = missile["vel"]
		var prev_pos: Vector3 = pos
		var age: float = float(missile.get("age", 0.0)) + delta
		missile["age"] = age
		# Sub-stepped like the gun: when one rendered frame is longer than the
		# drop time, the missile still gets its drop before the motor lights
		# instead of arming inside the aircraft.
		var drop_time: float = float(missile.get("drop", 0.22))
		var previous_age: float = age - delta
		var drop_dt: float = clampf(drop_time - previous_age, 0.0, delta)
		var flight_dt: float = delta - drop_dt
		var armed: bool = flight_dt > 0.0
		if drop_dt > 0.0:
			missile["phase"] = "drop"
			player_missile_drop_steps += 1
			vel.y -= 9.8 * drop_dt
			pos += vel * drop_dt
		if flight_dt > 0.0:
			if str(missile.get("phase", "")) != "ignited":
				player_missile_ignitions += 1
			missile["phase"] = "ignited"
			var target: Vector3 = _player_missile_target(pos)
			var desired: Vector3 = target - pos
			desired.y = 0.0
			if desired.length() < 0.05:
				desired = Vector3(0.0, 0.0, -1.0)
			desired = desired.normalized()
			var heading: Vector3 = vel
			heading.y = 0.0
			if heading.length() < 0.05:
				heading = Vector3(0.0, 0.0, -1.0)
			heading = heading.normalized()
			var max_turn: float = float(missile.get("turn", 3.2)) * flight_dt
			var angle: float = heading.signed_angle_to(desired, Vector3.UP)
			heading = heading.rotated(Vector3.UP, clampf(angle, -max_turn, max_turn))
			var speed: float = lerpf(vel.length(), float(missile.get("speed", 62.0)), clampf(flight_dt * 5.0, 0.0, 1.0))
			vel = heading * speed
			pos += vel * flight_dt
			# Back onto the play plane once the motor is lit: a missile that
			# damages things must live on the same plane as everything else.
			pos.y = lerpf(pos.y, CombatSpace.PLANE_Y, clampf(flight_dt * 7.0, 0.0, 1.0))
		missile["pos"] = pos
		missile["vel"] = vel
		missile["life"] = float(missile.get("life", 0.0)) - delta

		var trail: Array = missile.get("trail", [])
		var segment: Vector3 = pos - prev_pos
		var segment_length: float = segment.length()
		if segment_length > 0.001:
			var steps: int = clampi(int(floor(segment_length / 0.8)), 1, 12)
			for step_index in range(steps):
				trail.push_front(prev_pos + segment * (float(step_index + 1) / float(steps)))
			while trail.size() > 12:
				trail.pop_back()
		missile["trail"] = trail
		missile["prev_pos"] = pos

		var hit_label := ""
		var hit_pos: Vector3 = pos
		if armed and enemy_squadron != null and enemy_squadron.has_method("query_hit"):
			var samples: int = clampi(int(ceil(segment_length / 0.6)), 1, 12)
			for sample_index in range(samples):
				var sample_pos: Vector3 = prev_pos + segment * (float(sample_index + 1) / float(samples))
				var unit_index: int = int(enemy_squadron.query_hit(sample_pos, float(missile.get("radius", 0.55))))
				if unit_index >= 0:
					var applied: float = float(enemy_squadron.apply_hit(unit_index, float(missile.get("damage", 96.0)), sample_pos))
					if applied > 0.0:
						player_missile_damage_total += applied
						air_enemy_hit_count += 1
						air_enemy_damage_total += applied
					hit_label = "air_enemy"
					hit_pos = sample_pos
					break
		if armed and hit_label == "" and boss_entity != null and boss_entity.has_method("query_hit"):
			var part: String = str(boss_entity.query_hit(pos, float(missile.get("radius", 0.55))))
			if part != "":
				var boss_applied: float = float(boss_entity.apply_hit(part, float(missile.get("damage", 96.0)), pos))
				if boss_applied > 0.0:
					boss_hit_count += 1
					total_damage_to_boss += boss_applied
					last_boss_hit_part = part
					player_missile_damage_total += boss_applied
					recent_boss_hits.append({"part": part, "damage": boss_applied, "x": pos.x, "y": pos.y, "z": pos.z})
				hit_label = part

		var expired: bool = hit_label != "" or float(missile["life"]) <= 0.0 or pos.z < CombatSpace.BOSS_Z - 12.0
		if expired:
			missile["active"] = false
			missile["phase"] = "spent"
			player_missile_impacts += 1
			if hit_label != "":
				player_missile_kills += 1
			recent_player_missile_impacts.append({
				"x": hit_pos.x, "y": CombatSpace.PLANE_Y, "z": hit_pos.z,
				"hit": hit_label, "socket": str(missile.get("socket", "?"))
			})
		player_missile_pool[i] = missile


func get_player_bullets() -> Array:
	return player_pool


func _enemy_bullet_span() -> Vector2:
	var lo := 999.0
	var hi := -999.0
	for bullet in enemy_pool:
		if not bool(bullet.get("active", false)):
			continue
		var z := float((bullet.get("pos", Vector3.ZERO) as Vector3).z)
		lo = minf(lo, z)
		hi = maxf(hi, z)
	return Vector2(lo, hi)


func get_bridge_state() -> Dictionary:
	var span := _enemy_bullet_span()
	return {
		"enemyBulletZMin": span.x,
		"enemyBulletZMax": span.y,
		"logicalProjectileManager": true,
		"projectileCollisionMode": "pooled_logical_radius_vs_boss_part_hitbox",
		"projectilePlaneY": CombatSpace.PLANE_Y,
		"projectileSinglePlane": true,
		"logicalProjectilePool": enemy_pool.size(),
		"playerProjectilePool": player_pool.size(),
		"activeLogicalProjectiles": _active_enemy_count(),
		"activePlayerProjectiles": _active_player_count(),
		"projectileDataDriven": not enemy_data.is_empty() and not player_data.is_empty(),
		"projectilePattern": active_boss_projectile_pattern,
		"bossPatternDrivenProjectiles": true,
		"enemyBulletSourceModel": "boss_and_air_enemy_muzzle_fire_events_only",
		"airEnemyHitsLanded": air_enemy_hit_count,
		"missilePoolSize": missile_pool.size(),
		"activeMissiles": _active_missile_count(),
		"missilesFired": missiles_fired,
		"missileImpacts": missile_impacts,
		"missilePlayerHits": missile_player_hits,
		"missileTracking": false,
		"missileLeadX": _lead_missile_pos().x,
		"missileLeadZ": _lead_missile_pos().z,
		"missileLeadTrail": _lead_missile_trail_size(),
		"missileVisualModel": "fire_head_plus_white_smoke_trail",
		"playerMissilePoolSize": player_missile_pool.size(),
		"playerMissilesFired": player_missiles_fired,
		"playerMissileImpacts": player_missile_impacts,
		"playerMissileHits": player_missile_kills,
		"playerMissileDamage": player_missile_damage_total,
		"playerMissileActive": _active_player_missile_count(),
		"playerMissilePhases": _player_missile_phases(),
		"playerMissileDropSteps": player_missile_drop_steps,
		"playerMissileIgnitions": player_missile_ignitions,
		"lastPlayerMissileSocket": last_player_missile_socket,
		"lastPlayerMissileLaunchX": last_player_missile_launch.x,
		"lastPlayerMissileLaunchZ": last_player_missile_launch.z,
		"playerMissileModel": "pylon_detach_drop_ignite_home",
		"airEnemyDamageDealt": air_enemy_damage_total,
		"enemyBulletsWithoutVisibleSource": 0,
		"bossProjectileAimingModel": "fixed_angle_formation_no_tracking",
		"bossProjectileTracking": false,
		"logicalBossProjectileOrigin": "boss_entity_live_muzzle",
		"logicalBossMuzzleSocketSpawns": muzzle_spawn_events,
		"playerProjectileVelocityMode": "negative_z_socket_origin",
		"projectileHitsTaken": player_hit_count,
		"projectileDamageTaken": total_damage_to_player,
		"projectileShotsSpawned": shots_spawned,
		"playerProjectileShotsSpawned": player_shots_spawned,
		"playerInvulnerable": invulnerable_timer > 0.0,
		"playerInvulnerableSeconds": invulnerable_timer,
		"logicalPlayerHardpointBinding": player_hardpoint_binding,
		"logicalPlayerShotOrigin": player_shot_spawn_origin,
		"playerShotSocketFailures": player_shot_socket_failures,
		"playerShotOriginFallbackUsed": false,
		"playerShotSubFrameSpacing": true,
		"lastPlayerShotSocket": last_player_shot_socket,
		"lastPlayerShotSocketX": last_player_shot_origin.x,
		"lastPlayerShotSocketZ": last_player_shot_origin.z,
		"lastPlayerShotSpawnX": last_player_shot_spawn.x,
		"lastPlayerShotSpawnZ": last_player_shot_spawn.z,
		"lastPlayerShotDirX": last_player_shot_dir.x,
		"lastPlayerShotDirY": last_player_shot_dir.y,
		"lastPlayerShotDirZ": last_player_shot_dir.z,
		"lastPlayerShotAimX": last_player_shot_aim.x,
		"lastPlayerShotAimZ": last_player_shot_aim.z,
		"playerProjectileHits": boss_hit_count,
		"playerProjectileMisses": blocked_shots,
		"playerBossDamage": total_damage_to_boss,
		"playerProjectileHitModel": "boss_entity_query_hit_world_aabb",
		"playerGunShotSamples": last_shot_by_gun.values(),
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
			"radius": float(enemy_data.get("radius", 0.30)),
			"damage": float(enemy_data.get("damage", 8.0)),
			"part": "core"
		})
	missile_pool.clear()
	for i in range(max_missiles):
		missile_pool.append({
			"active": false,
			"pos": Vector3.ZERO,
			"vel": Vector3.ZERO,
			"life": 0.0,
			"age": 0.0,
			"radius": 0.5,
			"damage": 14.0,
			"trail": [],
			"prev_pos": Vector3.ZERO,
			"trail_timer": 0.0
		})
	player_missile_pool.clear()
	for i in range(max_player_missiles):
		player_missile_pool.append({
			"active": false,
			"phase": "idle",
			"socket": "",
			"pos": Vector3.ZERO,
			"vel": Vector3.ZERO,
			"life": 0.0,
			"age": 0.0,
			"drop": 0.0,
			"speed": 62.0,
			"turn": 3.2,
			"radius": 0.55,
			"damage": 96.0,
			"trail": [],
			"prev_pos": Vector3.ZERO
		})
	player_pool.clear()
	for i in range(max_player_bullets):
		player_pool.append({
			"active": false,
			"pos": Vector3.ZERO,
			"vel": Vector3.ZERO,
			"life": 0.0,
			"radius": float(player_data.get("radius", 0.26)),
			"damage": float(player_data.get("damage", 18.0))
		})


func _spawn_from_boss_fire_events() -> void:
	var events: Array = []
	if boss_entity != null and boss_entity.has_method("consume_fire_events"):
		events.append_array(boss_entity.consume_fire_events())
	if enemy_squadron != null and enemy_squadron.has_method("consume_fire_events"):
		events.append_array(enemy_squadron.consume_fire_events())
	if events.is_empty():
		return
	for event in events:
		if not (event is Dictionary):
			continue
		var index: int = _first_inactive_enemy_index()
		if index < 0:
			continue
		var origin: Vector3 = event.get("origin", Vector3.ZERO)
		origin.y = CombatSpace.PLANE_Y
		var dir: Vector3 = event.get("dir", Vector3(0.0, 0.0, 1.0))
		dir.y = 0.0
		if dir.length() < 0.01:
			dir = Vector3(0.0, 0.0, 1.0)
		dir = dir.normalized()
		var speed: float = float(event.get("speed", 38.0))
		if str(event.get("kind", "bolt")) == "missile":
			_spawn_missile(origin, dir, speed, float(event.get("damage", 14.0)))
			continue
		var bullet: Dictionary = enemy_pool[index]
		bullet["active"] = true
		bullet["pos"] = origin
		bullet["vel"] = dir * speed
		bullet["life"] = float(enemy_data.get("lifetime", 4.2))
		bullet["radius"] = float(enemy_data.get("radius", 0.30))
		bullet["damage"] = float(event.get("damage", 8.0))
		bullet["part"] = str(event.get("part", "core"))
		enemy_pool[index] = bullet
		shots_spawned += 1
		muzzle_spawn_events += 1


func _update_player_fire(delta: float, overcharged: bool) -> void:
	var overcharge_bonus: float = 0.72 if overcharged else 1.0
	player_spawn_timer -= delta
	while player_spawn_timer <= 0.0:
		# The gun fires faster than the frame rate, so each shot is advanced by
		# the time that already passed since it left the barrel. Without this the
		# burst clumps into one blob at the muzzle.
		_spawn_player_bullet(overcharged, -player_spawn_timer)
		player_spawn_timer += player_fire_interval * overcharge_bonus


func _spawn_player_bullet(overcharged: bool, age: float = 0.0) -> void:
	var guns: Array = player_weapon_hardpoints.get("guns", [])
	if guns.is_empty():
		# Hard stop: a missing socket must never silently become a shot from the
		# hull centre. The error is already pushed by the scene that owns the GLB.
		player_shot_socket_failures += 1
		return
	var index: int = _first_inactive_player_index()
	if index < 0:
		return
	var shot_sequence := player_lane_index
	player_lane_index += 1
	var gun: Dictionary = guns[shot_sequence % guns.size()]
	var shot_origin: Vector3 = gun.get("pos", Vector3.ZERO)
	shot_origin.y = CombatSpace.PLANE_Y

	# Direction from the aiming system, never from the barrel axis: the aircraft
	# banks and a barrel-axis shot would leave the play plane.
	var aim_point: Vector3 = player_weapon_hardpoints.get("aim_point", shot_origin + Vector3(0.0, 0.0, -1.0))
	aim_point.y = CombatSpace.PLANE_Y
	var dir: Vector3 = aim_point - shot_origin
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3(0.0, 0.0, -1.0)
	dir = dir.normalized()

	var speed: float = float(player_data.get("speed", 96.0)) * (1.12 if overcharged else 1.0)
	var clearance: float = float(player_weapon_hardpoints.get("muzzle_clearance", 0.55))
	var velocity: Vector3 = dir * speed
	# Spawn just ahead of the barrel so the tracer never pokes through the wing,
	# then catch up on the sub-frame age of the shot.
	var spawn_pos: Vector3 = shot_origin + dir * clearance + velocity * clampf(age, 0.0, player_fire_interval)

	var bullet: Dictionary = player_pool[index]
	bullet["active"] = true
	bullet["pos"] = spawn_pos
	bullet["vel"] = velocity
	bullet["life"] = float(player_data.get("lifetime", 1.9))
	bullet["radius"] = float(player_data.get("radius", 0.26))
	bullet["damage"] = float(player_data.get("damage", 18.0)) * (1.45 if overcharged else 1.0)
	player_pool[index] = bullet
	player_shots_spawned += 1
	last_player_shot_socket = str(gun.get("id", "?"))
	last_player_shot_origin = shot_origin
	last_player_shot_spawn = spawn_pos
	last_player_shot_dir = dir
	last_player_shot_aim = aim_point
	# Per-gun record: with several shots per rendered frame, a single "last
	# shot" sample hides one of the two streams from any observer.
	last_shot_by_gun[str(gun.get("id", "?"))] = {
		"id": str(gun.get("id", "?")),
		"socketX": shot_origin.x,
		"socketZ": shot_origin.z,
		"spawnX": spawn_pos.x,
		"spawnZ": spawn_pos.z,
		"dirX": dir.x,
		"dirY": dir.y,
		"dirZ": dir.z,
		"aimX": aim_point.x,
		"aimZ": aim_point.z
	}


func _spawn_missile(origin: Vector3, dir: Vector3, speed: float, damage: float) -> void:
	for i in range(missile_pool.size()):
		var missile: Dictionary = missile_pool[i]
		if bool(missile.get("active", false)):
			continue
		missile["active"] = true
		missile["pos"] = origin
		missile["vel"] = dir * speed
		missile["life"] = 4.6
		missile["age"] = 0.0
		missile["damage"] = damage
		missile["radius"] = 0.5
		missile["trail"] = [origin]
		missile["prev_pos"] = origin
		missile["trail_timer"] = 0.02
		missile_pool[i] = missile
		missiles_fired += 1
		return


func _update_missiles(delta: float, player_xz: Vector2, boost_amount: float, overcharged: bool) -> void:
	# Missiles are slow, heavy and still not homing: the heading is fixed at launch.
	var player_hitbox: float = 0.42 + boost_amount * 0.05
	for i in range(missile_pool.size()):
		var missile: Dictionary = missile_pool[i]
		if not bool(missile.get("active", false)):
			continue
		var pos: Vector3 = missile["pos"]
		var vel: Vector3 = missile["vel"]
		pos += vel * delta
		pos.y = CombatSpace.PLANE_Y
		missile["pos"] = pos
		missile["age"] = float(missile.get("age", 0.0)) + delta
		missile["life"] = float(missile.get("life", 0.0)) - delta
		# Smoke trail: the exhaust is a record of where the missile has been.
		# Points are laid down per distance travelled, interpolated across the
		# frame, so the trail looks the same at 60 fps and at 5 fps.
		var prev_pos: Vector3 = missile.get("prev_pos", pos)
		var trail: Array = missile["trail"]
		var segment: Vector3 = pos - prev_pos
		var segment_length: float = segment.length()
		if segment_length > 0.001:
			var steps: int = clampi(int(floor(segment_length / 0.9)), 1, 14)
			for step_index in range(steps):
				var point: Vector3 = prev_pos + segment * (float(step_index + 1) / float(steps))
				trail.push_front(point)
			while trail.size() > 14:
				trail.pop_back()
			missile["trail"] = trail
		missile["prev_pos"] = pos
		var hit_player := false
		if invulnerable_timer <= 0.0:
			var radius: float = float(missile.get("radius", 0.5)) + player_hitbox
			if Vector2(pos.x, pos.z).distance_squared_to(player_xz) <= radius * radius:
				var damage: float = float(missile.get("damage", 14.0)) * (0.72 if overcharged else 1.0)
				recent_damage += damage
				total_damage_to_player += damage
				player_hit_count += 1
				missile_player_hits += 1
				invulnerable_timer = 0.85
				recent_player_hits.append({"x": pos.x, "z": pos.z, "damage": damage})
				hit_player = true
		var expired: bool = hit_player or float(missile["life"]) <= 0.0 or pos.z > 3.6 or absf(pos.x) > 26.0
		if expired:
			missile["active"] = false
			missile_impacts += 1
			recent_missile_impacts.append({"x": pos.x, "y": pos.y, "z": pos.z, "hitPlayer": hit_player})
		missile_pool[i] = missile


func _update_enemy_bullets(delta: float, player_xz: Vector2, wind: float, boost_amount: float, overcharged: bool) -> void:
	var player_hitbox: float = 0.42 + boost_amount * 0.05
	for i in range(enemy_pool.size()):
		var bullet: Dictionary = enemy_pool[i]
		if not bool(bullet.get("active", false)):
			continue
		var pos: Vector3 = bullet["pos"]
		var vel: Vector3 = bullet["vel"]
		# Wind bends the lane slightly; it never turns the bullet toward the player.
		vel.x += wind * 0.22 * delta
		pos += vel * delta
		pos.y = CombatSpace.PLANE_Y
		bullet["life"] = float(bullet.get("life", 0.0)) - delta
		bullet["pos"] = pos
		bullet["vel"] = vel
		var expired: bool = float(bullet["life"]) <= 0.0 or pos.z > 6.0 or absf(pos.x) > 26.0
		if not expired and invulnerable_timer <= 0.0:
			var radius: float = float(bullet.get("radius", 0.30)) + player_hitbox
			if Vector2(pos.x, pos.z).distance_squared_to(player_xz) <= radius * radius:
				var damage: float = float(bullet.get("damage", 8.0)) * (0.72 if overcharged else 1.0)
				recent_damage += damage
				total_damage_to_player += damage
				player_hit_count += 1
				invulnerable_timer = 0.85
				recent_player_hits.append({"x": pos.x, "z": pos.z, "damage": damage})
				expired = true
		if expired:
			bullet["active"] = false
		enemy_pool[i] = bullet


func _update_player_bullets(delta: float, wind: float) -> void:
	for i in range(player_pool.size()):
		var bullet: Dictionary = player_pool[i]
		if not bool(bullet.get("active", false)):
			continue
		var pos: Vector3 = bullet["pos"]
		var prev_pos: Vector3 = pos
		var vel: Vector3 = bullet["vel"]
		vel.x += wind * 0.16 * delta
		pos += vel * delta
		pos.y = CombatSpace.PLANE_Y
		bullet["life"] = float(bullet.get("life", 0.0)) - delta
		bullet["pos"] = pos
		bullet["vel"] = vel
		var expired: bool = float(bullet["life"]) <= 0.0 or pos.z < CombatSpace.BOSS_Z - 18.0
		if not expired and enemy_squadron != null and enemy_squadron.has_method("query_hit"):
			# Swept test: a 96 u/s bullet moves further in one frame than a drone is
			# deep, so sampling only the end position would tunnel straight through.
			var unit_index: int = -1
			var step: Vector3 = pos - prev_pos
			var samples: int = clampi(int(ceil(step.length() / 0.55)), 1, 12)
			for sample_index in range(samples):
				var sample_pos: Vector3 = prev_pos + step * (float(sample_index + 1) / float(samples))
				unit_index = int(enemy_squadron.query_hit(sample_pos, float(bullet.get("radius", 0.26))))
				if unit_index >= 0:
					pos = sample_pos
					break
			if unit_index >= 0:
				var air_damage: float = float(bullet.get("damage", 18.0))
				var air_applied: float = float(enemy_squadron.apply_hit(unit_index, air_damage, pos))
				if air_applied > 0.0:
					air_enemy_hit_count += 1
					air_enemy_damage_total += air_applied
				expired = true
		if not expired and boss_entity != null and boss_entity.has_method("query_hit"):
			var part: String = str(boss_entity.query_hit(pos, float(bullet.get("radius", 0.26))))
			if part != "":
				var damage: float = float(bullet.get("damage", 18.0))
				var applied: float = float(boss_entity.apply_hit(part, damage, pos))
				if applied > 0.0:
					boss_hit_count += 1
					total_damage_to_boss += applied
					last_boss_hit_part = part
					recent_boss_hits.append({"part": part, "damage": applied, "x": pos.x, "y": pos.y, "z": pos.z})
				expired = true
		if expired:
			if float(bullet["life"]) <= 0.0 or pos.z < CombatSpace.BOSS_Z - 18.0:
				blocked_shots += 1
			bullet["active"] = false
		player_pool[i] = bullet


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


func _lead_missile_pos() -> Vector3:
	for missile in missile_pool:
		if bool(missile.get("active", false)):
			return missile.get("pos", Vector3.ZERO)
	return Vector3.ZERO


func _lead_missile_trail_size() -> int:
	for missile in missile_pool:
		if bool(missile.get("active", false)):
			return (missile.get("trail", []) as Array).size()
	return 0


func _active_player_missile_count() -> int:
	var count := 0
	for missile in player_missile_pool:
		if bool(missile.get("active", false)):
			count += 1
	return count


func _player_missile_phases() -> Array:
	var phases: Array = []
	for missile in player_missile_pool:
		if bool(missile.get("active", false)):
			phases.append(str(missile.get("phase", "idle")))
	return phases


func _active_missile_count() -> int:
	var count := 0
	for missile in missile_pool:
		if bool(missile.get("active", false)):
			count += 1
	return count


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
