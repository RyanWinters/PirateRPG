extends Node
class_name GameState

enum Phase {
	PICKPOCKET,
	THUG,
	CAPTAIN,
	PIRATE_KING,
}

const MUTINY_THRESHOLD: float = 25.0
const DEBUG_BUILD_FEATURE: StringName = &"debug"
const DEBUG_COMMAND_SOURCE: StringName = &"DebugCommand"

const THUG_UNLOCK_GOLD: int = 100
const CAPTAIN_UNLOCK_GOLD: int = 750
const CAPTAIN_UNLOCK_CREW: int = 3
const PIRATE_KING_UNLOCK_GOLD: int = 2500
const PIRATE_KING_UNLOCK_CREW: int = 8
const PIRATE_KING_UNLOCK_LOYALTY: float = 70.0

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




func _unhandled_input(event: InputEvent) -> void:
	if not _is_debug_commands_enabled():
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_F6:
			execute_debug_command("add_resource gold 100")
			get_viewport().set_input_as_handled()
		KEY_F7:
			execute_debug_command("set_resource food 50")
			get_viewport().set_input_as_handled()
		KEY_F8:
			execute_debug_command("set_phase captain")
			get_viewport().set_input_as_handled()

func get_phase() -> int:
	return _phase


func set_phase(new_phase: int, reason: StringName = &"GameState.set_phase") -> void:
	if new_phase == _phase:
		return
	if not _can_set_phase(new_phase, reason):
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
	_evaluate_phase_unlocks(source)


func add_resource(resource_name: StringName, amount: int, source: StringName = &"GameState.add_resource") -> void:
	set_resource(resource_name, get_resource(resource_name) + amount, source)


func set_loyalty(new_loyalty: float) -> void:
	_loyalty = clampf(new_loyalty, 0.0, 100.0)
	_mark_active()
	if _loyalty <= MUTINY_THRESHOLD:
		EventBus.mutiny_warning.emit(_loyalty, MUTINY_THRESHOLD, 60.0)
	_evaluate_phase_unlocks(&"GameState.set_loyalty")


func set_crew_roster(roster: Array) -> void:
	_crew_roster = roster.duplicate(true)
	_mark_active()
	_evaluate_phase_unlocks(&"GameState.set_crew_roster")


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


func execute_debug_command(raw_command: String) -> bool:
	if not _is_debug_commands_enabled():
		_emit_debug_feedback(false, raw_command, "Debug commands are disabled in this build.")
		return false

	var trimmed_command: String = raw_command.strip_edges()
	if trimmed_command.is_empty():
		_emit_debug_feedback(false, raw_command, "Command cannot be empty.")
		return false

	var command_parts: PackedStringArray = trimmed_command.split(" ", false)
	if command_parts.is_empty():
		_emit_debug_feedback(false, raw_command, "Command cannot be empty.")
		return false

	var command_name: String = command_parts[0].to_lower()
	match command_name:
		"set_resource":
			return _execute_set_resource_command(command_parts, trimmed_command)
		"add_resource":
			return _execute_add_resource_command(command_parts, trimmed_command)
		"set_phase":
			return _execute_set_phase_command(command_parts, trimmed_command)
		_:
			_emit_debug_feedback(false, trimmed_command, "Unknown debug command '%s'." % command_name)
			return false


func get_debug_command_help_lines() -> PackedStringArray:
	return PackedStringArray([
		"set_resource <type> <amount> (amount must be >= 0)",
		"add_resource <type> <amount>",
		"set_phase <phase_name>",
		"Valid resource keys: %s" % ", ".join(_get_valid_resource_names()),
		"Valid phase names: %s" % ", ".join(_get_valid_phase_names()),
	])


func _execute_set_resource_command(command_parts: PackedStringArray, raw_command: String) -> bool:
	if command_parts.size() != 3:
		_emit_debug_feedback(false, raw_command, "Usage: set_resource <type> <amount>")
		return false

	var resource_name: StringName = StringName(command_parts[1].to_lower())
	if not _resources.has(resource_name):
		_emit_debug_feedback(false, raw_command, "Invalid resource key '%s'. Valid keys: %s" % [command_parts[1], ", ".join(_get_valid_resource_names())])
		return false

	if not command_parts[2].is_valid_int():
		_emit_debug_feedback(false, raw_command, "Amount must be a whole number.")
		return false

	var amount: int = int(command_parts[2])
	if amount < 0:
		_emit_debug_feedback(false, raw_command, "Amount cannot be negative for set_resource.")
		return false

	set_resource(resource_name, amount, DEBUG_COMMAND_SOURCE)
	_emit_debug_feedback(true, raw_command, "Set %s to %d." % [String(resource_name), amount])
	return true


