# Task board

Ownership rule: a file/folder is owned by one agent at a time. Do not edit files owned by another active task.

| ID | Title | Owner | Branch | Status |
|----|-------|-------|--------|--------|
| 001 | Core skeleton: tick, events, commands, host, RNG, hash, tests | OpenCode (GLM 5.3) | `agent/opencode/core-skeleton` | DONE (PR #1 merged) |
| 002 | Solar system view (2D orbits) and HUD on top of host API | Replit | `agent/replit/solar-view` | DONE (PR #2 merged) |
| 003 | Registry + base JSON data + validation | OpenCode | `agent/opencode/registry` | IN REVIEW (PR) |
| 004 | Save/Load v1 + fixture save | OpenCode | `agent/opencode/save-v1` | BLOCKED by 003 |

---

## TASK 002 — Solar system view and HUD

**Owner:** Replit. **Owns:** `view/`, `ui/`, and view smoke tests. **Depends on:** TASK 001 core host API.

### Delivered
- A view-only, JSON-defined schematic of the Sun and eight planets with deterministic analytic circular orbits.
- Camera overview, mouse drag / wheel zoom, touch pan / pinch zoom.
- A touch-sized HUD for pause/resume, ×1/×10/×100 speed, zoom, and overview; all simulation changes go through commands on `SimulationHost`.
- A view-layer fractional-time accumulator so frame intervals shorter than one simulation tick are not discarded.
- A headless integration smoke test for scene setup, host commands, pause, speed, and time advancement.

### Not included
Registry-backed planet data, orbital gameplay, planet selection, buildings, resources, save/load, Android export, and multiplayer.

### Verification
Run `godot --headless --path . --script res://tests/run_all.gd` and
`godot --headless --path . --script res://tests/view_smoke.gd`.
The core test runner also passes with Godot 4.5.1.

---

## TASK 001 — Core skeleton

**Owner:** OpenCode (GLM 5.3). **Reviewer:** Pandays. **Owns:** `core/`, `tests/`, `tools/`.
**Read first:** `AGENTS.md`, `docs/ARCHITECTURE.md`, ADR-0001..0004, 0011, 0014, 0015.

### Goal
A headless-capable simulation core that can tick deterministically, accept commands, emit events, and prove determinism by a state hash. No gameplay content yet, no UI.

### Deliverables
1. `core/gen/rng.gd` — own seeded integer RNG (e.g. PCG32/xorshift), state serializable. Must not use Godot's global random.
2. `core/sim/constants.gd` — tick constants in one place (placeholder values, documented).
3. `core/sim/sim_state.gd` — plain data: `tick:int`, `seed:int`, `rng_state`, `paused:bool`, `speed:int`, `player_id:int` default 1. Methods to serialize to/from Dictionary (ints and strings only).
4. `core/sim/event_queue.gd` — priority queue ordered by (tick, sequence number), deterministic for equal ticks.
5. `core/events/event_bus.gd` + `core/events/sim_event.gd` — events emitted by the core, subscribers via signals/callables.
6. `core/commands/command.gd` base class (`validate(state)`, `apply(state, bus)`), plus `PauseCommand` and `SetSpeedCommand`.
7. `core/sim/simulation.gd` — `step()`, `advance(n_ticks)`, runs due events from the queue, uses pause/speed rules.
8. `core/sim/state_hash.gd` — own deterministic hash (e.g. FNV-1a 64-bit over canonical int/string serialization). Do not rely on Godot `hash()` for this.
9. `core/host/simulation_host.gd` (interface: `send_command`, `subscribe`, `get_state_view`, `advance`) and `core/host/local_host.gd`.
10. `tests/run_all.gd` — minimal headless runner (extends SceneTree), prints PASS/FAIL per test, exit code non-zero on failure. No addons.
11. Tests: RNG reproducibility; event queue ordering; commands validate/apply and emit events; **determinism** (10 000 ticks twice with same seed + same command script -> equal hash; different seed -> different hash); state serialize/deserialize roundtrip keeps hash.
12. Short `docs/core-api.md` describing the public API (host, commands, events).

### Acceptance criteria
- `powershell -File tools/run_tests.ps1` exits 0 and prints all tests PASS.
- `grep` finds no `Node`, `SceneTree` (except in `tests/run_all.gd`), `Input`, `randf`, `randi`, `OS.`, `Time.` in `core/`.
- No `float` in `SimState`.
- No new addons, no C#, no networking code.
- PR description lists what was done and what was intentionally NOT done.

### Out of scope
Orbits, buildings, resources, registry, saves to disk, UI, scenes, mods, online.

---

## Prompt to paste into OpenCode (Task 001)

```
You are working on the Godot 4.5.1 (GDScript) project "Lagrange" by Pandays.
First read AGENTS.md, docs/ARCHITECTURE.md, docs/adr/ and docs/TASKS.md (TASK 001).
Create branch agent/opencode/core-skeleton and implement TASK 001 exactly as specified.
Follow all hard rules in AGENTS.md (core has no Nodes, commands/events only, integers only,
own seeded RNG, no networking, no hardcoded local paths, Godot path comes from GODOT_BIN).
Do not add anything outside the task scope, no empty placeholder folders, no new dependencies.
When done: run tools/run_tests.ps1, fix failures, then open a PR with a summary of what
was done and what was intentionally not done. If anything is unclear, write the question
in the PR description instead of guessing. Do not push to main.
```
