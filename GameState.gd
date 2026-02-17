extends Node
class_name GameState

enum Phase {
	PICKPOCKET,
	THUG,
	CAPTAIN,
	PIRATE_KING,
}

const MUTINY_THRESHOLD: float = 25.0

var _resources: Dictionary = {
	"gold": 0,
	"food": 0,
}
var _loyalty: float = 100.0
var _phase: int = Phase.PICKPOCKET


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
	EventBus.phase_changed.emit(old_phase, _phase, reason)


func get_resource(resource_name: StringName) -> int:
	return int(_resources.get(resource_name, 0))


func set_resource(resource_name: StringName, new_value: int, source: StringName = &"GameState.set_resource") -> void:
	var old_value: int = get_resource(resource_name)
	if old_value == new_value:
		return
	_resources[resource_name] = new_value
	EventBus.resource_changed.emit(resource_name, old_value, new_value, source)


func add_resource(resource_name: StringName, amount: int, source: StringName = &"GameState.add_resource") -> void:
	set_resource(resource_name, get_resource(resource_name) + amount, source)


func set_loyalty(new_loyalty: float) -> void:
	_loyalty = clampf(new_loyalty, 0.0, 100.0)
	if _loyalty <= MUTINY_THRESHOLD:
		EventBus.mutiny_warning.emit(_loyalty, MUTINY_THRESHOLD, 60.0)


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
