# ADR-0003: Time model

Status: accepted

## Decision
Fixed simulation tick plus a priority event queue for scheduled things (arrivals, completions).

## Why
Ticking everything cannot scale to a huge universe.

## Consequences
Long-running activities are scheduled as events, not polled.
