extends Node3D
class_name ForwardArenaDirector

# Phase 2 battlefield director: layered storm arena, warzone depth, and weather volumes
# that affect flight feel. This is runtime 3D geometry/GLB usage, not static photos.

const CLOUD_BANK_PATH = "res://assets/models/air_cloud_cluster.glb"
const ARENA_CHUNK_PATH = "res://assets/models/air_arena_tile.glb"
const SUPPORT_JET_PATH = "res://assets/models/support_jet.glb"
const DEPTH_LAYER_COUNT = 5

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
var smoke_columns: Array = []
var fire_pockets: Array = []
var rain_sheets: Array = []
var debris_streaks: Array = []
var air_traffic: Array = []
var tracer_streaks: Array = []
var boss_anchor: Node3D
var boss_core: MeshInstance3D
var boss_beams: Array = []
var cinematic_bullets: Array = []
var player_beams: Array = []
var missile_trails: Array = []
var shield_bubbles: Array = []
var explosion_bursts: Array = []
var storm_cells: Array = []
var lightning_nodes: Array = []

var cloud_scene: PackedScene
var arena_scene: PackedScene
var support_scene: PackedScene

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


func setup() -> void:
	if is_setup:
		return
	rng.randomize()
	name = "ForwardArenaDirector"
	visible = false
	_load_scene_assets()
	_create_materials()
	_create_far_sky_layer()
	_create_mid_cloud_layer()
	_create_warzone_layer()
	_create_near_weather_layer()
	_create_distant_battle_layer()
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
	_reset_layers()


func stop_mission() -> void:
	active = false
	visible = false


func update_arena(delta: float, player_corridor: Vector2, travel_speed: float) -> Dictionary:
	if not active:
		return get_weather_effect()
	forward_time += delta
	_update_weather_logic(delta, player_corridor)
	_update_far_sky(delta, travel_speed)
	_update_mid_clouds(delta, travel_speed)
	_update_warzone(delta, travel_speed)
	_update_near_weather(delta, travel_speed)
	_update_distant_battle(delta, travel_speed)
	_update_visual_lock_composition(delta, travel_speed)
	_update_storm_cells(delta, travel_speed, player_corridor)
	_update_lightning_nodes()
	return get_weather_effect()


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
		"lightningFlash": lightning_flash,
		"lightningOvercharge": overcharge_timer > 0.0,
		"overchargeSeconds": overcharge_timer,
		"stormHazard": storm_hazard,
		"bossAnchor": boss_anchor != null,
		"bossName": "Dreadnought Leviathan",
		"visualLockComposition": "dreadnought_forward_battle",
		"hazardPushX": hazard_push.x,
		"hazardPushY": hazard_push.y,
		"distantTraffic": air_traffic.size(),
		"arenaDirector": "ForwardArenaDirector"
	}


func get_bridge_state() -> Dictionary:
	var effect = get_weather_effect()
	effect.erase("turbulence")
	return effect


func _load_scene_assets() -> void:
	var cloud_resource = load(CLOUD_BANK_PATH)
	if cloud_resource is PackedScene:
		cloud_scene = cloud_resource
	var arena_resource = load(ARENA_CHUNK_PATH)
	if arena_resource is PackedScene:
		arena_scene = arena_resource
	var support_resource = load(SUPPORT_JET_PATH)
	if support_resource is PackedScene:
		support_scene = support_resource


func _create_materials() -> void:
	storm_cloud_mat = _make_material(Color(0.48, 0.61, 0.76, 0.26), Color(0.05, 0.11, 0.18, 1.0), 0.0, 0.26)
	deep_cloud_mat = _make_material(Color(0.16, 0.22, 0.32, 0.38), Color(0.03, 0.08, 0.14, 1.0), 0.0, 0.38)
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


func _create_far_sky_layer() -> void:
	for i in range(4):
		var bank = _cloud_bank_node("FarStormWall_%02d" % i, 3, true)
		bank.position = Vector3(rng.randf_range(-26.0, 26.0), rng.randf_range(9.0, 16.0), -72.0 - i * 34.0)
		bank.scale = Vector3(rng.randf_range(1.6, 3.0), rng.randf_range(0.8, 1.4), rng.randf_range(1.4, 2.6))
		bank.set_meta("speed_mul", rng.randf_range(0.10, 0.18))
		add_child(bank)
		far_sky_banks.append(bank)


