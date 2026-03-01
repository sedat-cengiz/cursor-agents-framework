---
name: cursor-agents-framework
description: Modular multi-agent development framework with 5 layers (Core, Technology, Process, Domain, Learning). Use when the user wants to set up agents for a new project, select technology stack or domain pack, bootstrap agent rules, or asks about multi-agent development workflow.
---

# Cursor Agents Framework — Skill Entry Point

## Overview

A modular, reusable, continuously-learning multi-agent system organized in 5 independent layers. Each layer can be selected independently based on project needs.

## Architecture

```
Layer 1: CORE (always installed)
├── global-conventions.mdc    (priority: 10, standards, communication, golden rules)
├── orchestrator.mdc          (priority: 15, PM, RACI, sprint, DoD, agent routing)
└── code-quality.mdc          (priority: 20, review, complexity, fitness functions)

Layer 2: TECHNOLOGY (pick what you need)
├── tech-dotnet.mdc           (priority: 40, .NET 9, EF Core, CQRS, async)
├── tech-react.mdc            (priority: 40, React 19, TanStack, Zustand)
├── tech-python.mdc           (priority: 40, Python 3.12+, FastAPI, SQLAlchemy)
├── tech-sql-server.mdc       (priority: 40, SQL Server, indexing, multi-tenancy)
├── tech-maui.mdc             (priority: 40, .NET MAUI 9, Blazor Hybrid, offline)
├── tech-ai-ml.mdc            (priority: 40, ML.NET, Semantic Kernel, RAG)
├── tech-devops.mdc           (priority: 40, Docker, Aspire, CI/CD, SRE)
├── tech-security.mdc         (priority: 100, OWASP 2025, JWT, supply chain)
└── tech-testing.mdc          (priority: 40, xUnit/pytest, Playwright, TDD)

Layer 3: PROCESS (always installed)
├── process-analysis.mdc      (priority: 50, BA, user stories, INVEST)
├── process-architecture.mdc  (priority: 50, ADR, API contracts, DDD)
└── process-documentation.mdc (priority: 50, BPMN, SOP, Lean Six Sigma)

Layer 4: DOMAIN (pick your domain)
├── wms/                      (Warehouse Management)
│   ├── domain-wms-concepts.mdc
│   ├── domain-wms-processes.mdc
│   └── domain-wms-integrations.mdc
├── ecommerce/                (E-Commerce)
│   ├── domain-ecom-concepts.mdc
│   └── domain-ecom-processes.mdc
└── _template/                (New domain template)
    └── domain-template.mdc

Layer 5: LEARNING (always installed)
└── agent-learning.mdc        (priority: 5, continuous learning system)
```

## Agent Aliases

After installation, agents can be invoked via short aliases in Cursor chat:

| Alias | Maps To | Role |
|-------|---------|------|
| **@sef** | orchestrator.mdc | Project Manager — start here |
| @backend | tech-dotnet.mdc (or project's backend tech) | Backend developer |
| @frontend | tech-react.mdc (or project's frontend tech) | Frontend developer |
| @qa | tech-testing.mdc | QA / Test engineer |
| @db | tech-sql-server.mdc | Database architect |
| @guvenlik | tech-security.mdc | Security specialist |
| @devops | tech-devops.mdc | DevOps / SRE |
| @mobil | tech-maui.mdc | Mobile developer |
| @ai | tech-ai-ml.mdc | AI/ML engineer |
| @review | code-quality.mdc | Code reviewer |
| @mimari | process-architecture.mdc | Solution architect |
| @analist | process-analysis.mdc | Business analyst |
| @dokumantasyon | process-documentation.mdc | Process documentation |

## Quick Start — New Project Setup

### Option 1: Interactive Installer
```powershell
# PowerShell (Windows/macOS/Linux)
.\scripts\install.ps1 -ProjectPath "D:\MyProject"

# Bash (macOS/Linux)
./scripts/install.sh ~/my-project
```

### Option 2: Via Cursor Chat
Tell Cursor: "Install cursor-agents-framework. Stack: .NET + React. Domain: WMS"

The agent will:
1. Copy Core layer files to `{project}/.cursor/rules/`
2. Copy selected Technology files
3. Copy Process layer files
4. Copy selected Domain pack files
5. Copy Learning system
6. Create `docs/agents/` folder structure with templates
7. Generate `agents.manifest.json`
8. Create agent aliases for easy invocation

### Option 3: Manual Setup
```powershell
$fw = "$env:USERPROFILE\.cursor\skills\cursor-agents-framework"
$target = "D:\MyProject\.cursor\rules"

# Core (required)
Copy-Item "$fw\core\*" $target
# Technology (select)
Copy-Item "$fw\technology\tech-dotnet.mdc" $target
Copy-Item "$fw\technology\tech-react.mdc" $target
# Process (required)
Copy-Item "$fw\process\*" $target
# Domain (select)
Copy-Item "$fw\domains\wms\*" $target
# Learning (required)
Copy-Item "$fw\learning\agent-learning.mdc" $target
```

## Configuration

After install, each project has an `agents.manifest.json` at its root. This file declares which layers/packs are active. See `docs/CONFIGURATION.md` for schema details.

## Adding a New Domain Pack

1. Copy `domains/_template/domain-template.mdc`
2. Fill in domain-specific concepts, entities, processes, rules
3. Save to `domains/{domain-name}/`
4. Optionally split into multiple files: `domain-{name}-concepts.mdc`, `domain-{name}-processes.mdc`

## Adding a New Technology Pack

1. Copy `technology/_template/tech-template.mdc`
2. Fill in technology-specific patterns, conventions, anti-patterns
3. Set appropriate `globs` for file-type activation
4. Save to `technology/tech-{name}.mdc`

## Continuous Learning

Agents record lessons → project `docs/agents/lessons-learned.md` → universal lessons promoted to global `learning/knowledge-base/lessons-learned.md` → rules evolve over time.

## Version

**Framework Version:** 3.0.0
**Based on:** jeager-agents v1 + v2 (battle-tested on Jeager WMS project)
