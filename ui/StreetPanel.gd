extends Control
class_name StreetPanel

@export var game_state_path: NodePath = NodePath("/root/GameState")
@export var event_bus_path: NodePath = NodePath("/root/EventBus")

@onready var _steal_button: Button = %StealButton
@onready var _gold_value_label: Label = %GoldValueLabel
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _progression_hint_label: Label = %ProgressionHintLabel
@onready var _idle_crew_list: ItemList = %IdleCrewList
@onready var _template_picker: OptionButton = %TemplatePicker
@onready var _template_info_label: RichTextLabel = %TemplateInfoLabel
@onready var _assignment_hint_label: Label = %AssignmentHintLabel
@onready var _start_expedition_button: Button = %StartExpeditionButton
@onready var _active_expeditions_label: RichTextLabel = %ActiveExpeditionsLabel
@onready var _claimable_expeditions_list: ItemList = %ClaimableExpeditionsList
@onready var _claim_button: Button = %ClaimButton

var _game_state: GameState
var _event_bus: EventBus
var _feedback_message: String = "Ready to steal."
var _eta_accumulator: float = 0.0
var _selected_template_key: StringName = &""
var _template_keys_by_index: Array[StringName] = []
var _crew_id_by_item_index: Array[String] = []
var _claimable_id_by_item_index: Array[StringName] = []


func _ready() -> void:
	if not _resolve_singletons():
		set_process(false)
		return

	_steal_button.pressed.connect(_on_steal_pressed)
	_template_picker.item_selected.connect(_on_template_selected)
	_idle_crew_list.item_selected.connect(_on_crew_selection_changed)
	_idle_crew_list.multi_selected.connect(_on_crew_multi_selected)
	_start_expedition_button.pressed.connect(_on_start_expedition_pressed)
	_claimable_expeditions_list.item_selected.connect(_on_claimable_selection_changed)
	_claim_button.pressed.connect(_on_claim_pressed)

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
	_eta_accumulator += delta
	if _eta_accumulator < 0.25:
		return
	_eta_accumulator = 0.0
	_refresh_active_expeditions_ui()


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
	_refresh_assignment_controls()
	_refresh_template_info()
	_refresh_active_expeditions_ui()
	_refresh_claimable_expeditions_ui()


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


func _refresh_assignment_controls() -> void:
	_crew_id_by_item_index.clear()
	_idle_crew_list.clear()
	for crew_member: CrewMember in _game_state.get_idle_crew():
		var item_text: String = "%s (C:%d S:%d L:%d)" % [crew_member.name, crew_member.combat, crew_member.stealth, crew_member.loyalty]
		_idle_crew_list.add_item(item_text)
		_crew_id_by_item_index.append(crew_member.id)

	_template_picker.clear()
	_template_keys_by_index.clear()
	for template: Dictionary in _game_state.list_unlocked_expedition_templates():
		var template_key: StringName = StringName(str(template.get("key", "")))
		_template_picker.add_item(String(template_key).capitalize())
		_template_keys_by_index.append(template_key)

	if _template_keys_by_index.is_empty():
		_selected_template_key = &""
	else:
		var template_index: int = _template_keys_by_index.find(_selected_template_key)
		if template_index == -1:
			template_index = 0
		_selected_template_key = _template_keys_by_index[template_index]
		_template_picker.select(template_index)
	_refresh_assignment_action_state()


func _refresh_assignment_action_state() -> void:
	var selected_crew_count: int = _get_selected_crew_ids().size()
	var can_assign: bool = selected_crew_count > 0 and not _selected_template_key.is_empty()
	_start_expedition_button.disabled = not can_assign
	if can_assign:
		_assignment_hint_label.text = "Ready: %d crew selected for %s." % [selected_crew_count, String(_selected_template_key)]
	else:
		_assignment_hint_label.text = "Select idle crew and an expedition template."


func _refresh_template_info() -> void:
	if _selected_template_key.is_empty():
		_template_info_label.text = "No unlocked expedition templates available yet."
		return

	var template: Dictionary = _game_state.get_expedition_template(_selected_template_key)
	if template.is_empty():
		_template_info_label.text = "Selected template is unavailable."
		return

	var duration_seconds: int = maxi(1, int(template.get("base_duration_seconds", 60)))
	var risk_profile: Dictionary = template.get("risk_profile", {}) as Dictionary
	var failure_chance: float = clampf(float(risk_profile.get("failure_chance", 0.0)), 0.0, 1.0)
	var reward_table: Dictionary = template.get("reward_table", {}) as Dictionary
	var expected_yield: String = _format_expected_yield(reward_table.get("success", {}) as Dictionary)
	var selected_crew_profile: Dictionary = _build_selected_crew_profile()
	var suitability_lines: Array[String] = _build_suitability_lines(template, selected_crew_profile)

	var lines: Array[String] = [
		"[b]Template:[/b] %s" % String(_selected_template_key).capitalize(),
		"[b]Duration:[/b] %s" % _format_duration(duration_seconds),
		"[b]Risk:[/b] %.1f%% base failure" % (failure_chance * 100.0),
		"[b]Expected yield:[/b] %s" % expected_yield,
		"[b]Suitability:[/b]",
	]
	lines.append_array(suitability_lines)
	_template_info_label.text = "\n".join(lines)


