extends Control
class_name StreetPanel

@export var game_state_path: NodePath = NodePath("/root/GameState")
@export var event_bus_path: NodePath = NodePath("/root/EventBus")

@onready var _steal_button: Button = %StealButton
@onready var _gold_value_label: Label = %GoldValueLabel
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _progression_hint_label: Label = %ProgressionHintLabel

var _game_state: GameState
var _event_bus: EventBus
var _feedback_message: String = "Ready to steal."
var _poll_accumulator: float = 0.0


func _ready() -> void:
	if not _resolve_singletons():
		set_process(false)
		return

	_steal_button.pressed.connect(_on_steal_pressed)
	_event_bus.steal_click_resolved.connect(_on_steal_click_resolved)
	_event_bus.passive_income_tick.connect(_on_passive_income_tick)
	_event_bus.resource_changed.connect(_on_resource_changed)
	_event_bus.phase_changed.connect(_on_phase_changed)
	_event_bus.pickpocket_level_up.connect(_on_pickpocket_level_up)
	_event_bus.pickpocket_upgrade_unlocked.connect(_on_pickpocket_upgrade_unlocked)
	_event_bus.pickpocket_crew_slot_unlocked.connect(_on_pickpocket_crew_slot_unlocked)
	_event_bus.street_event_triggered.connect(_on_street_event_triggered)
	_event_bus.expedition_started.connect(_on_expedition_started)
	_event_bus.expedition_completed.connect(_on_expedition_completed)
	_event_bus.expedition_claimed.connect(_on_expedition_claimed)

	_refresh_all_ui()
	set_process(true)


func _process(delta: float) -> void:
	_refresh_cooldown_state()
	_poll_accumulator += delta
	if _poll_accumulator >= 0.25:
		_poll_accumulator = 0.0
		_refresh_resource_and_progression_labels()


func _resolve_singletons() -> bool:
	var game_state_node: Node = get_node_or_null(game_state_path)
	if game_state_node is GameState:
		_game_state = game_state_node as GameState
	else:
		push_error("StreetPanel expected GameState at %s" % game_state_path)
		return false

	var event_bus_node: Node = get_node_or_null(event_bus_path)
	if event_bus_node is EventBus:
		_event_bus = event_bus_node as EventBus
	else:
		push_error("StreetPanel expected EventBus at %s" % event_bus_path)
		return false
	return true


func _refresh_all_ui() -> void:
	_refresh_resource_and_progression_labels()
	_refresh_cooldown_state()


func _refresh_resource_and_progression_labels() -> void:
	_gold_value_label.text = str(_game_state.get_resource(&"gold"))
	_progression_hint_label.text = _game_state.get_progression_hint_text()


func _refresh_cooldown_state() -> void:
	var cooldown_remaining_msec: int = _game_state.get_steal_click_cooldown_remaining_msec()
	if cooldown_remaining_msec > 0:
		_steal_button.disabled = true
		var cooldown_seconds: float = float(cooldown_remaining_msec) / 1000.0
		_feedback_label.text = "%s (cooldown %.2fs)" % [_feedback_message, cooldown_seconds]
		return
	_steal_button.disabled = false
	_feedback_label.text = _feedback_message


func _on_steal_pressed() -> void:
	_game_state.steal_click()


func _on_steal_click_resolved(success: bool, gold_gained: int, cooldown_remaining_msec: int) -> void:
	if success:
		_feedback_message = "+%d gold stolen" % gold_gained
	else:
		_feedback_message = "Too risky! Wait %dms" % cooldown_remaining_msec
	_refresh_all_ui()


func _on_passive_income_tick(gold_gained: int, _tick_interval_seconds: float) -> void:
	if gold_gained > 0:
		_feedback_message = "Street hustle +%d gold" % gold_gained
	_refresh_resource_and_progression_labels()


func _on_resource_changed(resource_name: StringName, _old_value: int, _new_value: int, _source: StringName) -> void:
	if resource_name != &"gold":
		return
	_refresh_resource_and_progression_labels()


func _on_phase_changed(_old_phase: int, _new_phase: int, _reason: StringName) -> void:
	_refresh_resource_and_progression_labels()


func _on_pickpocket_level_up(_previous_level: int, _new_level: int, _total_xp: int) -> void:
	_refresh_resource_and_progression_labels()


func _on_pickpocket_upgrade_unlocked(_upgrade_id: StringName, _unlocked_at_level: int) -> void:
	_refresh_resource_and_progression_labels()


func _on_pickpocket_crew_slot_unlocked(_total_slots: int, _unlocked_at_level: int) -> void:
	_refresh_resource_and_progression_labels()


func _on_street_event_triggered(event_id: StringName, payload: Dictionary) -> void:
	match event_id:
		&"guard_patrol":
			var guard_loss: int = absi(int(payload.get("gold_delta", 0)))
			_feedback_message = "Guard patrol! Lost %d gold" % guard_loss
		&"lucky_mark":
			var lucky_gain: int = maxi(0, int(payload.get("gold_delta", 0)))
			_feedback_message = "Lucky mark! +%d bonus gold" % lucky_gain
		&"rival_thief":
			var outcome: String = String(payload.get("outcome", "loss"))
			var rival_delta: int = int(payload.get("gold_delta", 0))
			if outcome == "win":
				_feedback_message = "Rival thief outplayed! +%d gold" % maxi(0, rival_delta)
			else:
				_feedback_message = "Rival thief stole your haul! %d gold lost" % absi(rival_delta)
		_:
			_feedback_message = "Street event: %s" % String(event_id)

	_refresh_resource_and_progression_labels()

func _on_expedition_started(_expedition_id: StringName, template_key: StringName, crew_ids: PackedStringArray, _start_unix: int, _eta_unix: int) -> void:
	_feedback_message = "Expedition %s departed with %d crew" % [String(template_key), crew_ids.size()]
	_refresh_resource_and_progression_labels()


func _on_expedition_completed(_expedition_id: StringName, template_key: StringName, _completed_unix: int, _rewards: Dictionary) -> void:
	_feedback_message = "Expedition %s returned. Rewards are claimable." % String(template_key)
	_refresh_resource_and_progression_labels()


func _on_expedition_claimed(_expedition_id: StringName, template_key: StringName, rewards: Dictionary) -> void:
	_feedback_message = "Claimed %s rewards: %s" % [String(template_key), str(rewards)]
	_refresh_resource_and_progression_labels()
