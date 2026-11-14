# ADR-0008: Procedural generation

Status: accepted

## Decision
Seed for each layer = hash(galaxy_seed, coordinates, layer). Only player-caused deltas are stored. generator_version is stored in the save; old versions stay selectable.

## Why
Changing an algorithm must not regenerate worlds under existing colonies.

## Consequences
Keep old generator code paths or freeze them.