func _refresh_active_expeditions_ui() -> void:
	var now_unix: int = Time.get_unix_time_from_system()
	var lines: Array[String] = []
	for expedition: Dictionary in _game_state.get_active_expeditions():
		var template_key: String = String(expedition.get("template_key", "unknown"))
		var eta_unix: int = int(expedition.get("eta_unix", now_unix))
		var remaining_seconds: int = maxi(0, eta_unix - now_unix)
		var crew_count: int = (expedition.get("crew_ids", PackedStringArray()) as PackedStringArray).size()
		lines.append("• %s (%d crew) ETA %s" % [template_key.capitalize(), crew_count, _format_duration(remaining_seconds)])

	if lines.is_empty():
		_active_expeditions_label.text = "No active expeditions."
		return
	_active_expeditions_label.text = "\n".join(lines)


func _refresh_claimable_expeditions_ui() -> void:
	_claimable_expeditions_list.clear()
	_claimable_id_by_item_index.clear()
	for expedition: Dictionary in _game_state.get_claimable_expeditions():
		var expedition_id: StringName = StringName(str(expedition.get("expedition_id", "")))
		var template_key: String = String(expedition.get("template_key", "unknown")).capitalize()
		var rewards: Dictionary = expedition.get("rewards", {}) as Dictionary
		_claimable_expeditions_list.add_item("%s — %s" % [template_key, _format_reward_map(rewards)])
		_claimable_id_by_item_index.append(expedition_id)

	_claim_button.disabled = _claimable_expeditions_list.get_selected_items().is_empty()


func _on_steal_pressed() -> void:
	_game_state.steal_click()


func _on_template_selected(index: int) -> void:
	if index < 0 or index >= _template_keys_by_index.size():
		_selected_template_key = &""
	else:
		_selected_template_key = _template_keys_by_index[index]
	_refresh_assignment_action_state()
	_refresh_template_info()


func _on_crew_selection_changed(_index: int) -> void:
	_refresh_assignment_action_state()
	_refresh_template_info()


func _on_crew_multi_selected(_index: int, _selected: bool) -> void:
	_refresh_assignment_action_state()
	_refresh_template_info()


func _on_start_expedition_pressed() -> void:
	var selected_crew_ids: PackedStringArray = _get_selected_crew_ids()
	if selected_crew_ids.is_empty() or _selected_template_key.is_empty():
		return
	var runtime_payload: Dictionary = _game_state.start_expedition(_selected_template_key, selected_crew_ids)
	if runtime_payload.is_empty():
		_feedback_message = "Unable to start expedition. Check crew/template requirements."
		_refresh_all_ui()
		return
	_feedback_message = "Started %s with %d crew." % [String(_selected_template_key), selected_crew_ids.size()]
	_refresh_all_ui()


func _on_claimable_selection_changed(_index: int) -> void:
	_claim_button.disabled = _claimable_expeditions_list.get_selected_items().is_empty()


func _on_claim_pressed() -> void:
	var selected_items: PackedInt32Array = _claimable_expeditions_list.get_selected_items()
	if selected_items.is_empty():
		return
	var selected_index: int = int(selected_items[0])
	if selected_index < 0 or selected_index >= _claimable_id_by_item_index.size():
		return
	_game_state.claim_expedition(_claimable_id_by_item_index[selected_index])


func _on_steal_click_resolved(success: bool, gold_gained: int, cooldown_remaining_msec: int) -> void:
	if success:
		_feedback_message = "+%d gold stolen" % gold_gained
	else:
		_feedback_message = "Too risky! Wait %dms" % cooldown_remaining_msec
	_refresh_resource_and_progression_labels()
	_refresh_cooldown_state()


func _on_passive_income_tick(gold_gained: int, _tick_interval_seconds: float) -> void:
	if gold_gained > 0:
		_feedback_message = "Street hustle +%d gold" % gold_gained
	_refresh_resource_and_progression_labels()


func _on_resource_changed(resource_name: StringName, _old_value: int, _new_value: int, _source: StringName) -> void:
	if resource_name == &"gold":
		_refresh_resource_and_progression_labels()


func _on_phase_changed(_old_phase: int, _new_phase: int, _reason: StringName) -> void:
	_refresh_resource_and_progression_labels()
	_refresh_assignment_controls()
	_refresh_template_info()


