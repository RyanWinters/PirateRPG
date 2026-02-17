extends Node
class_name GameState

enum Phase {
	PICKPOCKET,
	THUG,
	CAPTAIN,
	PIRATE_KING,
}

const MUTINY_THRESHOLD: float = 25.0

@export var save_manager_path: NodePath = NodePath("/root/SaveManager")

var _resources: Dictionary = {
	"gold": 0,
	"food": 0,
}
var _crew_roster: Array = []
var _loyalty: float = 100.0
var _phase: int = Phase.PICKPOCKET
var _last_save_unix: int = 0
var _last_active_unix: int = 0


func _ready() -> void:
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.offline_progress_ready.connect(_on_offline_progress_ready)


func get_phase() -> int:
	return _phase


func set_phase(new_phase: int, reason: StringName = &"GameState.set_phase") -> void:
	if new_phase == _phase:
		return
	var old_phase: int = _phase
	_phase = new_phase
	_mark_active()
	EventBus.phase_changed.emit(old_phase, _phase, reason)


func get_resource(resource_name: StringName) -> int:
	return int(_resources.get(resource_name, 0))


func set_resource(resource_name: StringName, new_value: int, source: StringName = &"GameState.set_resource") -> void:
	var old_value: int = get_resource(resource_name)
	if old_value == new_value:
		return
	_resources[resource_name] = new_value
	_mark_active()
	EventBus.resource_changed.emit(resource_name, old_value, new_value, source)


func add_resource(resource_name: StringName, amount: int, source: StringName = &"GameState.add_resource") -> void:
	set_resource(resource_name, get_resource(resource_name) + amount, source)


func set_loyalty(new_loyalty: float) -> void:
	_loyalty = clampf(new_loyalty, 0.0, 100.0)
	_mark_active()
	if _loyalty <= MUTINY_THRESHOLD:
		EventBus.mutiny_warning.emit(_loyalty, MUTINY_THRESHOLD, 60.0)


func set_crew_roster(roster: Array) -> void:
	_crew_roster = roster.duplicate(true)
	_mark_active()


func get_crew_roster() -> Array:
	return _crew_roster.duplicate(true)


func save_state() -> bool:
	var save_manager: SaveManager = _get_save_manager()
	if save_manager == null:
		push_error("SaveManager not found at path: %s" % save_manager_path)
		return false
	return save_manager.save_game(_build_save_state())


func load_state() -> void:
	var save_manager: SaveManager = _get_save_manager()
	if save_manager == null:
		push_error("SaveManager not found at path: %s" % save_manager_path)
		return
	_apply_loaded_state(save_manager.load_game())


func _build_save_state() -> Dictionary:
	return {
		"resources": _resources.duplicate(true),
		"crew_roster": _crew_roster.duplicate(true),
		"current_phase": _phase,
		"last_save_unix": _last_save_unix,
		"last_active_unix": _last_active_unix,
	}


func _apply_loaded_state(state: Dictionary) -> void:
	var loaded_resources: Dictionary = state.get("resources", {})
	for resource_name: Variant in loaded_resources.keys():
		var key: StringName = StringName(str(resource_name))
		var old_value: int = get_resource(key)
		var new_value: int = int(loaded_resources[resource_name])
		if old_value == new_value:
			continue
		_resources[key] = new_value
		EventBus.resource_changed.emit(key, old_value, new_value, &"SaveManager.load_game")

	_crew_roster = (state.get("crew_roster", []) as Array).duplicate(true)
	set_phase(int(state.get("current_phase", _phase)), &"SaveManager.load_game")
	_last_save_unix = int(state.get("last_save_unix", 0))
	_last_active_unix = int(state.get("last_active_unix", 0))


func _get_save_manager() -> SaveManager:
	var node: Node = get_node_or_null(save_manager_path)
	if node is SaveManager:
		return node as SaveManager
	return null


func _mark_active() -> void:
	_last_active_unix = Time.get_unix_time_from_system()


func _on_resource_changed(resource_name: StringName, _old_value: int, new_value: int, source: StringName) -> void:
	if String(source).begins_with("GameState"):
		return
	_resources[resource_name] = new_value


func _on_phase_changed(_old_phase: int, new_phase: int, reason: StringName) -> void:
	if String(reason).begins_with("GameState"):
		return
	_phase = new_phase


func _on_offline_progress_ready(_elapsed_seconds: int, reward_snapshot: Dictionary, _simulated_ticks: int) -> void:
	for resource_name: StringName in reward_snapshot.keys():
		add_resource(resource_name, int(reward_snapshot[resource_name]), &"GameState.offline_progress")
