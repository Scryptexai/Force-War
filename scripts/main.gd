extends Node2D

# Force War: Storm Convoy
# Original tactical escort shooter for Godot Web. The player protects a ground
# convoy through branching routes and extreme weather instead of simply clearing
# every enemy on screen.

const W = 720.0
const H = 960.0
const SAVE_PATH = "user://force_war_storm_convoy_save.json"
const SAVE_KEY = "force-war-storm-convoy-v2"
const PLAYER_RADIUS = 19.0
const CONVOY_RADIUS = 25.0
const ROAD_WIDTH = 156.0
const MAX_STAGE = 6

enum GameState { TITLE, BRIEFING, GROUND, PLAYING, STAGE_CLEAR, GAME_OVER, PAUSED }

var rng = RandomNumberGenerator.new()
var font: Font
var state = GameState.TITLE
var previous_state = GameState.TITLE
var time = 0.0
var textures = {}

var stages = []
var loadouts = []
var save_data = {}
var selected_stage = 0
var selected_loadout = 0
var stage_index = 0
var stage = {}
var loadout = {}

var player = {}
var convoy = []
var bullets = []
var enemy_bullets = []
var enemies = []
var pickups = []
var support_drops = []
var effects = []
var particles = []
var clouds = []
var hazards = []
var lightning_marks = []
var bg_stars = []

var route_progress = 0.0
var route_distance = 1000.0
var route_offset = 0.0
var route_target_offset = 0.0
var route_speed = 34.0
var route_speed_mod = 1.0
var stage_threat = 1.0
var stage_reward_mod = 1.0
var stage_wind_mod = 0.0
var stage_score = 0
var stage_stars = 0
var kills = 0
var convoy_damage_taken = 0
var civilians_saved = 0

var spawn_timer = 0.0
var wave_index = 0
var boss_spawned = false
var boss_defeated = false
var finish_timer = 0.0
var branch_pending = false
var branch_choice_index = 0
var branch_timer = 0.0
var branch_checkpoint_index = 0
var applied_branches = []

var support_counts = {}
var support_cooldown = 0.0
var smoke_timer = 0.0
var radar_timer = 0.0
var overcharge_timer = 0.0
var supply_turret_timer = 0.0
var lightning_timer = 0.0
var lightning_next = 5.0
var weather_flash = 0.0
var warning_text = ""
var warning_timer = 0.0

var pointer_active = false
var pointer_target = Vector2.ZERO
var touch_active = false
var js_timer = 0.0

# 3D ground-chase prologue state. These are real GLB scene instances rendered
# by a perspective Camera3D, not static photos and not top-down.
var ground_root: Node3D
var ground_camera: Camera3D
var ground_player_node: Node3D
var ground_jet_node: Node3D
var ground_road_markers: Array = []
var ground_enemies: Array = []
var ground_bullets: Array = []
var ground_enemy_bullets: Array = []
var ground_time = 0.0
var ground_distance = 0.0
var ground_player_x = 0.0
var ground_car_hp = 100
var ground_car_max_hp = 100
var ground_spawn_timer = 0.0
var ground_shot_cd = 0.0
var ground_jet_called = false
var ground_jet_timer = 0.0
var ground_transition_ready = false


func _ready() -> void:
	rng.randomize()
	font = SystemFont.new()
	load_textures()
	stages = make_stage_defs()
	loadouts = make_loadouts()
	save_data = default_save()
	load_save()
	selected_stage = int(clamp(int(save_data.get("unlocked_stage", 1)) - 1, 0, stages.size() - 1))
	selected_loadout = int(save_data.get("last_loadout", 0))
	init_background()
	reset_player()
	js_emit("ready", {
		"game": "Force War: Storm Convoy",
		"engine_target": "Godot 4.6.2 stable Web",
		"objective": "escort_convoy"
	})


func _process(delta: float) -> void:
	time += delta
	update_background(delta)
	warning_timer = max(0.0, warning_timer - delta)
	weather_flash = max(0.0, weather_flash - delta * 2.6)
	if state == GameState.GROUND:
		update_ground_chase(delta)
	elif state == GameState.PLAYING:
		update_playing(delta)
	elif state == GameState.STAGE_CLEAR or state == GameState.GAME_OVER:
		update_particles(delta)
		update_effects(delta)
	js_timer -= delta
	if js_timer <= 0.0:
		js_timer = 0.5
		push_js_state()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_active = event.pressed
		pointer_target = event.position
	elif event is InputEventScreenDrag:
		touch_active = true
		pointer_target = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer_active = event.pressed
		pointer_target = event.position
	elif event is InputEventMouseMotion and pointer_active:
		pointer_target = event.position

	if event.is_action_pressed("pause"):
		if state == GameState.PLAYING or state == GameState.GROUND:
			previous_state = state
			state = GameState.PAUSED
			js_emit("pause", {})
		elif state == GameState.PAUSED:
			state = previous_state
			js_emit("resume", {})
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if state == GameState.GROUND:
			handle_ground_key(event.keycode)
		elif state == GameState.PLAYING:
			handle_play_key(event.keycode)
		elif state == GameState.BRIEFING:
			handle_briefing_key(event.keycode)
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			handle_accept()
		elif event.keycode == KEY_ESCAPE:
			handle_escape()
		elif state == GameState.GAME_OVER and event.keycode == KEY_R:
			start_stage(selected_stage)


func handle_accept() -> void:
	if state == GameState.TITLE:
		state = GameState.BRIEFING
	elif state == GameState.BRIEFING:
		start_stage(selected_stage)
	elif state == GameState.STAGE_CLEAR:
		state = GameState.BRIEFING
		selected_stage = int(clamp(int(save_data.get("unlocked_stage", 1)) - 1, 0, stages.size() - 1))
	elif state == GameState.GAME_OVER:
		start_stage(selected_stage)
	elif state == GameState.PAUSED:
		state = previous_state


func handle_escape() -> void:
	if state == GameState.TITLE:
		return
	if state == GameState.PLAYING or state == GameState.GROUND:
		previous_state = state
		state = GameState.PAUSED
	elif state == GameState.PAUSED:
		if previous_state == GameState.GROUND:
			cleanup_ground_scene()
		state = GameState.BRIEFING
		js_emit("abort_mission", {})
	else:
		state = GameState.TITLE


func handle_briefing_key(keycode: int) -> void:
	var unlocked = int(save_data.get("unlocked_stage", 1))
	if keycode == KEY_LEFT:
		selected_loadout = posmod(selected_loadout - 1, loadouts.size())
	elif keycode == KEY_RIGHT:
		selected_loadout = posmod(selected_loadout + 1, loadouts.size())
	elif keycode == KEY_UP:
		selected_stage = max(0, selected_stage - 1)
	elif keycode == KEY_DOWN:
		selected_stage = min(unlocked - 1, selected_stage + 1)
	elif keycode == KEY_ENTER or keycode == KEY_KP_ENTER or keycode == KEY_SPACE:
		start_stage(selected_stage)
	elif keycode == KEY_ESCAPE:
		state = GameState.TITLE


func handle_ground_key(keycode: int) -> void:
	if (keycode == KEY_ENTER or keycode == KEY_KP_ENTER or keycode == KEY_SPACE) and ground_transition_ready:
		enter_air_phase()
	elif keycode == KEY_ESCAPE:
		previous_state = state
		state = GameState.PAUSED


func handle_play_key(keycode: int) -> void:
	if branch_pending:
		if keycode == KEY_LEFT or keycode == KEY_A:
			branch_choice_index = max(0, branch_choice_index - 1)
		elif keycode == KEY_RIGHT or keycode == KEY_D:
			branch_choice_index = min(2, branch_choice_index + 1)
		elif keycode == KEY_ENTER or keycode == KEY_KP_ENTER or keycode == KEY_SPACE:
			apply_branch_choice(branch_choice_index)
			return
	if keycode == KEY_1:
		drop_support("repair")
	elif keycode == KEY_2:
		drop_support("smoke")
	elif keycode == KEY_3:
		drop_support("supply")
	elif keycode == KEY_4:
		drop_support("radar")
	elif keycode == KEY_5:
		drop_support("rod")
	elif keycode == KEY_Q and branch_pending:
		apply_branch_choice(0)
	elif keycode == KEY_E and branch_pending:
		apply_branch_choice(2)


func load_textures() -> void:
	var paths = {
		# AI-painted PNG sprites used in gameplay. SVG files remain as editable fallbacks/source references.
		"player": "res://assets/rendered/player_stormhawk.png",
		"player_support": "res://assets/rendered/player_stormhawk.png",
		"interceptor": "res://assets/rendered/enemy_interceptor.png",
		"bomber": "res://assets/rendered/enemy_bomber.png",
		"gunship": "res://assets/rendered/enemy_gunship.png",
		"drone": "res://assets/rendered/enemy_storm_drone.png",
		"tank": "res://assets/rendered/enemy_tank.png",
		"sam": "res://assets/rendered/enemy_sam.png",
		"artillery": "res://assets/rendered/enemy_artillery.png",
		"command": "res://assets/rendered/convoy_command_truck.png",
		"fuel": "res://assets/rendered/convoy_fuel_tanker.png",
		"apc": "res://assets/rendered/convoy_apc.png",
		"supply_truck": "res://assets/rendered/convoy_supply_truck.png",
		"bg_monsoon": "res://assets/rendered/background_monsoon_pass.png",
		"bg_delta": "res://assets/rendered/background_black_delta.png",
		"bg_thunder": "res://assets/rendered/background_thunder_ridge.png",
		"boss": "res://assets/rendered/boss_aegis_weather_engine.png",
		"repair": "res://assets/rendered/support_repair_pod.png",
		"smoke": "res://assets/rendered/support_smoke_pod.png",
		"supply": "res://assets/rendered/support_supply_pod.png",
		"radar": "res://assets/rendered/support_radar_pod.png",
		"rod": "res://assets/rendered/support_rod_pod.png",
		"storm_icon": "res://assets/weather/storm_icon.svg",
		"rain_icon": "res://assets/weather/rain_icon.svg",
		"wind_icon": "res://assets/weather/wind_icon.svg",
		"cloud_icon": "res://assets/weather/cloud_icon.svg"
	}
	textures.clear()
	for key in paths.keys():
		var tex = load(paths[key])
		if tex != null:
			textures[key] = tex


