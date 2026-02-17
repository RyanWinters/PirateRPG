extends RefCounted
class_name StreetEvents

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func set_rng_seed(seed: int) -> void:
	_rng.seed = seed


func set_rng_source(rng: RandomNumberGenerator) -> void:
	if rng == null:
		return
	_rng = rng


func roll_chance(chance: float) -> bool:
	return _rng.randf() < clampf(chance, 0.0, 1.0)


func roll_weighted(definitions: Array[Dictionary]) -> Dictionary:
	if definitions.is_empty():
		return {}

	var total_weight: float = 0.0
	for definition: Dictionary in definitions:
		total_weight += maxf(0.0, float(definition.get("weight", 0.0)))

	if total_weight <= 0.0:
		return {}

	var roll: float = _rng.randf_range(0.0, total_weight)
	var cursor: float = 0.0
	for definition: Dictionary in definitions:
		cursor += maxf(0.0, float(definition.get("weight", 0.0)))
		if roll <= cursor:
			return definition.duplicate(true)

	return definitions[definitions.size() - 1].duplicate(true)


func roll_event_payload(definitions: Array[Dictionary]) -> Dictionary:
	var event_payload: Dictionary = roll_weighted(definitions)
	if event_payload.is_empty():
		return {}

	var event_id: StringName = StringName(str(event_payload.get("id", "unknown")))
	event_payload["id"] = event_id
	if event_id == &"rival_thief":
		var win_chance: float = float(event_payload.get("win_chance", 0.5))
		event_payload["outcome"] = "win" if roll_chance(win_chance) else "loss"
	return event_payload
