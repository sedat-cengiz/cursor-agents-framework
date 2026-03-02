# Changelog

All notable changes to the Cursor Agents Framework are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
