# Lagrange (working title)

2D space sandbox on Godot 4.5.1 (GDScript). Starts on Earth, grows to interstellar scale.
Core loop: expansion through logistics (exploration + economy + fleet).

**Author / project lead:** Pandays (Пандейс)

## Start here
- `docs/PROJECT.md` — project passport: vision, scope, roles, credits
- `AGENTS.md` — rules for AI agents and contributors
- `docs/ARCHITECTURE.md` — layers, folders, decisions
- `docs/adr/` — architecture decision records
- `docs/TASKS.md` — task board and ownership
- `docs/SLICE-01.md` — first vertical slice
- `docs/LOCAL_SETUP.md` — how to run and test locally

Simulation core (`core/`) is independent from Godot nodes and runs headless.
Current mode: **singleplayer**. Online/LAN is planned for the future; only the architecture is prepared (see ADR-0011, ADR-0015).

## Copyright
(c) Pandays. All rights reserved until a license is chosen.