func _create_mid_cloud_layer() -> void:
	for i in range(8):
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
		chunk.position = Vector3(0.0, -9.0, -24.0 - i * 22.0)
		chunk.set_meta("speed_mul", 0.88)
		chunk.add_child(_box_mesh("OceanOrFloodedCityPlateLeft", Vector3(-8.5, 0.0, 0.0), Vector3(8.5, 0.045, 13.0), ocean_mat))
		chunk.add_child(_box_mesh("OceanOrFloodedCityPlateRight", Vector3(8.5, 0.0, 0.0), Vector3(8.5, 0.045, 13.0), ocean_mat))
		for b in range(9):
			var bx = rng.randf_range(-11.0, -5.0) if b % 2 == 0 else rng.randf_range(5.0, 11.0)
			var bz = rng.randf_range(-5.6, 5.6)
			var by = rng.randf_range(0.35, 1.8)
			chunk.add_child(_box_mesh("CityBlock_%02d" % b, Vector3(bx, by * 0.5, bz), Vector3(rng.randf_range(0.45, 1.25), by, rng.randf_range(0.45, 1.4)), city_mat))
		for f in range(4):
			var fire = _box_mesh("GroundFirePocket_%02d" % f, Vector3(rng.randf_range(-10.0, -4.8) if f % 2 == 0 else rng.randf_range(4.8, 10.0), 0.52, rng.randf_range(-5.6, 5.6)), Vector3(0.35, rng.randf_range(0.7, 1.45), 0.35), fire_mat)
			chunk.add_child(fire)
			fire_pockets.append(fire)
		for s in range(3):
			var smoke = _smoke_column("SmokeColumn_%02d" % s, Vector3(rng.randf_range(-10.5, -5.0) if s % 2 == 0 else rng.randf_range(5.0, 10.5), 1.0, rng.randf_range(-5.8, 5.8)))
			chunk.add_child(smoke)
			smoke_columns.append(smoke)
		add_child(chunk)
		warzone_chunks.append(chunk)


func _create_near_weather_layer() -> void:
	for i in range(16):
		var sheet = _box_mesh("RainSheet_%02d" % i, Vector3.ZERO, Vector3(rng.randf_range(0.025, 0.055), rng.randf_range(3.6, 8.4), rng.randf_range(0.025, 0.055)), rain_mat)
		sheet.position = Vector3(rng.randf_range(-8.5, 8.5), rng.randf_range(0.5, 6.0), -5.0 - rng.randf_range(0.0, 78.0))
		sheet.rotation_degrees = Vector3(rng.randf_range(-18.0, -8.0), 0.0, rng.randf_range(-15.0, 15.0))
		sheet.set_meta("speed_mul", rng.randf_range(1.18, 1.48))
		add_child(sheet)
		rain_sheets.append(sheet)
	for i in range(12):
		var debris = _box_mesh("NearDebrisStreak_%02d" % i, Vector3.ZERO, Vector3(rng.randf_range(0.06, 0.13), rng.randf_range(0.03, 0.08), rng.randf_range(0.8, 2.2)), debris_mat)
		debris.position = Vector3(rng.randf_range(-10.0, 10.0), rng.randf_range(-1.8, 4.7), -8.0 - rng.randf_range(0.0, 95.0))
		debris.rotation_degrees = Vector3(rng.randf_range(-4.0, 4.0), rng.randf_range(-12.0, 12.0), rng.randf_range(-24.0, 24.0))
		debris.set_meta("speed_mul", rng.randf_range(1.10, 1.55))
		add_child(debris)
		debris_streaks.append(debris)