func _execute_add_resource_command(command_parts: PackedStringArray, raw_command: String) -> bool:
	if command_parts.size() != 3:
		_emit_debug_feedback(false, raw_command, "Usage: add_resource <type> <amount>")
		return false

	var resource_name: StringName = StringName(command_parts[1].to_lower())
	if not _resources.has(resource_name):
		_emit_debug_feedback(false, raw_command, "Invalid resource key '%s'. Valid keys: %s" % [command_parts[1], ", ".join(_get_valid_resource_names())])
		return false

	if not command_parts[2].is_valid_int():
		_emit_debug_feedback(false, raw_command, "Amount must be a whole number.")
		return false

	var amount: int = int(command_parts[2])
	if amount < 0:
		_emit_debug_feedback(false, raw_command, "Amount cannot be negative for add_resource.")
		return false

	add_resource(resource_name, amount, DEBUG_COMMAND_SOURCE)
	_emit_debug_feedback(true, raw_command, "Added %d %s." % [amount, String(resource_name)])
	return true


func _execute_set_phase_command(command_parts: PackedStringArray, raw_command: String) -> bool:
	if command_parts.size() != 2:
		_emit_debug_feedback(false, raw_command, "Usage: set_phase <phase_name>")
		return false

	var phase_name: String = command_parts[1].to_lower()
	if not _is_valid_phase_name(phase_name):
		_emit_debug_feedback(false, raw_command, "Unknown phase name '%s'. Valid names: %s" % [command_parts[1], ", ".join(_get_valid_phase_names())])
		return false

	var phase_value: int = _phase_value_from_name(phase_name)
	set_phase(phase_value, DEBUG_COMMAND_SOURCE)
	_emit_debug_feedback(true, raw_command, "Set phase to %s." % phase_name)
	return true


func can_unlock_phase(phase: int) -> bool:
	return _meets_unlock_conditions(phase)


func get_next_unlockable_phase() -> int:
	var next_phase: int = _phase + 1
	if next_phase > Phase.PIRATE_KING:
		return -1
	if _meets_unlock_conditions(next_phase):
		return next_phase
	return -1


func _can_set_phase(new_phase: int, reason: StringName) -> bool:
	if new_phase < Phase.PICKPOCKET or new_phase > Phase.PIRATE_KING:
		push_warning("Attempted to set invalid phase value: %d" % new_phase)
		return false
	if _is_phase_override_reason(reason):
		return true
	if new_phase <= _phase:
		return true
	if new_phase != _phase + 1:
		push_warning("Phase progression must advance sequentially. Current=%d Requested=%d" % [_phase, new_phase])
		return false
	if not _meets_unlock_conditions(new_phase):
		push_warning("Unlock conditions are not met for phase %s." % _phase_name_from_value(new_phase))
		return false
	return true


func _is_phase_override_reason(reason: StringName) -> bool:
	return reason == DEBUG_COMMAND_SOURCE or String(reason).begins_with("SaveManager")


func _evaluate_phase_unlocks(source: StringName) -> void:
	if source == DEBUG_COMMAND_SOURCE:
		return
	if String(source).begins_with("SaveManager"):
		return
	var next_phase: int = _phase + 1
	while next_phase <= Phase.PIRATE_KING and _meets_unlock_conditions(next_phase):
		set_phase(next_phase, &"GameState.auto_unlock")
		next_phase = _phase + 1


func _meets_unlock_conditions(phase: int) -> bool:
	match phase:
		Phase.PICKPOCKET:
			return true
		Phase.THUG:
			return get_resource(&"gold") >= THUG_UNLOCK_GOLD
		Phase.CAPTAIN:
			return get_resource(&"gold") >= CAPTAIN_UNLOCK_GOLD and _crew_roster.size() >= CAPTAIN_UNLOCK_CREW
		Phase.PIRATE_KING:
			return get_resource(&"gold") >= PIRATE_KING_UNLOCK_GOLD and _crew_roster.size() >= PIRATE_KING_UNLOCK_CREW and _loyalty >= PIRATE_KING_UNLOCK_LOYALTY
		_:
			return false


func _phase_name_from_value(phase: int) -> String:
	match phase:
		Phase.PICKPOCKET:
			return "pickpocket"
		Phase.THUG:
			return "thug"
		Phase.CAPTAIN:
			return "captain"
		Phase.PIRATE_KING:
			return "pirate_king"
		_:
			return "unknown"


func _phase_value_from_name(phase_name: String) -> int:
	match phase_name:
		"pickpocket":
			return Phase.PICKPOCKET
		"thug":
			return Phase.THUG
		"captain":
			return Phase.CAPTAIN
		"pirate_king":
			return Phase.PIRATE_KING
		_:
			return -1


func _is_valid_phase_name(phase_name: String) -> bool:
	return _phase_value_from_name(phase_name) >= 0


func _get_valid_phase_names() -> PackedStringArray:
	return PackedStringArray(["pickpocket", "thug", "captain", "pirate_king"])


func _get_valid_resource_names() -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for resource_key: Variant in _resources.keys():
		keys.append(String(resource_key))
	keys.sort()
	return keys


func _is_debug_commands_enabled() -> bool:
	return OS.has_feature(DEBUG_BUILD_FEATURE)


func _emit_debug_feedback(success: bool, command: String, message: String) -> void:
	EventBus.debug_command_feedback.emit(success, command, message)
	if success:
		print("[DebugCommand] %s" % message)
		return
	push_warning("[DebugCommand] %s" % message)


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
