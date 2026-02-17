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

const STEAL_CLICK_BASE_GOLD: int = 2
const STEAL_CLICK_PHASE_MULTIPLIER: float = 0.45
const STEAL_CLICK_COOLDOWN_MSEC: int = 225
const PASSIVE_TICK_INTERVAL_SECONDS: float = 1.0
const STREET_EVENT_TRIGGER_CADENCE_ACTIONS: int = 5
const STREET_EVENT_TRIGGER_CHANCE_PER_CADENCE: float = 0.35
const STREET_EVENT_GUARD_PATROL_WEIGHT: float = 1.0
const STREET_EVENT_LUCKY_MARK_WEIGHT: float = 1.2
const STREET_EVENT_RIVAL_THIEF_WEIGHT: float = 0.8
const STREET_EVENT_GUARD_PATROL_GOLD_LOSS: int = 6
const STREET_EVENT_LUCKY_MARK_GOLD_BONUS: int = 10
const STREET_EVENT_RIVAL_THIEF_WIN_CHANCE: float = 0.5
const STREET_EVENT_RIVAL_THIEF_WIN_GOLD_BONUS: int = 12
const STREET_EVENT_RIVAL_THIEF_LOSS_GOLD_LOSS: int = 8

const PICKPOCKET_MAX_LEVEL: int = 5
const PICKPOCKET_CLICK_XP_GAIN: int = 1
const PICKPOCKET_PASSIVE_TICK_XP_GAIN: int = 1
const PICKPOCKET_LEVEL_XP_THRESHOLDS: Dictionary = {
	1: 0,
	2: 25,
	3: 75,
	4: 160,
	5: 300,
}
const PICKPOCKET_UPGRADE_UNLOCK_GATES: Dictionary = {
	2: [&"quick_hands"],
	3: [&"crowd_reader"],
	4: [&"lock_tumbler"],
	5: [&"ghost_step"],
}
const PICKPOCKET_CREW_SLOT_UNLOCK_GATES: Dictionary = {
	2: 1,
}

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
var _last_steal_click_msec: int = -STEAL_CLICK_COOLDOWN_MSEC
var _passive_tick_accumulator: float = 0.0
var _pickpocket_level: int = 1
var _pickpocket_xp: int = 0
var _unlocked_upgrades: Array[StringName] = []
var _crew_slots_unlocked: int = 0
var _street_events: StreetEvents = StreetEvents.new()
var _street_event_action_counter: int = 0


func _ready() -> void:
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.offline_progress_ready.connect(_on_offline_progress_ready)
	_street_events.set_rng_seed(Time.get_unix_time_from_system())
	set_process(true)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_persist_on_background()
		NOTIFICATION_APPLICATION_RESUMED:
			_process_resume_cycle()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_persist_on_quit()


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_passive_tick_accumulator += delta
	while _passive_tick_accumulator >= PASSIVE_TICK_INTERVAL_SECONDS:
		_passive_tick_accumulator -= PASSIVE_TICK_INTERVAL_SECONDS
		_apply_passive_income_tick()


func steal_click() -> bool:
	var now_msec: int = Time.get_ticks_msec()
	var elapsed_msec: int = now_msec - _last_steal_click_msec
	if elapsed_msec < STEAL_CLICK_COOLDOWN_MSEC:
		var cooldown_remaining_msec: int = STEAL_CLICK_COOLDOWN_MSEC - elapsed_msec
		EventBus.steal_click_resolved.emit(false, 0, cooldown_remaining_msec)
		return false

	_last_steal_click_msec = now_msec
	var gold_gained: int = _calculate_steal_click_gold_gain()
	add_resource(&"gold", gold_gained, &"GameState.steal_click")
	_apply_pickpocket_progress(PICKPOCKET_CLICK_XP_GAIN, &"GameState.steal_click")
	EventBus.steal_click_resolved.emit(true, gold_gained, 0)
	_try_trigger_street_event(&"GameState.steal_click")
	return true


func get_steal_click_cooldown_remaining_msec() -> int:
	var elapsed_msec: int = Time.get_ticks_msec() - _last_steal_click_msec
	return maxi(0, STEAL_CLICK_COOLDOWN_MSEC - elapsed_msec)


func set_street_event_rng_seed(seed: int) -> void:
	_street_events.set_rng_seed(seed)


func set_street_event_rng_source(rng: RandomNumberGenerator) -> void:
	_street_events.set_rng_source(rng)


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
		KEY_F9:
			steal_click()
			get_viewport().set_input_as_handled()

func get_phase() -> int:
	return _phase


