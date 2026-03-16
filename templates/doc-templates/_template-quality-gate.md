# Quality Gate Report

Her gate gecisinde `@sef` bu raporu doldurur. Serbest metin yeterli degildir; evidence alanlari zorunludur.

---

## Metadata

- **report_id:** GATE-WORK-XXX-GX-001
- **job_id:** WORK-XXX
- **gate_id:** [G1 | G2 | G3 | G4 | G5 | G6 | G7]
- **gate_name:** [Analiz | Kabul | Mimari | Uygulama | Test | Review | Yayin]
- **timestamp:** YYYY-MM-DD HH:MM
- **decision_id:** DEC-XXX
- **state_ref:** `docs/agents/workflow-state.md`
- **outcome:** [passed | warning | failed | stopped | skipped]
- **execution_id:** EXEC-XXXXXXXX
- **runtime_event_log_ref:** `docs/agents/runtime/state-events.jsonl`

---

## Decision Summary

- **decision_topic:** [gate_transition | gate_failure | gate_skip]
- **chosen_path:** [gate gecti / kaldi / atlandi]
- **rationale:** [kisa gerekce]
- **skip_reason:** [yoksa `none`]

---

## Evidence Status

<!-- Allowed values: verified | not_verified | pending | skipped_with_reason -->

- **build_status:** pending
- **lint_status:** pending
- **test_status:** pending
- **coverage_status:** pending
- **review_status:** pending
- **security_status:** pending
- **documentation_status:** pending

---

## Evidence Refs

| Evidence Field | Required For This Gate | Evidence Ref | Notes |
|----------------|------------------------|--------------|-------|
| build_status | no | — | |
| lint_status | no | — | |
| test_status | no | — | |
| coverage_status | no | — | |
| review_status | no | — | |
| security_status | no | — | |
| documentation_status | yes | — | |

### Evidence Command Log

| Evidence Field | Command | Exit Code |
|----------------|---------|-----------|
| build_status | — | 0 |

---

## Criteria Breakdown

| # | Criterion | Result | Notes |
|---|-----------|--------|-------|
| 1 | | [passed | failed | skipped] | |
| 2 | | [passed | failed | skipped] | |
| 3 | | [passed | failed | skipped] | |

---

## Failure / Next Action

- **failed_gate:** [none | G1 | G2 | G3 | G4 | G5 | G6 | G7]
- **failure_report_ref:** [yoksa `none`]
- **owner_agent:** [@sef | @analist | @mimari | @backend | @frontend | @qa | @review | @guvenlik | @devops]
- **next_action:** [siradaki net aksiyon]

---

## Traceability

- **workflow_state_ref:** `docs/agents/workflow-state.md`
- **related_decision_log_ref:** `docs/agents/decisions/decision-log-WORK-XXX-001.md`
