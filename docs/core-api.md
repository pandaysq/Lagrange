# Core API (TASK 001)

Public API of the simulation core. The core is headless-capable, uses only
`RefCounted`/plain data, and is independent from scenes and rendering
(ADR-0001). View/ui talks **only** to a `SimulationHost` (ADR-0011).

Project lead and author: Pandays (Пандейс).

## Quick start (headless)

```gdscript
var host := LocalHost.new(12345)          # seed
host.subscribe(Callable(self, "_on_event"))
host.send_command(SetSpeedCommand.new(10))
host.advance(100)                          # raw deterministic ticks
var s := host.get_state_view()             # read-only by convention
```

## Layers

```
core/host/    SimulationHost (interface), LocalHost (singleplayer)
core/sim/     Simulation, SimState, EventQueue, StateHash, SimConstants
core/commands/Command, PauseCommand, SetSpeedCommand
core/events/  EventBus, SimEvent
core/gen/     Rng (own seeded PCG32)
```

## SimulationHost (core/host/simulation_host.gd)

| Method | Purpose |
|--------|---------|
| `send_command(cmd: Command) -> bool` | Validate + apply a command; `false` = rejected, no state change, no events. |
| `subscribe(cb: Callable) -> void` | Subscribe a callable taking one `SimEvent`. |
| `unsubscribe(cb: Callable) -> void` | Remove a subscription. |
| `get_state_view() -> SimState` | Current state. Read-only by convention: only commands mutate state. |
| `advance(p_ticks: int) -> int` | Raw deterministic primitive: exactly `p_ticks` ticks (0 when paused). |
| `advance_frame(delta_ms: int) -> int` | Map integer real time to ticks through `TICKS_PER_SECOND` and `speed`; 0 when paused. The only place where speed matters. |

`LocalHost` (singleplayer, ADR-0015) implements this over an owned
`Simulation`. A future authoritative server is another subclass of the same
interface; no networking code exists or is planned in this slice.

## Time model (ADR-0003)

- Fixed tick. One game second = `SimConstants.TICKS_PER_SECOND` (10, placeholder).
- `state.paused` stops ticking entirely (`step`, `advance`, `advance_frame` return 0).
- `state.speed` is one of `SimConstants.SPEED_LEVELS` (x1/x10/x100, placeholder).
- `Simulation.step()` = 1 tick; `advance(n)` = n ticks; `advance_for_ms(ms)`
  = `ms * speed * TICKS_PER_SECOND / 1000` ticks (integer math, remainder dropped).

## Commands (ADR-0002)

Base `Command` (core/commands/command.gd): `validate(state) -> bool` and
`apply(state, bus)`. Base `validate` rejects everything; concrete commands
override it. Included commands:

- `PauseCommand(paused: bool)` — sets `state.paused` (send the explicit
  desired value; a toggle button sends `not state.paused`). Emits
  `paused` / `unpaused`. No-op (rejected) when the value already matches.
- `SetSpeedCommand(speed: int)` — sets `state.speed`. Valid only for levels
  in `SimConstants.SPEED_LEVELS` and different from the current one. Emits
  `speed_changed` with payload `{speed, old_speed}`.

Commands carry `player_id` (default 1, ADR-0015). Events carry the same id.

## Events (ADR-0002)

`EventBus.emit_event(ev)` delivers `SimEvent` values to subscribers in
emission order (deterministic, because emissions happen inside the tick
loop). `SimEvent` fields: `type: String`, `tick: int`, `player_id: int`,
`data: Dictionary` (ints and strings only). Types so far: `paused`,
`unpaused`, `speed_changed`, `scheduled` (a run due entry from the queue).

## State and determinism (ADR-0004)

`SimState` (core/sim/sim_state.gd): `tick`, `seed`, `paused`, `speed`,
`player_id`, `rng: Rng`, `queue: EventQueue`. No floats anywhere in core.

- `SimState.to_dict()` / `load_dict(d)` / `from_dict(d)`: canonical
  serialization, ints and strings only (bools become 0/1).
- `StateHash.hash_state(state)` / `hash_dict(d)`: own FNV-1a 64-bit over the
  canonical serialization (sorted dictionary keys, ints as 8 LE bytes,
  strings as length + UTF-8 bytes). Godot's built-in `hash()` is not used.
- The hash covers the full state including `seed`, RNG state and the event
  queue, so: same seed + same command script → equal hash; different seed →
  different hash; serialize → deserialize keeps the hash.

## EventQueue (scheduler)

`EventQueue.push(run_tick, kind, data)` schedules a plain entry;
entries pop in `(tick, sequence number)` order — equal ticks in insertion
order (the sequence counter is monotonic and serialized).
`Simulation.schedule_event(run_tick, kind, data)` is the passthrough used
by future gameplay systems; due entries are emitted as `scheduled` events.

## RNG

`Rng` (core/gen/rng.gd) is a PCG32 with serializable state:
`next_u32()`, `next_below(bound)`, `next_in_range(from, to)`,
`to_dict()` / `load_dict()` / `from_dict()`, `reseed(seed, stream)`.
The engine's global random number generator is never used. One draw per
tick (`SimConstants.RNG_DRAWS_PER_TICK = 1`) is a placeholder binding the
stream to the tick loop until gameplay mechanics define real draws.

## Testing

`tools/run_tests.ps1` (requires `GODOT_BIN`, see `docs/LOCAL_SETUP.md`)
runs `tests/run_all.gd` headless: prints PASS/FAIL per test, exit code
non-zero on failure. Covered: RNG reproducibility, queue ordering,
commands validate/apply/emit, speed/pause frame rules, determinism
(10 000 ticks, same seed + script → equal hash, different seed → different
hash), serialize roundtrip keeps the hash.