func is_first_crew_slot_unlocked() -> bool:
	return _crew_slots_unlocked >= 1



func get_pickpocket_level() -> int:
	return _pickpocket_level


func get_pickpocket_xp() -> int:
	return _pickpocket_xp


func get_pickpocket_next_level_xp_requirement() -> int:
	if _pickpocket_level >= PICKPOCKET_MAX_LEVEL:
		return _get_pickpocket_level_xp_threshold(PICKPOCKET_MAX_LEVEL)
	return _get_pickpocket_level_xp_threshold(_pickpocket_level + 1)


func get_progression_hint_text() -> String:
	var next_phase: int = _phase + 1
	if next_phase <= Phase.PIRATE_KING:
		var requirements: Array[String] = _get_phase_requirement_hints(next_phase)
		if not requirements.is_empty():
			return "Next phase (%s): %s" % [_phase_name_from_value(next_phase).capitalize(), ", ".join(requirements)]

	var pickpocket_hint: String = _build_pickpocket_unlock_hint()
	if not pickpocket_hint.is_empty():
		return pickpocket_hint
	return "All current street progression goals are complete."

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
		"last_steal_click_msec": _last_steal_click_msec,
		"passive_tick_accumulator": _passive_tick_accumulator,
		"pickpocket_level": _pickpocket_level,
		"pickpocket_xp": _pickpocket_xp,
		"unlocked_upgrades": _unlocked_upgrades.duplicate(),
		"crew_slots_unlocked": _crew_slots_unlocked,
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
	_last_steal_click_msec = int(state.get("last_steal_click_msec", _last_steal_click_msec))
	_passive_tick_accumulator = clampf(float(state.get("passive_tick_accumulator", 0.0)), 0.0, PASSIVE_TICK_INTERVAL_SECONDS)
	_pickpocket_level = clampi(int(state.get("pickpocket_level", _pickpocket_level)), 1, PICKPOCKET_MAX_LEVEL)
	_pickpocket_xp = maxi(0, int(state.get("pickpocket_xp", _pickpocket_xp)))
	if _pickpocket_xp < _get_pickpocket_level_xp_threshold(_pickpocket_level):
		_pickpocket_xp = _get_pickpocket_level_xp_threshold(_pickpocket_level)
	_unlocked_upgrades = _normalize_unlocked_upgrades(state.get("unlocked_upgrades", _unlocked_upgrades))
	_crew_slots_unlocked = maxi(0, int(state.get("crew_slots_unlocked", _crew_slots_unlocked)))
	_reconcile_pickpocket_progression(false, &"SaveManager.load_game")


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



func _get_phase_requirement_hints(phase: int) -> Array[String]:
	var requirements: Array[String] = []
	match phase:
		Phase.THUG:
			if get_resource(&"gold") < THUG_UNLOCK_GOLD:
				requirements.append("Gold %d/%d" % [get_resource(&"gold"), THUG_UNLOCK_GOLD])
		Phase.CAPTAIN:
			if get_resource(&"gold") < CAPTAIN_UNLOCK_GOLD:
				requirements.append("Gold %d/%d" % [get_resource(&"gold"), CAPTAIN_UNLOCK_GOLD])
			if _crew_roster.size() < CAPTAIN_UNLOCK_CREW:
				requirements.append("Crew %d/%d" % [_crew_roster.size(), CAPTAIN_UNLOCK_CREW])
		Phase.PIRATE_KING:
			if get_resource(&"gold") < PIRATE_KING_UNLOCK_GOLD:
				requirements.append("Gold %d/%d" % [get_resource(&"gold"), PIRATE_KING_UNLOCK_GOLD])
			if _crew_roster.size() < PIRATE_KING_UNLOCK_CREW:
				requirements.append("Crew %d/%d" % [_crew_roster.size(), PIRATE_KING_UNLOCK_CREW])
			if _loyalty < PIRATE_KING_UNLOCK_LOYALTY:
				requirements.append("Loyalty %.1f/%.1f" % [_loyalty, PIRATE_KING_UNLOCK_LOYALTY])
	return requirements


