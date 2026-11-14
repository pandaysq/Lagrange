# AGENTS.md — rules for AI agents working on Lagrange (OpenCode, Replit, others)

Read this file and `docs/ARCHITECTURE.md` before ANY change. If a task conflicts with them, stop and ask the human.

## Project (working title: Lagrange)
2D space sandbox on Godot 4.5.1, GDScript only. Long-term: huge procedural universe, mods, optional authoritative server.
The simulation core lives in `core/` and is independent from Godot nodes.

## Hard rules (never break)
1. `core/` MUST NOT reference Nodes, Scenes, SceneTree, Input, or any `view/` / `ui/` code. Only `RefCounted`, `Resource`, plain data.
2. All player actions go through Commands (`core/commands/`). UI never mutates state directly.
3. State changes produce Events. View/UI only reads state and listens to events.
4. Entities are referenced by stable integer IDs, never by object references.
5. Economy and resources use integers (or fixed-point). No `float` in core simulation state. Floats only in `view/`.
6. No `randf()`, `randi()`, `Time`, `OS` calls in `core/`. Use the seeded RNG from `core/gen/rng.gd` only.
7. Game content (items, buildings, techs, ships) lives in `data/` as JSON, never hardcoded in scripts.
8. Content IDs are namespaced strings (`base:iron_ore`). Saves store string IDs, never indexes.
9. Anything that can run in a distant (dormant) system must be computable analytically (elapsed time -> result).
10. Do not change save format or generator output without bumping version and adding a migration (see ADR-0007, ADR-0008).
11. Do not add dependencies, addons, or C# without a written ADR approved by the human.
12. Singleplayer only for now. Do NOT write networking, lobbies, sockets, or sync code (ADR-0015). Attach player data to a player ID in state (default player 1), not to global singletons.
13. Never hardcode paths to Godot or any local path. Use the `GODOT_BIN` environment variable (see `docs/LOCAL_SETUP.md`).

## Workflow
- One task = one branch (`agent/<tool>/<short-name>`) = one PR. Never push to `main`.
- Two agents must not edit the same files at the same time. Check `docs/TASKS.md` for ownership.
- Small PRs (< ~400 changed lines). Split bigger work.
- Every PR: tests added/updated, all tests pass headless, `docs/` updated if behavior or API changed.
- Do not add features that are not in the task. No "helpful" extra systems or empty placeholder folders.
- If something is unclear, write the question in the PR description instead of guessing.

## Code style
- Typed GDScript everywhere (`var x: int`, `func f(a: int) -> void`).
- `class_name` for public core classes. Files `snake_case.gd`, classes `PascalCase`.
- Public core APIs documented with `##` doc comments.
- Core functions are small and pure where possible (state in, result out).

## Testing
- Task 001 uses a minimal custom headless runner `tests/run_all.gd` (no addons). Framework choice (GdUnit4/GUT) is decided later via ADR-0014.
- Mandatory tests that must always pass:
  - Determinism: run N ticks twice with same seed -> identical state hash.
  - Save migration: load every fixture in `tests/fixtures/saves/` -> loads and migrates.
- Run headless: `powershell -File tools/run_tests.ps1`

## Definition of done
Code in the right layer, tests green, no rule above violated, docs updated, PR description lists what changed and what was NOT done.

## Credits and attribution
Project author and lead: Pandays (Пандейс). Keep this credit in README and any about/credits screen. Do not remove or change it.
