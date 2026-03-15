---
name: cursor-agents-framework
description: Enterprise-grade AI software delivery framework with orchestration engine, quality gates, failure management, and 5 layers (Core, Technology, Process, Domain, Learning). Use when the user wants to set up agents for a new project, coordinate development with @sef, select technology stack or domain pack, or asks about multi-agent development workflow. Single entry point: @sef.
---

# Cursor Agents Framework — Skill Entry Point

## Overview

An enterprise-grade, modular, continuously-learning AI software delivery framework. **Single entry point: `@sef`** — orchestrates work classification, dynamic agent routing, quality gates, failure management, and shared state.

## Architecture

```
Layer 1: CORE (always installed)
├── global-conventions.mdc        (priority: 10, standards, communication, golden rules)
├── orchestrator.mdc              (priority: 15, decision engine, routing, quality gates, state)
├── orchestration-policies.mdc    (priority: 16, failure policy, context filters, gate definitions)
└── code-quality.mdc              (priority: 20, review, complexity, fitness functions)

Layer 2: TECHNOLOGY (pick what you need)
├── tech-dotnet.mdc               (priority: 40, .NET 9, EF Core, CQRS, async)
├── tech-react.mdc                (priority: 40, React 19, TanStack, Zustand)
├── tech-python.mdc               (priority: 40, Python 3.12+, FastAPI, SQLAlchemy)
├── tech-java.mdc                 (priority: 40, Java 21+, Spring Boot 3, JPA)
├── tech-go.mdc                   (priority: 40, Go 1.22+, chi/gin, sqlx/pgx)
├── tech-angular.mdc              (priority: 40, Angular 17+, Signals, NgRx)
├── tech-vue.mdc                  (priority: 40, Vue 3.4+, Pinia, Composition API)
├── tech-nextjs.mdc               (priority: 40, Next.js 14+, App Router, RSC)
├── tech-flutter.mdc              (priority: 40, Flutter 3.22+, Riverpod, GoRouter)
├── tech-sql-server.mdc           (priority: 40, SQL Server, indexing, multi-tenancy)
├── tech-maui.mdc                 (priority: 40, .NET MAUI 9, Blazor Hybrid, offline)
├── tech-ai-ml.mdc                (priority: 40, ML.NET, Semantic Kernel, RAG)
├── tech-devops.mdc               (priority: 40, Docker, Aspire, CI/CD, SRE)
├── tech-security.mdc             (priority: 100, OWASP 2025, JWT, supply chain)
└── tech-testing.mdc              (priority: 40, xUnit/pytest, Playwright, TDD)

Layer 3: PROCESS (always installed)
├── process-analysis.mdc          (priority: 50, BA, user stories, INVEST)
├── process-architecture.mdc      (priority: 50, ADR, API contracts, DDD)
└── process-documentation.mdc     (priority: 50, BPMN, SOP, Lean Six Sigma)

Layer 4: DOMAIN (pick your domain)
├── wms/                          (Warehouse Management)
├── ecommerce/                    (E-Commerce)
└── _template/                    (New domain template)

Layer 5: LEARNING (always installed)
└── agent-learning.mdc            (priority: 5, continuous learning system)
```

## Orchestration Engine (v4.0)

### Single Entry Point
User writes `@sef "do X"` → system handles everything automatically.

### Work Classification
Every request is classified: **work type** (feature/bugfix/refactor/integration/performance/ux-ui/devops-infra/research), **scope** (S/M/L/XL), **risk** (low/medium/high/critical).

### Dynamic Routing
Per-work-type agent pipeline with minimum-necessary-agents principle.

### Quality Gates
7 gates: Analysis → Acceptance → Architecture → Implementation → Testing → Review → Release. Applied per work type (bugfix skips Analysis/Architecture).

### Failure Policy
Retry matrix by risk level, hard stop conditions, human-in-the-loop triggers.

### Context Filtering
Each agent receives only what it needs — filtered handoff per role.

### Shared State
Centralized in `docs/agents/workflow-state.md`. Only @sef writes; agents read.

## Agent Aliases

| Turkish | English | Maps To | Role |
|---------|---------|---------|------|
| **@sef** | **@pm** | orchestrator.mdc | Orchestrator — **single entry point** |
| @backend | @backend | tech-{backend}.mdc | Backend developer |
| @frontend | @frontend | tech-{frontend}.mdc | Frontend developer |
| @qa | @qa | tech-testing.mdc | QA / Test engineer |
| @db | @db | tech-{database}.mdc | Database architect |
| @guvenlik | @security | tech-security.mdc | Security specialist |
| @devops | @devops | tech-devops.mdc | DevOps / SRE |
| @mobil | @mobile | tech-{mobile}.mdc | Mobile developer |
| @ai | @ai | tech-ai-ml.mdc | AI/ML engineer |
| @review | @review | code-quality.mdc | Code reviewer |
| @mimari | @architect | process-architecture.mdc | Solution architect |
| @analist | @analyst | process-analysis.mdc | Business analyst |
| @dokumantasyon | @docs | process-documentation.mdc | Process documentation |

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

### Option 3: Manual Setup
```powershell
$fw = "$env:USERPROFILE\.cursor\skills\cursor-agents-framework"
$target = "D:\MyProject\.cursor\rules"

# Core (required — includes orchestration-policies)
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

Each project has an `agents.manifest.json` at its root with an optional `orchestration` block:

```json
{
  "orchestration": {
    "enableQualityGates": true,
    "enableFailurePolicy": true,
    "maxRetries": 3,
    "humanInLoopThreshold": "high"
  }
}
```

See `docs/CONFIGURATION.md` for full schema.

## Continuous Learning

Agents record lessons → project `docs/agents/lessons-learned.md` → universal lessons promoted to global `learning/knowledge-base/lessons-learned.md` → rules evolve over time.

## Version

**Framework Version:** 4.0.0
