extends Node
class_name GameState

signal phase_changed(previous_phase: int, new_phase: int)

enum Phase {
	PICKPOCKET,
	THUG,
	CAPTAIN,
	PIRATE_KING,
}

# Persisted progression state.
var current_phase: int = Phase.PICKPOCKET
var pickpocket_actions_completed: int = 0
var total_gold_earned: int = 0
var thug_contracts_completed: int = 0
var crew_members_recruited: int = 0
var infamy: int = 0
var captain_trial_won: bool = false

# Unlock configuration values are centralized here for balancing.
const THUG_REQUIRED_PICKPOCKET_ACTIONS := 25
const THUG_REQUIRED_TOTAL_GOLD := 500
const CAPTAIN_REQUIRED_THUG_CONTRACTS := 12
const CAPTAIN_REQUIRED_CREW_MEMBERS := 6
const PIRATE_KING_REQUIRED_INFAMY := 1_000

func get_current_phase() -> int:
	return current_phase

func is_phase_unlocked(phase: int) -> bool:
	return phase <= current_phase

func try_advance_phase() -> bool:
	var previous_phase := current_phase

	match current_phase:
		Phase.PICKPOCKET:
			# PICKPOCKET -> THUG: requires enough street actions and total gold.
			# Threshold values are configured in THUG_REQUIRED_* constants above.
			if pickpocket_actions_completed >= THUG_REQUIRED_PICKPOCKET_ACTIONS and total_gold_earned >= THUG_REQUIRED_TOTAL_GOLD:
				current_phase = Phase.THUG
		Phase.THUG:
			# THUG -> CAPTAIN: requires contract completions and crew size targets.
			# Threshold values are configured in CAPTAIN_REQUIRED_* constants above.
			if thug_contracts_completed >= CAPTAIN_REQUIRED_THUG_CONTRACTS and crew_members_recruited >= CAPTAIN_REQUIRED_CREW_MEMBERS:
				current_phase = Phase.CAPTAIN
		Phase.CAPTAIN:
			# CAPTAIN -> PIRATE_KING: requires winning the captain trial and enough infamy.
			# Threshold values are configured by captain_trial_won and PIRATE_KING_REQUIRED_INFAMY.
			if captain_trial_won and infamy >= PIRATE_KING_REQUIRED_INFAMY:
				current_phase = Phase.PIRATE_KING
		Phase.PIRATE_KING:
			# Final phase reached; no further transitions.
			pass

	if previous_phase != current_phase:
		phase_changed.emit(previous_phase, current_phase)
		return true

	return false
