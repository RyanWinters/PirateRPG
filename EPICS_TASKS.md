# Pirate RPG - Epics & Task Tracker

Use this document as the single source of truth for planning and implementation order.

## Epic 1: Core Progression Framework (Phases + Save Foundation)
- [x] **Task 1.1**: Create global phase model in `GameState.gd` with enum and unlock conditions (`Pickpocket -> Thug -> Captain -> PirateKing`).
- [x] **Task 1.2**: Implement `SaveManager.gd` v1 with serialization for resources, crew, phase, and timestamps.
- [x] **Task 1.3**: Build `TimeManager.gd` to calculate offline elapsed time and emit `offline_progress_ready`.
- [x] **Task 1.4**: Create `EventBus.gd` signal contract for system decoupling (`resource_changed`, `phase_changed`, `mutiny_warning`, etc.).
- [x] **Task 1.5**: Add debug/developer commands for quickly setting resources and phase during iteration.

## Epic 2: Pickpocket Clicker Loop (Early Game Retention)
- [x] **Task 2.1**: Implement click action (`steal_click`) with scaling formula and anti-spam guard.
- [x] **Task 2.2**: Add passive income tick system (baseline street hustle generation).
- [ ] **Task 2.3**: Define level curve and unlock rules for upgrades and first crew slot.
- [ ] **Task 2.4**: Build `StreetPanel` UI with click button, gain feedback, and progression hints.
- [ ] **Task 2.5**: Add random street events (guard patrol, lucky mark, rival thief) using weighted outcomes.

## Epic 3: Idle Crew Expeditions (Mid-Game Automation)
- [ ] **Task 3.1**: Create `CrewMember` data model (combat, stealth, loyalty, upkeep).
- [ ] **Task 3.2**: Build expedition templates (smuggling, fishing, raiding) with duration/risk/reward tables.
- [ ] **Task 3.3**: Implement assignment workflow (idle crew -> expedition slot -> countdown -> return).
- [ ] **Task 3.4**: Add offline expedition resolution using elapsed-time chunk simulation.
- [ ] **Task 3.5**: Build Crew/Expedition UI for assignment, ETAs, expected yields, and claim flow.

## Epic 4: Tactical Combat System (Lanes/Grid + RPS Utility)
- [ ] **Task 4.1**: Define combat board model (3-lane or compact grid) with occupancy rules.
- [ ] **Task 4.2**: Implement turn order and action economy (initiative, AP, cooldowns, status effects).
- [ ] **Task 4.3**: Implement RPS interactions (cannons > hull, grapeshot > crew, boarding > low morale).
- [ ] **Task 4.4**: Add enemy AI behavior profiles (broadside, brace, boarding rush).
- [ ] **Task 4.5**: Create post-battle resolution for loot, casualties, morale, and faction reaction.

## Epic 5: Respect/Fear & Faction Dynamics (CK3-Lite)
- [ ] **Task 5.1**: Implement crew authority model with dual metrics (`respect`, `fear`) and drift logic.
- [ ] **Task 5.2**: Create mutiny threshold rules tied to losses, wages, cruelty, and favoritism.
- [ ] **Task 5.3**: Build faction relationship model (ally, extort, eradicate + truce/retaliation logic).
- [ ] **Task 5.4**: Add diplomacy actions with resource costs and outcome chances.
- [ ] **Task 5.5**: Create narrative event generator for crew disputes and faction incidents.

## Epic 6: Rogue-lite Build Paths & Replayability
- [ ] **Task 6.1**: Implement run-start archetype selection (`Dread Pirate`, `Merchant Lord`, `Voodoo Master`).
- [ ] **Task 6.2**: Create modular perk tree system (shared + archetype-specific nodes).
- [ ] **Task 6.3**: Add run modifiers/relics that alter economy, combat, and morale formulas.
- [ ] **Task 6.4**: Implement prestige/reset loop with meta-currency and permanent unlocks.
- [ ] **Task 6.5**: Add end-of-run summary screen with progression analytics.

## Tracking Notes
- Mark tasks complete by changing `[ ]` to `[x]`.
- If scope changes, append new tasks under the relevant epic rather than replacing completed history.
- Keep implementation order sequential unless dependencies are explicitly removed.
