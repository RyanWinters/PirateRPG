extends RefCounted
class_name ExpeditionTemplates

const TEMPLATE_SMUGGLING: StringName = &"smuggling"
const TEMPLATE_FISHING: StringName = &"fishing"
const TEMPLATE_RAIDING: StringName = &"raiding"

const DEFAULT_RISK_ROLLS: int = 100

const TEMPLATES: Dictionary = {
	TEMPLATE_SMUGGLING: {
		"key": TEMPLATE_SMUGGLING,
		"base_duration_seconds": 420,
		"risk_profile": {
			"failure_chance": 0.2,
			"hazards": {
				"coast_guard": 0.5,
				"cargo_loss": 0.35,
				"betrayal": 0.15,
			},
		},
		"reward_table": {
			"success": {
				"gold": Vector2i(45, 90),
				"food": Vector2i(0, 3),
			},
			"failure": {
				"gold": Vector2i(5, 25),
				"food": Vector2i(0, 1),
			},
		},
		"minimum_crew": 2,
		"minimum_stats": {
			"stealth": 35,
			"loyalty": 30,
		},
		"unlock_requirement": {
			"required_phase": GameState.Phase.THUG,
		},
	},
	TEMPLATE_FISHING: {
		"key": TEMPLATE_FISHING,
		"base_duration_seconds": 300,
		"risk_profile": {
			"failure_chance": 0.08,
			"hazards": {
				"storm": 0.65,
				"spoiled_catch": 0.35,
			},
		},
		"reward_table": {
			"success": {
				"gold": Vector2i(12, 32),
				"food": Vector2i(10, 26),
			},
			"failure": {
				"gold": Vector2i(0, 8),
				"food": Vector2i(3, 9),
			},
		},
		"minimum_crew": 1,
		"minimum_stats": {
			"loyalty": 20,
		},
	},
	TEMPLATE_RAIDING: {
		"key": TEMPLATE_RAIDING,
		"base_duration_seconds": 540,
		"risk_profile": {
			"failure_chance": 0.35,
			"hazards": {
				"navy_counterattack": 0.45,
				"boarding_losses": 0.4,
				"captain_injured": 0.15,
			},
		},
		"reward_table": {
			"success": {
				"gold": Vector2i(85, 170),
				"food": Vector2i(8, 20),
			},
			"failure": {
				"gold": Vector2i(15, 45),
				"food": Vector2i(0, 6),
			},
		},
		"minimum_crew": 4,
		"minimum_stats": {
			"combat": 45,
			"loyalty": 40,
		},
		"unlock_requirement": {
			"required_phase": GameState.Phase.CAPTAIN,
		},
	},
}

var _fallback_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_fallback_rng.randomize()


func get_template(template_key: StringName) -> Dictionary:
	if not TEMPLATES.has(template_key):
		return {}
	return (TEMPLATES[template_key] as Dictionary).duplicate(true)


func list_templates() -> Array[Dictionary]:
	var templates: Array[Dictionary] = []
	for template_key: StringName in TEMPLATES.keys():
		templates.append(get_template(template_key))
	return templates


func list_unlocked_templates(progression_state: Dictionary) -> Array[Dictionary]:
	var unlocked_templates: Array[Dictionary] = []
	for template_key: StringName in TEMPLATES.keys():
		var template: Dictionary = get_template(template_key)
		if template.is_empty():
			continue
		if not is_template_unlocked(template, progression_state):
			continue
		unlocked_templates.append(template)
	return unlocked_templates


func is_template_unlocked(template: Dictionary, progression_state: Dictionary) -> bool:
	if template.is_empty():
		return false

	var crew_count: int = int(progression_state.get("crew_count", 0))
	if crew_count < int(template.get("minimum_crew", 0)):
		return false

	var crew_stats: Dictionary = progression_state.get("crew_stats", {}) as Dictionary
	var minimum_stats: Dictionary = template.get("minimum_stats", {}) as Dictionary
	for stat_name: Variant in minimum_stats.keys():
		if float(crew_stats.get(stat_name, 0.0)) < float(minimum_stats[stat_name]):
			return false

	var unlock_requirement: Dictionary = template.get("unlock_requirement", {}) as Dictionary
	if unlock_requirement.has("required_phase"):
		if int(progression_state.get("phase", 0)) < int(unlock_requirement["required_phase"]):
			return false
	if unlock_requirement.has("requires_upgrade"):
		var upgrades: Array = progression_state.get("upgrades", []) as Array
		var required_upgrade: StringName = StringName(str(unlock_requirement["requires_upgrade"]))
		if not upgrades.has(required_upgrade):
			return false

	return true