func _create_distant_battle_layer() -> void:
	for i in range(8):
		var traffic = Node3D.new()
		traffic.name = "DistantAirTraffic_%02d" % i
		traffic.position = Vector3(rng.randf_range(-18.0, 18.0), rng.randf_range(3.0, 10.0), -45.0 - rng.randf_range(0.0, 130.0))
		traffic.set_meta("speed_mul", rng.randf_range(0.30, 0.56))
		traffic.set_meta("side_speed", rng.randf_range(-1.6, 1.6))
		if support_scene:
			var jet = support_scene.instantiate()
			jet.name = "DistantJetSilhouetteGLB"
			jet.scale = Vector3(0.55, 0.55, 0.55)
			jet.rotation_degrees = Vector3(0.0, 180.0 + rng.randf_range(-22.0, 22.0), 0.0)
			traffic.add_child(jet)
		else:
			traffic.add_child(_box_mesh("DistantJetFallback", Vector3.ZERO, Vector3(0.8, 0.08, 0.55), city_mat))
		add_child(traffic)
		air_traffic.append(traffic)
	for i in range(18):
		var mat = tracer_cyan_mat if i % 3 == 0 else tracer_red_mat
		var tracer = _box_mesh("DistantTracer_%02d" % i, Vector3.ZERO, Vector3(0.045, 0.045, rng.randf_range(2.2, 6.4)), mat)
		tracer.position = Vector3(rng.randf_range(-18.0, 18.0), rng.randf_range(1.0, 10.5), -24.0 - rng.randf_range(0.0, 145.0))
		tracer.rotation_degrees = Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(-28.0, 28.0), rng.randf_range(-18.0, 18.0))
		tracer.set_meta("speed_mul", rng.randf_range(0.62, 0.95))
		add_child(tracer)
		tracer_streaks.append(tracer)


