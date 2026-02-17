extends Node
class_name TimeManager

const BASE_OFFLINE_TICK_SECONDS: int = 10

var _income_rate_per_second: float = 1.0


func _ready() -> void:
	EventBus.phase_changed.connect(_on_phase_changed)


func process_offline_progress(last_saved_unix: int, now_unix: int = Time.get_unix_time_from_system()) -> void:
	if last_saved_unix <= 0:
		return
	var elapsed_seconds: int = maxi(0, now_unix - last_saved_unix)
	if elapsed_seconds <= 0:
		return

	var simulated_ticks: int = maxi(1, int(elapsed_seconds / BASE_OFFLINE_TICK_SECONDS))
	var reward_snapshot: Dictionary = {
		"gold": int(round(elapsed_seconds * _income_rate_per_second)),
	}

	EventBus.offline_progress_ready.emit(elapsed_seconds, reward_snapshot, simulated_ticks)


func _on_phase_changed(_old_phase: int, new_phase: int, _reason: StringName) -> void:
	match new_phase:
		0:
			_income_rate_per_second = 1.0
		1:
			_income_rate_per_second = 2.0
		2:
			_income_rate_per_second = 3.0
		_:
			_income_rate_per_second = 5.0
