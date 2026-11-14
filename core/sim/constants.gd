class_name SimConstants
extends RefCounted

## Central place for tick-related constants. All values are placeholder
## defaults for the core skeleton; real tuning comes with gameplay slices.

## How many simulation ticks make one game second.
const TICKS_PER_SECOND: int = 10

## Seed used when no explicit seed is given.
const DEFAULT_SEED: int = 1

## Player id attached to singleplayer state (ADR-0015: player data lives on
## a player id in state, never in singletons).
const DEFAULT_PLAYER_ID: int = 1

## Allowed speed multiplier levels (x1, x10, x100) as first playable slice.
const SPEED_LEVELS: Array[int] = [1, 10, 100]

## Default speed level.
const DEFAULT_SPEED: int = 1

## RNG draws per tick. Placeholder: the core advances its own seeded
## stream once per tick so the stream stays bound to the tick loop;
## gameplay systems will define real draws per mechanic.
const RNG_DRAWS_PER_TICK: int = 1