func make_stage_defs() -> Array:
	return [
		{
			"name": "Operation Monsoon Pass",
			"codename": "MONSOON PASS",
			"brief": "Konvoi medis harus melewati lembah banjir. Hujan menurunkan visibilitas, tapi petir jarang.",
			"distance": 950.0,
			"weather": {"kind": "monsoon", "wind": -0.42, "rain": 0.82, "cloud": 0.38, "lightning": 0.18, "visibility": 0.72, "flood": 0.45},
			"boss": "Rainbreaker Turret",
			"hue": 0.57,
			"branches": [
				{"name": "Flooded Village", "risk": 0.75, "reward": 0.9, "wind": -0.08, "speed": 0.82, "offset": -110.0, "note": "Lambat, banyak cover smoke."},
				{"name": "Raised Highway", "risk": 1.0, "reward": 1.0, "wind": 0.0, "speed": 1.0, "offset": 0.0, "note": "Seimbang."},
				{"name": "Broken Dam", "risk": 1.35, "reward": 1.35, "wind": 0.18, "speed": 1.18, "offset": 115.0, "note": "Cepat, banyak bomber."}
			]
		},
		{
			"name": "Operation Forked Canyon",
			"codename": "FORKED CANYON",
			"brief": "Angin silang di ngarai membelokkan peluru. Pilih jalur yang cocok dengan aim dan support.",
			"distance": 1100.0,
			"weather": {"kind": "crosswind", "wind": 0.78, "rain": 0.15, "cloud": 0.24, "lightning": 0.08, "visibility": 0.9, "flood": 0.05},
			"boss": "Canyon Railgun",
			"hue": 0.08,
			"branches": [
				{"name": "Left Ridge", "risk": 1.1, "reward": 1.1, "wind": -0.55, "speed": 1.02, "offset": -150.0, "note": "Angin balik, banyak SAM."},
				{"name": "Dry River", "risk": 0.92, "reward": 0.9, "wind": 0.2, "speed": 0.92, "offset": -20.0, "note": "Lebih aman tapi lambat."},
				{"name": "Cliff Sprint", "risk": 1.45, "reward": 1.45, "wind": 0.62, "speed": 1.25, "offset": 140.0, "note": "High risk reward."}
			]
		},
		{
			"name": "Operation Black Delta",
			"codename": "BLACK DELTA",
			"brief": "Awan hitam menyembunyikan drone dan artillery spotter. Radar flare jadi kunci.",
			"distance": 1240.0,
			"weather": {"kind": "blackout", "wind": -0.18, "rain": 0.55, "cloud": 0.78, "lightning": 0.35, "visibility": 0.54, "flood": 0.38},
			"boss": "Delta Jammer",
			"hue": 0.68,
			"branches": [
				{"name": "Mangrove Mask", "risk": 0.96, "reward": 1.0, "wind": -0.15, "speed": 0.88, "offset": -120.0, "note": "Banyak awan, sedikit tank."},
				{"name": "Oil Causeway", "risk": 1.18, "reward": 1.22, "wind": 0.05, "speed": 1.04, "offset": 20.0, "note": "Artillery padat."},
				{"name": "Radio Marsh", "risk": 1.36, "reward": 1.45, "wind": 0.24, "speed": 1.12, "offset": 125.0, "note": "Jammer dan drone elite."}
			]
		},
		{
			"name": "Operation Thunder Ridge",
			"codename": "THUNDER RIDGE",
			"brief": "Badai listrik konstan. Lightning rod bisa mengubah bahaya menjadi senjata.",
			"distance": 1360.0,
			"weather": {"kind": "thunderstorm", "wind": 0.32, "rain": 0.48, "cloud": 0.58, "lightning": 0.9, "visibility": 0.62, "flood": 0.12},
			"boss": "Storm Crown",
			"hue": 0.76,
			"branches": [
				{"name": "Grounded Ridge", "risk": 0.98, "reward": 0.96, "wind": -0.1, "speed": 0.9, "offset": -110.0, "note": "Petir lebih aman."},
				{"name": "Copper Vein", "risk": 1.28, "reward": 1.38, "wind": 0.0, "speed": 1.06, "offset": 10.0, "note": "Petir sering, banyak overcharge."},
				{"name": "Sky Needle", "risk": 1.62, "reward": 1.72, "wind": 0.4, "speed": 1.18, "offset": 140.0, "note": "Rute tercepat dan paling berbahaya."}
			]
		},
		{
			"name": "Operation Ash Harbor",
			"codename": "ASH HARBOR",
			"brief": "Abu dan asap industri menutup area. Smoke sendiri bisa jadi cover atau jebakan visibility.",
			"distance": 1480.0,
			"weather": {"kind": "ashfall", "wind": -0.52, "rain": 0.08, "cloud": 0.72, "lightning": 0.25, "visibility": 0.48, "flood": 0.0},
			"boss": "Harbor Siege Walker",
			"hue": 0.03,
			"branches": [
				{"name": "Container Maze", "risk": 1.05, "reward": 1.05, "wind": -0.18, "speed": 0.9, "offset": -130.0, "note": "Cover tinggi, turret padat."},
				{"name": "Crane Avenue", "risk": 1.25, "reward": 1.24, "wind": 0.08, "speed": 1.04, "offset": 0.0, "note": "Artillery beruntun."},
				{"name": "Dry Dock Sprint", "risk": 1.55, "reward": 1.62, "wind": 0.34, "speed": 1.22, "offset": 135.0, "note": "Gunship dan SAM."}
			]
		},
		{
			"name": "Operation Eye of Aegis",
			"codename": "EYE OF AEGIS",
			"brief": "Final escort melewati pusat badai. Semua sistem cuaca dan musuh aktif bersamaan.",
			"distance": 1650.0,
			"weather": {"kind": "supercell", "wind": 0.64, "rain": 0.72, "cloud": 0.82, "lightning": 1.0, "visibility": 0.46, "flood": 0.22},
			"boss": "Aegis Weather Engine",
			"hue": 0.91,
			"branches": [
				{"name": "Quiet Eye", "risk": 1.22, "reward": 1.2, "wind": -0.32, "speed": 0.94, "offset": -120.0, "note": "Lebih terkendali tapi panjang."},
				{"name": "Wall Cloud", "risk": 1.48, "reward": 1.5, "wind": 0.18, "speed": 1.07, "offset": 10.0, "note": "Awan dan drone sangat padat."},
				{"name": "Lightning Gate", "risk": 1.88, "reward": 2.05, "wind": 0.68, "speed": 1.28, "offset": 150.0, "note": "Final high-risk route."}
			]
		}
	]


func make_loadouts() -> Array:
	return [
		{
			"name": "Guardian Relief",
			"role": "Proteksi maksimal untuk stage hujan/fog.",
			"gun": 1.0,
			"armor": 1.15,
			"support": {"repair": 5, "smoke": 4, "supply": 2, "radar": 2, "rod": 1}
		},
		{
			"name": "Storm Harvester",
			"role": "Memanfaatkan petir untuk overcharge dan chain damage.",
			"gun": 1.08,
			"armor": 1.0,
			"support": {"repair": 3, "smoke": 2, "supply": 2, "radar": 2, "rod": 4}
		},
		{
			"name": "Interdiction Wing",
			"role": "Firepower tinggi, support terbatas untuk jalur berisiko.",
			"gun": 1.32,
			"armor": 0.95,
			"support": {"repair": 2, "smoke": 2, "supply": 3, "radar": 1, "rod": 1}
		},
		{
			"name": "Recon Warden",
			"role": "Anti-awan/jammer: radar banyak dan convoy turret sustain.",
			"gun": 0.98,
			"armor": 1.05,
			"support": {"repair": 3, "smoke": 3, "supply": 3, "radar": 5, "rod": 1}
		}
	]


func default_save() -> Dictionary:
	return {
		"stars": 0,
		"best_score": 0,
		"unlocked_stage": 1,
		"campaign_cleared": false,
		"last_loadout": 0,
		"version": 2
	}


func ensure_save_shape() -> void:
	var base = default_save()
	for key in base.keys():
		if not save_data.has(key):
			save_data[key] = base[key]
	save_data["stars"] = max(0, int(save_data.get("stars", 0)))
	save_data["best_score"] = max(0, int(save_data.get("best_score", 0)))
	save_data["unlocked_stage"] = int(clamp(int(save_data.get("unlocked_stage", 1)), 1, MAX_STAGE))
	save_data["last_loadout"] = int(clamp(int(save_data.get("last_loadout", 0)), 0, loadouts.size() - 1))


func apply_loaded_save(data) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	for key in data.keys():
		save_data[key] = data[key]
	ensure_save_shape()


func load_save() -> void:
	var loaded = false
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var bridge = Engine.get_singleton("JavaScriptBridge")
		var raw = bridge.eval("localStorage.getItem('" + SAVE_KEY + "')", true)
		if typeof(raw) == TYPE_STRING and raw != "":
			apply_loaded_save(JSON.parse_string(raw))
			loaded = true
	if not loaded and FileAccess.file_exists(SAVE_PATH):
		var text = FileAccess.get_file_as_string(SAVE_PATH)
		if text != "":
			apply_loaded_save(JSON.parse_string(text))
	ensure_save_shape()


func save_game() -> void:
	ensure_save_shape()
	var text = JSON.stringify(save_data)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		Engine.get_singleton("JavaScriptBridge").eval("localStorage.setItem('" + SAVE_KEY + "', " + JSON.stringify(text) + ");", false)


func init_background() -> void:
	bg_stars.clear()
	for i in range(120):
		bg_stars.append({
			"pos": Vector2(rng.randf_range(0.0, W), rng.randf_range(0.0, H)),
			"speed": rng.randf_range(22.0, 150.0),
			"size": rng.randf_range(1.0, 3.4),
			"phase": rng.randf_range(0.0, TAU)
		})


func update_background(delta: float) -> void:
	var fast = 1.0 if state == GameState.PLAYING else 0.24
	for s in bg_stars:
		var pos = s["pos"]
		pos.y += float(s["speed"]) * fast * delta
		if pos.y > H + 8.0:
			pos.y = -8.0
			pos.x = rng.randf_range(0.0, W)
		s["pos"] = pos


func reset_player() -> void:
	player = {
		"pos": Vector2(W * 0.5, H - 150.0),
		"hp": 120,
		"max_hp": 120,
		"speed": 350.0,
		"shot_cd": 0.0,
		"missile_cd": 0.5,
		"invuln": 1.0
	}


func start_stage(index: int) -> void:
	stage_index = int(clamp(index, 0, stages.size() - 1))
	selected_stage = stage_index
	stage = stages[stage_index]
	loadout = loadouts[selected_loadout]
	save_data["last_loadout"] = selected_loadout
	save_game()
	reset_player()
	player["max_hp"] = int(float(player["max_hp"]) * float(loadout.get("armor", 1.0)))
	player["hp"] = player["max_hp"]

	convoy.clear()
	convoy.append(make_convoy_vehicle("command", "Command Truck", 165, -86.0, -20.0))
	convoy.append(make_convoy_vehicle("fuel", "Fuel Tanker", 135, -28.0, 24.0))
	convoy.append(make_convoy_vehicle("apc", "APC Guardian", 190, 34.0, -28.0))
	convoy.append(make_convoy_vehicle("supply_truck", "Supply Truck", 150, 92.0, 20.0))

	bullets.clear()
	enemy_bullets.clear()
	enemies.clear()
	pickups.clear()
	support_drops.clear()
	effects.clear()
	particles.clear()
	clouds.clear()
	hazards.clear()
	lightning_marks.clear()
	applied_branches.clear()
	branch_pending = false
	branch_checkpoint_index = 0
	branch_choice_index = 1
	branch_timer = 0.0
	route_progress = 0.0
	route_distance = float(stage["distance"])
	route_offset = 0.0
	route_target_offset = 0.0
	route_speed = 36.0 + stage_index * 2.0
	route_speed_mod = 1.0
	stage_threat = 1.0 + stage_index * 0.12
	stage_reward_mod = 1.0
	stage_wind_mod = 0.0
	stage_score = 0
	stage_stars = 0
	kills = 0
	convoy_damage_taken = 0
	civilians_saved = 0
	spawn_timer = 1.0
	wave_index = 0
	boss_spawned = false
	boss_defeated = false
	finish_timer = 0.0
	smoke_timer = 0.0
	radar_timer = 0.0
	overcharge_timer = 0.0
	supply_turret_timer = 0.0
	support_cooldown = 0.0
	lightning_next = max(1.8, 7.0 - weather_value("lightning") * 4.0)
	lightning_timer = lightning_next

	support_counts = {}
	var support = loadout.get("support", {})
	for key in ["repair", "smoke", "supply", "radar", "rod"]:
		support_counts[key] = int(support.get(key, 0))
	spawn_weather_field()
	start_ground_phase()
	js_emit("stage_start", {"stage": stage_index + 1, "name": stage["name"], "loadout": loadout["name"], "weather": stage["weather"], "phase": "ground_chase"})


func make_convoy_vehicle(kind: String, name: String, hp: int, y_offset: float, lane: float) -> Dictionary:
	return {
		"kind": kind,
		"name": name,
		"hp": hp,
		"max_hp": hp,
		"pos": Vector2(W * 0.5 + lane, H - 180.0 + y_offset),
		"y_offset": y_offset,
		"lane": lane,
		"turret_cd": rng.randf_range(0.2, 1.0),
		"alive": true,
		"flash": 0.0
	}


func spawn_weather_field() -> void:
	var cloud_count = int(5 + weather_value("cloud") * 12.0)
	for i in range(cloud_count):
		clouds.append({
			"pos": Vector2(rng.randf_range(80.0, W - 80.0), rng.randf_range(-120.0, H)),
			"radius": rng.randf_range(72.0, 150.0),
			"speed": rng.randf_range(12.0, 54.0),
			"alpha": rng.randf_range(0.18, 0.42),
			"phase": rng.randf_range(0.0, TAU)
		})


func start_ground_phase() -> void:
	cleanup_ground_scene()
	ground_time = 0.0
	ground_distance = 0.0
	ground_player_x = 0.0
	ground_car_max_hp = 120 + stage_index * 12
	ground_car_hp = ground_car_max_hp
	ground_spawn_timer = 0.7
	ground_shot_cd = 0.0
	ground_jet_called = false
	ground_jet_timer = 0.0
	ground_transition_ready = false
	ground_enemies.clear()
	ground_bullets.clear()
	ground_enemy_bullets.clear()
	setup_ground_scene()
	state = GameState.GROUND
	show_warning("GROUND CHASE: drive, shoot, survive until jet link arrives.")
	js_emit("ground_phase", {"stage": stage_index + 1, "mode": "third_person_car_chase"})


func cleanup_ground_scene() -> void:
	if ground_root != null and is_instance_valid(ground_root):
		ground_root.queue_free()
	ground_root = null
	ground_camera = null
	ground_player_node = null
	ground_jet_node = null
	ground_road_markers.clear()
	ground_enemies.clear()
	ground_bullets.clear()
	ground_enemy_bullets.clear()


func setup_ground_scene() -> void:
	ground_root = Node3D.new()
	ground_root.name = "GroundChase3D"
	add_child(ground_root)

	var light = DirectionalLight3D.new()
	light.name = "StormSun"
	light.light_energy = 2.2
	light.rotation_degrees = Vector3(-58.0, -26.0, 0.0)
	ground_root.add_child(light)

	var ambient = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.055, 0.075, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.47, 0.58, 1.0)
	env.ambient_light_energy = 1.25
	ambient.environment = env
	ground_root.add_child(ambient)

	ground_camera = Camera3D.new()
	ground_camera.name = "GroundChaseCamera"
	ground_camera.current = true
	ground_camera.fov = 62.0
	ground_root.add_child(ground_camera)

	# Road and terrain are Godot mesh assets, not background photos.
	var road = make_box_3d(Vector3(0, -0.04, -72), Vector3(9.5, 0.08, 220.0), Color(0.08, 0.085, 0.09, 1.0), "RoadMesh")
	ground_root.add_child(road)
	for side in [-1, 1]:
		var shoulder = make_box_3d(Vector3(side * 6.4, -0.06, -72), Vector3(3.0, 0.08, 220.0), Color(0.11, 0.16, 0.10, 1.0), "WetShoulder")
		ground_root.add_child(shoulder)
	for i in range(22):
		var marker = make_box_3d(Vector3(0, 0.025, -i * 9.5), Vector3(0.22, 0.035, 3.8), Color(1.0, 0.86, 0.3, 1.0), "LaneMarker")
		ground_root.add_child(marker)
		ground_road_markers.append(marker)
	for i in range(18):
		for side in [-1, 1]:
			var rock = make_box_3d(Vector3(side * rng.randf_range(7.5, 11.0), 0.25, -i * 12.0 - rng.randf_range(0.0, 4.0)), Vector3(rng.randf_range(0.6, 1.7), rng.randf_range(0.35, 1.0), rng.randf_range(0.6, 1.8)), Color(0.12, 0.13, 0.12, 1.0), "RoadsideRock")
			ground_root.add_child(rock)

	ground_player_node = spawn_ground_model("res://assets/models/player_car.glb", Vector3(0.0, 0.08, 0.0), 0.0, "PlayerCar")
	# A friendly convoy preview car runs ahead to sell the escort/chase camera before air mode starts.
	spawn_ground_model("res://assets/models/convoy_car.glb", Vector3(-1.8, 0.08, -13.0), 0.0, "ConvoyLead")
	update_ground_camera()


