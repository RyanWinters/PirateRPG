extends Node
class_name TimeManager

const BASE_OFFLINE_TICK_SECONDS: int = 10
const DEFAULT_MAX_OFFLINE_SECONDS: int = 60 * 60 * 8

@export var max_offline_seconds: int = DEFAULT_MAX_OFFLINE_SECONDS
@export var debug_logging_enabled: bool = false

var _last_emitted_elapsed_seconds: int = 0
var _cycle_emitted: bool = false


func begin_offline_cycle_from_save_data(save_data: Dictionary, now_unix: int = Time.get_unix_time_from_system()) -> int:
	var last_active_unix: int = int(save_data.get("last_active_unix", 0))
	return begin_offline_cycle(last_active_unix, now_unix)


func begin_offline_cycle(last_active_unix: int, now_unix: int = Time.get_unix_time_from_system()) -> int:
	_cycle_emitted = false
	var elapsed_seconds: int = compute_elapsed_seconds(last_active_unix, now_unix)
	_emit_offline_progress_once(elapsed_seconds)
	return elapsed_seconds


func compute_elapsed_seconds(last_active_unix: int, now_unix: int = Time.get_unix_time_from_system()) -> int:
	if last_active_unix <= 0:
		_debug_log("No last_active_unix found; offline elapsed defaults to 0.")
		return 0
	var raw_elapsed_seconds: int = maxi(0, now_unix - last_active_unix)
	var clamped_elapsed_seconds: int = _clamp_elapsed_seconds(raw_elapsed_seconds)
	_debug_log("Offline elapsed computed (raw=%d, clamped=%d, now=%d, last_active=%d)." % [raw_elapsed_seconds, clamped_elapsed_seconds, now_unix, last_active_unix])
	return clamped_elapsed_seconds


func elapsed_to_ticks(elapsed_seconds: int, tick_seconds: int = BASE_OFFLINE_TICK_SECONDS) -> int:
	if elapsed_seconds <= 0:
		return 0
	if tick_seconds <= 0:
		return 0
	return maxi(1, int(elapsed_seconds / tick_seconds))


func elapsed_to_chunks(elapsed_seconds: int, chunk_seconds: int) -> Array:
	var chunks: Array = []
	if elapsed_seconds <= 0 or chunk_seconds <= 0:
		return chunks

	var remaining: int = elapsed_seconds
	while remaining > 0:
		var chunk_size: int = mini(chunk_seconds, remaining)
		chunks.append(chunk_size)
		remaining -= chunk_size
	return chunks


func get_last_emitted_elapsed_seconds() -> int:
	return _last_emitted_elapsed_seconds


func _emit_offline_progress_once(elapsed_seconds: int) -> void:
	if _cycle_emitted:
		_debug_log("Skipping duplicate offline_progress_ready emit in current cycle.")
		return
	_cycle_emitted = true
	_last_emitted_elapsed_seconds = elapsed_seconds
	_debug_log("Emitting offline_progress_ready with elapsed_seconds=%d." % elapsed_seconds)
	EventBus.offline_progress_ready.emit(elapsed_seconds)


func _clamp_elapsed_seconds(elapsed_seconds: int) -> int:
	if max_offline_seconds <= 0:
		return elapsed_seconds
	return mini(elapsed_seconds, max_offline_seconds)


func _debug_log(message: String) -> void:
	if not debug_logging_enabled:
		return
	print("[TimeManager] %s" % message)
