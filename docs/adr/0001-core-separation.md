# ADR-0001: Core separated from Godot

Status: accepted

## Decision
All simulation logic lives in `core/` using only RefCounted/Resource/plain data. No Nodes, no SceneTree.

## Why
Testable headless, reusable on a server, view can be replaced.

## Consequences
View must subscribe to events and map IDs to nodes itself.