func make_box_3d(pos: Vector3, size: Vector3, color: Color, node_name: String) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	material.metallic = 0.05
	mesh.material = material
	var node = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	return node


func spawn_ground_model(path: String, pos: Vector3, yaw: float, node_name: String) -> Node3D:
	var packed = load(path)
	var node: Node3D
	if packed != null and packed is PackedScene:
		node = packed.instantiate()
	else:
		node = make_box_3d(Vector3.ZERO, Vector3(1.3, 0.55, 2.8), Color(0.2, 0.4, 0.8, 1.0), node_name)
	node.name = node_name
	node.position = pos
	node.rotation.y = yaw
	ground_root.add_child(node)
	return node


func update_ground_chase(delta: float) -> void:
	ground_time += delta
	ground_distance += delta * 36.0
	ground_shot_cd = max(0.0, ground_shot_cd - delta)
	var steer = Input.get_axis("move_left", "move_right")
	if touch_active or pointer_active:
		steer = clamp((pointer_target.x - W * 0.5) / (W * 0.35), -1.0, 1.0)
	ground_player_x = clamp(ground_player_x + steer * 7.2 * delta, -3.4, 3.4)
	if ground_player_node != null:
		ground_player_node.position.x = ground_player_x
		ground_player_node.rotation.z = lerp(ground_player_node.rotation.z, -steer * 0.08, min(1.0, delta * 8.0))
		ground_player_node.rotation.y = lerp(ground_player_node.rotation.y, -steer * 0.05, min(1.0, delta * 5.0))

	for marker in ground_road_markers:
		marker.position.z += delta * 36.0
		if marker.position.z > 8.0:
			marker.position.z -= 210.0

	if ground_shot_cd <= 0.0:
		spawn_ground_bullet(Vector3(ground_player_x, 0.65, -1.8), -52.0, true)
		ground_shot_cd = 0.16

	ground_spawn_timer -= delta
	if ground_spawn_timer <= 0.0 and not ground_jet_called:
		spawn_ground_enemy()
		ground_spawn_timer = rng.randf_range(1.0, 1.8) / max(0.8, stage_threat)

	update_ground_enemies(delta)
	update_ground_bullets(delta)
	update_ground_camera()

	if ground_time > 20.0 and not ground_jet_called:
		call_support_jet()
	if ground_jet_called:
		update_support_jet(delta)
	if ground_car_hp <= 0:
		cleanup_ground_scene()
		game_over("Ground vehicle destroyed")


func update_ground_camera() -> void:
	if ground_camera == null:
		return
	ground_camera.position = Vector3(ground_player_x * 0.45, 4.2, 9.8)
	ground_camera.look_at(Vector3(ground_player_x * 0.25, 0.55, -17.0), Vector3.UP)


func spawn_ground_enemy() -> void:
	var x = rng.randf_range(-3.0, 3.0)
	var z = rng.randf_range(-72.0, -58.0)
	var node = spawn_ground_model("res://assets/models/enemy_car.glb", Vector3(x, 0.08, z), PI, "EnemyCar")
	ground_enemies.append({"node": node, "x": x, "z": z, "hp": 80.0 + stage_index * 18.0, "shoot_cd": rng.randf_range(0.6, 1.5), "drift": rng.randf_range(-0.55, 0.55)})


func spawn_ground_bullet(pos: Vector3, speed_z: float, friendly: bool) -> void:
	var color = Color(0.35, 0.95, 1.0, 1.0) if friendly else Color(1.0, 0.2, 0.08, 1.0)
	var node = make_box_3d(pos, Vector3(0.12, 0.12, 0.55), color, "GroundBullet")
	ground_root.add_child(node)
	var item = {"node": node, "z_speed": speed_z, "friendly": friendly, "life": 2.2}
	if friendly:
		ground_bullets.append(item)
	else:
		ground_enemy_bullets.append(item)


func update_ground_enemies(delta: float) -> void:
	for e in ground_enemies:
		e["z"] = float(e["z"]) + delta * (14.0 + stage_index * 1.2)
		e["x"] = clamp(float(e["x"]) + float(e["drift"]) * delta, -3.5, 3.5)
		e["shoot_cd"] = float(e["shoot_cd"]) - delta
		var node: Node3D = e["node"]
		if node != null and is_instance_valid(node):
			node.position = Vector3(float(e["x"]), 0.08, float(e["z"]))
		if float(e["shoot_cd"]) <= 0.0 and float(e["z"]) < -8.0:
			spawn_ground_bullet(Vector3(float(e["x"]), 0.62, float(e["z"]) + 1.7), 36.0, false)
			e["shoot_cd"] = rng.randf_range(1.0, 1.8)
	for i in range(ground_enemies.size() - 1, -1, -1):
		var e = ground_enemies[i]
		if float(e["z"]) > 3.0:
			if abs(float(e["x"]) - ground_player_x) < 1.1:
				damage_ground_car(22)
			remove_ground_enemy(i)


func update_ground_bullets(delta: float) -> void:
	for b in ground_bullets:
		b["life"] = float(b["life"]) - delta
		var node: Node3D = b["node"]
		if node != null and is_instance_valid(node):
			node.position.z += float(b["z_speed"]) * delta
	for b in ground_enemy_bullets:
		b["life"] = float(b["life"]) - delta
		var node: Node3D = b["node"]
		if node != null and is_instance_valid(node):
			node.position.z += float(b["z_speed"]) * delta
	# Friendly bullet vs enemy cars.
	for bi in range(ground_bullets.size() - 1, -1, -1):
		var b = ground_bullets[bi]
		var bnode: Node3D = b["node"]
		if bnode == null or not is_instance_valid(bnode) or float(b["life"]) <= 0.0 or bnode.position.z < -86.0:
			remove_ground_bullet(ground_bullets, bi)
			continue
		for ei in range(ground_enemies.size() - 1, -1, -1):
			var e = ground_enemies[ei]
			if abs(float(e["x"]) - bnode.position.x) < 0.75 and abs(float(e["z"]) - bnode.position.z) < 1.25:
				e["hp"] = float(e["hp"]) - 34.0
				remove_ground_bullet(ground_bullets, bi)
				if float(e["hp"]) <= 0.0:
					stage_score += 160
					stage_stars += 1
					spawn_particles(Vector2(W * 0.5 + float(e["x"]) * 60.0, H * 0.55), Color(1.0, 0.35, 0.12, 1.0), 20, 180.0)
					remove_ground_enemy(ei)
				break
	# Enemy bullets vs player car.
	for bi in range(ground_enemy_bullets.size() - 1, -1, -1):
		var b = ground_enemy_bullets[bi]
		var bnode: Node3D = b["node"]
		if bnode == null or not is_instance_valid(bnode) or float(b["life"]) <= 0.0 or bnode.position.z > 8.0:
			remove_ground_bullet(ground_enemy_bullets, bi)
			continue
		if bnode.position.z > -0.8 and abs(bnode.position.x - ground_player_x) < 0.7:
			damage_ground_car(10)
			remove_ground_bullet(ground_enemy_bullets, bi)


func remove_ground_enemy(index: int) -> void:
	if index < 0 or index >= ground_enemies.size():
		return
	var node: Node3D = ground_enemies[index].get("node")
	if node != null and is_instance_valid(node):
		node.queue_free()
	ground_enemies.remove_at(index)


func remove_ground_bullet(list: Array, index: int) -> void:
	if index < 0 or index >= list.size():
		return
	var node: Node3D = list[index].get("node")
	if node != null and is_instance_valid(node):
		node.queue_free()
	list.remove_at(index)


func damage_ground_car(amount: int) -> void:
	ground_car_hp = max(0, ground_car_hp - amount)
	weather_flash = max(weather_flash, 0.25)
	show_warning("CAR HIT — keep the chase alive until air support arrives")


func call_support_jet() -> void:
	ground_jet_called = true
	ground_jet_timer = 0.0
	ground_jet_node = spawn_ground_model("res://assets/models/support_jet.glb", Vector3(0.0, 7.2, 16.0), 0.0, "SupportJet")
	show_warning("JET SUPPORT INBOUND — prepare direct switch to aircraft")
	js_emit("support_jet_inbound", {"stage": stage_index + 1})


func update_support_jet(delta: float) -> void:
	ground_jet_timer += delta
	if ground_jet_node != null and is_instance_valid(ground_jet_node):
		var t = clamp(ground_jet_timer / 4.0, 0.0, 1.0)
		ground_jet_node.position = Vector3(sin(time * 1.8) * 0.7, lerp(7.2, 2.8, t), lerp(16.0, -18.0, t))
		ground_jet_node.rotation.z = sin(time * 3.0) * 0.08
	if ground_jet_timer > 2.2 and not ground_transition_ready:
		ground_transition_ready = true
		show_warning("JET LINK READY — press SPACE/ENTER to switch into Sky Force mode")
		js_emit("air_switch_ready", {})
	if ground_jet_timer > 8.0:
		enter_air_phase()


func enter_air_phase() -> void:
	if state != GameState.GROUND:
		return
	stage_score += 600 + int(ground_car_hp * 4)
	stage_stars += 8 + int(ground_car_hp / 25)
	cleanup_ground_scene()
	reset_player()
	player["max_hp"] = int(float(player["max_hp"]) * float(loadout.get("armor", 1.0)))
	player["hp"] = player["max_hp"]
	state = GameState.PLAYING
	show_warning("AIRCRAFT SWITCH COMPLETE: Sky Force escort mode engaged")
	js_emit("air_phase_start", {"score": stage_score, "stars": stage_stars})


func update_playing(delta: float) -> void:
	support_cooldown = max(0.0, support_cooldown - delta)
	smoke_timer = max(0.0, smoke_timer - delta)
	radar_timer = max(0.0, radar_timer - delta)
	overcharge_timer = max(0.0, overcharge_timer - delta)
	supply_turret_timer = max(0.0, supply_turret_timer - delta)
	route_offset = lerp(route_offset, route_target_offset, min(1.0, delta * 1.2))
	update_player(delta)
	update_weather(delta)
	update_route_and_convoy(delta)
	update_branching(delta)
	update_spawning(delta)
	update_enemies(delta)
	update_bullets(delta)
	update_enemy_bullets(delta)
	update_support_drops(delta)
	update_effects(delta)
	update_hazards(delta)
	update_convoy_turrets(delta)
	update_particles(delta)
	check_collisions()
	if convoy_total_hp() <= 0:
		game_over("Convoy destroyed")
	elif int(player.get("hp", 0)) <= 0:
		game_over("Aircraft lost")
	elif route_progress >= route_distance and (boss_defeated or not boss_spawned):
		complete_stage()
	elif boss_defeated:
		finish_timer -= delta
		if finish_timer <= 0.0:
			complete_stage()


func update_player(delta: float) -> void:
	var pos = player["pos"]
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_active or pointer_active:
		var to_target = pointer_target - pos
		if to_target.length() > 10.0:
			direction = to_target.normalized()
	pos += direction * float(player["speed"]) * delta
	pos.x = clamp(pos.x, 35.0, W - 35.0)
	pos.y = clamp(pos.y, 98.0, H - 72.0)
	player["pos"] = pos
	player["shot_cd"] = max(0.0, float(player["shot_cd"]) - delta)
	player["missile_cd"] = max(0.0, float(player["missile_cd"]) - delta)
	player["invuln"] = max(0.0, float(player["invuln"]) - delta)
	if float(player["shot_cd"]) <= 0.0:
		fire_player_shot()
	if float(player["missile_cd"]) <= 0.0 and (selected_loadout == 2 or overcharge_timer > 0.0):
		fire_micro_missile()


func fire_player_shot() -> void:
	var pos = player["pos"]
	var gun_mod = float(loadout.get("gun", 1.0))
	if overcharge_timer > 0.0:
		gun_mod *= 1.65
	var lanes = 2 if gun_mod < 1.2 else 3
	if overcharge_timer > 0.0:
		lanes += 2
	var spread = 0.13 + (lanes - 2) * 0.035
	for i in range(lanes):
		var t = 0.0 if lanes == 1 else float(i) / float(lanes - 1) - 0.5
		var angle = t * spread
		var vel = Vector2(sin(angle), -cos(angle)) * (760.0 + gun_mod * 60.0)
		bullets.append({"pos": pos + Vector2(t * 30.0, -30.0), "vel": vel, "damage": 12.0 * gun_mod, "radius": 5.0, "life": 1.6, "kind": "plasma"})
	player["shot_cd"] = max(0.065, 0.15 / gun_mod)