func _build_pickpocket_unlock_hint() -> String:
	var next_level: int = _pickpocket_level + 1
	if next_level > PICKPOCKET_MAX_LEVEL:
		return "Pickpocket mastery reached (level %d)." % PICKPOCKET_MAX_LEVEL

	var threshold: int = _get_pickpocket_level_xp_threshold(next_level)
	var missing_xp: int = maxi(0, threshold - _pickpocket_xp)
	var unlock_notes: Array[String] = []

	if PICKPOCKET_UPGRADE_UNLOCK_GATES.has(next_level):
		var upgrades: Array = PICKPOCKET_UPGRADE_UNLOCK_GATES[next_level]
		var upgrade_labels: Array[String] = []
		for upgrade_variant: Variant in upgrades:
			upgrade_labels.append(String(upgrade_variant).replace("_", " "))
		if not upgrade_labels.is_empty():
			unlock_notes.append("upgrade: %s" % ", ".join(upgrade_labels))

	if PICKPOCKET_CREW_SLOT_UNLOCK_GATES.has(next_level):
		var crew_slots: int = int(PICKPOCKET_CREW_SLOT_UNLOCK_GATES[next_level])
		unlock_notes.append("crew slots: %d" % crew_slots)

	var unlock_suffix: String = ""
	if not unlock_notes.is_empty():
		unlock_suffix = " (unlocks %s)" % "; ".join(unlock_notes)

	return "Pickpocket level %d -> %d: %d XP to go%s" % [_pickpocket_level, next_level, missing_xp, unlock_suffix]

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
		_apply_pickpocket_progress(simulated_ticks * PICKPOCKET_PASSIVE_TICK_XP_GAIN, &"GameState.offline_progress_ticks")


func _apply_passive_income_tick() -> void:
	var passive_gold: int = _calculate_passive_tick_gold_gain()
	if passive_gold <= 0:
		return
	add_resource(&"gold", passive_gold, &"GameState.passive_income")
	_apply_pickpocket_progress(PICKPOCKET_PASSIVE_TICK_XP_GAIN, &"GameState.passive_income")
	EventBus.passive_income_tick.emit(passive_gold, PASSIVE_TICK_INTERVAL_SECONDS)
	_try_trigger_street_event(&"GameState.passive_income")




func _try_trigger_street_event(source: StringName) -> void:
	_street_event_action_counter += 1
	if _street_event_action_counter % STREET_EVENT_TRIGGER_CADENCE_ACTIONS != 0:
		return
	if not _street_events.roll_chance(STREET_EVENT_TRIGGER_CHANCE_PER_CADENCE):
		return

	var payload: Dictionary = _street_events.roll_event_payload(_build_street_event_definitions())
	if payload.is_empty():
		return
	_apply_street_event_payload(payload, source)


func _build_street_event_definitions() -> Array[Dictionary]:
	return [
		{
			"id": &"guard_patrol",
			"weight": STREET_EVENT_GUARD_PATROL_WEIGHT,
			"gold_loss": STREET_EVENT_GUARD_PATROL_GOLD_LOSS,
		},
		{
			"id": &"lucky_mark",
			"weight": STREET_EVENT_LUCKY_MARK_WEIGHT,
			"gold_bonus": STREET_EVENT_LUCKY_MARK_GOLD_BONUS,
		},
		{
			"id": &"rival_thief",
			"weight": STREET_EVENT_RIVAL_THIEF_WEIGHT,
			"win_chance": STREET_EVENT_RIVAL_THIEF_WIN_CHANCE,
			"gold_bonus": STREET_EVENT_RIVAL_THIEF_WIN_GOLD_BONUS,
			"gold_loss": STREET_EVENT_RIVAL_THIEF_LOSS_GOLD_LOSS,
		},
	]


func _apply_street_event_payload(payload: Dictionary, source: StringName) -> void:
	var event_id: StringName = StringName(str(payload.get("id", "unknown")))
	var event_source: StringName = StringName("GameState.street_event.%s" % String(event_id))
	var result_payload: Dictionary = payload.duplicate(true)
	result_payload["trigger_source"] = source
	result_payload["action_counter"] = _street_event_action_counter

	match event_id:
		&"guard_patrol":
			var gold_loss: int = maxi(0, int(result_payload.get("gold_loss", STREET_EVENT_GUARD_PATROL_GOLD_LOSS)))
			var old_gold: int = get_resource(&"gold")
			var new_gold: int = maxi(0, old_gold - gold_loss)
			set_resource(&"gold", new_gold, event_source)
			result_payload["gold_delta"] = new_gold - old_gold
		&"lucky_mark":
			var gold_bonus: int = maxi(0, int(result_payload.get("gold_bonus", STREET_EVENT_LUCKY_MARK_GOLD_BONUS)))
			add_resource(&"gold", gold_bonus, event_source)
			result_payload["gold_delta"] = gold_bonus
		&"rival_thief":
			var outcome: String = String(result_payload.get("outcome", "loss"))
			if outcome == "win":
				var win_bonus: int = maxi(0, int(result_payload.get("gold_bonus", STREET_EVENT_RIVAL_THIEF_WIN_GOLD_BONUS)))
				add_resource(&"gold", win_bonus, event_source)
				result_payload["gold_delta"] = win_bonus
			else:
				var rival_loss: int = maxi(0, int(result_payload.get("gold_loss", STREET_EVENT_RIVAL_THIEF_LOSS_GOLD_LOSS)))
				var previous_gold: int = get_resource(&"gold")
				var adjusted_gold: int = maxi(0, previous_gold - rival_loss)
				set_resource(&"gold", adjusted_gold, event_source)
				result_payload["gold_delta"] = adjusted_gold - previous_gold
		_:
			result_payload["gold_delta"] = 0

	EventBus.street_event_triggered.emit(event_id, result_payload)

