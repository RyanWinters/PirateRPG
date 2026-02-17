extends Node
class_name SaveManager

# Save file path: user://savegame.json
# Keys used in payload:
# - save_version: integer schema version.
# - resources: Dictionary[String -> int]
# - crew_roster: Array[Dictionary] (each crew entry has id, name, role, level, loyalty).
# - current_phase: integer progression phase.
# - last_save_unix: integer unix timestamp for most recent write.
# - last_active_unix: integer unix timestamp for most recent in-session activity.
const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

@export var debug_logging_enabled: bool = false

const DEFAULT_CREW_MEMBER := {
	"id": "",
	"name": "",
	"role": "deckhand",
	"level": 1,
	"loyalty": 100.0,
}

const DEFAULT_SAVE_STATE := {
	"save_version": SAVE_VERSION,
	"resources": {
		"gold": 0,
		"food": 0,
	},
	"crew_roster": [],
	"current_phase": 0,
	"last_save_unix": 0,
	"last_active_unix": 0,
	"last_steal_click_msec": -225,
	"passive_tick_accumulator": 0.0,
	"street_xp": 0,
	"street_level": 1,
	"street_upgrades_unlocked": false,
	"first_crew_slot_unlocked": false,
}


func get_default_state() -> Dictionary:
	var defaults: Dictionary = DEFAULT_SAVE_STATE.duplicate(true)
	defaults["save_version"] = SAVE_VERSION
	return defaults


func save_game(state: Dictionary) -> bool:
	return _save_game_with_reason(state, &"manual_save")


func save_on_quit(state: Dictionary) -> bool:
	return _save_game_with_reason(state, &"app_quit")


func save_on_background(state: Dictionary) -> bool:
	return _save_game_with_reason(state, &"app_background")


func touch_last_active_unix(state: Dictionary, now_unix: int = Time.get_unix_time_from_system()) -> Dictionary:
	var normalized_state: Dictionary = _normalize_state(state)
	normalized_state["last_active_unix"] = maxi(0, now_unix)
	return normalized_state


func load_game() -> Dictionary:
	var defaults: Dictionary = get_default_state()
	if not FileAccess.file_exists(SAVE_PATH):
		return defaults

	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		push_error("Unable to open save file for read: %s" % SAVE_PATH)
		return defaults

	var raw_text: String = save_file.get_as_text()
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save payload is corrupted or not a dictionary. Falling back to defaults.")
		return defaults

	var payload: Dictionary = parsed
	var migrated: Dictionary = _migrate_save_payload(payload)
	return _normalize_state(migrated)


func _save_game_with_reason(state: Dictionary, reason: StringName) -> bool:
	var now_unix: int = Time.get_unix_time_from_system()
	var normalized_state: Dictionary = _normalize_state(state)
	normalized_state["save_version"] = SAVE_VERSION
	normalized_state["last_save_unix"] = now_unix
	normalized_state["last_active_unix"] = now_unix

	var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_error("Unable to open save file for write: %s" % SAVE_PATH)
		return false

	save_file.store_string(JSON.stringify(normalized_state))
	_debug_log("Saved game (%s) with last_active_unix=%d." % [String(reason), now_unix])
	return true


func _migrate_save_payload(payload: Dictionary) -> Dictionary:
	var version: int = int(payload.get("save_version", 1))
	var migrated: Dictionary = payload.duplicate(true)

	while version < SAVE_VERSION:
		match version:
			# Future migrations should be added here, for example:
			# 1:
			# 	migrated = _migrate_v1_to_v2(migrated)
			_:
				push_warning("Unknown legacy save version %d. Using normalized fallback values." % version)
				version = SAVE_VERSION
				break

	migrated["save_version"] = SAVE_VERSION
	return migrated


func _normalize_state(payload: Dictionary) -> Dictionary:
	var normalized: Dictionary = get_default_state()

	var incoming_resources: Variant = payload.get("resources", {})
	if typeof(incoming_resources) == TYPE_DICTIONARY:
		for resource_name: Variant in incoming_resources.keys():
			normalized["resources"][str(resource_name)] = int(incoming_resources[resource_name])

	var incoming_crew: Variant = payload.get("crew_roster", [])
	if typeof(incoming_crew) == TYPE_ARRAY:
		var normalized_roster: Array = []
		for crew_member: Variant in incoming_crew:
			if typeof(crew_member) != TYPE_DICTIONARY:
				continue
			var normalized_member: Dictionary = DEFAULT_CREW_MEMBER.duplicate(true)
			normalized_member["id"] = str(crew_member.get("id", normalized_member["id"]))
			normalized_member["name"] = str(crew_member.get("name", normalized_member["name"]))
			normalized_member["role"] = str(crew_member.get("role", normalized_member["role"]))
			normalized_member["level"] = maxi(1, int(crew_member.get("level", normalized_member["level"])))
			normalized_member["loyalty"] = clampf(float(crew_member.get("loyalty", normalized_member["loyalty"])), 0.0, 100.0)
			normalized_roster.append(normalized_member)
		normalized["crew_roster"] = normalized_roster

	normalized["current_phase"] = maxi(0, int(payload.get("current_phase", normalized["current_phase"])))
	normalized["last_save_unix"] = maxi(0, int(payload.get("last_save_unix", normalized["last_save_unix"])))
	normalized["last_active_unix"] = maxi(0, int(payload.get("last_active_unix", normalized["last_active_unix"])))
	normalized["last_steal_click_msec"] = int(payload.get("last_steal_click_msec", normalized["last_steal_click_msec"]))
	normalized["passive_tick_accumulator"] = clampf(float(payload.get("passive_tick_accumulator", normalized["passive_tick_accumulator"])), 0.0, 1.0)
	normalized["street_xp"] = maxi(0, int(payload.get("street_xp", normalized["street_xp"])))
	normalized["street_level"] = maxi(1, int(payload.get("street_level", normalized["street_level"])))
	normalized["street_upgrades_unlocked"] = bool(payload.get("street_upgrades_unlocked", normalized["street_upgrades_unlocked"]))
	normalized["first_crew_slot_unlocked"] = bool(payload.get("first_crew_slot_unlocked", normalized["first_crew_slot_unlocked"]))
	normalized["save_version"] = SAVE_VERSION

	return normalized


func _debug_log(message: String) -> void:
	if not debug_logging_enabled:
		return
	print("[SaveManager] %s" % message)
