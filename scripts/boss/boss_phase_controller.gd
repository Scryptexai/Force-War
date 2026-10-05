extends Node
class_name BossPhaseController

# Data-oriented boss controller for the forward-air vertical slice.
# The visible boss GLB is owned by ForwardArenaDirector; this node owns gameplay
# phase/part health, weak-point routing, and attack-pattern scheduling.

const BOSS_DATA_PATH = "res://data/bosses/dreadnought_leviathan.json"

var active := false
var boss_name := "Dreadnought Leviathan"
var boss_data: Dictionary = {}
var max_hp := 7600.0
var total_hp := 7600.0
var phase := 1
var phase_name := "INTRO"
var fire_pressure := 0.0
var destroyed_parts: Array = []
var parts := {
	"shield": {"hp": 2400.0, "max": 2400.0, "required_phase": 1},
	"left_wing": {"hp": 950.0, "max": 950.0, "required_phase": 2},
	"right_wing": {"hp": 950.0, "max": 950.0, "required_phase": 2},
	"turrets": {"hp": 1250.0, "max": 1250.0, "required_phase": 2},
	"core": {"hp": 2050.0, "max": 2050.0, "required_phase": 3}
}
var attack_patterns: Array = []
var phase_pattern_index := 0
var pattern_timer := 0.0
var pattern_clock := 0.0
var active_attack_pattern := "shield_lane_sweep_pool_v1"
var active_pattern_phase := 1
var active_pattern_duration := 2.2
var current_target_part := "shield"
var projectile_damage_total := 0.0
var projectile_hit_count := 0
var last_damage_amount := 0.0
var hit_flash_timer := 0.0


func setup() -> void:
	boss_data = _load_json(BOSS_DATA_PATH)
	if not boss_data.is_empty():
		boss_name = str(boss_data.get("name", boss_name))
		attack_patterns = boss_data.get("attack_patterns", [])


func start_mission(stage_data: Dictionary) -> void:
	if boss_data.is_empty():
		setup()
	active = true
	var threat: float = float(stage_data.get("threat", 1.0))
	_reset_parts(threat)
	phase = 1
	phase_name = "PHASE_1_SHIELD"
	fire_pressure = 0.0
	destroyed_parts.clear()
	phase_pattern_index = 0
	pattern_timer = 0.0
	pattern_clock = 0.0
	active_attack_pattern = "shield_lane_sweep_pool_v1"
	active_pattern_phase = 1
	active_pattern_duration = 2.2
	current_target_part = "shield"
	projectile_damage_total = 0.0
	projectile_hit_count = 0
	last_damage_amount = 0.0
	hit_flash_timer = 0.0
	_recalculate_total_hp()
	_update_phase()
	_select_next_attack_pattern(true)


func stop_mission() -> void:
	active = false


func update_boss(delta: float, overcharged: bool, player_pressure: float) -> void:
	if not active:
		return
	pattern_clock += delta
	pattern_timer = max(0.0, pattern_timer - delta)
	hit_flash_timer = max(0.0, hit_flash_timer - delta)
	fire_pressure = lerp(fire_pressure, player_pressure * (1.12 if overcharged else 1.0), min(1.0, delta * 2.5))
	_update_phase()
	_update_targetable_part()
	if pattern_timer <= 0.0:
		_select_next_attack_pattern(false)
	_recalculate_total_hp()


func apply_projectile_damage(part_name: String, amount: float) -> float:
	if not active or amount <= 0.0:
		return 0.0
	var target: String = _resolve_damage_target(part_name)
	var damage: float = amount
	if target == "shield" and part_name != "shield" and _part_ratio("shield") > 0.0:
		damage *= 0.52
	var before_ratio: float = get_hp_ratio()
	_apply_part_damage(target, damage)
	_update_phase()
	_update_targetable_part()
	_recalculate_total_hp()
	var applied: float = max(0.0, before_ratio * max_hp - total_hp)
	if applied > 0.0:
		projectile_damage_total += applied
		projectile_hit_count += 1
		last_damage_amount = applied
		hit_flash_timer = 0.16
	return applied


func get_bridge_state() -> Dictionary:
	return {
		"bossPhaseController": true,
		"bossPhase": phase,
		"bossPhaseName": phase_name,
		"bossHpRatio": get_hp_ratio(),
		"bossShieldRatio": _part_ratio("shield"),
		"bossCoreRatio": _part_ratio("core"),
		"bossDestroyedParts": destroyed_parts.size(),
		"bossPartCount": parts.size(),
		"bossDamageModel": "parts_shield_wings_turrets_core",
		"bossWeakPointModel": "shield_then_wings_turrets_then_core",
		"bossTargetablePart": current_target_part,
		"bossFirePressure": fire_pressure,
		"bossPatternScheduler": true,
		"bossAttackPattern": active_attack_pattern,
		"bossPatternClock": pattern_clock,
		"bossPatternTimeRemaining": pattern_timer,
		"bossDataDriven": not boss_data.is_empty(),
		"bossProjectileDamageTaken": projectile_damage_total,
		"bossProjectileHitCount": projectile_hit_count,
		"bossLastProjectileDamage": last_damage_amount,
		"bossHitFlash": hit_flash_timer > 0.0
	}