func fire_micro_missile() -> void:
	var target = nearest_enemy(player["pos"])
	if target.is_empty():
		player["missile_cd"] = 1.0
		return
	var pos = player["pos"]
	for side in [-1, 1]:
		bullets.append({"pos": pos + Vector2(side * 24.0, -5.0), "vel": Vector2(side * 70.0, -430.0), "damage": 38.0, "radius": 8.0, "life": 4.0, "kind": "missile", "target_id": int(target.get("id", -1))})
	player["missile_cd"] = 2.4 if overcharge_timer <= 0.0 else 1.15


func update_route_and_convoy(delta: float) -> void:
	var flood = weather_value("flood")
	var speed_factor = route_speed_mod
	if is_convoy_in_flood():
		speed_factor *= max(0.62, 1.0 - flood * 0.38)
		smoke_timer = max(0.0, smoke_timer - delta * 0.2)
	var alive_ratio = float(convoy_alive_count()) / max(1.0, float(convoy.size()))
	route_progress += route_speed * speed_factor * (0.55 + alive_ratio * 0.45) * delta
	for i in range(convoy.size()):
		var v = convoy[i]
		var base_y = H - 118.0 + float(v["y_offset"])
		var x = route_x_for_progress(route_progress - float(i) * 23.0) + float(v["lane"])
		v["pos"] = Vector2(clamp(x, 70.0, W - 70.0), base_y)
		v["flash"] = max(0.0, float(v.get("flash", 0.0)) - delta * 5.0)


func route_x_for_progress(progress: float) -> float:
	var curve = sin(progress * 0.012 + stage_index * 0.4) * 64.0 + sin(progress * 0.003) * 45.0
	return W * 0.5 + route_offset + curve


func route_x_for_y(y: float) -> float:
	var ahead = route_progress + (H - y) * 0.85
	return route_x_for_progress(ahead)


func update_branching(delta: float) -> void:
	var checkpoints = [0.31, 0.62]
	if branch_pending:
		branch_timer -= delta
		if branch_timer <= 0.0:
			apply_branch_choice(branch_choice_index)
		return
	if branch_checkpoint_index < checkpoints.size():
		var ratio = route_progress / route_distance
		if ratio >= checkpoints[branch_checkpoint_index]:
			branch_pending = true
			branch_choice_index = 1
			branch_timer = 9.0
			show_warning("ROUTE SPLIT: choose a branch with ←/→ then ENTER")
			js_emit("route_split", {"checkpoint": branch_checkpoint_index + 1, "choices": stage["branches"]})


func apply_branch_choice(index: int) -> void:
	if not branch_pending:
		return
	var branches = stage["branches"]
	index = int(clamp(index, 0, branches.size() - 1))
	var b = branches[index]
	applied_branches.append(b["name"])
	stage_threat *= float(b.get("risk", 1.0))
	stage_reward_mod *= float(b.get("reward", 1.0))
	stage_wind_mod += float(b.get("wind", 0.0))
	route_speed_mod *= float(b.get("speed", 1.0))
	route_target_offset = clamp(route_target_offset + float(b.get("offset", 0.0)), -210.0, 210.0)
	branch_pending = false
	branch_checkpoint_index += 1
	show_warning("ROUTE SELECTED: " + str(b["name"]) + " — " + str(b["note"]))
	js_emit("route_selected", {"name": b["name"], "risk": b["risk"], "reward": b["reward"]})


func update_spawning(delta: float) -> void:
	if route_progress > route_distance * 0.78 and not boss_spawned:
		spawn_boss()
	spawn_timer -= delta
	if spawn_timer <= 0.0 and not boss_defeated:
		spawn_wave()
		var base = max(1.0, 3.4 - stage_index * 0.18 - route_progress / route_distance)
		spawn_timer = base / max(0.65, stage_threat)


func spawn_wave() -> void:
	wave_index += 1
	var pattern = wave_index % 8
	var progress_ratio = route_progress / route_distance
	match pattern:
		0:
			for i in range(3 + stage_index):
				spawn_enemy("interceptor", Vector2(100.0 + i * 120.0, -50.0 - i * 24.0))
		1:
			for i in range(2 + int(stage_index / 2)):
				spawn_enemy("bomber", Vector2(rng.randf_range(90.0, W - 90.0), -70.0 - i * 90.0))
		2:
			spawn_enemy("tank", Vector2(-70.0, rng.randf_range(180.0, 520.0)))
			spawn_enemy("tank", Vector2(W + 70.0, rng.randf_range(180.0, 520.0)))
		3:
			spawn_enemy("sam", Vector2(rng.randf_range(70.0, W - 70.0), -70.0))
			for i in range(2):
				spawn_enemy("interceptor", Vector2(rng.randf_range(80.0, W - 80.0), -140.0 - i * 60.0))
		4:
			spawn_enemy("artillery", Vector2(-85.0 if rng.randf() < 0.5 else W + 85.0, rng.randf_range(110.0, 380.0)))
		5:
			for i in range(2 + stage_index):
				spawn_enemy("drone", Vector2(rng.randf_range(80.0, W - 80.0), -60.0 - i * 58.0))
		6:
			spawn_enemy("gunship", Vector2(W * 0.5, -90.0))
			spawn_enemy("bomber", Vector2(150.0, -180.0))
			spawn_enemy("bomber", Vector2(W - 150.0, -220.0))
		7:
			spawn_enemy("mine_layer", Vector2(rng.randf_range(120.0, W - 120.0), -70.0))
	if progress_ratio > 0.5 and rng.randf() < 0.33 + stage_index * 0.04:
		spawn_enemy("artillery", Vector2(W + 90.0, rng.randf_range(130.0, 360.0)))


func spawn_enemy(kind: String, pos: Vector2) -> void:
	var id = int(Time.get_ticks_msec()) + enemies.size() * 37 + rng.randi_range(0, 9999)
	var e = {"id": id, "kind": kind, "pos": pos, "vel": Vector2.ZERO, "hp": 30.0, "max_hp": 30.0, "radius": 18.0, "shoot_cd": rng.randf_range(0.6, 1.8), "t": 0.0, "score": 120, "ground": false, "flash": 0.0}
	var diff = 1.0 + stage_index * 0.16 + route_progress / route_distance * 0.45
	match kind:
		"interceptor":
			e["hp"] = 28.0 * diff
			e["vel"] = Vector2(0.0, 180.0 + stage_index * 12.0)
			e["radius"] = 18.0
			e["score"] = 140
		"bomber":
			e["hp"] = 72.0 * diff
			e["vel"] = Vector2(0.0, 118.0 + stage_index * 8.0)
			e["radius"] = 28.0
			e["score"] = 320
		"gunship":
			e["hp"] = 165.0 * diff
			e["vel"] = Vector2(0.0, 74.0)
			e["radius"] = 38.0
			e["score"] = 620
		"drone":
			e["hp"] = 36.0 * diff
			e["vel"] = Vector2(0.0, 135.0)
			e["radius"] = 19.0
			e["score"] = 180
		"tank":
			e["hp"] = 88.0 * diff
			e["vel"] = Vector2(72.0 if pos.x < 0 else -72.0, 42.0)
			e["radius"] = 26.0
			e["score"] = 260
			e["ground"] = true
		"sam":
			e["hp"] = 70.0 * diff
			e["vel"] = Vector2(0.0, 64.0)
			e["radius"] = 25.0
			e["score"] = 360
			e["ground"] = true
		"artillery":
			e["hp"] = 96.0 * diff
			e["vel"] = Vector2(55.0 if pos.x < 0 else -55.0, 22.0)
			e["radius"] = 30.0
			e["score"] = 430
			e["ground"] = true
		"mine_layer":
			e["hp"] = 78.0 * diff
			e["vel"] = Vector2(0.0, 108.0)
			e["radius"] = 24.0
			e["score"] = 300
			e["ground"] = true
		"boss":
			e["hp"] = 1100.0 + stage_index * 380.0
			e["vel"] = Vector2.ZERO
			e["radius"] = 92.0
			e["score"] = 5000 + stage_index * 1200
	e["max_hp"] = e["hp"]
	enemies.append(e)


func spawn_boss() -> void:
	boss_spawned = true
	spawn_enemy("boss", Vector2(W * 0.5, -140.0))
	show_warning("BLOCKADE AHEAD: " + str(stage["boss"]) + " must be neutralized.")
	js_emit("boss_incoming", {"boss": stage["boss"]})


func update_enemies(delta: float) -> void:
	for e in enemies:
		e["t"] = float(e["t"]) + delta
		e["shoot_cd"] = float(e["shoot_cd"]) - delta
		e["flash"] = max(0.0, float(e.get("flash", 0.0)) - delta * 5.0)
		var kind = str(e["kind"])
		var pos = e["pos"]
		var vel = e["vel"]
		var t = float(e["t"])
		match kind:
			"interceptor":
				pos += vel * delta
				pos.x += sin(t * 3.1 + float(e["id"]) * 0.01) * 80.0 * delta
				if float(e["shoot_cd"]) <= 0.0 and pos.y > 30.0 and pos.y < H - 160.0:
					shoot_at_player(pos, 260.0 + stage_index * 15.0, 13.0)
					e["shoot_cd"] = rng.randf_range(1.0, 1.8)
			"bomber":
				var cpos = convoy_center()
				var desired = (cpos - pos).normalized() * (125.0 + stage_index * 8.0)
				vel = vel.lerp(desired, min(1.0, delta * 0.8))
				pos += vel * delta
				if float(e["shoot_cd"]) <= 0.0 and pos.y > 70.0:
					drop_bomb(pos, cpos)
					e["shoot_cd"] = rng.randf_range(1.5, 2.5)
			"gunship":
				if pos.y < 165.0:
					pos += vel * delta
				else:
					pos.x = W * 0.5 + sin(time * 0.8 + e["id"] * 0.01) * 210.0
				if float(e["shoot_cd"]) <= 0.0 and pos.y > 70.0:
					shoot_spread_at_convoy(pos, 5, 0.75, 215.0, 18.0)
					e["shoot_cd"] = rng.randf_range(1.4, 2.0)
			"drone":
				pos += vel * delta
				pos.x += sin(t * 2.4) * 60.0 * delta
				if float(e["shoot_cd"]) <= 0.0 and pos.y > 60.0:
					shoot_at_convoy(pos, 240.0, 12.0, Color(0.65, 0.95, 1.0, 1.0), true)
					e["shoot_cd"] = rng.randf_range(1.0, 1.6)
			"tank":
				pos += vel * delta
				if abs(pos.x - route_x_for_y(pos.y)) < ROAD_WIDTH * 0.8:
					vel.x *= 0.96
				if float(e["shoot_cd"]) <= 0.0:
					shoot_at_convoy(pos, 225.0, 22.0, Color(1.0, 0.55, 0.2, 1.0))
					e["shoot_cd"] = rng.randf_range(1.7, 2.6)
			"sam":
				pos += vel * delta
				if float(e["shoot_cd"]) <= 0.0 and pos.y > 20.0:
					shoot_at_player(pos, 330.0, 20.0, Color(1.0, 0.24, 0.18, 1.0), true)
					e["shoot_cd"] = rng.randf_range(2.0, 3.0)
			"artillery":
				pos += vel * delta
				if float(e["shoot_cd"]) <= 0.0:
					spawn_artillery_marker()
					e["shoot_cd"] = rng.randf_range(2.4, 3.6)
			"mine_layer":
				pos += vel * delta
				pos.x += sin(t * 2.0) * 48.0 * delta
				if float(e["shoot_cd"]) <= 0.0:
					hazards.append({"kind": "mine", "pos": Vector2(route_x_for_y(H - 160.0) + rng.randf_range(-42.0, 42.0), H - 165.0), "radius": 26.0, "timer": 7.0, "armed": true})
					e["shoot_cd"] = rng.randf_range(1.6, 2.6)
			"boss":
				if pos.y < 150.0:
					pos.y += 70.0 * delta
				else:
					pos.x = W * 0.5 + sin(time * 0.65) * 155.0
					pos.y = 150.0 + sin(time * 1.2) * 18.0
				if float(e["shoot_cd"]) <= 0.0 and pos.y > 120.0:
					boss_attack(pos)
					e["shoot_cd"] = max(0.5, 1.15 - stage_index * 0.07)
		e["pos"] = pos
		e["vel"] = vel
	for i in range(enemies.size() - 1, -1, -1):
		var p = enemies[i]["pos"]
		if p.y > H + 130.0 or p.x < -190.0 or p.x > W + 190.0:
			enemies.remove_at(i)


func shoot_at_player(origin: Vector2, speed: float, damage: float, color: Color = Color(1.0, 0.35, 0.22, 1.0), guided: bool = false) -> void:
	var dir = (player["pos"] - origin).normalized()
	enemy_bullets.append({"pos": origin, "vel": dir * speed, "damage": damage, "radius": 6.0, "target": "player", "color": color, "life": 5.0, "guided": guided})


func shoot_at_convoy(origin: Vector2, speed: float, damage: float, color: Color = Color(1.0, 0.65, 0.25, 1.0), guided: bool = false) -> void:
	var target = convoy_center()
	var dir = (target - origin).normalized()
	enemy_bullets.append({"pos": origin, "vel": dir * speed, "damage": damage, "radius": 7.0, "target": "convoy", "color": color, "life": 5.0, "guided": guided})


