extends Node
class_name EventBus

# EventBus Signal Contract (public API — keep names and payload order stable)
# - resource_changed(resource_name, old_value, new_value, source)
#   Broadcast whenever a resource value changes.
# - phase_changed(old_phase, new_phase, reason)
#   Broadcast whenever progression phase changes.
# - mutiny_warning(current_loyalty, threshold, eta_seconds)
#   Broadcast when loyalty trends indicate mutiny risk.
# - offline_progress_ready(elapsed_seconds, reward_snapshot, simulated_ticks)
#   Broadcast after offline progress is computed and ready to apply.

signal resource_changed(resource_name: StringName, old_value: int, new_value: int, source: StringName)
signal phase_changed(old_phase: int, new_phase: int, reason: StringName)
signal mutiny_warning(current_loyalty: float, threshold: float, eta_seconds: float)
signal offline_progress_ready(elapsed_seconds: int, reward_snapshot: Dictionary, simulated_ticks: int)