func _create_visual_lock_composition_layer() -> void:
	# Recenter the arena around the reference composition: readable player path,
	# a massive boss carrier in the upper half, ordered projectile lanes, smoke,
	# shielded support craft, and explosions over the warzone below.
	boss_anchor = Node3D.new()
	boss_anchor.name = "DreadnoughtLeviathanBossAnchor"
	boss_anchor.position = Vector3(0.0, 12.5, -96.0)
	boss_anchor.set_meta("base_z", -96.0)
	boss_anchor.add_child(_box_mesh("LeviathanMainHull", Vector3(0.0, 0.0, 0.0), Vector3(24.0, 2.4, 8.2), boss_hull_mat))
	boss_anchor.add_child(_box_mesh("LeviathanUpperDeck", Vector3(0.0, 1.65, -0.3), Vector3(17.0, 0.95, 5.9), boss_armor_mat))
	boss_anchor.add_child(_box_mesh("LeviathanBowPlate", Vector3(0.0, -0.15, 5.1), Vector3(11.5, 1.3, 0.9), boss_armor_mat))
	boss_anchor.add_child(_box_mesh("LeftFlightSponson", Vector3(-12.7, -0.15, 0.6), Vector3(3.8, 0.65, 5.8), boss_hull_mat))
	boss_anchor.add_child(_box_mesh("RightFlightSponson", Vector3(12.7, -0.15, 0.6), Vector3(3.8, 0.65, 5.8), boss_hull_mat))
	for i in range(7):
		var tx = -7.8 + i * 2.6
		var tower = _box_mesh("CommandTower_%02d" % i, Vector3(tx, 2.8 + rng.randf_range(0.0, 1.0), rng.randf_range(-2.8, 2.5)), Vector3(0.75, rng.randf_range(2.2, 4.8), 0.75), boss_armor_mat)
		boss_anchor.add_child(tower)
		var light = _box_mesh("TowerBlueBeacon_%02d" % i, tower.position + Vector3(0.0, tower.mesh.size.y * 0.55 + 0.10, 0.0), Vector3(0.20, 0.12, 0.20), player_beam_mat)
		boss_anchor.add_child(light)
	for i in range(11):
		var sx = -7.5 + i * 1.5
		boss_anchor.add_child(_box_mesh("LeviathanBlueWindow_%02d" % i, Vector3(sx, -0.45, 5.68), Vector3(0.45, 0.16, 0.08), player_beam_mat))
		if i % 2 == 0:
			boss_anchor.add_child(_box_mesh("LeviathanRedPort_%02d" % i, Vector3(sx + 0.7, 0.20, 5.75), Vector3(0.34, 0.14, 0.08), tracer_red_mat))
	boss_core = _sphere_mesh("LeviathanCoreCannon", Vector3(0.0, -0.20, 5.92), 0.92, boss_core_mat)
	boss_anchor.add_child(boss_core)
	add_child(boss_anchor)

	for i in range(5):
		var x = -4.4 + i * 2.2
		var beam = _box_mesh("BossLaserLance_%02d" % i, Vector3(x, 5.8 - abs(float(i) - 2.0) * 0.30, -54.0 + i * 1.4), Vector3(0.07, 0.07, 46.0), tracer_red_mat)
		beam.rotation_degrees = Vector3(0.0, -x * 1.6, x * 2.0)
		beam.set_meta("base_x", x)
		add_child(beam)
		boss_beams.append(beam)

	var lanes = [-3.4, -2.15, -0.9, 0.9, 2.15, 3.4]
	for i in range(36):
		var lane = lanes[i % lanes.size()]
		var bullet = _box_mesh("ReadableEnemyBolt_%02d" % i, Vector3(lane, rng.randf_range(1.6, 5.4), -34.0 - i * 3.8), Vector3(0.16, 0.16, 1.28), tracer_red_mat)
		bullet.set_meta("lane", lane)
		bullet.set_meta("speed_mul", rng.randf_range(1.20, 1.55))
		add_child(bullet)
		cinematic_bullets.append(bullet)

	for i in range(2):
		var beam_x = -0.42 if i == 0 else 0.42
		var player_beam = _box_mesh("PlayerCyanFireLane_%02d" % i, Vector3(beam_x, 1.75, -38.0), Vector3(0.075, 0.075, 72.0), player_beam_mat)
		player_beam.set_meta("beam_x", beam_x)
		add_child(player_beam)
		player_beams.append(player_beam)

	for i in range(16):
		var trail = _box_mesh("MissileSmokeTrail_%02d" % i, Vector3(rng.randf_range(-11.0, 11.0), rng.randf_range(-0.7, 3.5), -14.0 - rng.randf_range(0.0, 94.0)), Vector3(0.24, 0.24, rng.randf_range(3.0, 8.5)), missile_smoke_mat)
		trail.rotation_degrees = Vector3(rng.randf_range(-10.0, 10.0), rng.randf_range(-26.0, 26.0), rng.randf_range(-18.0, 18.0))
		trail.set_meta("speed_mul", rng.randf_range(0.72, 1.05))
		add_child(trail)
		missile_trails.append(trail)

	for i in range(5):
		var explosion = _sphere_mesh("WarzoneExplosionBurst_%02d" % i, Vector3(rng.randf_range(-9.5, 9.5), rng.randf_range(-2.4, 1.4), -24.0 - rng.randf_range(0.0, 86.0)), rng.randf_range(0.65, 1.35), explosion_mat)
		explosion.set_meta("base_radius", explosion.scale.x)
		explosion.set_meta("speed_mul", rng.randf_range(0.78, 1.05))
		add_child(explosion)
		explosion_bursts.append(explosion)

	for i in range(2):
		var shield_x = -8.8 if i == 0 else 8.6
		var shield = _sphere_mesh("WingmanShieldBubble_%02d" % i, Vector3(shield_x, 2.0 + i * 0.45, -34.0 - i * 18.0), 1.75, shield_mat)
		shield.set_meta("speed_mul", 0.66 + i * 0.06)
		add_child(shield)
		shield_bubbles.append(shield)



func _create_storm_hazard_cells() -> void:
	for i in range(4):
		var cell = _cloud_bank_node("StormCellHazard_%02d" % i, 5, false)
		cell.position = Vector3(rng.randf_range(-5.0, 5.0), rng.randf_range(0.4, 3.8), -35.0 - i * 42.0)
		cell.scale = Vector3(2.1, 1.4, 2.1)
		cell.set_meta("speed_mul", 0.54)
		cell.set_meta("radius", 3.9)
		cell.add_child(_box_mesh("StormHazardCore", Vector3.ZERO, Vector3(4.2, 3.0, 4.2), hazard_mat))
		add_child(cell)
		storm_cells.append(cell)
	for i in range(5):
		var bolt = _box_mesh("LightningFork_%02d" % i, Vector3.ZERO, Vector3(0.05, rng.randf_range(5.0, 10.0), 0.05), lightning_mat)
		bolt.position = Vector3(rng.randf_range(-10.0, 10.0), rng.randf_range(4.0, 8.0), -22.0 - rng.randf_range(0.0, 100.0))
		bolt.rotation_degrees = Vector3(rng.randf_range(-12.0, 12.0), 0.0, rng.randf_range(-28.0, 28.0))
		bolt.visible = false
		add_child(bolt)
		lightning_nodes.append(bolt)


