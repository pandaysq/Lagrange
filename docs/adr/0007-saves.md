# ADR-0007: Save format

Status: accepted

## Decision
Saves have format_version, migrations chain, active mod list with versions, generator version, and sector-chunked data.

## Why
Long-lived project; old saves must keep loading.

## Consequences
Every format change needs migration + fixture save in tests/fixtures/saves/.
