# Failure Report

Agent basarisizligi, escalation veya hard stop sonrasi `@sef` bu raporu doldurur.

---

## Metadata

- **failure_id:** FAIL-WORK-XXX-001
- **job_id:** WORK-XXX
- **timestamp:** YYYY-MM-DD HH:MM
- **agent:** [@analist | @mimari | @backend | @frontend | @qa | @review | @guvenlik | @devops | @sef]
- **step:** [analysis | architecture | implementation | testing | review | release]
- **decision_id:** DEC-XXX
- **state_ref:** `docs/agents/workflow-state.md`
- **failed_gate:** [none | G1 | G2 | G3 | G4 | G5 | G6 | G7]
- **execution_id:** EXEC-XXXXXXXX
- **runtime_event_log_ref:** `docs/agents/runtime/state-events.jsonl`

---

## Failure Counters

- **risk_level:** [dusuk | orta | yuksek | kritik]
- **failure_count_total:** 1
- **failure_count_current_stage:** 1
- **retry_attempt:** 1
- **retry_limit:** [0 | 1 | 2]
- **retry_allowed:** [yes | no]
- **escalation_required:** [yes | no]
- **human_in_loop_required:** [yes | no]

---

## Failure Type

- **failure_type:** [format_error | missing_output | logic_inconsistency | architecture_violation | test_failure | security_risk | insufficient_context]
- **root_cause:** [spesifik aciklama]

---

## Expected vs Actual

| Area | Expected | Actual |
|------|----------|--------|
| Output | | |
| Format | | |
| Content | | |

---

## Action Taken

- **action_taken:** [retry | escalate | hard_stop | ask_user | reroute]
- **resolution_status:** [open | mitigated | resolved | blocked]
- **next_action:** [siradaki net aksiyon]

---

## Prevention

- **prevention_note:** [tekrar etmemesi icin alinacak onlem]

---

## Traceability

- **decision_log_ref:** `docs/agents/decisions/decision-log-WORK-XXX-001.md`
- **quality_gate_ref:** [yoksa `none`]
- **state_snapshot_ref:** [yoksa `none`]
- **agent_output_ref:** [yoksa `none`]
