# ADR-0004: Determinism

Status: accepted

## Decision
Core state uses integers/fixed-point. Floats only in view. Randomness only via seeded RNG. Orbits computed by formula from time, not integrated.

## Why
Reproducible tests/replays; instant time skipping.

## Consequences
Same-build reproducibility is required; cross-platform bit-exactness is not (server is authoritative).
