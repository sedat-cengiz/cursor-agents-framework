# State Snapshot

Belirli bir anda orkestrasyon durumunun dondurulmus gorunumu. Failure, hard stop, checkpoint veya kullanici talebi durumunda kullanilir.

---

## Metadata

- **snapshot_id:** SNAP-WORK-XXX-001
- **job_id:** WORK-XXX
- **timestamp:** YYYY-MM-DD HH:MM
- **snapshot_reason:** [gate_transition | failure | user_request | checkpoint | hard_stop]
- **state_ref:** `docs/agents/workflow-state.md`
- **execution_id:** EXEC-XXXXXXXX
- **runtime_event_log_ref:** `docs/agents/runtime/state-events.jsonl`

---

## Job Summary

- **title:** [kisa is basligi]
- **job_type:** [feature | bugfix | refactor | integration | performance | ux-ui | devops-infra | research]
- **scope:** [S | M | L | XL]
- **risk_level:** [dusuk | orta | yuksek | kritik]
- **current_phase:** [classification | analysis | architecture | implementation | testing | review | release | blocked]

---

## Control State

- **active_gate:** [G1 | G2 | G3 | G4 | G5 | G6 | G7 | none]
- **next_action:** [siradaki net aksiyon]
- **human_in_loop_status:** [not_required | pending_user | engaged | resolved]

---

## Failure State

- **failure_count_total:** 0
- **failure_count_current_stage:** 0
- **last_failure_type:** [none | format_error | missing_output | logic_inconsistency | architecture_violation | test_failure | security_risk | insufficient_context]
- **last_failed_gate:** [none | G1 | G2 | G3 | G4 | G5 | G6 | G7]

---

## Agent Pipeline Snapshot

| # | Agent | Status | Output | Ref |
|---|-------|--------|--------|-----|
| 1 | | | | |

---

## Gate Snapshot

| Gate | Status | Report Ref | Decision Ref |
|------|--------|------------|--------------|
| G1 | pending | — | — |
| G2 | pending | — | — |
| G3 | pending | — | — |
| G4 | pending | — | — |
| G5 | pending | — | — |
| G6 | pending | — | — |
| G7 | pending | — | — |

---

## Change Summary

- **changed_contracts:** [yok | liste]
- **changed_components:** [yok | liste]
- **changed_data_model:** [yok | ozet]
- **open_risks:** [none | risk listesi]

---

## Traceability

- **decision_refs:** []
- **failure_report_refs:** []
- **quality_gate_refs:** []
