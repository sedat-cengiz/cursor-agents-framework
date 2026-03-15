# Changelog

All notable changes to the Cursor Agents Framework are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.0.0] - 2026-03-15

### Added
- **Enterprise-grade orchestration engine** in `orchestrator.mdc`:
  - Work classification engine: 8 work types (feature, bugfix, refactor, integration, performance, ux-ui, devops-infra, research) with scope (S/M/L/XL) and risk level (low/medium/high/critical)
  - Dynamic routing engine: per-work-type agent pipelines with minimum-necessary-agents principle
  - Quality gate protocol: 7 mandatory gates (Analysis, Acceptance, Architecture, Implementation, Testing, Review, Release) with per-work-type applicability matrix
  - Execution loop: classify → route → plan → [gate → agent → validate → state]* → summary
  - State management protocol: shared state in `workflow-state.md`, only @sef writes
  - Final summary protocol: structured completion report to user
- **`orchestration-policies.mdc`** (new core file):
  - Failure policy: 7 failure types, per-risk-level retry matrix, hard stop conditions, human-in-the-loop triggers
  - Context filter specifications: per-agent-role "need to know" templates
  - Quality gate detailed definitions: criteria, pass/fail actions, skip conditions for each gate
- **New templates** (3):
  - `_template-state-snapshot.md` — shared state checkpoint format
  - `_template-failure-report.md` — standardized failure report
  - `_template-quality-gate.md` — quality gate pass/fail report
- **Manifest `orchestration` config block**: `singleEntryPoint`, `enableWorkClassification`, `enableDynamicRouting`, `enableQualityGates`, `enableFailurePolicy`, `enableContextFiltering`, `enableSharedState`, `maxRetries`, `humanInLoopThreshold`

### Changed
- `orchestrator.mdc`: Major rewrite — from static linear workflow to enterprise decision engine. Preserved: Kimlik, RACI, Sprint Planning, DoD, Anti-patterns
- `global-conventions.mdc`: Agent communication protocol updated for orchestration flow; shared state read/write protocol added
- `code-quality.mdc`: Quality gate integration section added; backend PR checklist strengthened (layer boundaries, retry/timeout, backward compat, logging); frontend PR checklist strengthened (loading/empty/error states, design consistency, component reuse, responsive, UX integrity, performance)
- `workflow-state.md` template: Extended with shared state fields (work ID, type, agent pipeline, scope, affected layers, API/DB changes, test/review status, risk register, failure counter)
- `_template-handoff.md`: Extended with structured context sections (work summary, agent-specific task, finalized decisions, technical context, constraints, expected output)
- `agent-guide.md`: Rewritten for single entry point (@sef), orchestration flow, work types, quality gates, example workflows
- Install scripts (`install.ps1`, `install.sh`): Updated to copy `orchestration-policies.mdc` as core rule
- Manifest schema: `frameworkVersion` default updated to 4.0.0

### Fixed
- `agent-learning.mdc`: Replaced legacy `jeager-agents/v2` paths with `cursor-agents-framework`

### Migration from v3.x
- Backward compatible: existing v3.x projects continue to work
- New orchestration features are enabled by default but all are optional via manifest `orchestration` block
- Run `install.ps1` or `install.sh` to update rules; `project-config.mdc` preserved as always

---

## [3.0.0] - 2026-03-01

### Added
- Initial framework release, extracted and generalized from jeager-agents v1/v2
- **5-layer architecture**: Core, Technology, Process, Domain, Learning
- **Manifest system**: `agents.manifest.schema.json` for project configuration
- **Core rules** (generalized, technology-agnostic):
  - `global-conventions.mdc` — universal standards, agent communication protocol
  - `orchestrator.mdc` — PM, RACI, sprint, DoD, agent routing
  - `code-quality.mdc` — 360-degree review, complexity metrics, PR checklists
- **Technology packs** (8 + template):
  - tech-dotnet, tech-react, tech-sql-server, tech-maui, tech-ai-ml, tech-devops, tech-security, tech-testing
  - `_template/tech-template.mdc` for creating new tech packs
- **Process rules** (3):
  - process-analysis, process-architecture, process-documentation
- **Domain packs** (2 + template):
  - WMS (3 files: concepts, processes, integrations)
  - E-Commerce (2 files: concepts, processes)
  - `_template/domain-template.mdc` for creating new domain packs
- **Learning system**:
  - agent-learning.mdc with global knowledge base
- **Cross-platform install scripts**:
  - PowerShell (install.ps1) — Windows, macOS, Linux
  - Bash (install.sh) — macOS, Linux
  - Batch (install.bat) — Windows
- **Templates** (10):
  - project-config, AGENTS.md, agent-guide, taskboard, workflow-state
  - ADR, user story, API contract, handoff, code review templates
- **Documentation** (9 guides):
  - Architecture, Getting Started, Configuration, New Project Setup
  - Migration Guide, Creating Domain Pack, Creating Tech Pack
  - Distribution, Evolution
- **Example manifests** (3):
  - .NET + React + WMS (full stack)
  - Python + Vue + E-Commerce
  - Minimal (no domain)

### Changed
- Core rules no longer contain .NET/React/SQL Server specific content (moved to tech packs)
- Naming changed from "jeager-agents" to "cursor-agents-framework"
- Agent aliases now configurable via manifest

### Migration from jeager-agents
- See [Migration Guide](docs/MIGRATION-GUIDE.md) for v1/v2 → v3 transition steps

## [3.1.0] - 2026-03-01

### Added
- **7 new technology packs**:
  - `tech-python.mdc` — Python 3.12+, FastAPI, Django, SQLAlchemy 2.0, Pydantic v2, pytest
  - `tech-java.mdc` — Java 21+, Spring Boot 3, Spring Data JPA, Hibernate 6, Virtual Threads
  - `tech-go.mdc` — Go 1.22+, chi/gin, sqlx/pgx, gRPC, structured concurrency
  - `tech-angular.mdc` — Angular 17+, Signals, NgRx SignalStore, standalone components
  - `tech-vue.mdc` — Vue 3.4+, Composition API, Pinia, VeeValidate
  - `tech-nextjs.mdc` — Next.js 14+, App Router, Server Components, Server Actions, Prisma
  - `tech-flutter.mdc` — Flutter 3.22+, Dart 3.4+, Riverpod 2.0, GoRouter, drift
- **Bilingual alias support**: English aliases (@pm, @security, @architect, @analyst, @docs, @mobile) alongside Turkish ones
- **`aliasLanguage` manifest option**: `"tr"`, `"en"`, or `"both"` to control which alias set is installed
- **Lifecycle scripts**:
  - `update.ps1` — Selective update of installed rules from latest framework
  - `uninstall.ps1` — Clean removal of framework rules (preserves project-config.mdc)
  - `validate.ps1` — Validates project setup against manifest (missing/orphan files, structure)

### Changed
- Manifest schema updated: technology enum now includes java, go, angular, vue, nextjs, flutter
- Install script now supports comma-separated multi-digit selection (e.g. `1,2,14,15`)
- README and SKILL.md updated with full technology pack listing and bilingual alias table
