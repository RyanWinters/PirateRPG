extends RefCounted
class_name CrewMember

const MIN_STAT: int = 0
const MAX_STAT: int = 100
const MIN_UPKEEP: int = 0
const MAX_UPKEEP: int = 100

var id: String
var name: String
var combat: int
var stealth: int
var loyalty: int
var upkeep: int
var assignment: String


func _init(
	new_id: String = "",
	new_name: String = "Deckhand",
	new_combat: int = 25,
	new_stealth: int = 25,
	new_loyalty: int = 50,
	new_upkeep: int = 1,
	new_assignment: String = ""
) -> void:
	id = _normalize_id(new_id)
	name = _normalize_name(new_name)
	combat = _clamp_stat(new_combat)
	stealth = _clamp_stat(new_stealth)
	loyalty = _clamp_stat(new_loyalty)
	upkeep = clampi(new_upkeep, MIN_UPKEEP, MAX_UPKEEP)
	assignment = _normalize_assignment(new_assignment)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"combat": combat,
		"stealth": stealth,
		"loyalty": loyalty,
		"upkeep": upkeep,
		"assignment": assignment,
	}


static func from_dict(payload: Dictionary) -> CrewMember:
	return CrewMember.new(
		str(payload.get("id", "")),
		str(payload.get("name", "Deckhand")),
		int(payload.get("combat", 25)),
		int(payload.get("stealth", 25)),
		int(payload.get("loyalty", 50)),
		int(payload.get("upkeep", 1)),
		str(payload.get("assignment", ""))
	)


func is_assigned() -> bool:
	return not assignment.is_empty()


func set_assignment(new_assignment: String) -> void:
	assignment = _normalize_assignment(new_assignment)


static func _clamp_stat(value: int) -> int:
	return clampi(value, MIN_STAT, MAX_STAT)


static func _normalize_name(raw_name: String) -> String:
	var cleaned_name: String = raw_name.strip_edges()
	if cleaned_name.is_empty():
		return "Deckhand"
	return cleaned_name


static func _normalize_id(raw_id: String) -> String:
	var cleaned_id: String = raw_id.strip_edges()
	if not cleaned_id.is_empty():
		return cleaned_id
	var unix_msec: int = Time.get_unix_time_from_system() * 1000
	var random_bits: int = randi()
	return "crew_%d_%d" % [unix_msec, random_bits]


static func _normalize_assignment(raw_assignment: String) -> String:
	return raw_assignment.strip_edges()
