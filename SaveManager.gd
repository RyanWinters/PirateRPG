extends Node
class_name SaveManager

const SAVE_PATH := "user://savegame.json"

var _cached_resources: Dictionary = {}
var _cached_phase: int = 0
var _last_saved_unix: int = 0


func _ready() -> void:
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.mutiny_warning.connect(_on_mutiny_warning)


func save_game() -> void:
	var payload: Dictionary = {
		"resources": _cached_resources,
		"phase": _cached_phase,
		"last_saved_unix": Time.get_unix_time_from_system(),
	}
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_error("Unable to open save file for write: %s" % SAVE_PATH)
		return
	save_file.store_string(JSON.stringify(payload))
	_last_saved_unix = payload["last_saved_unix"]


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		push_error("Unable to open save file for read: %s" % SAVE_PATH)
		return
	var parsed: Variant = JSON.parse_string(save_file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid save payload")
		return

	var payload: Dictionary = parsed
	_last_saved_unix = int(payload.get("last_saved_unix", 0))

	var loaded_resources: Dictionary = payload.get("resources", {})
	for resource_name: StringName in loaded_resources.keys():
		var value: int = int(loaded_resources[resource_name])
		EventBus.resource_changed.emit(resource_name, int(_cached_resources.get(resource_name, 0)), value, &"SaveManager.load_game")

	var loaded_phase: int = int(payload.get("phase", _cached_phase))
	EventBus.phase_changed.emit(_cached_phase, loaded_phase, &"SaveManager.load_game")


func get_last_saved_unix() -> int:
	return _last_saved_unix


func _on_resource_changed(resource_name: StringName, _old_value: int, new_value: int, _source: StringName) -> void:
	_cached_resources[resource_name] = new_value


func _on_phase_changed(_old_phase: int, new_phase: int, _reason: StringName) -> void:
	_cached_phase = new_phase


func _on_mutiny_warning(current_loyalty: float, threshold: float, eta_seconds: float) -> void:
	print("Mutiny warning: loyalty %.2f <= %.2f (eta %.2fs)" % [current_loyalty, threshold, eta_seconds])