func shoot_spread_at_convoy(origin: Vector2, count: int, spread: float, speed: float, damage: float) -> void:
	var base = (convoy_center() - origin).angle()
	for i in range(count):
		var t = 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var a = base + t * spread
		enemy_bullets.append({"pos": origin, "vel": Vector2(cos(a), sin(a)) * speed, "damage": damage, "radius": 6.0, "target": "convoy", "color": Color(1.0, 0.28, 0.38, 1.0), "life": 5.0, "guided": false})


func drop_bomb(origin: Vector2, target: Vector2) -> void:
	hazards.append({"kind": "bomb", "pos": target + Vector2(rng.randf_range(-55.0, 55.0), rng.randf_range(-35.0, 35.0)), "from": origin, "radius": 54.0, "timer": 1.45, "armed": false, "damage": 32.0})


func boss_attack(pos: Vector2) -> void:
	var phase = int(floor(time * 1.4)) % 4
	if phase == 0:
		shoot_spread_at_convoy(pos + Vector2(0, 52), 9, 1.25, 245.0 + stage_index * 12.0, 18.0)
	elif phase == 1:
		for side in [-1, 1]:
			shoot_at_player(pos + Vector2(side * 70.0, 20.0), 340.0, 22.0, Color(1.0, 0.3, 0.18, 1.0), true)
	elif phase == 2:
		spawn_artillery_marker(3)
	else:
		for i in range(3):
			spawn_enemy("drone", pos + Vector2(-80.0 + i * 80.0, 40.0))


func spawn_artillery_marker(count: int = 1) -> void:
	for i in range(count):
		var target = convoy_center() + Vector2(rng.randf_range(-95.0, 95.0), rng.randf_range(-70.0, 45.0))
		hazards.append({"kind": "artillery", "pos": target, "radius": 62.0, "timer": 1.8 + i * 0.25, "armed": false, "damage": 42.0})


func update_bullets(delta: float) -> void:
	var wind = current_wind()
	for b in bullets:
		if str(b.get("kind", "")) == "missile":
			var target = nearest_enemy(b["pos"])
			if not target.is_empty():
				var desired = (target["pos"] - b["pos"]).normalized() * 560.0
				b["vel"] = b["vel"].lerp(desired, min(1.0, delta * 5.5))
		else:
			b["vel"].x += wind * 100.0 * delta
		b["pos"] = b["pos"] + b["vel"] * delta
		b["life"] = float(b.get("life", 2.0)) - delta
	for i in range(bullets.size() - 1, -1, -1):
		var p = bullets[i]["pos"]
		if p.y < -70.0 or p.y > H + 90.0 or p.x < -100.0 or p.x > W + 100.0 or float(bullets[i].get("life", 0.0)) <= 0.0:
			bullets.remove_at(i)


func update_enemy_bullets(delta: float) -> void:
	var wind = current_wind()
	for b in enemy_bullets:
		if bool(b.get("guided", false)):
			var target = player["pos"] if str(b.get("target", "")) == "player" else convoy_center()
			var desired = (target - b["pos"]).normalized() * max(220.0, b["vel"].length())
			b["vel"] = b["vel"].lerp(desired, min(1.0, delta * 1.7))
		else:
			b["vel"].x += wind * 72.0 * delta
		b["pos"] = b["pos"] + b["vel"] * delta
		b["life"] = float(b.get("life", 5.0)) - delta
	for i in range(enemy_bullets.size() - 1, -1, -1):
		var p = enemy_bullets[i]["pos"]
		if p.y > H + 80.0 or p.y < -120.0 or p.x < -130.0 or p.x > W + 130.0 or float(enemy_bullets[i].get("life", 0.0)) <= 0.0:
			enemy_bullets.remove_at(i)


func update_support_drops(delta: float) -> void:
	for d in support_drops:
		d["pos"] = d["pos"] + d["vel"] * delta
		d["vel"] = d["vel"].lerp(Vector2(0.0, 300.0), min(1.0, delta * 1.6))
		d["life"] = float(d["life"]) - delta
		if Vector2(d["pos"]).y > H - 250.0:
			resolve_support_drop(d)
			d["life"] = -1.0
	for i in range(support_drops.size() - 1, -1, -1):
		if float(support_drops[i].get("life", 0.0)) <= 0.0:
			support_drops.remove_at(i)


func drop_support(kind: String) -> void:
	if support_cooldown > 0.0:
		return
	if int(support_counts.get(kind, 0)) <= 0:
		show_warning(kind.to_upper() + " depleted")
		return
	support_counts[kind] = int(support_counts[kind]) - 1
	support_cooldown = 0.35
	var pos = player["pos"] + Vector2(0.0, 20.0)
	support_drops.append({"kind": kind, "pos": pos, "vel": Vector2(current_wind() * 120.0, 130.0), "life": 3.0, "radius": 18.0})
	show_warning("Dropped " + kind.capitalize() + " pod")
	js_emit("support_drop", {"kind": kind, "remaining": support_counts[kind]})


func resolve_support_drop(d: Dictionary) -> void:
	var kind = str(d["kind"])
	var pos = d["pos"]
	match kind:
		"repair":
			var v = nearest_convoy_vehicle(pos, true)
			if not v.is_empty():
				v["hp"] = min(int(v["max_hp"]), int(v["hp"]) + 72)
				v["flash"] = 1.0
				stage_score += 280
				spawn_particles(v["pos"], Color(0.3, 1.0, 0.45, 1.0), 24, 210.0)
		"smoke":
			effects.append({"kind": "smoke", "pos": Vector2(pos.x, H - 175.0), "radius": 125.0, "life": 8.0, "max_life": 8.0})
			smoke_timer = max(smoke_timer, 8.0)
			stage_score += 120
		"supply":
			supply_turret_timer = max(supply_turret_timer, 12.0)
			stage_score += 240
			spawn_particles(convoy_center(), Color(1.0, 0.85, 0.28, 1.0), 26, 220.0)
		"radar":
			radar_timer = max(radar_timer, 11.0)
			stage_score += 180
			effects.append({"kind": "radar", "pos": pos, "radius": 40.0, "life": 1.2, "max_life": 1.2})
		"rod":
			effects.append({"kind": "rod", "pos": Vector2(pos.x, H - 225.0), "radius": 58.0, "life": 10.0, "max_life": 10.0})
			stage_score += 160
	spawn_particles(pos, Color(0.75, 0.9, 1.0, 1.0), 16, 180.0)


func update_effects(delta: float) -> void:
	for e in effects:
		e["life"] = float(e["life"]) - delta
		if str(e.get("kind", "")) == "smoke":
			e["pos"] = e["pos"] + Vector2(current_wind() * 24.0, -8.0) * delta
			e["radius"] = float(e["radius"]) + delta * 6.0
		elif str(e.get("kind", "")) == "radar":
			e["radius"] = float(e["radius"]) + delta * 540.0
	for i in range(effects.size() - 1, -1, -1):
		if float(effects[i].get("life", 0.0)) <= 0.0:
			effects.remove_at(i)


func update_hazards(delta: float) -> void:
	for h in hazards:
		h["timer"] = float(h["timer"]) - delta
		if str(h["kind"]) == "mine":
			h["pos"] = h["pos"] + Vector2(0.0, 48.0) * delta
		if float(h["timer"]) <= 0.0 and not bool(h.get("triggered", false)):
			trigger_hazard(h)
			h["triggered"] = true
	for i in range(hazards.size() - 1, -1, -1):
		if bool(hazards[i].get("triggered", false)) or Vector2(hazards[i]["pos"]).y > H + 80.0:
			hazards.remove_at(i)


func trigger_hazard(h: Dictionary) -> void:
	var kind = str(h["kind"])
	var pos = h["pos"]
	var radius = float(h.get("radius", 50.0))
	var damage = float(h.get("damage", 35.0))
	spawn_particles(pos, Color(1.0, 0.45, 0.1, 1.0), 44, 380.0)
	if kind == "artillery" or kind == "bomb" or kind == "mine":
		for v in convoy:
			if bool(v.get("alive", true)) and Vector2(v["pos"]).distance_to(pos) < radius + CONVOY_RADIUS:
				damage_convoy(damage, pos, kind)
		if player["pos"].distance_to(pos) < radius:
			damage_player(damage * 0.65)


func update_convoy_turrets(delta: float) -> void:
	if supply_turret_timer <= 0.0:
		return
	for v in convoy:
		if not bool(v.get("alive", true)):
			continue
		if str(v["kind"]) != "apc" and rng.randf() > 0.35:
			continue
		v["turret_cd"] = float(v.get("turret_cd", 0.0)) - delta
		if float(v["turret_cd"]) <= 0.0:
			var target = nearest_enemy(v["pos"])
			if not target.is_empty() and Vector2(target["pos"]).y < H - 120.0:
				var dir = (target["pos"] - v["pos"]).normalized()
				bullets.append({"pos": v["pos"] + Vector2(0.0, -18.0), "vel": dir * 520.0, "damage": 13.0, "radius": 4.0, "life": 1.6, "kind": "aa"})
				v["turret_cd"] = 0.22


func update_weather(delta: float) -> void:
	for c in clouds:
		var pos = c["pos"]
		pos.y += float(c["speed"]) * delta
		pos.x += current_wind() * 18.0 * delta + sin(time * 0.5 + float(c["phase"])) * 8.0 * delta
		if pos.y > H + float(c["radius"]):
			pos.y = -float(c["radius"])
			pos.x = rng.randf_range(70.0, W - 70.0)
		c["pos"] = pos
	lightning_timer -= delta
	if weather_value("lightning") > 0.05 and lightning_timer <= 0.0:
		strike_lightning()
		lightning_timer = rng.randf_range(2.2, 7.0) / max(0.35, weather_value("lightning") + 0.25)


func strike_lightning() -> void:
	var target = Vector2(rng.randf_range(70.0, W - 70.0), rng.randf_range(120.0, H - 190.0))
	for e in effects:
		if str(e.get("kind", "")) == "rod":
			target = e["pos"]
			break
	lightning_marks.append({"pos": target, "life": 0.28, "max_life": 0.28})
	weather_flash = 1.0
	spawn_particles(target, Color(0.75, 0.88, 1.0, 1.0), 34, 460.0)
	var hit_enemy = false
	for i in range(enemies.size() - 1, -1, -1):
		var e = enemies[i]
		var dist = Vector2(e["pos"]).distance_to(target)
		if dist < 105.0:
			e["hp"] = float(e["hp"]) - (210.0 * (1.0 - dist / 105.0) + 40.0)
			e["flash"] = 1.0
			hit_enemy = true
			if float(e["hp"]) <= 0.0:
				kill_enemy_at(i)
	if player["pos"].distance_to(target) < 130.0 and not hit_enemy:
		overcharge_timer = max(overcharge_timer, 8.0)
		show_warning("LIGHTNING OVERCHARGE: weapons boosted")
	for v in convoy:
		if Vector2(v["pos"]).distance_to(target) < 90.0:
			damage_convoy(18.0, target, "lightning")
	js_emit("lightning", {"x": target.x, "y": target.y, "overcharge": overcharge_timer})


func check_collisions() -> void:
	for bi in range(bullets.size() - 1, -1, -1):
		if bi >= bullets.size():
			continue
		var b = bullets[bi]
		var hit = false
		for ei in range(enemies.size() - 1, -1, -1):
			if ei >= enemies.size():
				continue
			var e = enemies[ei]
			if Vector2(b["pos"]).distance_to(e["pos"]) <= float(e["radius"]) + float(b["radius"]):
				e["hp"] = float(e["hp"]) - float(b["damage"])
				e["flash"] = 1.0
				hit = true
				if str(b.get("kind", "")) == "missile":
					spawn_particles(b["pos"], Color(1.0, 0.55, 0.16, 1.0), 22, 260.0)
					for splash in enemies:
						if splash != e and Vector2(splash["pos"]).distance_to(b["pos"]) < 70.0:
							splash["hp"] = float(splash["hp"]) - float(b["damage"]) * 0.35
				if float(e["hp"]) <= 0.0:
					kill_enemy_at(ei)
				break
		if hit and bi < bullets.size():
			bullets.remove_at(bi)

	for i in range(enemy_bullets.size() - 1, -1, -1):
		var b = enemy_bullets[i]
		if str(b.get("target", "")) == "player":
			if player["pos"].distance_to(b["pos"]) <= PLAYER_RADIUS + float(b["radius"]):
				damage_player(float(b["damage"]))
				enemy_bullets.remove_at(i)
		else:
			var v = nearest_convoy_vehicle(b["pos"], true)
			if not v.is_empty() and Vector2(v["pos"]).distance_to(b["pos"]) <= CONVOY_RADIUS + float(b["radius"]):
				var dmg = float(b["damage"])
				if is_smoke_covering(v["pos"]):
					dmg *= 0.35
					display_miss(v["pos"])
				damage_convoy(dmg, b["pos"], "incoming_fire")
				enemy_bullets.remove_at(i)

	for h in hazards:
		if str(h["kind"]) == "mine" and not bool(h.get("triggered", false)):
			for v in convoy:
				if bool(v.get("alive", true)) and Vector2(v["pos"]).distance_to(h["pos"]) < float(h["radius"]) + CONVOY_RADIUS:
					trigger_hazard(h)
					h["triggered"] = true
					break

	for i in range(enemies.size() - 1, -1, -1):
		if i >= enemies.size():
			continue
		var e = enemies[i]
		var kind = str(e["kind"])
		if kind == "boss":
			continue
		var v = nearest_convoy_vehicle(e["pos"], true)
		if not v.is_empty() and Vector2(v["pos"]).distance_to(e["pos"]) < float(e["radius"]) + CONVOY_RADIUS * 0.8:
			damage_convoy(24.0 if kind != "bomber" else 48.0, e["pos"], "collision")
			e["hp"] = 0.0
			kill_enemy_at(i)
		elif player["pos"].distance_to(e["pos"]) < float(e["radius"]) + PLAYER_RADIUS and not bool(e.get("ground", false)):
			damage_player(24.0)
			e["hp"] = 0.0
			kill_enemy_at(i)


