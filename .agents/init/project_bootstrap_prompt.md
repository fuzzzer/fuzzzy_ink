# Fuzzzy Ink — Project Bootstrap & Context Extraction Prompt

*User Instructions: Feed this entire file to the AI when onboarding it to the project or when reinitializing the AI workspace memory. This ensures the AI deeply understands the project and sets up its working memory correctly.*

---
**PROMPT TO AI:**

"We are bootstrapping the **Fuzzzy Ink** Flutter project into our AI Workspace. You must immediately switch to **INIT mode**. Your objective is to perform a deep forensic analysis of the codebase, populate your `.agents/project_guide/` memory banks with production-grade documentation, and identify all technical debt.

Execute the following 5 phases sequentially and meticulously:

### Phase 1: Rule Extraction & Architectural Comparison
1.  **Scan the Codebase:** Recursively read the entire `lib/src/` directory.
2.  **Compare against General Guides:** For every file you read, cross-reference its patterns against our master guide in `.agents/general_guide/flutter_architecture.md`.
3.  **Document Deviations:** Note any project-specific patterns that override general rules.

### Phase 2: Populate `project_context.md`
Overwrite `.agents/project_guide/project_context.md` with a detailed breakdown. **The output of this phase should be a document that another engineer could read to understand the entire project without looking at the code.**
1.  **Core Overview:** Define the Project Name, Target Audience, and Core Value Proposition.
2.  **Technical Stack:** Parse `pubspec.yaml` and `rust/fuzzy_crypto_core/Cargo.toml` and create markdown tables of all key dependencies and their versions (Flutter/Dart from `.fvmrc`, Rust from `rust-toolchain.toml`).
3.  **High-Level Architecture Document:** Generate a **Mermaid.js diagram** that visually maps the system architecture. This diagram must show Entry Points, App Shell, Core Layer, Features (fuzzzy_ink, fuzzy_auth, fuzzy_vault, fuzzy_basics), UI Kit, the generated bridge (`lib/rust_bridge/`) and the Rust crypto core (`rust/fuzzy_crypto_core`).
4.  **Key Deviations:** Document how this offline-only app differs from a typical client-server Flutter architecture.

### Phase 3: Populate `architecture_state.md` & Log Refactors
Overwrite `.agents/project_guide/architecture_state.md`. **The output of this phase should be an exhaustive, live snapshot of the application's implementation details.**
1.  **Feature Implementation Status:** Create a detailed checklist of all features found in `lib/src/` and list their core components (Models, Repositories, Cubits, Pages).
2.  **Cubit/BLoC Registry:** Full table of all Cubits with their State classes and file locations.
3.  **Repository Registry:** Full table of all Repositories with their file locations.
4.  **Navigation Map:** Document the GoRouter route table (`lib/src/app/app_router.dart`) and the auth redirect.
5.  **Data Storage Map:** Document what data lives where (Isar, SecureStorage, SharedPreferences).
6.  **Refactor Logging (CRITICAL):** Create a 'Technical Debt & Known Issues' section with specific, actionable items.

### Phase 4: Populate `file_tree.md`
Overwrite `.agents/project_guide/file_tree.md`. Generate an ASCII-style directory tree of the `lib/src/` directory. The level of detail should be sufficient to show the canonical feature structure (`storage`, `data`, `bloc`, `ui`).

### Phase 5: Workflow Alignment
Review the project for custom scripts and tooling.
1.  Verify the presence of `fvm` and ensure all commands use `fvm flutter ...` / `fvm dart ...`.
2.  Verify the presence of `./exp.sh`, `./loc.sh`, `./m.sh`, `./buildrunner.sh`, `./sbom.sh`, `flutter_rust_bridge_codegen` and the cargo gates, run each once, and ensure they are documented (working or marked BROKEN with the reason) in `.agents/workflows/scripts_reference.md`.

**Completion Gate:**
Once all 5 phases are complete, output a summary report of your findings, highlight the top 3 most critical technical debt items you logged, and explicitly confirm: *'INIT mode complete. Fuzzzy Ink Workspace memory is fully populated and ready for the 4-Persona Lifecycle.'*"
