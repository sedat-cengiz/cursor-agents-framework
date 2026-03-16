# Cursor Agents Framework

An enterprise-oriented **AI software delivery framework** for [Cursor IDE](https://cursor.com).

**Tum isler tek giris noktasindan baslar: `@sef`.** Kullanici yalnizca `@sef` ile calisir; diger agent'lar `@sef` tarafindan secilen ve yonetilen ic koordinasyon katmanidir.

## Vision

This framework turns Cursor into a **structured software delivery workflow**: not just code generation, but classified work intake, dynamic agent routing, quality gates, failure tracking, shared state, and traceable handoffs coordinated by a single orchestrator.

It includes a deterministic orchestration runtime. Enforcement is achieved through:
- runtime-driven orchestration transitions in `@sef`
- structured markdown artifacts (`workflow-state`, decision logs, gate reports, failure reports)
- PowerShell validation and live runtime smoke tests that check enforcement rules

**User writes:** `@sef "add order module"`
**System delivers:** classified work, selected internal agents, filtered handoffs, tracked gates, visible state, and a final summary.

## Key Features

- **Single user-facing entry point**: `@sef` is the only agent the user is expected to talk to
- **Dynamic internal routing**: `@sef` selects the minimum necessary internal agent pipeline for the work type
- **Natural-language intake bridge**: free-text user requests are converted into runtime classification input (`job_type`, `scope`, `risk_level`, affected layers, approval checkpoints)
- **Decision traceability**: classification, routing, gate transitions, retries, escalations, and hard stops are recorded as runtime-linked artifacts
- **Evidence-based quality gates**: build, lint, test, coverage, review, security, and documentation evidence are tracked explicitly
- **State-bound failure policy**: retry, escalation, and human-in-the-loop decisions are tied to workflow-state counters
- **Separate approval checkpoints**: plan approval and release approval are persisted independently and can be resumed with the same execution id
- **Minimal enforcement layer**: `scripts/validate-orchestration.ps1` checks state, gate, decision, and failure artifacts
- **Live runtime coverage**: feature, bugfix, refactor, retry, escalation, and hard-stop scenarios run through the deterministic runner in smoke tests
- **Execution adapter seam**: `runtime/executor/AgentExecutionAdapter.psm1` lets `@sef` call real internal agent commands instead of synthesizing outputs in the main path
- **Project-local runtime install**: install/update copy `runtime/`, validator scripts, `scripts/run-agent.ps1`, output schema, and runtime config templates into the target project
- **5-layer architecture**: Core, Technology, Process, Domain, Learning
- **Manifest-based configuration**: one `agents.manifest.json` defines the project setup
- **Parallel execution support**: backend and frontend style splits can run against a contract-first handoff model

## How It Works

```
@sef "add feature X"
  │
  ├── 1. INTAKE: parse request summary, job type, scope, risk, and affected layers
  ├── 2. ROUTE: select the minimal internal agent set for the context
  ├── 3. PLAN: persist plan approval checkpoint
  │
  ├── 4. EXECUTE (per agent):
  │   ├── Write filtered context handoff
  │   ├── Call project-local `scripts/run-agent.ps1`
  │   ├── Validate normalized agent output
  │   ├── Update workflow-state
  │   ├── Write decision / gate / failure artifacts as needed
  │   └── Check quality gate with evidence
  │
  ├── 5. HANDLE FAILURES: retry / escalate / hard stop / resume
  │
  └── 6. RELEASE: persist release approval checkpoint and final summary
```

## Enforcement Model

The framework is intentionally hybrid:

- **LLM-guided**: work classification, internal agent selection, handoff writing, and human-readable summaries
- **Validation-supported**: workflow-state shape, decision log fields, gate evidence fields, failure counters, and artifact references

This means the framework is stronger than a plain rule pack while remaining lightweight compared to heavy workflow platforms.

Current honest scope:
- Natural-language intake is implemented in the runtime entry path, but classification quality is still heuristic / prompt-quality dependent
- Live runtime path is implemented and smoke-tested for `feature`, `bugfix`, and `refactor`
- Install/update now vendor the runtime into the target project, but real delivery still depends on the project configuring agent commands in `docs/agents/runtime/agent-invocation.json`
- `generic` evidence now fails closed for build/test/security checks; use `dotnet`, `node`, `python`, or a custom evidence command map for real verification

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

That's it. `@sef` will parse the user request, classify the work, select the internal agents, persist approval checkpoints, manage workflow-state, apply quality gates, and deliver the final user-facing summary.

## Orchestration Architecture

### Work Classification

Every request is classified before execution:

| Dimension | Values |
|-----------|--------|
| **Work Type** | `feature`, `bugfix`, `refactor`, `integration`, `performance`, `ux-ui`, `devops-infra`, `research` |
| **Scope** | S (1 file, <1h), M (2-5 files, <4h), L (multi-layer, 1-3d), XL (new bounded context, 3d+) |
| **Risk** | low, medium, high, critical |

### Dynamic Agent Routing

Not all agents run for every task. `@sef` selects the minimum necessary internal agents:

| Work Type | Agent Pipeline |
|-----------|---------------|
| **feature** | analyst → architect(?) → backend ∥ frontend → qa → review → devops(?) |
| **bugfix** | [relevant developer] → qa → review |
| **refactor** | architect(?) → [relevant developer] → qa → review |
| **integration** | analyst → architect → backend → qa → security → review |
| **research** | [relevant agents] → summary (no gates) |

### Quality Gates

7 checkpoints are available and are applied per work type. Gate outcomes are expected to be backed by evidence artifacts:

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

Hard stop triggers: security risk, architecture violation (high risk), 3 cumulative failures, or user request. Retry / escalation decisions are intended to be recorded in workflow-state and linked failure reports.

## Runtime Artifacts

Recommended orchestration artifacts live under `docs/agents/`:

- `workflow-state.md`
- `decisions/decision-log-*.md`
- `quality-gates/*.md`
- `failures/*.md`
- `state-snapshots/*.md`

These files are the main audit trail for `@sef`'s orchestration behavior.

### Upper-Tier (v4.1)

- **Parallel steps:** When the pipeline has ∥ (e.g. backend ∥ frontend), Sef prepares separate handoffs, runs both agents (same turn or sequentially), then validates and runs the gate once both are done. See `orchestrator.mdc` § 4.2a and `orchestration-policies.mdc` § Paralel adim.
- **DoR:** Before each gate or handoff, Sef checks Definition of Ready (entry criteria) from `orchestration-policies.mdc` § Definition of Ready.
- **Delivery metrics:** Optional `deliveryMetrics` in manifest + "Delivery Metrikleri" in global-conventions for DORA-style targets (not enforced by the framework).
- **Process map:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) § "Surec ve Orkestrasyon Eslesmesi" — table mapping gates/agents to BPMN and process documentation.
- **Observability:** Optional rules in tech-devops for critical-flow logging, health checks for new dependencies, postmortem template.

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