func kill_enemy_at(index: int) -> void:
	if index < 0 or index >= enemies.size():
		return
	var e = enemies[index]
	var pos = e["pos"]
	var kind = str(e["kind"])
	var score = int(float(e.get("score", 100)) * stage_reward_mod)
	stage_score += score
	stage_stars += max(1, int(score / 110))
	kills += 1
	spawn_particles(pos, enemy_color(kind), 22 if kind != "boss" else 110, 300.0 if kind != "boss" else 620.0)
	enemies.remove_at(index)
	if kind == "boss":
		boss_defeated = true
		finish_timer = 2.5
		stage_score += int(4000 * stage_reward_mod)
		stage_stars += int(80 * stage_reward_mod)
		show_warning("BLOCKADE DOWN: convoy pushing to extraction")
		js_emit("boss_down", {"score": stage_score})


func damage_player(amount: float) -> void:
	if float(player.get("invuln", 0.0)) > 0.0:
		return
	player["hp"] = int(player["hp"]) - int(amount)
	player["invuln"] = 0.9
	spawn_particles(player["pos"], Color(1.0, 0.2, 0.13, 1.0), 26, 280.0)


func damage_convoy(amount: float, source: Vector2, reason: String) -> void:
	var v = nearest_convoy_vehicle(source, true)
	if v.is_empty():
		return
	var reduced = amount
	if smoke_timer > 0.0 and is_smoke_covering(v["pos"]):
		reduced *= 0.45
	v["hp"] = int(v["hp"]) - int(reduced)
	v["flash"] = 1.0
	convoy_damage_taken += int(reduced)
	spawn_particles(v["pos"], Color(1.0, 0.36, 0.12, 1.0), 16, 190.0)
	if int(v["hp"]) <= 0 and bool(v.get("alive", true)):
		v["alive"] = false
		v["hp"] = 0
		spawn_particles(v["pos"], Color(1.0, 0.22, 0.06, 1.0), 60, 430.0)
		show_warning(str(v["name"]) + " destroyed!")
		js_emit("convoy_vehicle_destroyed", {"vehicle": v["name"], "reason": reason})


func complete_stage() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.STAGE_CLEAR
	var convoy_bonus = int(convoy_total_hp() * 6.0)
	var support_bonus = int((support_counts.get("repair", 0) + support_counts.get("smoke", 0) + support_counts.get("supply", 0)) * 60)
	var route_bonus = int(stage_reward_mod * 450.0)
	var clear_stars = int(60 + stage_index * 25 + convoy_bonus / 25 + route_bonus / 20)
	stage_score += convoy_bonus + support_bonus + route_bonus
	stage_stars += clear_stars
	save_data["stars"] = int(save_data.get("stars", 0)) + stage_stars
	if stage_score > int(save_data.get("best_score", 0)):
		save_data["best_score"] = stage_score
	if stage_index + 1 >= int(save_data.get("unlocked_stage", 1)) and int(save_data.get("unlocked_stage", 1)) < stages.size():
		save_data["unlocked_stage"] = int(save_data.get("unlocked_stage", 1)) + 1
	if stage_index == stages.size() - 1:
		save_data["campaign_cleared"] = true
	save_game()
	js_emit("stage_clear", {"stage": stage_index + 1, "score": stage_score, "stars": stage_stars, "convoy_hp": convoy_total_hp(), "branches": applied_branches})


func game_over(reason: String) -> void:
	if state == GameState.GAME_OVER:
		return
	state = GameState.GAME_OVER
	stage_stars = int(stage_stars * 0.35)
	save_data["stars"] = int(save_data.get("stars", 0)) + stage_stars
	if stage_score > int(save_data.get("best_score", 0)):
		save_data["best_score"] = stage_score
	save_game()
	spawn_particles(convoy_center(), Color(1.0, 0.2, 0.08, 1.0), 80, 500.0)
	show_warning(reason)
	js_emit("game_over", {"reason": reason, "score": stage_score, "stars": stage_stars})


func weather_value(key: String) -> float:
	if stage.is_empty() or not stage.has("weather"):
		return 0.0
	return float(stage["weather"].get(key, 0.0))


func current_wind() -> float:
	return weather_value("wind") + stage_wind_mod


func is_convoy_in_flood() -> bool:
	return weather_value("flood") > 0.05 and sin(route_progress * 0.021) > 0.42


func convoy_center() -> Vector2:
	var sum = Vector2.ZERO
	var count = 0
	for v in convoy:
		if bool(v.get("alive", true)):
			sum += v["pos"]
			count += 1
	if count == 0:
		return Vector2(route_x_for_progress(route_progress), H - 170.0)
	return sum / float(count)


func convoy_total_hp() -> int:
	var total = 0
	for v in convoy:
		total += int(v.get("hp", 0))
	return total


func convoy_max_hp() -> int:
	var total = 0
	for v in convoy:
		total += int(v.get("max_hp", 0))
	return total


func convoy_alive_count() -> int:
	var count = 0
	for v in convoy:
		if bool(v.get("alive", true)):
			count += 1
	return count


func nearest_convoy_vehicle(pos: Vector2, alive_only: bool = false) -> Dictionary:
	var best = {}
	var best_dist = INF
	for v in convoy:
		if alive_only and not bool(v.get("alive", true)):
			continue
		var d = pos.distance_squared_to(v["pos"])
		if d < best_dist:
			best_dist = d
			best = v
	return best


func nearest_enemy(pos: Vector2) -> Dictionary:
	var best = {}
	var best_dist = INF
	for e in enemies:
		var d = pos.distance_squared_to(e["pos"])
		if d < best_dist:
			best_dist = d
			best = e
	return best


func is_smoke_covering(pos: Vector2) -> bool:
	for e in effects:
		if str(e.get("kind", "")) == "smoke" and Vector2(e["pos"]).distance_to(pos) < float(e.get("radius", 0.0)):
			return true
	return false


func is_hidden_by_cloud(pos: Vector2) -> bool:
	if radar_timer > 0.0:
		return false
	for c in clouds:
		if Vector2(c["pos"]).distance_to(pos) < float(c["radius"]) * 0.75:
			return true
	return false


func display_miss(pos: Vector2) -> void:
	effects.append({"kind": "text", "text": "SMOKE", "pos": pos + Vector2(0.0, -35.0), "life": 0.8, "max_life": 0.8})


func show_warning(text: String) -> void:
	warning_text = text
	warning_timer = 3.2


func spawn_particles(pos: Vector2, color: Color, count: int, power: float) -> void:
	for i in range(count):
		var a = rng.randf_range(0.0, TAU)
		var speed = rng.randf_range(power * 0.15, power)
		var life = rng.randf_range(0.35, 1.2)
		particles.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * speed, "life": life, "max_life": life, "size": rng.randf_range(1.8, 5.8), "color": color})


func update_particles(delta: float) -> void:
	for p in particles:
		p["pos"] = p["pos"] + p["vel"] * delta
		p["vel"] = p["vel"] * (1.0 - min(0.85, delta * 1.8))
		p["life"] = float(p["life"]) - delta
	for i in range(particles.size() - 1, -1, -1):
		if float(particles[i]["life"]) <= 0.0:
			particles.remove_at(i)
	for i in range(lightning_marks.size() - 1, -1, -1):
		lightning_marks[i]["life"] = float(lightning_marks[i]["life"]) - delta
		if float(lightning_marks[i]["life"]) <= 0.0:
			lightning_marks.remove_at(i)


func enemy_color(kind: String) -> Color:
	match kind:
		"interceptor":
			return Color(1.0, 0.56, 0.24, 1.0)
		"bomber":
			return Color(1.0, 0.25, 0.18, 1.0)
		"gunship":
			return Color(0.9, 0.25, 1.0, 1.0)
		"drone":
			return Color(0.4, 0.95, 1.0, 1.0)
		"tank", "sam", "artillery", "mine_layer":
			return Color(0.8, 0.95, 0.45, 1.0)
		"boss":
			return Color(1.0, 0.12, 0.38, 1.0)
	return Color.WHITE


