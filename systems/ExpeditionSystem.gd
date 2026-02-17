extends RefCounted
class_name ExpeditionSystem

const STATUS_ACTIVE: StringName = &"active"
const STATUS_CLAIMABLE: StringName = &"claimable"

var _event_bus: EventBus
var _active_expeditions: Dictionary = {}
var _runtime_counter: int = 0


func configure(event_bus: EventBus) -> void:
	_event_bus = event_bus


func restore_state(state: Dictionary) -> void:
	_active_expeditions.clear()
	_runtime_counter = maxi(0, int(state.get("runtime_counter", 0)))
	var saved_expeditions: Variant = state.get("active_expeditions", {})
	if typeof(saved_expeditions) != TYPE_DICTIONARY:
		return
	for expedition_id_variant: Variant in saved_expeditions.keys():
		var expedition_id: StringName = StringName(str(expedition_id_variant))
		var payload: Variant = saved_expeditions[expedition_id_variant]
		if typeof(payload) != TYPE_DICTIONARY:
			continue
		var normalized_payload: Dictionary = _normalize_runtime_payload(expedition_id, payload as Dictionary)
		if normalized_payload.is_empty():
			continue
		_active_expeditions[expedition_id] = normalized_payload


func serialize_state() -> Dictionary:
	var serialized_expeditions: Dictionary = {}
	for expedition_id: StringName in _active_expeditions.keys():
		serialized_expeditions[String(expedition_id)] = (_active_expeditions[expedition_id] as Dictionary).duplicate(true)
	return {
		"runtime_counter": _runtime_counter,
		"active_expeditions": serialized_expeditions,
	}


func start_expedition(template_key: StringName, crew_ids: PackedStringArray, start_unix: int, eta_unix: int) -> Dictionary:
	if crew_ids.is_empty():
		return {}
	if eta_unix <= start_unix:
		return {}
	_runtime_counter += 1
	var expedition_id: StringName = StringName("expedition_%d" % _runtime_counter)
	var runtime_payload: Dictionary = {
		"expedition_id": expedition_id,
		"template_key": template_key,
		"crew_ids": crew_ids,
		"start_unix": start_unix,
		"eta_unix": eta_unix,
		"completed_unix": 0,
		"status": STATUS_ACTIVE,
		"rewards": {},
	}
	_active_expeditions[expedition_id] = runtime_payload
	_emit_started(runtime_payload)
	return runtime_payload.duplicate(true)


func process_time_tick(now_unix: int, reward_resolver: Callable) -> Array[Dictionary]:
	var completed: Array[Dictionary] = []
	for expedition_id: StringName in _active_expeditions.keys():
		var runtime_payload: Dictionary = _active_expeditions[expedition_id] as Dictionary
		if StringName(runtime_payload.get("status", "")) != STATUS_ACTIVE:
			continue
		if now_unix < int(runtime_payload.get("eta_unix", 0)):
			continue
		var template_key: StringName = StringName(str(runtime_payload.get("template_key", "")))
		var rewards: Dictionary = {}
		if reward_resolver.is_valid():
			var resolved: Variant = reward_resolver.call(template_key)
			if typeof(resolved) == TYPE_DICTIONARY:
				rewards = (resolved as Dictionary).duplicate(true)
		runtime_payload["status"] = STATUS_CLAIMABLE
		runtime_payload["completed_unix"] = now_unix
		runtime_payload["rewards"] = rewards
		_active_expeditions[expedition_id] = runtime_payload
		completed.append(runtime_payload.duplicate(true))
		_emit_completed(runtime_payload)
	return completed


func claim_expedition(expedition_id: StringName) -> Dictionary:
	if not _active_expeditions.has(expedition_id):
		return {}
	var runtime_payload: Dictionary = _active_expeditions[expedition_id] as Dictionary
	if StringName(runtime_payload.get("status", "")) != STATUS_CLAIMABLE:
		return {}
	_active_expeditions.erase(expedition_id)
	_emit_claimed(runtime_payload)
	return runtime_payload.duplicate(true)


func get_active_expeditions() -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for payload: Dictionary in _active_expeditions.values():
		if StringName(payload.get("status", "")) == STATUS_ACTIVE:
			active.append(payload.duplicate(true))
	return active


func get_claimable_expeditions() -> Array[Dictionary]:
	var claimable: Array[Dictionary] = []
	for payload: Dictionary in _active_expeditions.values():
		if StringName(payload.get("status", "")) == STATUS_CLAIMABLE:
			claimable.append(payload.duplicate(true))
	return claimable


func _normalize_runtime_payload(expedition_id: StringName, payload: Dictionary) -> Dictionary:
	var template_key: StringName = StringName(str(payload.get("template_key", "")))
	var start_unix: int = maxi(0, int(payload.get("start_unix", 0)))
	var eta_unix: int = maxi(start_unix, int(payload.get("eta_unix", start_unix)))
	var status: StringName = StringName(str(payload.get("status", String(STATUS_ACTIVE))))
	if status != STATUS_ACTIVE and status != STATUS_CLAIMABLE:
		status = STATUS_ACTIVE
	var completed_unix: int = maxi(0, int(payload.get("completed_unix", 0)))
	if status == STATUS_CLAIMABLE and completed_unix <= 0:
		completed_unix = eta_unix
	var rewards: Dictionary = {}
	var reward_variant: Variant = payload.get("rewards", {})
	if typeof(reward_variant) == TYPE_DICTIONARY:
		rewards = (reward_variant as Dictionary).duplicate(true)

	var normalized_crew_ids: PackedStringArray = PackedStringArray()
	var crew_variant: Variant = payload.get("crew_ids", PackedStringArray())
	if typeof(crew_variant) == TYPE_PACKED_STRING_ARRAY:
		normalized_crew_ids = crew_variant
	elif typeof(crew_variant) == TYPE_ARRAY:
		for crew_id_variant: Variant in crew_variant:
			normalized_crew_ids.append(str(crew_id_variant))
	if normalized_crew_ids.is_empty():
		return {}

	return {
		"expedition_id": expedition_id,
		"template_key": template_key,
		"crew_ids": normalized_crew_ids,
		"start_unix": start_unix,
		"eta_unix": eta_unix,
		"completed_unix": completed_unix,
		"status": status,
		"rewards": rewards,
	}


func _emit_started(runtime_payload: Dictionary) -> void:
	if _event_bus == null:
		return
	_event_bus.expedition_started.emit(
		StringName(str(runtime_payload.get("expedition_id", ""))),
		StringName(str(runtime_payload.get("template_key", ""))),
		runtime_payload.get("crew_ids", PackedStringArray()) as PackedStringArray,
		int(runtime_payload.get("start_unix", 0)),
		int(runtime_payload.get("eta_unix", 0))
	)


func _emit_completed(runtime_payload: Dictionary) -> void:
	if _event_bus == null:
		return
	_event_bus.expedition_completed.emit(
		StringName(str(runtime_payload.get("expedition_id", ""))),
		StringName(str(runtime_payload.get("template_key", ""))),
		int(runtime_payload.get("completed_unix", 0)),
		runtime_payload.get("rewards", {}) as Dictionary
	)


func _emit_claimed(runtime_payload: Dictionary) -> void:
	if _event_bus == null:
		return
	_event_bus.expedition_claimed.emit(
		StringName(str(runtime_payload.get("expedition_id", ""))),
		StringName(str(runtime_payload.get("template_key", ""))),
		runtime_payload.get("rewards", {}) as Dictionary
	)
