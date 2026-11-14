# ADR-0006: Registry and mods

Status: accepted

## Decision
Content defined in JSON with namespaced IDs (`base:iron_ore`). Registry validates schemas at startup. Mods are data packs with a manifest, dependencies, load order, explicit override rules. Saves store string IDs.

## Why
Index-based references break saves when mods change.

## Consequences
Script mods deferred; require a separate ADR and sandbox.
