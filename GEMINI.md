# Agentic Workspace Rules

**Start by reading:** `.agents/orchestrator.md`

This file boots any AI agent into the Fuzzzy Seal agentic development workflow. The orchestrator will load the full project context and manage the 4-persona SDLC lifecycle (Planner → Doer → Reviewer → Documenter).

## Quick Context

- **Project:** Fuzzzy Seal — offline-first encryption app (Flutter)
- **AI Memory:** `.agents/` directory (project guide, architecture, personas, tasks)
- **Key Constraint:** 100% offline. No servers, no HTTP, no remote APIs.
- **FVM:** All Flutter/Dart commands must use `fvm flutter ...` / `fvm dart ...`
