# ADR-0014: Testing

Status: accepted

## Decision
GdUnit4 (final choice to confirm in slice 1), headless CI on GitHub Actions. Mandatory: determinism hash test and save-migration test.

## Why
Agents break old code often; tests catch it.

## Consequences
CI must be green to merge.