func push_js_state() -> void:
	if not (OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge")):
		return
	var payload = {
		"screen": state_name(),
		"score": stage_score,
		"stars": stage_stars,
		"stage": stage_index + 1,
		"progress": route_progress / max(1.0, route_distance),
		"convoyHp": convoy_total_hp(),
		"convoyMaxHp": convoy_max_hp(),
		"playerHp": int(player.get("hp", 0)),
		"weather": stage.get("weather", {})
	}
	Engine.get_singleton("JavaScriptBridge").eval("window.ForceWarBridge=window.ForceWarBridge||{events:[]};window.ForceWarBridge.state=" + JSON.stringify(payload) + ";", false)


func js_emit(event_name: String, detail: Dictionary) -> void:
	if not (OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge")):
		return
	var payload = {"event": event_name, "detail": detail, "time": Time.get_ticks_msec()}
	var encoded = JSON.stringify(payload)
	var code = "window.ForceWarBridge=window.ForceWarBridge||{events:[]};" + \
		"window.ForceWarBridge.lastEvent=" + encoded + ";" + \
		"window.ForceWarBridge.events.push(" + encoded + ");" + \
		"window.dispatchEvent(new CustomEvent('force-war-event',{detail:" + encoded + "}));"
	Engine.get_singleton("JavaScriptBridge").eval(code, false)


func state_name() -> String:
	match state:
		GameState.TITLE:
			return "title"
		GameState.BRIEFING:
			return "briefing"
		GameState.GROUND:
			return "ground_chase"
		GameState.PLAYING:
			return "playing"
		GameState.STAGE_CLEAR:
			return "stage_clear"
		GameState.GAME_OVER:
			return "game_over"
		GameState.PAUSED:
			return "paused"
	return "unknown"


func _draw() -> void:
	if state == GameState.GROUND:
		draw_ground_overlay()
		return
	if state == GameState.PAUSED and previous_state == GameState.GROUND:
		draw_ground_overlay()
		draw_pause_overlay()
		return
	draw_background()
	match state:
		GameState.TITLE:
			draw_title()
		GameState.BRIEFING:
			draw_briefing()
		GameState.PLAYING:
			draw_game_world()
			draw_hud()
		GameState.PAUSED:
			draw_game_world()
			draw_hud()
			draw_pause_overlay()
		GameState.STAGE_CLEAR:
			draw_game_world()
			draw_stage_clear()
		GameState.GAME_OVER:
			draw_game_world()
			draw_game_over()


func stage_background_key() -> String:
	var idx = selected_stage
	if state == GameState.PLAYING or state == GameState.PAUSED or state == GameState.STAGE_CLEAR or state == GameState.GAME_OVER:
		idx = stage_index
	match idx:
		0:
			return "bg_monsoon"
		1:
			return "bg_thunder"
		2:
			return "bg_delta"
		3:
			return "bg_thunder"
		4:
			return "bg_delta"
		5:
			return "bg_thunder"
	return "bg_monsoon"


func draw_background() -> void:
	var hue = 0.6
	if state == GameState.BRIEFING:
		hue = float(stages[selected_stage].get("hue", 0.6))
	elif not stage.is_empty():
		hue = float(stage.get("hue", 0.6))
	var top = Color.from_hsv(hue, 0.72, 0.11, 1.0)
	var bottom = Color.from_hsv(fmod(hue + 0.1, 1.0), 0.82, 0.035, 1.0)
	for i in range(24):
		var t = float(i) / 23.0
		draw_rect(Rect2(0, H * t, W, H / 23.0 + 2), top.lerp(bottom, t))
	var bg_key = stage_background_key()
	if textures.has(bg_key):
		# Painted stage background is intentionally drawn under the tactical road/weather layers.
		draw_texture_rect(textures[bg_key], Rect2(0.0, 0.0, W, H), false, Color(1.0, 1.0, 1.0, 0.82))
		draw_rect(Rect2(0.0, 0.0, W, H), Color(0.0, 0.02, 0.05, 0.18))
	for s in bg_stars:
		var pulse = 0.55 + sin(time * 2.0 + float(s["phase"])) * 0.2
		draw_circle(s["pos"], float(s["size"]), Color(0.6, 0.88, 1.0, pulse * 0.45))
	if state == GameState.PLAYING or state == GameState.PAUSED or state == GameState.STAGE_CLEAR or state == GameState.GAME_OVER:
		draw_road()
		draw_weather_backdrop()


func draw_road() -> void:
	for y in range(-40, int(H) + 80, 34):
		var yy = float(y) + fmod(route_progress * 1.35, 34.0)
		var x = route_x_for_y(yy)
		draw_circle(Vector2(x, yy), ROAD_WIDTH * 0.5, Color(0.13, 0.12, 0.11, 0.72))
		draw_line(Vector2(x - ROAD_WIDTH * 0.42, yy - 22), Vector2(x - ROAD_WIDTH * 0.38, yy + 22), Color(1.0, 0.9, 0.45, 0.2), 2.0)
		draw_line(Vector2(x + ROAD_WIDTH * 0.42, yy - 22), Vector2(x + ROAD_WIDTH * 0.38, yy + 22), Color(1.0, 0.9, 0.45, 0.2), 2.0)
		if int((yy + route_progress) / 68.0) % 2 == 0:
			draw_line(Vector2(x, yy - 11), Vector2(x, yy + 11), Color(1.0, 1.0, 1.0, 0.18), 3.0)
	if is_convoy_in_flood():
		for i in range(4):
			var fy = H - 280.0 + i * 45.0
			var fx = route_x_for_y(fy)
			draw_circle(Vector2(fx, fy), ROAD_WIDTH * 0.55, Color(0.25, 0.54, 0.78, 0.24))


func draw_weather_backdrop() -> void:
	for c in clouds:
		var pos = c["pos"]
		var r = float(c["radius"])
		var alpha = float(c["alpha"])
		draw_circle(pos, r, Color(0.72, 0.78, 0.86, alpha))
		draw_circle(pos + Vector2(-r * 0.35, 8.0), r * 0.55, Color(0.82, 0.88, 0.94, alpha * 0.7))
		draw_circle(pos + Vector2(r * 0.32, -10.0), r * 0.48, Color(0.56, 0.62, 0.72, alpha * 0.8))
	var rain = weather_value("rain")
	if rain > 0.05:
		for i in range(int(70 * rain)):
			var x = fmod(float(i) * 97.0 + time * 250.0 * (0.3 + rain), W + 80.0) - 40.0
			var y = fmod(float(i) * 53.0 + time * 520.0, H + 80.0) - 40.0
			var slant = current_wind() * 22.0
			draw_line(Vector2(x, y), Vector2(x + slant, y + 28.0), Color(0.55, 0.86, 1.0, 0.18 + rain * 0.18), 1.5)
	for m in lightning_marks:
		var ratio = clamp(float(m["life"]) / float(m["max_life"]), 0.0, 1.0)
		var pos = m["pos"]
		draw_line(Vector2(pos.x - 24.0, 0.0), pos, Color(0.82, 0.92, 1.0, ratio), 5.0)
		draw_circle(pos, 100.0 * (1.0 - ratio + 0.25), Color(0.7, 0.85, 1.0, 0.22 * ratio))


func draw_game_world() -> void:
	for h in hazards:
		draw_hazard(h)
	for d in support_drops:
		draw_sprite(str(d["kind"]), d["pos"], Vector2(34.0, 34.0), time * 3.0, Color.WHITE)
	for e in effects:
		draw_effect(e)
	for v in convoy:
		draw_convoy_vehicle(v)
	for e in enemies:
		draw_enemy(e)
	for b in bullets:
		var p = b["pos"]
		var col = Color(0.5, 0.95, 1.0, 1.0) if str(b.get("kind", "")) != "aa" else Color(1.0, 0.85, 0.2, 1.0)
		if str(b.get("kind", "")) == "missile":
			col = Color(1.0, 0.55, 0.16, 1.0)
		draw_circle(p, float(b["radius"]), col)
		draw_line(p - Vector2(0, 14), p + Vector2(0, 6), Color(col.r, col.g, col.b, 0.55), 2.0)
	for b in enemy_bullets:
		var c = b["color"]
		draw_circle(b["pos"], float(b["radius"]) + 2.0, Color(c.r, c.g, c.b, 0.2))
		draw_circle(b["pos"], float(b["radius"]), c)
	draw_player()
	for p in particles:
		var ratio = clamp(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var c = p["color"]
		c.a = ratio
		draw_circle(p["pos"], float(p["size"]) * ratio, c)
	draw_visibility_overlay()


func draw_visibility_overlay() -> void:
	var visibility = weather_value("visibility")
	var darkness = clamp(1.0 - visibility, 0.0, 0.65)
	if darkness > 0.01:
		draw_rect(Rect2(0, 0, W, H), Color(0.0, 0.02, 0.05, darkness * 0.58))
	if weather_flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0.75, 0.88, 1.0, weather_flash * 0.25))


func draw_player() -> void:
	if state == GameState.GAME_OVER and int(player.get("hp", 0)) <= 0:
		return
	if float(player.get("invuln", 0.0)) > 0.0 and int(time * 20.0) % 2 == 0:
		return
	var pos = player["pos"]
	var tex_key = "player_support" if selected_loadout == 3 else "player"
	draw_sprite(tex_key, pos, Vector2(74.0, 74.0), 0.0, Color.WHITE)
	if overcharge_timer > 0.0:
		draw_arc(pos, 47.0 + sin(time * 8.0) * 3.0, -time * 3.0, TAU - time * 3.0, 60, Color(0.8, 0.92, 1.0, 0.65), 3.0)
	var flame = 16.0 + sin(time * 32.0) * 7.0
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-8, 28), pos + Vector2(0, 28 + flame), pos + Vector2(8, 28)]), Color(1.0, 0.45, 0.08, 0.82))


func draw_convoy_vehicle(v: Dictionary) -> void:
	var pos = v["pos"]
	var alive = bool(v.get("alive", true))
	var mod = Color.WHITE if alive else Color(0.18, 0.18, 0.18, 0.85)
	if float(v.get("flash", 0.0)) > 0.0:
		mod = mod.lerp(Color(1.0, 0.35, 0.18, 1.0), float(v["flash"]))
	draw_sprite(str(v["kind"]), pos, Vector2(60.0, 60.0), 0.0, mod)
	var ratio = clamp(float(v.get("hp", 0)) / max(1.0, float(v.get("max_hp", 1))), 0.0, 1.0)
	draw_bar(Rect2(pos.x - 33.0, pos.y + 34.0, 66.0, 6.0), ratio, Color(0.25, 1.0, 0.32, 1.0), Color(0.1, 0.0, 0.0, 0.65))
	if supply_turret_timer > 0.0 and alive:
		draw_arc(pos, 42.0, -PI * 0.5, PI * 0.2, 18, Color(1.0, 0.86, 0.25, 0.55), 2.0)


func draw_enemy(e: Dictionary) -> void:
	var pos = e["pos"]
	var kind = str(e["kind"])
	var hidden = is_hidden_by_cloud(pos) and kind != "boss"
	var alpha = 0.18 if hidden else 1.0
	var mod = Color(1.0, 1.0, 1.0, alpha)
	if float(e.get("flash", 0.0)) > 0.0:
		mod = mod.lerp(Color(1.0, 1.0, 1.0, alpha), float(e["flash"]))
	var key = kind
	if key == "mine_layer":
		key = "tank"
	if key == "boss":
		draw_boss(e, mod)
	else:
		var size = Vector2(62.0, 62.0)
		if kind == "gunship":
			size = Vector2(82.0, 82.0)
		elif bool(e.get("ground", false)):
			size = Vector2(64.0, 64.0)
		draw_sprite(key, pos, size, PI if not bool(e.get("ground", false)) else 0.0, mod)
	if not hidden and kind != "boss":
		var ratio = clamp(float(e["hp"]) / max(1.0, float(e["max_hp"])), 0.0, 1.0)
		if ratio < 0.98:
			draw_bar(Rect2(pos.x - 26.0, pos.y - float(e["radius"]) - 12.0, 52.0, 5.0), ratio, Color(1.0, 0.22, 0.22, alpha), Color(0, 0, 0, 0.5 * alpha))
	elif hidden:
		draw_circle(pos, float(e["radius"]) + 8.0, Color(0.6, 0.9, 1.0, 0.1))


func draw_boss(e: Dictionary, mod: Color) -> void:
	var pos = e["pos"]
	# Painted boss sprite replaces the previous procedural polygon placeholder.
	draw_sprite("boss", pos, Vector2(230.0, 230.0), PI, mod)
	draw_circle(pos + Vector2(0, -8), 36.0 + sin(time * 5.0) * 3.0, Color(0.3, 0.75, 1.0, 0.18 * mod.a))
	draw_arc(pos, 116.0 + sin(time * 2.5) * 4.0, -time * 1.5, TAU - time * 1.5, 96, Color(0.8, 0.92, 1.0, 0.22 * mod.a), 3.0)
	var ratio = clamp(float(e["hp"]) / max(1.0, float(e["max_hp"])), 0.0, 1.0)
	draw_text_center(str(stage["boss"]), 92.0, 22, Color(1.0, 0.82, 0.9, 0.95))
	draw_bar(Rect2(72.0, 104.0, W - 144.0, 14.0), ratio, Color(1.0, 0.08, 0.24, 1.0), Color(0, 0, 0, 0.62))


func draw_hazard(h: Dictionary) -> void:
	var kind = str(h["kind"])
	var pos = h["pos"]
	var radius = float(h.get("radius", 42.0))
	var timer = float(h.get("timer", 0.0))
	if kind == "mine":
		draw_circle(pos, 15.0 + sin(time * 6.0) * 2.0, Color(1.0, 0.75, 0.16, 0.8))
		draw_arc(pos, radius, 0.0, TAU, 36, Color(1.0, 0.3, 0.1, 0.2), 2.0)
	else:
		var pulse = 0.4 + sin(time * 12.0) * 0.22
		draw_arc(pos, radius, 0.0, TAU, 64, Color(1.0, 0.1, 0.08, 0.45 + pulse * 0.25), 4.0)
		draw_text_centered_at(str(max(1, int(ceil(timer)))), pos + Vector2(0, 7), 18, Color(1.0, 0.9, 0.75, 0.9))


func draw_effect(e: Dictionary) -> void:
	var kind = str(e.get("kind", ""))
	var pos = e.get("pos", Vector2.ZERO)
	var life = float(e.get("life", 1.0))
	var max_life = max(0.01, float(e.get("max_life", 1.0)))
	var ratio = clamp(life / max_life, 0.0, 1.0)
	if kind == "smoke":
		var r = float(e.get("radius", 120.0))
		for i in range(5):
			var a = float(i) / 5.0 * TAU + time * 0.35
			draw_circle(pos + Vector2(cos(a), sin(a)) * r * 0.18, r * (0.38 + i * 0.035), Color(0.78, 0.82, 0.84, 0.13 * ratio))
	elif kind == "radar":
		draw_arc(pos, float(e.get("radius", 40.0)), 0, TAU, 80, Color(0.45, 0.9, 1.0, 0.5 * ratio), 3.0)
	elif kind == "rod":
		draw_line(pos + Vector2(0, 34), pos + Vector2(0, -42), Color(0.92, 0.75, 1.0, 0.85 * ratio), 5.0)
		draw_arc(pos, 58.0, 0, TAU, 48, Color(0.75, 0.5, 1.0, 0.24 * ratio), 2.0)
	elif kind == "text":
		draw_text_centered_at(str(e.get("text", "")), pos + Vector2(0, -20.0 * (1.0 - ratio)), 16, Color(0.84, 0.92, 1.0, ratio))


func draw_title() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.24))
	var y = 178.0 + sin(time * 1.5) * 8.0
	draw_sprite("player", Vector2(W * 0.5, y), Vector2(128.0, 128.0), 0, Color.WHITE)
	draw_text_center("FORCE WAR", 330.0, 64, Color(0.72, 0.95, 1.0, 1.0))
	draw_text_center("STORM CONVOY", 382.0, 34, Color(1.0, 0.86, 0.28, 1.0))
	draw_text_center("Escort shooter taktis: proteksi konvoi, pilih jalur, manfaatkan badai.", 435.0, 20, Color(0.86, 0.94, 1.0, 0.9))
	draw_panel(Rect2(74, 512, W - 148, 214), "CORE LOOP")
	draw_text("• Konvoi punya HP per kendaraan dan bisa hancur sebelum pemain mati.", 105, 575, 18, Color(1,1,1,0.9))
	draw_text("• Route bercabang: aman/lambat, cepat/berbahaya, atau jalur badai reward tinggi.", 105, 607, 18, Color(1,1,1,0.9))
	draw_text("• Cuaca mengubah peluru, visibility, petir, dan flood road.", 105, 639, 18, Color(1,1,1,0.9))
	draw_text("• Drop repair, smoke, supply, radar, lightning rod sesuai forecast.", 105, 671, 18, Color(1,1,1,0.9))
	draw_text_center("ENTER / SPACE: Mission Briefing", 805 + sin(time * 4) * 3, 28, Color(1,1,1,0.96))
	draw_text_center("Godot 4.6.2 Web target • Original art/gameplay direction", 875, 15, Color(0.65,0.75,0.86,0.78))


