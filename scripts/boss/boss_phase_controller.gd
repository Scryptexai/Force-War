extends Node
class_name BossPhaseController

# Data-oriented first boss controller for the forward-air vertical slice.
# The visible boss GLB is owned by ForwardArenaDirector; this node owns gameplay
# phase/part health state so the boss is not just a decorative health bar.

var active := false
var boss_name := "Dreadnought Leviathan"
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


func start_mission(stage_data: Dictionary) -> void:
	active = true
	var threat := float(stage_data.get("threat", 1.0))
	max_hp = 6600.0 + threat * 900.0
	_reset_parts(threat)
	phase = 1
	phase_name = "PHASE_1_SHIELD"
	fire_pressure = 0.0
	destroyed_parts.clear()
	_recalculate_total_hp()


func stop_mission() -> void:
	active = false


func update_boss(delta: float, overcharged: bool, player_pressure: float) -> void:
	if not active:
		return
	fire_pressure = lerp(fire_pressure, player_pressure, min(1.0, delta * 2.5))
	var damage := delta * (125.0 + player_pressure * 95.0) * (1.35 if overcharged else 1.0)
	_apply_damage_to_current_target(damage)
	_update_phase()
	_recalculate_total_hp()


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
		"bossFirePressure": fire_pressure
	}


func get_hp_ratio() -> float:
	return clamp(total_hp / max(1.0, max_hp), 0.0, 1.0)


func _reset_parts(threat: float) -> void:
	parts = {
		"shield": {"hp": 2300.0 + threat * 220.0, "max": 2300.0 + threat * 220.0, "required_phase": 1},
		"left_wing": {"hp": 900.0 + threat * 80.0, "max": 900.0 + threat * 80.0, "required_phase": 2},
		"right_wing": {"hp": 900.0 + threat * 80.0, "max": 900.0 + threat * 80.0, "required_phase": 2},
		"turrets": {"hp": 1180.0 + threat * 130.0, "max": 1180.0 + threat * 130.0, "required_phase": 2},
		"core": {"hp": 1980.0 + threat * 260.0, "max": 1980.0 + threat * 260.0, "required_phase": 3}
	}
	max_hp = 0.0
	for key in parts.keys():
		max_hp += float(parts[key].get("max", 0.0))
	total_hp = max_hp


func _apply_damage_to_current_target(amount: float) -> void:
	var target := "shield"
	if phase >= 3:
		target = "core"
	elif phase >= 2:
		if _part_ratio("turrets") > 0.0:
			target = "turrets"
		elif _part_ratio("left_wing") > _part_ratio("right_wing"):
			target = "left_wing"
		else:
			target = "right_wing"
	_apply_part_damage(target, amount)


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


func _recalculate_total_hp() -> void:
	total_hp = 0.0
	for key in parts.keys():
		total_hp += float(parts[key].get("hp", 0.0))


func _part_ratio(part_name: String) -> float:
	if not parts.has(part_name):
		return 0.0
	var part: Dictionary = parts[part_name]
	return clamp(float(part.get("hp", 0.0)) / max(1.0, float(part.get("max", 1.0))), 0.0, 1.0)
