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
@export var time_manager_path: NodePath = NodePath("/root/TimeManager")

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


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_persist_on_background()
		NOTIFICATION_APPLICATION_RESUMED:
			_process_resume_cycle()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_persist_on_quit()


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
	_mark_active()
	var save_state: Dictionary = _build_save_state()
	var was_saved: bool = save_manager.save_game(save_state)
	if was_saved:
		var now_unix: int = Time.get_unix_time_from_system()
		_last_save_unix = now_unix
		_last_active_unix = now_unix
	return was_saved


func load_state() -> void:
	var save_manager: SaveManager = _get_save_manager()
	if save_manager == null:
		push_error("SaveManager not found at path: %s" % save_manager_path)
		return
	var loaded_state: Dictionary = save_manager.load_game()
	_apply_loaded_state(loaded_state)
	var time_manager: TimeManager = _get_time_manager()
	if time_manager != null:
		time_manager.begin_offline_cycle_from_save_data(loaded_state)


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


func _get_time_manager() -> TimeManager:
	var node: Node = get_node_or_null(time_manager_path)
	if node is TimeManager:
		return node as TimeManager
	return null


func _mark_active() -> void:
	_last_active_unix = Time.get_unix_time_from_system()


func _persist_on_background() -> void:
	var save_manager: SaveManager = _get_save_manager()
	if save_manager == null:
		return
	_mark_active()
	var now_unix: int = Time.get_unix_time_from_system()
	var was_saved: bool = save_manager.save_on_background(_build_save_state())
	if was_saved:
		_last_save_unix = now_unix


func _persist_on_quit() -> void:
	var save_manager: SaveManager = _get_save_manager()
	if save_manager == null:
		return
	_mark_active()
	var now_unix: int = Time.get_unix_time_from_system()
	var was_saved: bool = save_manager.save_on_quit(_build_save_state())
	if was_saved:
		_last_save_unix = now_unix


func _process_resume_cycle() -> void:
	var time_manager: TimeManager = _get_time_manager()
	if time_manager == null:
		return
	time_manager.begin_offline_cycle(_last_active_unix)



func _on_resource_changed(resource_name: StringName, _old_value: int, new_value: int, source: StringName) -> void:
	if String(source).begins_with("GameState"):
		return
	_resources[resource_name] = new_value


func _on_phase_changed(_old_phase: int, new_phase: int, reason: StringName) -> void:
	if String(reason).begins_with("GameState"):
		return
	_phase = new_phase


func _on_offline_progress_ready(elapsed_seconds: int) -> void:
	if elapsed_seconds <= 0:
		return
	var time_manager: TimeManager = _get_time_manager()
	var simulated_ticks: int = 0
	if time_manager != null:
		simulated_ticks = time_manager.elapsed_to_ticks(elapsed_seconds)
	var gold_per_second: float = _get_gold_income_per_second_for_phase(_phase)
	var offline_gold: int = int(round(elapsed_seconds * gold_per_second))
	if offline_gold > 0:
		add_resource(&"gold", offline_gold, &"GameState.offline_progress")
	if simulated_ticks > 0:
		add_resource(&"food", simulated_ticks, &"GameState.offline_progress_ticks")


func _get_gold_income_per_second_for_phase(phase: int) -> float:
	match phase:
		Phase.PICKPOCKET:
			return 1.0
		Phase.THUG:
			return 2.0
		Phase.CAPTAIN:
			return 3.0
		_:
			return 5.0
