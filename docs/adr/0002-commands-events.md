# ADR-0002: Commands and events

Status: accepted

## Decision
Every player action is a Command object: validated, applied to state, emits Events. UI never mutates state.

## Why
Saves, replays, tests, undo, and server authority all rely on this.

## Consequences
Slight boilerplate per action; worth it.