func resolve_risk_outcome(template_key: StringName, crew_stats: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var template: Dictionary = get_template(template_key)
	if template.is_empty():
		return {}

	var effective_rng: RandomNumberGenerator = _resolve_rng(rng)
	var risk_profile: Dictionary = template.get("risk_profile", {}) as Dictionary
	var base_failure_chance: float = clampf(float(risk_profile.get("failure_chance", 0.0)), 0.0, 1.0)
	var mitigation: float = _calculate_risk_mitigation(crew_stats)
	var adjusted_failure_chance: float = clampf(base_failure_chance * (1.0 - mitigation), 0.0, 1.0)
	var is_failure: bool = effective_rng.randf() < adjusted_failure_chance

	var outcome: Dictionary = {
		"template_key": template_key,
		"status": &"failure" if is_failure else &"success",
		"failure_chance": adjusted_failure_chance,
	}
	if is_failure:
		outcome["hazard"] = _roll_weighted_name(risk_profile.get("hazards", {}) as Dictionary, effective_rng)
	return outcome


func resolve_rewards(template_key: StringName, risk_outcome: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var template: Dictionary = get_template(template_key)
	if template.is_empty():
		return {}

	var outcome_status: StringName = StringName(str(risk_outcome.get("status", "success")))
	var reward_table: Dictionary = template.get("reward_table", {}) as Dictionary
	var reward_definitions: Dictionary = reward_table.get(outcome_status, {}) as Dictionary
	var effective_rng: RandomNumberGenerator = _resolve_rng(rng)

	var resolved_rewards: Dictionary = {}
	for resource_name: Variant in reward_definitions.keys():
		var reward_range: Variant = reward_definitions[resource_name]
		if reward_range is Vector2i:
			var bounds: Vector2i = reward_range as Vector2i
			resolved_rewards[resource_name] = effective_rng.randi_range(bounds.x, bounds.y)
			continue
		resolved_rewards[resource_name] = int(reward_range)
	return resolved_rewards


func simulate_expedition(template_key: StringName, crew_stats: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var risk_outcome: Dictionary = resolve_risk_outcome(template_key, crew_stats, rng)
	if risk_outcome.is_empty():
		return {}

	var rewards: Dictionary = resolve_rewards(template_key, risk_outcome, rng)
	return {
		"risk": risk_outcome,
		"rewards": rewards,
	}


func _resolve_rng(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	if rng != null:
		return rng
	return _fallback_rng


func _calculate_risk_mitigation(crew_stats: Dictionary) -> float:
	var stealth: float = float(crew_stats.get("stealth", 0.0))
	var combat: float = float(crew_stats.get("combat", 0.0))
	var loyalty: float = float(crew_stats.get("loyalty", 0.0))
	var weighted_score: float = (stealth * 0.45) + (combat * 0.35) + (loyalty * 0.20)
	return clampf(weighted_score / (100.0 * 1.75), 0.0, 0.45)


func _roll_weighted_name(weights: Dictionary, rng: RandomNumberGenerator) -> StringName:
	if weights.is_empty():
		return &"none"

	var total_weight: float = 0.0
	for key: Variant in weights.keys():
		total_weight += maxf(0.0, float(weights[key]))
	if total_weight <= 0.0:
		return &"none"

	var roll: float = rng.randf_range(0.0, total_weight)
	var cursor: float = 0.0
	for key: Variant in weights.keys():
		cursor += maxf(0.0, float(weights[key]))
		if roll <= cursor:
			return StringName(str(key))
	return StringName(str(weights.keys()[weights.size() - 1]))
