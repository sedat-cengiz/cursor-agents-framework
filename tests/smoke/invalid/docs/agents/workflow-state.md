# Workflow State

---

## Metadata

- **state_version:** 1.0
- **last_updated:** 2026-03-15 13:00
- **state_ref:** `docs/agents/workflow-state.md`

---

## Job Identity

- **job_id:** WORK-INVALID-001
- **title:** Broken fixture
- **job_type:** feature
- **scope:** M
- **risk_level:** orta
- **current_phase:** implementation
- **current_status:** in_progress

---

## Orchestration Control

- **selected_agents:** [@sef, @backend]
- **active_gate:** G4
- **completed_gates:** []
- **failed_gates:** []
- **human_in_loop_status:** not_required

---

## Failure Counters

- **failure_count_total:** 0
- **failure_count_current_stage:** 0
- **last_failure_type:** none
- **last_failed_gate:** none
- **retry_allowed:** yes
- **escalation_required:** no
- **human_in_loop_required:** no

---

## Evidence Status

| Evidence Field | Status | Evidence Ref | Note |
|----------------|--------|--------------|------|
| build_status | pending | — | |
| lint_status | pending | — | |
| test_status | pending | — | |
| coverage_status | pending | — | |
| review_status | pending | — | |
| security_status | pending | — | |

---

## Change Impact

- **changed_contracts:** [yok]
- **changed_components:** [BrokenService]
- **changed_data_model:** [yok]
- **affected_layers:** [Application]

---

## Verification Summary

- **test_status_summary:** pending
- **review_status_summary:** pending
- **open_risks:** none

---

## Major Decisions

| decision_id | Topic | Outcome | Ref |
|-------------|-------|---------|-----|
| DEC-WORK-INVALID-001 | gate_transition | incomplete fixture | `docs/agents/decisions/missing.md` |

---

## Agent Pipeline and Progress

| # | Agent | Status | Output | Gate | decision_ref | Notes |
|---|-------|--------|--------|------|--------------|-------|
| 1 | @backend | in_progress | — | G4 pending | DEC-WORK-INVALID-001 | |

---

## Gate Timeline

| Gate | Status | Report Ref | Decision Ref | Notes |
|------|--------|------------|--------------|-------|
| G4 | pending | `docs/agents/quality-gates/missing.md` | DEC-WORK-INVALID-001 | |

---

## Risks and Blockers

| Item | Level | Status | Owner | Ref |
|------|-------|--------|-------|-----|
| broken docs | orta | open | @sef | — |

---

## Traceability Refs

- **quality_gate_refs:** [`docs/agents/quality-gates/missing.md`]
- **failure_report_refs:** []
- **state_snapshot_refs:** []
