# Workflow State

Paylasimli orkestrasyon durumu. Bu dosya runtime event log'dan tureyen operasyonel gorunumdur; `@sef` yazarin tek sahibi, diger agent'lar yalnizca dolayli cikti uretir.

---

## Metadata

- **state_version:** 1.0
- **last_updated:** YYYY-MM-DD HH:MM
- **state_ref:** `docs/agents/workflow-state.md`
- **execution_id:** EXEC-XXXXXXXX
- **runtime_event_log_ref:** `docs/agents/runtime/state-events.jsonl`

---

## Job Identity

- **job_id:** WORK-XXX
- **title:** [kisa is basligi]
- **request_summary:** [serbest metin istegin kisa ozeti]
- **job_type:** [feature | bugfix | refactor | integration | performance | ux-ui | devops-infra | research]
- **scope:** [S | M | L | XL]
- **risk_level:** [dusuk | orta | yuksek | kritik]
- **affected_layers:** [API | UI | DB | Infra | Security]
- **current_phase:** [classification | analysis | architecture | implementation | testing | review | release | blocked]
- **current_status:** [pending | in_progress | waiting_for_user | failed | completed | stopped]
- **current_agent:** [@sef | @analist | @mimari | @backend | @frontend | @qa | @review | @guvenlik | @devops]

---

## Orchestration Control

- **selected_agents:** [@sef, @analist, @mimari, @backend, @frontend, @qa, @review]
- **active_gate:** [G1 | G2 | G3 | G4 | G5 | G6 | G7 | none]
- **completed_gates:** [G1, G2]
- **failed_gates:** []
- **next_action:** [siradaki net aksiyon]
- **human_in_loop_status:** [not_required | pending_user | engaged | resolved]
- **plan_approval_status:** [not_required | pending_user | approved | rejected]
- **release_approval_status:** [not_required | pending_user | approved | rejected]

---

## Failure Counters

- **failure_count_total:** 0
- **failure_count_current_stage:** 0
- **last_failure_type:** [none | format_error | missing_output | logic_inconsistency | architecture_violation | test_failure | security_risk | insufficient_context]
- **last_failed_gate:** [none | G1 | G2 | G3 | G4 | G5 | G6 | G7]
- **retry_allowed:** [yes | no]
- **escalation_required:** [yes | no]
- **human_in_loop_required:** [yes | no]

---

## Evidence Status

<!-- Evidence statuses: verified | not_verified | pending | skipped_with_reason -->

| Evidence Field | Status | Evidence Ref | Note |
|----------------|--------|--------------|------|
| build_status | pending | none | |
| lint_status | pending | none | |
| test_status | pending | none | |
| coverage_status | pending | none | |
| review_status | pending | none | |
| security_status | pending | none | |
| documentation_status | pending | none | |

---

## Change Impact

- **changed_contracts:** [yok | contract-order-v1.md]
- **changed_components:** [modul, servis, ekran, sinif listesi]
- **changed_data_model:** [yok | tablo/alan/migration ozeti]
- **affected_layers:** [Domain | Application | API | UI | DB | Infra]

---

## Verification Summary

- **test_status_summary:** [pending | passed | failed | skipped]
- **review_status_summary:** [pending | passed | failed | skipped]
- **open_risks:** [yoksa `none` yaz]

---

## Major Decisions

| decision_id | Topic | Outcome | Ref |
|-------------|-------|---------|-----|
| DEC-001 | work_classification | feature / L / orta | `docs/agents/decisions/decision-log-WORK-XXX-001.md` |

---

## Agent Pipeline and Progress

| # | Agent | Status | Output | Gate | decision_ref | Notes |
|---|-------|--------|--------|------|--------------|-------|
| 1 | @analist | pending | — | G2 | DEC-001 | |

<!-- Status: pending | in_progress | completed | failed | skipped -->
<!-- Gate result: G1-G7 passed | failed | warning | skipped -->

---

## Gate Timeline

| Gate | Status | Report Ref | Decision Ref | Notes |
|------|--------|------------|--------------|-------|
| G1 | pending | — | — | |
| G2 | pending | — | — | |
| G3 | pending | — | — | |
| G4 | pending | — | — | |
| G5 | pending | — | — | |
| G6 | pending | — | — | |
| G7 | pending | — | — | |

---

## Risks and Blockers

| Item | Level | Status | Owner | Ref |
|------|-------|--------|-------|-----|
| | | | | |

---

## Traceability Refs

- **quality_gate_refs:** []
- **failure_report_refs:** []
- **state_snapshot_refs:** []
- **agent_output_refs:** []
