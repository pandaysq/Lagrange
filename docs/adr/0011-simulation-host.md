# ADR-0011: SimulationHost

Status: accepted

## Decision
Core is accessed through a SimulationHost interface: LocalHost now, ServerHost later. Core runs headless.

## Why
Online becomes a deployment task, not a rewrite.

## Consequences
UI talks only to the host: send_command(), subscribe(), query().
