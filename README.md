# Cursor Agents Framework

An enterprise-grade, modular, continuously-learning **AI software delivery framework** for [Cursor IDE](https://cursor.com). One command — `@sef` — orchestrates a coordinated team of specialized AI agents to analyze, design, implement, test, review, and deliver software at enterprise quality.

## Vision

This framework turns Cursor into a **full software delivery system**: not just code generation, but structured analysis, architecture decisions, quality enforcement, failure management, and continuous learning — all coordinated by a single orchestrator that dynamically selects the right agents, applies quality gates, and manages state across the entire development lifecycle.

**User writes:** `@sef "add order module"`
**System delivers:** classified work, selected agents, filtered handoffs, quality gates, structured output, final summary.

## Key Features

- **Single Entry Point**: `@sef` handles everything — work classification, agent selection, quality gates, failure management
- **Enterprise Orchestration**: 8 work types, dynamic agent routing, 7 quality gates, failure policy with retry/escalation
- **5-Layer Architecture**: Core, Technology, Process, Domain, Learning — pick only what you need
- **Technology Agnostic**: Works with any stack — .NET, React, Python, Go, Java, Vue, Angular, etc.
- **Domain Packs**: Plug in domain knowledge (WMS, E-Commerce, or create your own)
- **Quality Gates**: Mandatory checkpoints between phases — no shortcuts to production
- **Failure Management**: Structured failure handling with retry limits, escalation, and hard stop conditions
- **Context Filtering**: Each agent receives only the information it needs — no context overload
- **Shared State**: Centralized project state managed by @sef, visible to all agents
- **Continuous Learning**: Agents record lessons; knowledge accumulates across projects
- **Manifest-Based Configuration**: One `agents.manifest.json` defines your project setup
- **Cross-Platform**: PowerShell, Bash, or manual setup

## How It Works

```
@sef "add feature X"
  │
  ├── 1. CLASSIFY: work type (feature), scope (L), risk (medium)
  ├── 2. ROUTE: select agents → analyst → architect → backend → frontend → qa → review
  ├── 3. PLAN: present to user for approval
  │
  ├── 4. EXECUTE (per agent):
  │   ├── Write filtered context handoff
  │   ├── Call agent
  │   ├── Validate output
  │   ├── Update shared state
  │   └── Check quality gate
  │
  ├── 5. HANDLE FAILURES: retry / escalate / hard stop
  │
  └── 6. SUMMARY: structured report to user
```

## Quick Start

### 1. Install the Framework

```bash
git clone https://github.com/sedat-cengiz/cursor-agents-framework.git

# Install as Cursor skill
# Windows:
xcopy /E /I cursor-agents-framework "%USERPROFILE%\.cursor\skills\cursor-agents-framework"
# macOS/Linux:
cp -r cursor-agents-framework ~/.cursor/skills/cursor-agents-framework
```

### 2. Set Up a New Project

```powershell
# Interactive installer
.\scripts\install.ps1 -ProjectPath "D:\MyProject"

# Or via Cursor chat:
# "Install agents framework. Stack: .NET + React. Domain: WMS"
```

### 3. Configure Your Project

Edit `.cursor/rules/global-conventions.mdc`:
- Set your project name and platform description
- Adjust technology stack if needed
- Review communication language settings

### 4. Start Working

```
@sef "add user authentication with JWT"
```

That's it. @sef will classify the work, select the right agents, apply quality gates, and deliver structured output.

## Orchestration Architecture

### Work Classification

Every request is classified before execution:

| Dimension | Values |
|-----------|--------|
| **Work Type** | `feature`, `bugfix`, `refactor`, `integration`, `performance`, `ux-ui`, `devops-infra`, `research` |
| **Scope** | S (1 file, <1h), M (2-5 files, <4h), L (multi-layer, 1-3d), XL (new bounded context, 3d+) |
| **Risk** | low, medium, high, critical |

### Dynamic Agent Routing

Not all agents run for every task. @sef selects the minimum necessary agents:

| Work Type | Agent Pipeline |
|-----------|---------------|
| **feature** | analyst → architect(?) → backend ∥ frontend → qa → review → devops(?) |
| **bugfix** | [relevant developer] → qa → review |
| **refactor** | architect(?) → [relevant developer] → qa → review |
| **integration** | analyst → architect → backend → qa → security → review |
| **research** | [relevant agents] → summary (no gates) |

### Quality Gates

7 mandatory checkpoints (applied per work type):

| Gate | What It Checks |
|------|---------------|
| G1 Analysis | Requirements clear, user approved |
| G2 Acceptance | US written with acceptance criteria |
| G3 Architecture | ADR + API contract defined |
| G4 Implementation | Build passes, no lint errors, no layer violations |
| G5 Testing | Tests written and passing, coverage met |
| G6 Review | Code review done, no MUST-FIX findings |
| G7 Release | DoD met, user approved |

### Failure Policy

| Risk Level | Max Retry | On Failure |
|-----------|-----------|------------|
| Low | 2 | Warning + continue |
| Medium | 1 | Escalate to user |
| High | 0 | Immediate escalation |
| Critical | 0 | Hard stop + report |

Hard stop triggers: security risk, architecture violation (high risk), 3 cumulative failures, or user request.

## Architecture

```
Layer 1: CORE (always installed)
├── global-conventions.mdc        → Standards, communication, golden rules
├── orchestrator.mdc              → Decision engine, routing, quality gates, state management
├── orchestration-policies.mdc    → Failure policy, context filters, gate definitions
└── code-quality.mdc              → Code review, complexity, PR checklists

Layer 2: TECHNOLOGY (pick what you need)
├── tech-dotnet.mdc               → .NET 9, ASP.NET Core, EF Core, CQRS
├── tech-react.mdc                → React 19, TypeScript, Vite, TanStack
├── tech-python.mdc               → Python 3.12+, FastAPI, Django, SQLAlchemy
├── tech-java.mdc                 → Java 21+, Spring Boot 3, JPA, Hibernate
├── tech-go.mdc                   → Go 1.22+, chi/gin, sqlx/pgx, gRPC
├── tech-angular.mdc              → Angular 17+, Signals, NgRx, RxJS
├── tech-vue.mdc                  → Vue 3.4+, Composition API, Pinia, Vite
├── tech-nextjs.mdc               → Next.js 14+, App Router, RSC, Prisma
├── tech-flutter.mdc              → Flutter 3.22+, Dart 3.4+, Riverpod
├── tech-sql-server.mdc           → SQL Server, indexing, multi-tenancy
├── tech-devops.mdc               → Docker, CI/CD, SRE, observability
├── tech-security.mdc             → OWASP, JWT, Zero Trust
├── tech-testing.mdc              → xUnit/pytest, Playwright, TDD
├── tech-maui.mdc                 → .NET MAUI, Blazor Hybrid, offline
├── tech-ai-ml.mdc                → ML.NET, Semantic Kernel, RAG
└── _template/                    → Create your own tech pack

Layer 3: PROCESS (always installed)
├── process-analysis.mdc          → BA, user stories, INVEST, requirements
├── process-architecture.mdc      → ADR, API contracts, C4, DDD
└── process-documentation.mdc     → BPMN, SOP, Lean Six Sigma

Layer 4: DOMAIN (pick your domain)
├── wms/                          → Warehouse Management System
├── ecommerce/                    → E-Commerce
└── _template/                    → Create your own domain pack

Layer 5: LEARNING (always installed)
├── agent-learning.mdc            → Continuous learning system
└── knowledge-base/               → Cross-project knowledge
```

## Agent Aliases

| Turkish | English | Role |
|---------|---------|------|
| `@sef` | `@pm` | Orchestrator — **start here** |
| `@backend` | `@backend` | Backend Developer |
| `@frontend` | `@frontend` | Frontend Developer |
| `@qa` | `@qa` | QA / Testing |
| `@review` | `@review` | Code Reviewer |
| `@mimari` | `@architect` | Solution Architect |
| `@analist` | `@analyst` | Business Analyst |
| `@guvenlik` | `@security` | Security Specialist |
| `@devops` | `@devops` | DevOps / SRE |
| `@dokumantasyon` | `@docs` | Process Documentation |

Set `"aliasLanguage": "en"` or `"both"` in your manifest.

## Project Manifest Example

```json
{
  "$schema": "../../agents.manifest.schema.json",
  "projectName": "MyApp",
  "platform": "Multi-tenant SaaS E-Commerce Platform",
  "language": { "communication": "tr", "code": "en", "docs": "tr" },
  "layers": {
    "technology": ["dotnet", "react", "sql-server", "devops", "security", "testing"],
    "domain": ["ecommerce"]
  },
  "aliases": {
    "backend": "tech-dotnet",
    "frontend": "tech-react"
  },
  "orchestration": {
    "enableQualityGates": true,
    "enableFailurePolicy": true,
    "maxRetries": 3,
    "humanInLoopThreshold": "high"
  }
}
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/ARCHITECTURE.md) | Framework design, layers, priority system |
| [Getting Started](docs/GETTING-STARTED.md) | Quick start for new users |
| [Configuration](docs/CONFIGURATION.md) | Manifest schema, overrides, customization |
| [New Project Setup](docs/NEW-PROJECT-SETUP.md) | Step-by-step project bootstrap |
| [Migration Guide](docs/MIGRATION-GUIDE.md) | Migrating from jeager-agents v1/v2 or v3.x |
| [Creating Domain Pack](docs/CREATING-DOMAIN-PACK.md) | How to add new domain knowledge |
| [Creating Tech Pack](docs/CREATING-TECH-PACK.md) | How to add new technology packs |
| [Distribution](docs/DISTRIBUTION.md) | How the framework is packaged and shared |
| [Evolution](docs/EVOLUTION.md) | Versioning, learning feedback, rule evolution |

## License

MIT