func _reset_layers() -> void:
	for i in range(far_sky_banks.size()):
		far_sky_banks[i].position = Vector3(rng.randf_range(-26.0, 26.0), rng.randf_range(9.0, 16.0), -72.0 - i * 34.0)
	for cloud in mid_cloud_banks:
		cloud.position = Vector3(rng.randf_range(-13.5, 13.5), rng.randf_range(3.0, 8.2), -36.0 - rng.randf_range(0.0, 130.0))
	for i in range(warzone_chunks.size()):
		warzone_chunks[i].position = Vector3(0.0, -9.0, -24.0 - i * 22.0)
	for rain in rain_sheets:
		rain.position = Vector3(rng.randf_range(-8.5, 8.5), rng.randf_range(0.5, 6.0), -5.0 - rng.randf_range(0.0, 78.0))
	for debris in debris_streaks:
		debris.position = Vector3(rng.randf_range(-10.0, 10.0), rng.randf_range(-1.8, 4.7), -8.0 - rng.randf_range(0.0, 95.0))
	for traffic in air_traffic:
		traffic.position = Vector3(rng.randf_range(-18.0, 18.0), rng.randf_range(3.0, 10.0), -45.0 - rng.randf_range(0.0, 130.0))
	for tracer in tracer_streaks:
		tracer.position = Vector3(rng.randf_range(-18.0, 18.0), rng.randf_range(1.0, 10.5), -24.0 - rng.randf_range(0.0, 145.0))
	if boss_anchor:
		boss_anchor.position = Vector3(0.0, 12.5, -96.0)
	for bullet in cinematic_bullets:
		bullet.position.z = -18.0 - rng.randf_range(0.0, 112.0)
		bullet.position.y = rng.randf_range(1.1, 4.5)
	for trail in missile_trails:
		trail.position = Vector3(rng.randf_range(-11.0, 11.0), rng.randf_range(-0.7, 3.5), -14.0 - rng.randf_range(0.0, 94.0))
	for explosion in explosion_bursts:
		explosion.position = Vector3(rng.randf_range(-9.5, 9.5), rng.randf_range(-2.4, 1.4), -24.0 - rng.randf_range(0.0, 86.0))
	for i in range(shield_bubbles.size()):
		shield_bubbles[i].position = Vector3(-8.8 if i == 0 else 8.6, 2.0 + i * 0.45, -34.0 - i * 18.0)
	for i in range(storm_cells.size()):
		storm_cells[i].position = Vector3(rng.randf_range(-5.0, 5.0), rng.randf_range(0.4, 3.8), -35.0 - i * 42.0)


func _update_weather_logic(delta: float, player_corridor: Vector2) -> void:
	var wind = float(stage_weather.get("wind", 0.0))
	var rain = float(stage_weather.get("rain", 0.0))
	var cloud = float(stage_weather.get("cloud", 0.0))
	var lightning = float(stage_weather.get("lightning", 0.0))
	var base_visibility = float(stage_weather.get("visibility", 0.84))
	var gust = sin(forward_time * 0.77) * 0.35 + sin(forward_time * 1.83 + 1.7) * 0.18
	wind_drift = wind * (0.70 + gust * 0.24)
	turbulence = Vector2(wind_drift * 0.42 + sin(forward_time * 2.4) * cloud * 0.11, sin(forward_time * 1.65 + 0.8) * (rain + cloud) * 0.08)

	cloud_cover = clamp(cloud * 0.22, 0.0, 0.38)
	cloud_occlusion = false
	for bank in mid_cloud_banks:
		if bank.position.z > -38.0 and bank.position.z < 4.0:
			var radius = float(bank.get_meta("radius", 3.8)) * max(bank.scale.x, bank.scale.z)
			var horizontal = abs(player_corridor.x - bank.position.x)
			var vertical = abs((1.55 + player_corridor.y) - bank.position.y)
			var proximity = clamp(1.0 - (horizontal + vertical * 0.8) / max(1.0, radius), 0.0, 1.0)
			if proximity > 0.22:
				cloud_occlusion = true
				cloud_cover = max(cloud_cover, 0.26 + proximity * 0.30)
	rain_visibility = clamp(base_visibility - rain * 0.08 - cloud_cover * 0.06 - storm_hazard * 0.05 + lightning_flash * 0.10, 0.62, 1.0)

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
			debris.position = Vector3(rng.randf_range(-10.0, 10.0), rng.randf_range(-1.8, 4.7), -100.0 - rng.randf_range(0.0, 35.0))


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


