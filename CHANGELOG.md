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
