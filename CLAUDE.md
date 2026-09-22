# Agentic Workspace Rules

**Start by reading:** `.agents/orchestrator.md`

This file boots any AI agent into the Fuzzzy Seal agentic development workflow. The orchestrator will load the full project context and manage the 4-persona SDLC lifecycle (Planner → Doer → Reviewer → Documenter).

## Talking to the owner — plain names, never codes (owner rule, 2026-09-18)

Everything the owner or the business partner reads — a message, a plan, a board card, a
walkthrough, an approval request — names things by what they are, never by an internal code:
no wave letters or numbers, no unit codes (E3, C2, U1), no ticket numbers, no decision-record
numbers, no session ids. Order is described in words — "first the contract, then the backend,
because the backend needs the contract" — never as a wave or phase label. A code may follow
once, in brackets, only if the owner will need to quote it. The owner reads remotely and has
not read our internal documents: a message that needs them to make sense is wrong.
Full standard: `~/FuzzyCore_HQ/company/OWNER_COMMS.md` §1.

## Quick Context

- **Project:** Fuzzzy Seal — offline-first encryption app (Flutter)
- **AI Memory:** `.agents/` directory (project guide, architecture, personas, tasks)
- **Key Constraint:** 100% offline. No servers, no HTTP, no remote APIs.
- **FVM:** All Flutter/Dart commands must use `fvm flutter ...` / `fvm dart ...`
