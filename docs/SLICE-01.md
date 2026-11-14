# Lagrange — Slice 01: first playable vertical slice

Goal: smallest end-to-end loop that exercises every architecture rule.

## Scope
1. Godot 4.5.1 project, folders per ARCHITECTURE.md (only what is needed).
2. Core: tick loop, event queue, SimulationHost/LocalHost, seeded RNG, state hash.
3. Solar system in 2D: Sun + planets on formula orbits; pause and x1/x10/x100 speed.
4. Registry with a few JSON items/buildings (`base:` namespace) + validation.
5. Commands: BuildMine, SetSpeed, Pause. Events emitted for each.
6. One building (mine) producing one resource (analytic production: rate x time).
7. Save/Load with format_version = 1 and a fixture save in tests.
8. Touch-friendly HUD: resource counter, time controls, build button.
9. CI: headless tests (determinism + save load).

## Out of scope
Ships, combat, tech tree, multiple systems, mods loading, online, art polish.

## Done when
Run 10k ticks twice with same seed -> equal hash; save, reload, continue -> same result; works on PC and an Android build.

## Suggested task split
- Agent A (OpenCode): core/ (sim, commands, events, host, save, tests)
- Agent B (Replit): view/ + ui/ + placeholder art, only through the host API