func draw_briefing() -> void:
	var st = stages[selected_stage]
	var lo = loadouts[selected_loadout]
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.28))
	draw_text_center("MISSION BRIEFING", 62, 38, Color(0.74, 0.94, 1.0, 1.0))
	draw_text_center("↑/↓ pilih operation • ←/→ pilih loadout • ENTER launch", 97, 17, Color(0.88, 0.96, 1.0, 0.82))
	draw_panel(Rect2(48, 128, W - 96, 246), "OPERATION")
	draw_text_center(str(st["codename"]), 184, 34, Color(1.0, 0.86, 0.25, 1.0))
	draw_text_center(str(st["name"]), 225, 23, Color(0.86, 0.96, 1.0, 1.0))
	draw_text_wrapped(str(st["brief"]), Rect2(86, 252, W - 172, 65), 17, Color(0.84, 0.93, 1.0, 0.9))
	draw_text_center("Stage " + str(selected_stage + 1) + "/" + str(stages.size()) + "   Unlocked: " + str(int(save_data.get("unlocked_stage", 1))) + "   Best: " + str(int(save_data.get("best_score", 0))), 345, 16, Color(0.72, 0.82, 0.94, 0.9))

	draw_panel(Rect2(48, 405, W - 96, 182), "WEATHER FORECAST")
	var w = st["weather"]
	var icons = [["wind_icon", "Wind", current_stage_weather_value(st, "wind")], ["rain_icon", "Rain", current_stage_weather_value(st, "rain")], ["cloud_icon", "Cloud", current_stage_weather_value(st, "cloud")], ["storm_icon", "Lightning", current_stage_weather_value(st, "lightning")]]
	for i in range(icons.size()):
		var item = icons[i]
		var x = 100.0 + i * 150.0
		draw_sprite(str(item[0]), Vector2(x, 478), Vector2(44, 44), 0, Color.WHITE)
		draw_text_centered_at(str(item[1]), Vector2(x, 525), 15, Color(0.88, 0.96, 1, 0.9))
		draw_bar(Rect2(x - 43, 540, 86, 8), clamp(abs(float(item[2])), 0.0, 1.0), Color(0.48, 0.88, 1.0, 1.0), Color(1,1,1,0.12))
	draw_text("Weather kind: " + str(w["kind"]) + "   Visibility: " + str(int(float(w["visibility"]) * 100)) + "%", 85, 575, 16, Color(0.85, 0.94, 1, 0.86))

	draw_panel(Rect2(48, 620, W - 96, 184), "LOADOUT")
	draw_text_center(str(lo["name"]), 675, 28, Color(1.0, 0.86, 0.25, 1.0))
	draw_text_center(str(lo["role"]), 710, 17, Color(0.86, 0.96, 1, 0.88))
	var support = lo["support"]
	var keys = ["repair", "smoke", "supply", "radar", "rod"]
	for i in range(keys.size()):
		var key = keys[i]
		var x = 110.0 + i * 125.0
		draw_sprite(key, Vector2(x, 758), Vector2(38, 38), 0, Color.WHITE)
		draw_text_centered_at(key.capitalize() + " x" + str(int(support.get(key, 0))), Vector2(x, 792), 14, Color(1,1,1,0.9))
	draw_text_center("ENTER: launch escort mission", 875 + sin(time * 4) * 3, 26, Color(1,1,1,0.96))


func current_stage_weather_value(st: Dictionary, key: String) -> float:
	return float(st["weather"].get(key, 0.0))


func draw_ground_overlay() -> void:
	# HUD overlay for the perspective 3D car phase. The rendered scene underneath is
	# composed of imported GLB cars/jet and procedural Godot meshes.
	draw_rect(Rect2(0, 0, W, 96), Color(0.0, 0.0, 0.0, 0.56))
	draw_rect(Rect2(0, H - 92, W, 92), Color(0.0, 0.0, 0.0, 0.48))
	draw_text("GROUND CHASE", 18, 30, 18, Color(0.92, 0.98, 1.0, 1.0))
	draw_text("3D GLB car combat — top-down begins only after aircraft switch", 18, 60, 14, Color(0.62, 0.82, 1.0, 0.92))
	var car_ratio = float(ground_car_hp) / max(1.0, float(ground_car_max_hp))
	draw_text("CAR ARMOR", 360, 30, 14, Color(0.86, 0.96, 1.0, 0.9))
	draw_bar(Rect2(452, 18, 170, 13), car_ratio, Color(0.25, 0.9, 1.0, 1.0), Color(0.2, 0.02, 0.02, 0.75))
	draw_text("CHASE", 360, 61, 14, Color(0.86, 0.96, 1.0, 0.9))
	draw_bar(Rect2(452, 49, 170, 13), clamp(ground_time / 28.0, 0.0, 1.0), Color(1.0, 0.84, 0.25, 1.0), Color(1.0, 1.0, 1.0, 0.12))
	draw_text("Enemy cars " + str(ground_enemies.size()) + "   Score " + str(stage_score), 660, 32, 14, Color(0.9, 0.96, 1.0, 0.88))
	draw_text("A/D or arrows steer · auto-cannons fire forward", 28, H - 52, 17, Color(0.9, 0.98, 1.0, 0.96))
	if ground_transition_ready:
		draw_rect(Rect2(W * 0.5 - 250, H * 0.5 - 60, 500, 118), Color(0.02, 0.08, 0.12, 0.76))
		draw_text_center("JET LINK READY", H * 0.5 - 14, 30, Color(0.45, 0.95, 1.0, 1.0))
		draw_text_center("Press SPACE / ENTER to switch directly into aircraft mode", H * 0.5 + 24, 16, Color(0.95, 0.98, 1.0, 0.96))
	elif ground_jet_called:
		draw_text_center("Support jet is attacking the road — hold formation", H - 50, 18, Color(1.0, 0.75, 0.35, 1.0))
	else:
		draw_text_center("Chase and destroy hostile cars until air support arrives", H - 50, 18, Color(0.72, 0.9, 1.0, 0.95))
	if warning_timer > 0.0:
		draw_rect(Rect2(W * 0.5 - 310, 106, 620, 34), Color(0.0, 0.0, 0.0, 0.54))
		draw_text_center(warning_text, 130, 14, Color(1.0, 0.9, 0.35, 1.0))


func draw_hud() -> void:
	draw_rect(Rect2(0, 0, W, 102), Color(0,0,0,0.52))
	draw_text("SCORE " + str(stage_score).pad_zeros(7), 15, 28, 18, Color(0.86, 0.96, 1, 1))
	draw_text("★ " + str(stage_stars), 15, 57, 18, Color(1.0, 0.86, 0.25, 1))
	var hp_ratio = float(player.get("hp", 0)) / max(1.0, float(player.get("max_hp", 1)))
	draw_text("JET", 170, 28, 14, Color(0.86, 0.96, 1, 0.88))
	draw_bar(Rect2(205, 17, 145, 12), hp_ratio, Color(0.35, 0.92, 1, 1), Color(0.1,0.02,0.02,0.7))
	var cv_ratio = float(convoy_total_hp()) / max(1.0, float(convoy_max_hp()))
	draw_text("CONVOY", 170, 59, 14, Color(0.86, 0.96, 1, 0.88))
	draw_bar(Rect2(238, 48, 164, 13), cv_ratio, Color(0.35, 1, 0.36, 1), Color(0.1,0.02,0.02,0.7))
	var progress = route_progress / max(1.0, route_distance)
	draw_text("ROUTE", 430, 28, 14, Color(0.86,0.96,1,0.88))
	draw_bar(Rect2(489, 17, 190, 12), progress, Color(1.0, 0.86, 0.25, 1), Color(1,1,1,0.12))
	draw_text("WIND " + str(snapped(current_wind(), 0.01)), 430, 58, 14, Color(0.72, 0.9, 1, 0.88))
	if overcharge_timer > 0:
		draw_text("OVERCHARGE " + str(int(overcharge_timer)), 560, 58, 14, Color(0.85, 0.95, 1, 1))
	elif radar_timer > 0:
		draw_text("RADAR " + str(int(radar_timer)), 560, 58, 14, Color(0.5, 0.9, 1, 1))
	var keys = ["repair", "smoke", "supply", "radar", "rod"]
	for i in range(keys.size()):
		var key = keys[i]
		var x = 72.0 + i * 116.0
		draw_sprite(key, Vector2(x, 86), Vector2(22, 22), 0, Color.WHITE)
		draw_text(str(i + 1) + ":" + str(int(support_counts.get(key, 0))), x + 18, 91, 14, Color(1,1,1,0.9))
	if branch_pending:
		draw_branch_prompt()
	if warning_timer > 0:
		draw_text_center(warning_text, 132, 18, Color(1.0, 0.9, 0.35, min(1.0, warning_timer)))


func draw_branch_prompt() -> void:
	var rect = Rect2(58, 178, W - 116, 118)
	draw_rect(rect, Color(0.02, 0.05, 0.1, 0.88))
	draw_rect(rect, Color(0.48, 0.86, 1.0, 0.35), false, 2.0)
	draw_text_center("ROUTE SPLIT — choose before " + str(int(ceil(branch_timer))) + "s", 208, 20, Color(1, 0.9, 0.32, 1))
	var branches = stage["branches"]
	for i in range(branches.size()):
		var b = branches[i]
		var x = 100.0 + i * 205.0
		var col = Color(0.12, 0.35, 0.5, 0.8) if i == branch_choice_index else Color(0.1, 0.13, 0.18, 0.78)
		draw_rect(Rect2(x, 226, 170, 52), col)
		draw_text_centered_at(str(b["name"]), Vector2(x + 85, 248), 15, Color(1,1,1,0.95))
		draw_text_centered_at("risk " + str(snapped(float(b["risk"]), 0.01)) + " / reward " + str(snapped(float(b["reward"]), 0.01)), Vector2(x + 85, 270), 12, Color(0.82,0.92,1,0.82))


func draw_stage_clear() -> void:
	draw_rect(Rect2(0,0,W,H), Color(0,0,0,0.6))
	draw_panel(Rect2(78, 248, W - 156, 420), "ESCORT COMPLETE")
	draw_text_center("CONVOY EXTRACTED", 330, 42, Color(1.0,0.86,0.28,1))
	draw_text_center(str(stage["name"]), 372, 22, Color(0.86,0.96,1,1))
	draw_text("Score", 150, 440, 22, Color(0.82,0.92,1,0.9))
	draw_text(str(stage_score), 430, 440, 22, Color(1,1,1,1))
	draw_text("Stars earned", 150, 482, 22, Color(0.82,0.92,1,0.9))
	draw_text(str(stage_stars), 430, 482, 22, Color(1,0.86,0.25,1))
	draw_text("Convoy HP", 150, 524, 22, Color(0.82,0.92,1,0.9))
	draw_text(str(convoy_total_hp()) + "/" + str(convoy_max_hp()), 430, 524, 22, Color(0.5,1,0.55,1))
	draw_text("Branches", 150, 566, 22, Color(0.82,0.92,1,0.9))
	draw_text(", ".join(applied_branches) if applied_branches.size() > 0 else "standard route", 300, 566, 16, Color(1,1,1,0.86))
	draw_text_center("ENTER: next briefing", 625 + sin(time * 4) * 3, 24, Color(1,1,1,0.96))


func draw_game_over() -> void:
	draw_rect(Rect2(0,0,W,H), Color(0,0,0,0.64))
	draw_panel(Rect2(84, 288, W - 168, 330), "MISSION FAILED")
	draw_text_center("CONVOY LOST", 368, 48, Color(1.0,0.32,0.22,1))
	draw_text_center("Score: " + str(stage_score), 430, 25, Color(0.9,0.98,1,1))
	draw_text_center("Recovered stars: " + str(stage_stars), 470, 20, Color(1,0.86,0.25,1))
	draw_text_center("R/ENTER: retry   ESC: briefing", 560, 22, Color(1,1,1,0.94))


func draw_pause_overlay() -> void:
	draw_rect(Rect2(0,0,W,H), Color(0,0,0,0.62))
	draw_text_center("PAUSED", H * 0.45, 52, Color(1,1,1,1))
	draw_text_center("P/ENTER lanjut • ESC abort ke briefing", H * 0.51, 22, Color(0.82,0.92,1,0.9))


func draw_sprite(key: String, pos: Vector2, size: Vector2, rotation: float = 0.0, modulate: Color = Color.WHITE) -> void:
	var tex = textures.get(key, null)
	if tex != null:
		draw_set_transform(pos, rotation, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-size * 0.5, size), false, modulate)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(pos, min(size.x, size.y) * 0.35, modulate)


func draw_panel(rect: Rect2, title: String) -> void:
	draw_rect(rect, Color(0.02, 0.06, 0.12, 0.78))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), Color(0.45,0.85,1,0.9))
	draw_rect(rect, Color(0.45,0.85,1,0.22), false, 1.0)
	draw_string(font, rect.position + Vector2(18, 32), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.65,0.9,1,0.88))


func draw_bar(rect: Rect2, ratio: float, fill: Color, back: Color) -> void:
	ratio = clamp(ratio, 0.0, 1.0)
	draw_rect(rect, back)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), fill)
	draw_rect(rect, Color(1,1,1,0.16), false, 1.0)


func draw_text(text: String, x: float, y: float, size: int = 18, color: Color = Color.WHITE) -> void:
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func draw_text_center(text: String, y: float, size: int = 18, color: Color = Color.WHITE) -> void:
	draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, W, size, color)


func draw_text_centered_at(text: String, pos: Vector2, size: int = 18, color: Color = Color.WHITE) -> void:
	draw_string(font, Vector2(pos.x - 120, pos.y), text, HORIZONTAL_ALIGNMENT_CENTER, 240, size, color)


func draw_text_wrapped(text: String, rect: Rect2, size: int, color: Color) -> void:
	var words = text.split(" ")
	var line = ""
	var y = rect.position.y + size
	for word in words:
		var candidate = word if line == "" else line + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > rect.size.x and line != "":
			draw_string(font, Vector2(rect.position.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, size, color)
			y += size + 7.0
			line = word
		else:
			line = candidate
	if line != "":
		draw_string(font, Vector2(rect.position.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, size, color)
