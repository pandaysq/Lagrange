# ADR-0015: Singleplayer first, online later

Status: accepted

## Decision
Current scope is singleplayer only (optionally LAN co-op in the far future). No networking code, sockets, lobbies, or sync protocols are written now. The foundation for online is already covered by: commands (ADR-0002), determinism (ADR-0004), SimulationHost (ADR-0011).

## Why
Building online first would stall the game before any gameplay exists. The architecture is enough to avoid a rewrite later.

## Consequences
- Do not add multiplayer features, even "small ones", without a new ADR.
- Do not store player-specific data in global singletons; always attach it to a player ID in state (default: player 1), so more players can be added later.
- Any future LAN/online mode = a new SimulationHost implementation, not a change to core rules.
