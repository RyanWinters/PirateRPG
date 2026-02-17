extends Node
class_name EventBus

# EventBus Signal Contract (public API — keep names and payload order stable)
# - resource_changed(resource_name, old_value, new_value, source)
#   Broadcast whenever a resource value changes.
# - phase_changed(old_phase, new_phase, reason)
#   Broadcast whenever progression phase changes.
# - mutiny_warning(current_loyalty, threshold, eta_seconds)
#   Broadcast when loyalty trends indicate mutiny risk.
# - offline_progress_ready(elapsed_seconds)
#   Broadcast after offline progress elapsed time is computed and clamped.
# - debug_command_feedback(success, command, message)
#   Broadcast after a debug command attempt so tools can show output.
# - steal_click_resolved(success, gold_gained, cooldown_remaining_msec)
#   Broadcast when steal_click is attempted so UI can render gain/cooldown feedback.
# - passive_income_tick(gold_gained, tick_interval_seconds)
#   Broadcast when the passive street hustle tick grants resources.
# - street_level_changed(old_level, new_level, current_xp, next_level_required_xp)
#   Broadcast whenever street progression level changes.
# - street_unlock_changed(unlock_key, is_unlocked, source)
#   Broadcast whenever early-game unlock flags change.

signal resource_changed(resource_name: StringName, old_value: int, new_value: int, source: StringName)
signal phase_changed(old_phase: int, new_phase: int, reason: StringName)
signal mutiny_warning(current_loyalty: float, threshold: float, eta_seconds: float)
signal offline_progress_ready(elapsed_seconds: int)
signal debug_command_feedback(success: bool, command: String, message: String)
signal steal_click_resolved(success: bool, gold_gained: int, cooldown_remaining_msec: int)
signal passive_income_tick(gold_gained: int, tick_interval_seconds: float)

signal street_level_changed(old_level: int, new_level: int, current_xp: int, next_level_required_xp: int)
signal street_unlock_changed(unlock_key: StringName, is_unlocked: bool, source: StringName)
