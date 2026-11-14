# Project passport — Lagrange (working title)

## Summary
- **Name:** Lagrange (working title, may change)
- **Genre:** 2D top-down space sandbox / management / exploration / sci-fi strategy
- **Engine:** Godot 4.5.1 stable, GDScript only
- **Platforms:** Windows (development), Android (primary mobile target); Linux/iOS possible later
- **Mode now:** singleplayer. Online is NOT being built now.
- **Long-term:** huge procedural universe starting from Earth, mods, authoritative server simulation, possible LAN/online co-op.

## Author and creative direction
**Pandays (Пандейс)** — author of the idea, project lead, creative and product decisions, final approval of architecture and scope.

The original idea: a huge space sandbox that starts on Earth, grows through colonization to interstellar and intergalactic scale, with building, upgrading, research, ship design, alien civilizations, a mod system, a campaign, and future online. The goal is a strong simulation core that lets new galaxies, mechanics and civilizations be added for years without rewriting the game.

## Who did what
| Who | Role |
|-----|------|
| Pandays | Idea, vision, project lead, decisions, review and approval |
| ChatGPT (OpenAI) | Early concept and first draft of the project vision / roadmap |
| Claude (Anthropic) | Architecture proposals, ADRs, core-loop design, project documents |
| OpenCode + GLM 5.3 | Implementation of `core/` (simulation, commands, saves, tests) |
| Replit (Core plan) | Implementation of `view/`, `ui/`, tools, asset pipeline |

AI tools propose and implement; Pandays decides. Nothing merges to `main` without Pandays' review.

## Decisions made (summary)
- Fully 2D (no 2.5D/3D scene).
- Own simulation core (INFINITY-style) on top of Godot, not a custom engine.
- Core loop: expansion through logistics; exploration, economy and fleet depend on each other. v1 combat = deterministic auto-resolve.
- Hybrid universe: handcrafted Earth/Solar System/story places + procedural rest.
- Mobile-friendly controls from the start; developed and tested on PC.
- Singleplayer first. Architecture prepared for an authoritative server later (see ADR-0011, ADR-0015).

## Not now (planned for the future)
Online multiplayer, LAN co-op, persistent universe, corporations between players, script mods, diplomacy, alien AI, full ship designer.
Rule: prepare the foundation (commands, events, host interface, deterministic simulation), write no networking code.

## Tools
OpenCode + GLM 5.3, Replit Core, GitHub, Godot 4.5.1. See `docs/LOCAL_SETUP.md`.
