# Lagrange — Architecture (working title)

Status: draft v0.1. Changes require an ADR in `docs/adr/`.

## 1. Vision
A 2D top-down space sandbox that starts on Earth and grows to interstellar scale. Core loop is **expansion through logistics**:

Recon -> Foothold -> Production -> Ships and tech -> Deeper recon

- **Exploration** gives places, blueprints, anomalies, knowledge.
- **Economy** gives materials and power.
- **Fleet** gives range, throughput and security.
Hard dependencies keep all three relevant: jump range is limited by tech and fuel; fuel comes from the economy; frontier needs supply lines; supply lines are vulnerable. Combat grows out of logistics (pirates, rivals, threatened colonies), v1 combat = deterministic auto-resolve.

## 2. Layers
```
ui/ + view/   Godot scenes, rendering, input, audio      (reads state, sends commands)
     |
     v  Commands (down)          Events (up)
core/         Simulation core, no Godot nodes            (headless-capable)
     |
data/ + mods/ JSON content, validated by registry
```

### Folder layout
```
core/
  host/        SimulationHost interface + LocalHost
  sim/         Tick loop, event scheduler, world state
  commands/    Command base class + validation + handlers
  events/      Event types, event bus
  gen/         Seeded RNG, universe generation
  registry/    Content registry, schemas, mod loading
  save/        Serialization, versioning, migrations
  systems/     Added only when gameplay needs them (economy, tech, logistics...)
view/          Solar-system scene, analytic orbits and camera
ui/            Simulation HUD; gameplay changes use host commands
data/base/     Base game content (JSON)
mods/          User mods
tests/         Unit tests, fixtures
tools/         Scripts, validators, asset tools
docs/          Architecture, ADRs, tasks
```
Start with only the folders needed by the current slice. Do not create empty "engines".

The TASK 002 solar-system view is a schematic, not a scale model: view-specific
body labels and orbital display parameters live in `view/solar_system.json`.
They are not simulation state or registry content. Positions are derived from
the integer simulation tick and each displayed period. The view accumulates
fractional wall-clock tick time before calling `SimulationHost.advance_frame`,
because the current core API intentionally accepts whole milliseconds and
drops any sub-tick remainder per call.

## 3. Key decisions (see ADRs)
| # | Topic | Summary |
|---|-------|---------|
| 1 | Core separation | `core/` has no Godot nodes |
| 2 | Commands/events | All actions are commands, all changes are events |
| 3 | Time | Fixed tick + priority event queue |
| 4 | Determinism | Integers in core, seeded RNG, orbits by formula |
| 5 | Coordinates | (sector int, local float) |
| 6 | Registry and mods | Namespaced string IDs, validation, load order |
| 7 | Saves | Versioned, migrations, mod list, sector chunks |
| 8 | Generation | Hash seeds per layer, store deltas, generator version in save |
| 9 | Simulation LOD | Active / Background / Dormant (analytic) |
| 10 | Logistics | Abstract routes with capacity and travel time |
| 11 | SimulationHost | Local now, authoritative server later |
| 12 | Input | Touch/mouse -> intents -> commands |
| 13 | Budgets | Numeric performance limits |
| 14 | Testing | Determinism + migration tests mandatory |

## 4. Simulation LOD
- **Active**: near player, full tick rate.
- **Background**: reduced tick rate, simplified rules.
- **Dormant**: no ticking; updated by events and analytic catch-up ("elapsed T, rate X -> result Y").
Design rule: a mechanic that cannot be computed analytically cannot exist in dormant systems.

## 5. Platform
Mobile-friendly UI from day one (touch targets, scalable layout); develop and test on PC. Primary target: Android + Windows. 2D only.

## 6. Out of scope for now
Diplomacy details, alien AI, multiplayer protocol, full ship designer. Only keep interfaces (commands, events, registry, SimulationHost) open for them.

## 7. Known risks
- Core in GDScript: a server would run headless Godot. Keep core API narrow and node-free so it can be ported.
- Scope creep: every PR must serve the current vertical slice.