func _update_visual_lock_composition(delta: float, travel_speed: float) -> void:
	if boss_anchor:
		boss_anchor.position.z = lerp(boss_anchor.position.z, -96.0 + sin(forward_time * 0.22) * 2.0, min(1.0, delta * 0.7))
		boss_anchor.position.x = sin(forward_time * 0.17) * 1.0
		boss_anchor.rotation_degrees.z = sin(forward_time * 0.19) * 1.5
	if boss_core:
		var core_pulse = 1.0 + sin(forward_time * 7.5) * 0.10 + lightning_flash * 0.32
		boss_core.scale = Vector3.ONE * core_pulse
	for beam in boss_beams:
		beam.visible = true
		beam.position.x = float(beam.get_meta("base_x", 0.0)) + sin(forward_time * 0.9 + beam.position.z) * 0.22
		beam.scale.z = 1.0 + lightning_flash * 0.18
	for bullet in cinematic_bullets:
		bullet.position.z += travel_speed * float(bullet.get_meta("speed_mul", 1.35)) * delta
		bullet.position.x = float(bullet.get_meta("lane", 0.0)) + sin(forward_time * 1.15 + bullet.position.z * 0.05) * 0.18
		bullet.rotation_degrees.x = 0.0
		if bullet.position.z > 6.0:
			bullet.position.z = -112.0 - rng.randf_range(0.0, 28.0)
			bullet.position.y = rng.randf_range(1.1, 4.5)
	for beam in player_beams:
		beam.position.x = float(beam.get_meta("beam_x", 0.0)) + sin(forward_time * 12.0) * 0.025
		beam.scale.z = 1.0 + (0.22 if overcharge_timer > 0.0 else 0.0) + sin(forward_time * 14.0) * 0.02
	for trail in missile_trails:
		trail.position.z += travel_speed * float(trail.get_meta("speed_mul", 0.9)) * delta
		trail.position.x += wind_drift * delta * 0.72
		trail.scale.z = 1.0 + sin(forward_time * 1.7 + trail.position.x) * 0.06
		if trail.position.z > 12.0:
			trail.position = Vector3(rng.randf_range(-11.0, 11.0), rng.randf_range(-0.7, 3.5), -112.0 - rng.randf_range(0.0, 28.0))
	for explosion in explosion_bursts:
		explosion.position.z += travel_speed * float(explosion.get_meta("speed_mul", 0.86)) * delta
		var pulse = 1.0 + sin(forward_time * 9.0 + explosion.position.x) * 0.18
		explosion.scale = Vector3.ONE * float(explosion.get_meta("base_radius", 1.0)) * pulse
		if explosion.position.z > 10.0:
			explosion.position = Vector3(rng.randf_range(-9.5, 9.5), rng.randf_range(-2.4, 1.4), -112.0 - rng.randf_range(0.0, 36.0))
	for shield in shield_bubbles:
		shield.position.z += travel_speed * float(shield.get_meta("speed_mul", 0.66)) * delta
		shield.rotation_degrees.y += delta * 22.0
		shield.scale = Vector3.ONE * (1.0 + sin(forward_time * 2.5 + shield.position.x) * 0.045)
		if shield.position.z > 10.0:
			shield.position = Vector3(rng.randf_range(-9.5, 9.5), rng.randf_range(1.5, 3.1), -105.0 - rng.randf_range(0.0, 44.0))



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
		var puff = _box_mesh("SmokePuff_%02d" % i, Vector3(rng.randf_range(-0.28, 0.28), i * 0.62, rng.randf_range(-0.25, 0.25)), Vector3(0.65 + i * 0.22, 0.55 + i * 0.12, 0.65 + i * 0.20), smoke_mat)
		puff.rotation_degrees = Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(0.0, 360.0), rng.randf_range(-12.0, 12.0))
		root.add_child(puff)
	return root


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