### Manifest and schema (tek kullanim yontemi)

Proje kokunde `agents.manifest.json` kullanin. IDE otomatik tamamlama ve dogrulama icin `$schema` alanini verin: framework'u projeye kurduysaniz schema genelde framework dizinindedir (ornegin `"$schema": "./agents.manifest.schema.json"` schema dosyasi proje kokundeyse). Install script (`install.ps1` / `install.sh`) ve validate script (`validate.ps1`) bu manifest'i okur; manifest'in schema ile uyumlu olmasi gerekir. Ornek manifest'ler: `examples/*/agents.manifest.json`. Orchestration ayarlari opsiyoneldir; belirtilmezse varsayilanlar kullanilir. Dokuman sablonlari ve enforcement validator, framework repo'da `templates/doc-templates/` ve `scripts/validate-orchestration.ps1` altindadir.

## Project Manifest Example

```json
{
  "$schema": "./agents.manifest.schema.json",
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
    "humanInLoopThreshold": "high",
    "runtime": {
      "executionMode": "command",
      "agentRunnerScriptPath": "scripts/run-agent.ps1",
      "agentInvocationConfigPath": "docs/agents/runtime/agent-invocation.json",
      "stackAdapter": "dotnet",
      "workingDirectory": ".",
      "evidenceCommandMapPath": "docs/agents/runtime/evidence-command-map.json",
      "agentTimeoutSeconds": 300
    }
  },
  "deliveryMetrics": {
    "deploymentFrequency": "per-sprint",
    "leadTimeTargetDays": 5,
    "mttrTargetHours": 4,
    "changeFailureRateTargetPercent": 15
  }
}
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/ARCHITECTURE.md) | Framework design, layers, priority system |
| [Enforcement Model](docs/ENFORCEMENT.md) | What is validator-supported vs still LLM-guided |
| [Example Workflows](docs/example-workflows/) | Feature, bugfix, refactor akislari (adim adim) |
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