func get_hp_ratio() -> float:
	return clamp(total_hp / max(1.0, max_hp), 0.0, 1.0)


func _reset_parts(threat: float) -> void:
	parts = {}
	var data_parts: Dictionary = boss_data.get("parts", {})
	if data_parts.is_empty():
		data_parts = {
			"shield": {"hp": 2400.0, "phase": 1},
			"left_wing": {"hp": 950.0, "phase": 2},
			"right_wing": {"hp": 950.0, "phase": 2},
			"turrets": {"hp": 1250.0, "phase": 2},
			"core": {"hp": 2050.0, "phase": 3}
		}
	for key in data_parts.keys():
		var source: Dictionary = data_parts[key]
		var base_hp: float = float(source.get("hp", 900.0))
		var required_phase: int = int(source.get("phase", source.get("required_phase", 1)))
		var scaled_hp: float = base_hp * (0.92 + threat * 0.08)
		parts[str(key)] = {"hp": scaled_hp, "max": scaled_hp, "required_phase": required_phase}
	max_hp = 0.0
	for key in parts.keys():
		max_hp += float(parts[key].get("max", 0.0))
	total_hp = max_hp


func _resolve_damage_target(part_name: String) -> String:
	if _part_ratio("shield") > 0.0:
		return "shield"
	if phase >= 3:
		return "core"
	if parts.has(part_name) and _part_ratio(part_name) > 0.0 and int(parts[part_name].get("required_phase", 1)) <= phase:
		return part_name
	if _part_ratio("turrets") > 0.0:
		return "turrets"
	if _part_ratio("left_wing") > 0.0:
		return "left_wing"
	if _part_ratio("right_wing") > 0.0:
		return "right_wing"
	return "core"


func _apply_part_damage(part_name: String, amount: float) -> void:
	if not parts.has(part_name):
		return
	var part: Dictionary = parts[part_name]
	if float(part.get("hp", 0.0)) <= 0.0:
		return
	part["hp"] = max(0.0, float(part.get("hp", 0.0)) - amount)
	parts[part_name] = part
	if float(part["hp"]) <= 0.0 and not destroyed_parts.has(part_name):
		destroyed_parts.append(part_name)


func _update_phase() -> void:
	if _part_ratio("core") <= 0.0:
		phase = 5
		phase_name = "DEFEATED"
	elif _part_ratio("shield") <= 0.0 and (_part_ratio("turrets") <= 0.0 or destroyed_parts.size() >= 3):
		phase = 3
		phase_name = "PHASE_3_CORE_EXPOSED"
	elif _part_ratio("shield") <= 0.0:
		phase = 2
		phase_name = "PHASE_2_TURRETS_WINGS"
	else:
		phase = 1
		phase_name = "PHASE_1_SHIELD"


func _update_targetable_part() -> void:
	if phase <= 1:
		current_target_part = "shield"
	elif phase >= 3:
		current_target_part = "core"
	elif _part_ratio("turrets") > 0.0:
		current_target_part = "turrets"
	elif _part_ratio("left_wing") > _part_ratio("right_wing"):
		current_target_part = "left_wing"
	elif _part_ratio("right_wing") > 0.0:
		current_target_part = "right_wing"
	else:
		current_target_part = "core"


func _select_next_attack_pattern(force: bool) -> void:
	var candidates: Array = []
	for pattern in attack_patterns:
		if pattern is Dictionary and int(pattern.get("phase", 1)) <= phase:
			candidates.append(pattern)
	if candidates.is_empty():
		candidates.append({"id": "shield_lane_sweep_pool_v1", "phase": 1, "duration": 2.2})
	if force:
		phase_pattern_index = 0
	else:
		phase_pattern_index = (phase_pattern_index + 1) % candidates.size()
	var selected: Dictionary = candidates[phase_pattern_index % candidates.size()]
	active_attack_pattern = str(selected.get("id", "shield_lane_sweep_pool_v1"))
	active_pattern_phase = int(selected.get("phase", phase))
	active_pattern_duration = float(selected.get("duration", 2.2))
	pattern_timer = active_pattern_duration


func _recalculate_total_hp() -> void:
	total_hp = 0.0
	for key in parts.keys():
		total_hp += float(parts[key].get("hp", 0.0))


func _part_ratio(part_name: String) -> float:
	if not parts.has(part_name):
		return 0.0
	var part: Dictionary = parts[part_name]
	return clamp(float(part.get("hp", 0.0)) / max(1.0, float(part.get("max", 1.0))), 0.0, 1.0)


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
