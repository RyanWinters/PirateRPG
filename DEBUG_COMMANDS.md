# Debug Commands (Development Builds Only)

`GameState.execute_debug_command(raw_command)` provides development-only command entry points for quickly iterating on progression state.

## Build Gating

Debug commands are only enabled when the build has the Godot `debug` feature (`OS.has_feature("debug")`).
In production/export builds where `debug` is unavailable, every command is rejected.

## Commands

- `set_resource <type> <amount>`
  - Sets a resource (`gold`, `food`, etc.) to an absolute value.
  - Validation: resource key must exist; amount must be a non-negative integer.
- `add_resource <type> <amount>`
  - Adds to an existing resource.
  - Validation: resource key must exist; amount must be a non-negative integer.
- `set_phase <phase_name>`
  - Forces progression phase.
  - Valid phases: `pickpocket`, `thug`, `captain`, `pirate_king`.

## Feedback + System Routing

- Successful commands call normal `GameState` mutators (`set_resource`, `add_resource`, `set_phase`) so that all normal `EventBus` signals continue to flow.
- Command outcome feedback is emitted on `EventBus.debug_command_feedback(success, command, message)` and also logged with `print`/`push_warning`.

## Hotkey Entry Points

When debug commands are enabled, `GameState` also wires development hotkeys:

- `F6` -> `add_resource gold 100`
- `F7` -> `set_resource food 50`
- `F8` -> `set_phase captain`
- `F9` -> calls `steal_click()` to test anti-spam and gain scaling

These are intentionally simple examples and can be adjusted per team workflow.