func _apply_pickpocket_progress(xp_delta: int, source: StringName) -> void:
	if xp_delta <= 0:
		return
	_pickpocket_xp += xp_delta
	_reconcile_pickpocket_progression(true, source)


func _reconcile_pickpocket_progression(emit_events: bool, _source: StringName) -> void:
	var previous_level: int = _pickpocket_level
	_pickpocket_level = _resolve_pickpocket_level_from_xp(_pickpocket_xp)
	if emit_events and _pickpocket_level > previous_level:
		EventBus.pickpocket_level_up.emit(previous_level, _pickpocket_level, _pickpocket_xp)

	for level_gate: int in PICKPOCKET_UPGRADE_UNLOCK_GATES.keys():
		if level_gate > _pickpocket_level:
			continue
		var upgrades_for_level: Array = PICKPOCKET_UPGRADE_UNLOCK_GATES[level_gate]
		for upgrade_variant: Variant in upgrades_for_level:
			var upgrade_id: StringName = StringName(str(upgrade_variant))
			if _unlocked_upgrades.has(upgrade_id):
				continue
			_unlocked_upgrades.append(upgrade_id)
			if emit_events:
				EventBus.pickpocket_upgrade_unlocked.emit(upgrade_id, level_gate)

	var highest_unlocked_slots: int = _crew_slots_unlocked
	var crew_slot_unlock_level: int = -1
	for level_gate: int in PICKPOCKET_CREW_SLOT_UNLOCK_GATES.keys():
		if level_gate > _pickpocket_level:
			continue
		var slots_for_level: int = int(PICKPOCKET_CREW_SLOT_UNLOCK_GATES[level_gate])
		if slots_for_level <= highest_unlocked_slots:
			continue
		highest_unlocked_slots = slots_for_level
		crew_slot_unlock_level = level_gate
	if highest_unlocked_slots > _crew_slots_unlocked:
		_crew_slots_unlocked = highest_unlocked_slots
		if emit_events:
			EventBus.pickpocket_crew_slot_unlocked.emit(_crew_slots_unlocked, crew_slot_unlock_level)


func _resolve_pickpocket_level_from_xp(total_xp: int) -> int:
	var resolved_level: int = 1
	for level_key: int in PICKPOCKET_LEVEL_XP_THRESHOLDS.keys():
		if total_xp < int(PICKPOCKET_LEVEL_XP_THRESHOLDS[level_key]):
			continue
		resolved_level = maxi(resolved_level, level_key)
	return clampi(resolved_level, 1, PICKPOCKET_MAX_LEVEL)


func _get_pickpocket_level_xp_threshold(level: int) -> int:
	return int(PICKPOCKET_LEVEL_XP_THRESHOLDS.get(level, 0))


func _normalize_unlocked_upgrades(raw_value: Variant) -> Array[StringName]:
	var normalized: Array[StringName] = []
	if typeof(raw_value) != TYPE_ARRAY:
		return normalized
	for upgrade_variant: Variant in raw_value:
		var upgrade_id: StringName = StringName(str(upgrade_variant))
		if normalized.has(upgrade_id):
			continue
		normalized.append(upgrade_id)
	return normalized


func _calculate_steal_click_gold_gain() -> int:
	var phase_bonus: float = 1.0 + (float(_phase) * STEAL_CLICK_PHASE_MULTIPLIER)
	var gold: int = maxi(1, int(round(STEAL_CLICK_BASE_GOLD * phase_bonus)))
	return gold


func _calculate_passive_tick_gold_gain() -> int:
	var gold_per_second: float = _get_gold_income_per_second_for_phase(_phase)
	return maxi(0, int(round(gold_per_second * PASSIVE_TICK_INTERVAL_SECONDS)))


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
