# ADR-0005: Coordinates

Status: accepted

## Decision
Position = (sector: Vector2i, local: Vector2 float). Distances computed via sector difference.

## Why
Single float loses precision at large distances and causes jitter.

## Consequences
All spatial APIs take/return this type; never raw global floats.
