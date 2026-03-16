# Enforcement Model

This framework now includes a deterministic orchestration runtime for transition guards.
Enforcement combines:

1. state-machine based runtime transitions and policy guards
2. structured markdown artifacts (derived audit trail)
3. PowerShell validation and smoke tests

## What Is Enforced

- free-text intake can be normalized into runtime fields before orchestration starts
- `workflow-state.md` must keep the minimum required fields
- decision logs must include identity, rationale, risk, and state/gate references
- quality gate reports must include evidence fields such as `build_status`, `lint_status`, `test_status`, `coverage_status`, `review_status`, `security_status`, and `documentation_status`
- passed gates must keep evidence refs for the required checks
- failure policy counters must stay consistent with risk level and retry rules
- artifact references between state, decision, gate, failure, and snapshot files must resolve
- runtime event log references must exist (`docs/agents/runtime/state-events.jsonl`)
- plan approval and release approval checkpoints are stored separately and can be resumed by `execution_id`
- strict mode requires handoff files and agent output contract files

## What Is Still LLM-Guided

- work classification quality
- handoff quality
- internal agent selection quality
- filtered context completeness
- rationale quality inside decision logs
- final summary quality

## Runtime Additions

- `runtime/Invoke-Orchestration.ps1`: deterministic runner
- `runtime/intake/RequestIntake.psm1`: natural-language intake bridge
- `runtime/engine/StateMachine.psm1`: transition graph and guards
- `runtime/engine/EventStore.psm1`: append-only event log and replay helpers
- `runtime/executor/EvidenceCollector.psm1`: command-based evidence probes
- `runtime/executor/AgentContract.psm1`: handoff and output contract checks
- `runtime/executor/AgentExecutionAdapter.psm1`: live agent execution seam (`@sef` -> command adapter -> normalized agent output)
- `runtime/policies/RetryPolicy.psm1`: retry/escalation/hard-stop decision rules
- `scripts/run-agent.ps1`: project-local normalized runner entry point

## Supported Live Path

The current enforced live path is intentionally narrow:

- `feature`
- `bugfix`
- `refactor`

For these flows, the runtime now accepts a free-text request, derives intake context, selects a minimal pipeline, writes project-local handoffs, runs internal agents through `scripts/run-agent.ps1`, and produces replayable event logs.

Important:

- `generic` evidence is fail-closed for build/test/security checks
- real G4-G6 verification should use `dotnet`, `node`, `python`, or a custom evidence command map
- the framework installs runtime files into the target project, but real agent execution still depends on project-specific command mapping in `docs/agents/runtime/agent-invocation.json`

## Production Metrics Gate

- `tests/run-smoke-tests.ps1` now produces `tests/smoke/enforcement-score.json`
- CI enforces `enforcement_score >= 0.90` as a merge gate
- Smoke tests execute live feature, bugfix, refactor, retry, escalation, hard-stop, and invalid-output scenarios through the runtime

## Validation Entry Points

- `scripts/validate.ps1`: project installation and structure validation
- `scripts/validate-orchestration.ps1`: orchestration artifact validation
- `tests/run-smoke-tests.ps1`: feature, bugfix, refactor, and negative smoke scenarios

## Evidence Status Values

- `verified`
- `not_verified`
- `pending`
- `skipped_with_reason`

## Main Goal

The user should be able to work only with `@sef`, while `@sef` manages the internal agent graph with more visible state, more explicit decisions, and less silent process skipping.