func _on_pickpocket_level_up(_previous_level: int, _new_level: int, _total_xp: int) -> void:
	_refresh_resource_and_progression_labels()


func _on_pickpocket_upgrade_unlocked(_upgrade_id: StringName, _unlocked_at_level: int) -> void:
	_refresh_resource_and_progression_labels()
	_refresh_assignment_controls()
	_refresh_template_info()


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
	_refresh_assignment_controls()
	_refresh_template_info()
	_refresh_active_expeditions_ui()
	_refresh_claimable_expeditions_ui()


func _on_expedition_completed(_expedition_id: StringName, template_key: StringName, _completed_unix: int, _rewards: Dictionary) -> void:
	_feedback_message = "Expedition %s returned. Rewards are claimable." % String(template_key)
	_refresh_assignment_controls()
	_refresh_template_info()
	_refresh_active_expeditions_ui()
	_refresh_claimable_expeditions_ui()


func _on_expedition_claimed(_expedition_id: StringName, template_key: StringName, rewards: Dictionary) -> void:
	_feedback_message = "Claimed %s rewards: %s" % [String(template_key), str(rewards)]
	_refresh_resource_and_progression_labels()
	_refresh_assignment_controls()
	_refresh_template_info()
	_refresh_active_expeditions_ui()
	_refresh_claimable_expeditions_ui()


func _get_selected_crew_ids() -> PackedStringArray:
	var selected_items: PackedInt32Array = _idle_crew_list.get_selected_items()
	var selected_ids: PackedStringArray = PackedStringArray()
	for selected_index: int in selected_items:
		if selected_index < 0 or selected_index >= _crew_id_by_item_index.size():
			continue
		selected_ids.append(_crew_id_by_item_index[selected_index])
	return selected_ids


func _build_selected_crew_profile() -> Dictionary:
	var selected_crew_ids: PackedStringArray = _get_selected_crew_ids()
	if selected_crew_ids.is_empty():
		return {
			"combat": 0.0,
			"stealth": 0.0,
			"loyalty": 0.0,
			"crew_count": 0,
		}

	var combat_total: float = 0.0
	var stealth_total: float = 0.0
	var loyalty_total: float = 0.0
	for crew_id: String in selected_crew_ids:
		var crew_member: CrewMember = _game_state.get_crew_member_by_id(crew_id)
		if crew_member == null:
			continue
		combat_total += crew_member.combat
		stealth_total += crew_member.stealth
		loyalty_total += crew_member.loyalty

	var crew_count: float = maxf(1.0, float(selected_crew_ids.size()))
	return {
		"combat": combat_total / crew_count,
		"stealth": stealth_total / crew_count,
		"loyalty": loyalty_total / crew_count,
		"crew_count": selected_crew_ids.size(),
	}


func _build_suitability_lines(template: Dictionary, selected_profile: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var minimum_crew: int = int(template.get("minimum_crew", 0))
	var selected_crew_count: int = int(selected_profile.get("crew_count", 0))
	var crew_indicator: String = "✅" if selected_crew_count >= minimum_crew else "⚠️"
	lines.append("  %s Crew: %d/%d" % [crew_indicator, selected_crew_count, minimum_crew])

	var minimum_stats: Dictionary = template.get("minimum_stats", {}) as Dictionary
	for stat_name_variant: Variant in minimum_stats.keys():
		var stat_name: String = String(stat_name_variant)
		var required_value: float = float(minimum_stats[stat_name_variant])
		var actual_value: float = float(selected_profile.get(stat_name, 0.0))
		var indicator: String = "✅" if actual_value >= required_value else "⚠️"
		lines.append("  %s %s %.1f/%.1f" % [indicator, stat_name.capitalize(), actual_value, required_value])
	if minimum_stats.is_empty():
		lines.append("  ✅ No minimum stat requirements")
	return lines


func _format_duration(total_seconds: int) -> String:
	var clamped: int = maxi(0, total_seconds)
	var hours: int = clamped / 3600
	var minutes: int = (clamped % 3600) / 60
	var seconds: int = clamped % 60
	if hours > 0:
		return "%dh %02dm %02ds" % [hours, minutes, seconds]
	return "%02dm %02ds" % [minutes, seconds]


func _format_expected_yield(success_rewards: Dictionary) -> String:
	if success_rewards.is_empty():
		return "None"
	return _format_reward_map(success_rewards)


func _format_reward_map(reward_map: Dictionary) -> String:
	var chunks: Array[String] = []
	for resource_name: Variant in reward_map.keys():
		var reward_value: Variant = reward_map[resource_name]
		if reward_value is Vector2i:
			var bounds: Vector2i = reward_value as Vector2i
			chunks.append("%s %d-%d" % [String(resource_name), bounds.x, bounds.y])
			continue
		chunks.append("%s %d" % [String(resource_name), int(reward_value)])
	chunks.sort()
	return ", ".join(chunks)
