# Cursor Agents Framework

A modular, reusable, continuously-learning **multi-agent development system** for [Cursor IDE](https://cursor.com). Organize your AI-assisted development with specialized expert agents across any technology stack and domain.

## What Is This?

This framework provides a set of `.mdc` rule files that turn Cursor into a coordinated team of specialized AI agents — a Project Manager, Business Analyst, Solution Architect, Backend/Frontend developers, QA Engineer, Security Specialist, and more — all working together with defined communication protocols, quality standards, and a continuous learning system.

## Key Features

- **5-Layer Architecture**: Core, Technology, Process, Domain, Learning — pick only what you need
- **Technology Agnostic**: Works with any stack — .NET, React, Python, Go, Java, Vue, Angular, etc.
- **Domain Packs**: Plug in domain knowledge (WMS, E-Commerce, or create your own)
- **Manifest-Based Configuration**: One `agents.manifest.json` defines your project's agent setup
- **Continuous Learning**: Agents record lessons; knowledge accumulates across projects
- **Cross-Platform Installation**: PowerShell, Bash, or manual setup

## Quick Start

### 1. Install the Framework

```bash
# Clone or download
git clone https://github.com/sedat-cengiz/cursor-agents-framework.git

# Install as Cursor skill (copy to skills directory)
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

Use agent aliases in Cursor chat:
- `@sef` — Project Manager (start here for task coordination)
- `@backend` — Backend developer
- `@frontend` — Frontend developer
- `@qa` — QA / Testing
- `@review` — Code reviewer
- `@mimari` — Solution Architect
- `@analist` — Business Analyst

## Architecture

```
Layer 1: CORE (always installed)
├── global-conventions.mdc    → Standards, communication, golden rules
├── orchestrator.mdc          → PM, RACI, sprint, DoD, agent routing
└── code-quality.mdc          → Code review, complexity, PR checklists

Layer 2: TECHNOLOGY (pick what you need)
├── tech-dotnet.mdc           → .NET, ASP.NET Core, EF Core, CQRS
├── tech-react.mdc            → React, TypeScript, Vite, TanStack
├── tech-python.mdc           → Python, FastAPI/Django, SQLAlchemy
├── tech-sql-server.mdc       → SQL Server, indexing, multi-tenancy
├── tech-devops.mdc           → Docker, CI/CD, SRE, observability
├── tech-security.mdc         → OWASP, JWT, Zero Trust
├── tech-testing.mdc          → xUnit/pytest, Playwright, TDD
├── tech-maui.mdc             → .NET MAUI, Blazor Hybrid, offline
├── tech-ai-ml.mdc            → ML.NET, Semantic Kernel, RAG
└── _template/                → Create your own tech pack

Layer 3: PROCESS (always installed)
├── process-analysis.mdc      → BA, user stories, INVEST, requirements
├── process-architecture.mdc  → ADR, API contracts, C4, DDD
└── process-documentation.mdc → BPMN, SOP, Lean Six Sigma

Layer 4: DOMAIN (pick your domain)
├── wms/                      → Warehouse Management System
├── ecommerce/                → E-Commerce
└── _template/                → Create your own domain pack

Layer 5: LEARNING (always installed)
├── agent-learning.mdc        → Continuous learning system
└── knowledge-base/           → Cross-project knowledge
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/ARCHITECTURE.md) | Framework design, layers, priority system |
| [Getting Started](docs/GETTING-STARTED.md) | Quick start for new users |
| [Configuration](docs/CONFIGURATION.md) | Manifest schema, overrides, customization |
| [New Project Setup](docs/NEW-PROJECT-SETUP.md) | Step-by-step project bootstrap |
| [Migration Guide](docs/MIGRATION-GUIDE.md) | Migrating from jeager-agents v1/v2 |
| [Creating Domain Pack](docs/CREATING-DOMAIN-PACK.md) | How to add new domain knowledge |
| [Creating Tech Pack](docs/CREATING-TECH-PACK.md) | How to add new technology packs |
| [Distribution](docs/DISTRIBUTION.md) | How the framework is packaged and shared |
| [Evolution](docs/EVOLUTION.md) | Versioning, learning feedback, rule evolution |

## Project Manifest Example

```json
{
  "$schema": "./node_modules/cursor-agents-framework/agents.manifest.schema.json",
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
  }
}
```

## License

MIT
