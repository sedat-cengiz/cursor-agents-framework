# Decision Log

`@sef`'in kritik operasyonel kararlarini izlenebilir hale getirmek icin kullanilir.
Mimari kararlar icin ADR kullanilmaya devam edilir; bu sablon operasyonel orkestrasyon kararlari icindir.

---

## Metadata

- **decision_id:** DEC-WORK-XXX-001
- **timestamp:** YYYY-MM-DD HH:MM
- **job_id:** WORK-XXX
- **decision_topic:** [work_classification | agent_routing | gate_transition | gate_skip | retry | escalation | hard_stop | human_in_loop | architecture_direction]

---

## Selected Path

- **chosen_path:** [secilen yolun tek satirlik ozeti]

---

## Rejected Alternatives

| Alternative | Description | Why Rejected |
|-------------|-------------|--------------|
| A | | |
| B | | |

---

## Rationale

- **rationale:** [kararin neden alindigi]

---

## Risk

- **risk_level:** [dusuk | orta | yuksek | kritik]
- **risk_note:** [kisa aciklama]

---

## Impact Scope

- **impacted_agents_or_layers:** [@backend, @frontend, Process, Technology]
- **related_gate_refs:** [G2, G3]
- **related_state_ref:** `docs/agents/workflow-state.md`

---

## Related Records

- **quality_gate_ref:** [yoksa `none`]
- **failure_report_ref:** [yoksa `none`]
- **adr_ref:** [yoksa `none`]
