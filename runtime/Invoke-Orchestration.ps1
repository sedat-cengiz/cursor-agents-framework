<#
.SYNOPSIS
    Deterministic orchestration runner for @sef.
.DESCRIPTION
    Executes a real handoff -> agent execution -> contract validation -> gate evaluation
    loop while keeping runtime events as the primary source of truth.
#>
param(
    [Parameter(Mandatory = $true)][string]$DocsPath,
    [string]$UserRequest = "",
    [string]$JobId = "",
    [string]$JobType = "",
    [string]$Scope = "",
    [string]$RiskLevel = "",
    [string]$Title = "",
    [switch]$EnableSyntheticRun,
    [ValidateSet("generic","dotnet","node","python")][string]$StackAdapter = "generic",
    [string]$ExecutionId = "",
    [switch]$ResumeExecution,
    [ValidateSet("none","approve_plan","approve_release","reject_plan","reject_release")][string]$ApprovalAction = "none",
    [string]$ManifestPath = "",
    [string]$AgentCommandTemplate = "",
    [string]$EvidenceCommandMapPath = "",
    [string]$WorkingDirectory = "",
    [int]$AgentTimeoutSeconds = 0,
    [switch]$AutoApproveUserDecisions,
    [ValidateSet("off","warn","enforce")][string]$StrictMode = "warn"  # NEW: Strict mode for direct agent calls
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Import-Module (Join-Path $PSScriptRoot "engine\StateMachine.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "engine\EventStore.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "intake\RequestIntake.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "executor\EvidenceCollector.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "executor\AgentContract.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "executor\AgentExecutionAdapter.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "policies\RetryPolicy.psm1") -Force

if (-not (Test-Path $DocsPath)) {
    throw "Docs path not found: $DocsPath"
}

$null = New-Item -ItemType Directory -Path (Join-Path $DocsPath "handoffs") -Force
$null = New-Item -ItemType Directory -Path (Join-Path $DocsPath "agent-outputs") -Force
$null = New-Item -ItemType Directory -Path (Join-Path $DocsPath "decisions") -Force
$null = New-Item -ItemType Directory -Path (Join-Path $DocsPath "quality-gates") -Force
$null = New-Item -ItemType Directory -Path (Join-Path $DocsPath "failures") -Force
$null = New-Item -ItemType Directory -Path (Join-Path $DocsPath "state-snapshots") -Force
$null = New-Item -ItemType Directory -Path (Join-Path $DocsPath "reviews") -Force

$eventPath = New-EventStore -DocsPath $DocsPath
if (-not $ExecutionId) {
    $ExecutionId = "EXEC-{0}" -f ([guid]::NewGuid().ToString("N").Substring(0, 8))
}

$runtimeConfig = Resolve-OrchestrationRuntimeConfig -DocsPath $DocsPath -ManifestPath $ManifestPath -ExecutionMode $(if ($EnableSyntheticRun) { "synthetic" } else { "" }) -AgentCommandTemplate $AgentCommandTemplate -EvidenceCommandMapPath $EvidenceCommandMapPath -WorkingDirectory $WorkingDirectory -StackAdapter $StackAdapter -AgentTimeoutSeconds $AgentTimeoutSeconds
$WorkingDirectory = [string]$runtimeConfig.working_directory
$StackAdapter = [string]$runtimeConfig.stack_adapter
$EvidenceCommandMapPath = [string]$runtimeConfig.evidence_command_map_path
$AgentCommandTemplate = [string]$runtimeConfig.agent_command_template
$executionMode = [string]$runtimeConfig.execution_mode

# STRICT MODE: Add strict mode to runtime config
$runtimeConfig.strict_mode = $StrictMode

# Log strict mode status at startup
if ($StrictMode -ne "off") {
    Write-Host "STRICT MODE [$StrictMode]: Direct agent calls without orchestrator will trigger quality gate checks." -ForegroundColor Yellow
}

function New-GeneratedJobId {
    param(
        [string]$ResolvedJobType = "feature"
    )

    $typeToken = $ResolvedJobType.ToUpperInvariant().Replace("-", "")
    return "WORK-{0}-{1}" -f $typeToken, (Get-Date -Format "yyyyMMddHHmmss")
}

function Copy-State {
    param([object]$InputState)

    if ($null -eq $InputState) { return $null }
    if ($InputState -is [System.Collections.IDictionary]) {
        $copy = @{}
        foreach ($key in $InputState.Keys) {
            $copy[$key] = Copy-State -InputState $InputState[$key]
        }
        return $copy
    }
    if ($InputState -is [System.Collections.IEnumerable] -and $InputState -isnot [string]) {
        $items = @()
        foreach ($item in $InputState) {
            $items += ,(Copy-State -InputState $item)
        }
        return $items
    }
    if ($InputState -is [pscustomobject]) {
        $copy = @{}
        foreach ($property in $InputState.PSObject.Properties) {
            $copy[$property.Name] = Copy-State -InputState $property.Value
        }
        return $copy
    }
    return $InputState
}

function ConvertTo-ListLiteral {
    param([object]$Value)
    if ($null -eq $Value) { return "[]" }
    $items = @($Value | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($items.Count -eq 0) { return "[]" }
    return "[" + (($items | ForEach-Object { [string]$_ }) -join ", ") + "]"
}

function ConvertTo-RefListLiteral {
    param([object]$Value)
    if ($null -eq $Value) { return "[]" }
    $items = @($Value | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($items.Count -eq 0) { return "[]" }
    return "[" + (($items | ForEach-Object { [string]$_ }) -join ", ") + "]"
}

function Merge-UniqueList {
    param(
        [object]$Existing,
        [object]$Incoming
    )

    $result = @()
    foreach ($item in @($Existing) + @($Incoming)) {
        if ($item -is [System.Collections.IDictionary]) { continue }
        if ([string]::IsNullOrWhiteSpace([string]$item)) { continue }
        if ($result -notcontains [string]$item) {
            $result += [string]$item
        }
    }
    return $result
}

function Set-StepField {
    param(
        [string]$Agent,
        [string]$StepId,
        [string]$Field,
        [object]$Value
    )

    foreach ($step in $script:state.pipeline) {
        if ($step.agent -eq $Agent -and $step.step_id -eq $StepId) {
            $step[$Field] = $Value
        }
    }
}

function Get-StepGroup {
    param(
        [int]$StartIndex
    )

    $current = $script:state.pipeline[$StartIndex]
    $group = @($current)
    if ($current.parallel_group -eq "none") {
        return $group
    }

    for ($i = $StartIndex + 1; $i -lt $script:state.pipeline.Count; $i++) {
        $candidate = $script:state.pipeline[$i]
        if ($candidate.parallel_group -eq $current.parallel_group -and $candidate.gate -eq $current.gate) {
            $group += $candidate
            continue
        }
        break
    }
    return $group
}

function Write-WorkflowStateDoc {
    $statePath = Join-Path $DocsPath "workflow-state.md"
    $gateLines = @()
    foreach ($gate in @("G1","G2","G3","G4","G5","G6","G7")) {
        $status = "skipped"
        $reportRef = "-"
        $decisionRef = "-"
        $notes = ""
        if (Test-GateAllowedForJobType -JobType $script:state.job_type -GateId $gate) {
            $status = "pending"
            if ($script:state.gate_results.ContainsKey($gate)) {
                $result = $script:state.gate_results[$gate]
                $status = [string]$result.status
                if ($result.report_ref) { $reportRef = $result.report_ref }
                if ($result.decision_id) { $decisionRef = [string]$result.decision_id }
                if ($result.notes) { $notes = [string]$result.notes }
            }
        } else {
            $notes = "not applicable for job type"
        }
        $gateLines += "| $gate | $status | $reportRef | $decisionRef | $notes |"
    }

    $decisionRows = @()
    foreach ($decision in @($script:state.decision_records)) {
        $decisionRows += "| $($decision.decision_id) | $($decision.topic) | $($decision.outcome) | $($decision.ref) |"
    }
    if ($decisionRows.Count -eq 0) {
        $decisionRows = @("| - | - | - | - |")
    }

    $pipelineRows = @()
    foreach ($step in $script:state.pipeline) {
        $status = if ($step.status) { $step.status } else { "pending" }
        $output = if ($step.output) { $step.output } else { "-" }
        $decisionRef = if ($step.decision_ref) { $step.decision_ref } else { "-" }
        $notes = if ($step.notes) { $step.notes } else { "" }
        $pipelineRows += "| $($step.order) | $($step.agent) | $status | $output | $($step.gate) | $decisionRef | $notes |"
    }

    $riskRows = if ([string]::IsNullOrWhiteSpace([string]$script:state.open_risks) -or [string]$script:state.open_risks -eq "none") {
        @("| none | dusuk | closed | @sef | - |")
    } else {
        @("| $($script:state.open_risks) | $($script:state.risk_level) | open | @sef | - |")
    }

    $doc = @(
        "# Workflow State",
        "",
        "---",
        "",
        "## Metadata",
        "",
        "- **state_version:** 1.0",
        "- **last_updated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
        "- **state_ref:** docs/agents/workflow-state.md",
        "- **execution_id:** $ExecutionId",
        "- **runtime_event_log_ref:** docs/agents/runtime/state-events.jsonl",
        "",
        "---",
        "",
        "## Job Identity",
        "",
        "- **job_id:** $($script:state.job_id)",
        "- **title:** $($script:state.title)",
        "- **request_summary:** $($script:state.request_summary)",
        "- **job_type:** $($script:state.job_type)",
        "- **scope:** $($script:state.scope)",
        "- **risk_level:** $($script:state.risk_level)",
        "- **affected_layers:** $(ConvertTo-ListLiteral -Value $script:state.affected_layers)",
        "- **current_phase:** $($script:state.current_phase)",
        "- **current_status:** $($script:state.current_status)",
        "- **current_agent:** $($script:state.current_agent)",
        "",
        "---",
        "",
        "## Orchestration Control",
        "",
        "- **selected_agents:** $(ConvertTo-ListLiteral -Value $script:state.selected_agents)",
        "- **active_gate:** $($script:state.active_gate)",
        "- **completed_gates:** $(ConvertTo-ListLiteral -Value $script:state.completed_gates)",
        "- **failed_gates:** $(ConvertTo-ListLiteral -Value $script:state.failed_gates)",
        "- **next_action:** $($script:state.next_action)",
        "- **human_in_loop_status:** $($script:state.human_in_loop_status)",
        "- **plan_approval_status:** $($script:state.approval_status.plan)",
        "- **release_approval_status:** $($script:state.approval_status.release)",
        "",
        "---",
        "",
        "## Failure Counters",
        "",
        "- **failure_count_total:** $($script:state.failure_count_total)",
        "- **failure_count_current_stage:** $($script:state.failure_count_current_stage)",
        "- **last_failure_type:** $($script:state.last_failure_type)",
        "- **last_failed_gate:** $($script:state.last_failed_gate)",
        "- **retry_allowed:** $($script:state.retry_allowed)",
        "- **escalation_required:** $($script:state.escalation_required)",
        "- **human_in_loop_required:** $($script:state.human_in_loop_required)",
        "",
        "---",
        "",
        "## Evidence Status",
        "",
        "| Evidence Field | Status | Evidence Ref | Note |",
        "|----------------|--------|--------------|------|",
        "| build_status | $($script:state.evidence_status.build_status) | - | |",
        "| lint_status | $($script:state.evidence_status.lint_status) | - | |",
        "| test_status | $($script:state.evidence_status.test_status) | - | |",
        "| coverage_status | $($script:state.evidence_status.coverage_status) | - | |",
        "| review_status | $($script:state.evidence_status.review_status) | - | |",
        "| security_status | $($script:state.evidence_status.security_status) | - | |",
        "| documentation_status | $($script:state.evidence_status.documentation_status) | - | |",
        "",
        "---",
        "",
        "## Change Impact",
        "",
        "- **changed_contracts:** $(ConvertTo-ListLiteral -Value $script:state.changed_contracts)",
        "- **changed_components:** $(ConvertTo-ListLiteral -Value $script:state.changed_components)",
        "- **changed_data_model:** $($script:state.changed_data_model)",
        "- **affected_layers:** [Application, API, UI, DB, Infra]",
        "",
        "---",
        "",
        "## Verification Summary",
        "",
        "- **test_status_summary:** $($script:state.test_status_summary)",
        "- **review_status_summary:** $($script:state.review_status_summary)",
        "- **open_risks:** $($script:state.open_risks)",
        "",
        "---",
        "",
        "## Major Decisions",
        "",
        "| decision_id | Topic | Outcome | Ref |",
        "|-------------|-------|---------|-----|"
    ) + $decisionRows + @(
        "",
        "---",
        "",
        "## Agent Pipeline and Progress",
        "",
        "| # | Agent | Status | Output | Gate | decision_ref | Notes |",
        "|---|-------|--------|--------|------|--------------|-------|"
    ) + $pipelineRows + @(
        "",
        "---",
        "",
        "## Gate Timeline",
        "",
        "| Gate | Status | Report Ref | Decision Ref | Notes |",
        "|------|--------|------------|--------------|-------|"
    ) + $gateLines + @(
        "",
        "---",
        "",
        "## Risks and Blockers",
        "",
        "| Item | Level | Status | Owner | Ref |",
        "|------|-------|--------|-------|-----|"
    ) + $riskRows + @(
        "",
        "---",
        "",
        "## Traceability Refs",
        "",
        "- **quality_gate_refs:** $(ConvertTo-RefListLiteral -Value $script:state.quality_gate_refs)",
        "- **failure_report_refs:** $(ConvertTo-RefListLiteral -Value $script:state.failure_report_refs)",
        "- **state_snapshot_refs:** $(ConvertTo-RefListLiteral -Value $script:state.state_snapshot_refs)",
        "- **agent_output_refs:** $(ConvertTo-RefListLiteral -Value $script:state.agent_output_refs)"
    )

    Set-Content -Path $statePath -Value $doc
}

function New-DecisionLog {
    param(
        [Parameter(Mandatory = $true)][string]$Topic,
        [Parameter(Mandatory = $true)][string]$ChosenPath,
        [Parameter(Mandatory = $true)][string]$Rationale,
        [string[]]$RelatedGateRefs = @(),
        [string]$Outcome = "",
        [string[]]$ImpactedAgents = @(),
        [string]$QualityGateRef = "none",
        [string]$FailureReportRef = "none"
    )

    $script:decisionSequence++
    $decisionId = "DEC-$JobId-{0:d3}" -f $script:decisionSequence
    $decisionFileName = "decision-log-$JobId-{0:d3}.md" -f $script:decisionSequence
    $decisionPath = Join-Path (Join-Path $DocsPath "decisions") $decisionFileName
    $relativeRef = "docs/agents/decisions/$decisionFileName"
    $doc = @(
        "# Decision Log",
        "",
        "---",
        "",
        "## Metadata",
        "",
        "- **decision_id:** $decisionId",
        "- **timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
        "- **job_id:** $JobId",
        "- **decision_topic:** $Topic",
        "",
        "---",
        "",
        "## Selected Path",
        "",
        "- **chosen_path:** $ChosenPath",
        "",
        "---",
        "",
        "## Rejected Alternatives",
        "",
        "| Alternative | Description | Why Rejected |",
        "|-------------|-------------|--------------|",
        "| A | none | primary path selected |",
        "",
        "---",
        "",
        "## Rationale",
        "",
        "- **rationale:** $Rationale",
        "",
        "---",
        "",
        "## Risk",
        "",
        "- **risk_level:** $RiskLevel",
        "- **risk_note:** runtime-managed decision",
        "",
        "---",
        "",
        "## Impact Scope",
        "",
        "- **impacted_agents_or_layers:** $(ConvertTo-ListLiteral -Value $ImpactedAgents)",
        "- **related_gate_refs:** $(ConvertTo-ListLiteral -Value $RelatedGateRefs)",
        "- **related_state_ref:** docs/agents/workflow-state.md",
        "",
        "---",
        "",
        "## Related Records",
        "",
        "- **quality_gate_ref:** $QualityGateRef",
        "- **failure_report_ref:** $FailureReportRef",
        "- **adr_ref:** none"
    )
    Set-Content -Path $decisionPath -Value $doc

    $script:state.major_decisions = Merge-UniqueList -Existing $script:state.major_decisions -Incoming @($decisionId)
    $decisionRecords = New-Object System.Collections.ArrayList
    foreach ($existing in @($script:state.decision_records)) {
        [void]$decisionRecords.Add($existing)
    }
    [void]$decisionRecords.Add(@{
        decision_id = $decisionId
        topic = $Topic
        outcome = $(if ($Outcome) { $Outcome } else { $ChosenPath })
        ref = $relativeRef
    })
    $script:state.decision_records = @($decisionRecords)

    [void](Add-StateEvent -EventPath $eventPath -ExecutionId $ExecutionId -JobId $JobId -EventType "decision_log" -Payload @{
        decision_id = $decisionId
        decision_topic = $Topic
        decision_ref = $relativeRef
    } -IdempotencyKey "$ExecutionId-decision-$decisionId")

    return @{
        decision_id = $decisionId
        ref = $relativeRef
    }
}

function Write-HandoffDoc {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Step,
        [Parameter(Mandatory = $true)][string]$DecisionId
    )

    $agentName = $Step.agent.TrimStart("@")
    $handoffFileName = "handoff-$JobId-$agentName-$($Step.step_id).md"
    $handoffPath = Join-Path (Join-Path $DocsPath "handoffs") $handoffFileName
    $doc = @(
        "# Handoff: @sef → $($Step.agent)",
        "",
        "**Tarih:** $(Get-Date -Format 'yyyy-MM-dd')  ",
        "**Is:** $JobId | **Tur:** $JobType | **Kapsam:** $Scope  ",
        "**Task:** TASK-$JobId-$($Step.order) | **Ilgili US:** none",
        "**Execution:** $ExecutionId | **Handoff Contract:** HANDOFF-CONTRACT-V2",
        "",
        "---",
        "",
        "## Is Ozeti",
        "",
        "$($script:state.request_summary)",
        "",
        "---",
        "",
        "## Bu Agent'in Gorevi",
        "",
        "1. Complete step $($Step.step_id) for gate $($Step.gate).",
        "2. Produce a normalized agent output JSON.",
        "",
        "---",
        "",
        "## Kesinlesmis Kararlar",
        "",
        "- **ADR:** none",
        "- **Kontrat:** $(ConvertTo-ListLiteral -Value $script:state.changed_contracts)",
        "- **Onceki agent ciktisi:** $(ConvertTo-ListLiteral -Value ($script:state.agent_output_refs | Select-Object -Last 3))",
        "- **State ref:** docs/agents/workflow-state.md",
        "- **Decision refs:** $(ConvertTo-ListLiteral -Value (($script:state.major_decisions | Select-Object -Last 3) + @($DecisionId)))",
        "",
        "---",
        "",
        "## Teknik Baglam",
        "",
        "- **Ilgili katmanlar:** $(ConvertTo-ListLiteral -Value $script:state.affected_layers)",
        "- **Ilgili dosyalar:** docs/agents, runtime, project-local scripts",
        "- **Mevcut mimari:** runtime-authoritative orchestration",
        "",
        "---",
        "",
        "## Kisitlar ve Riskler",
        "",
        "- Runtime state is authoritative.",
        "- **Active gate:** $($Step.gate)",
        "",
        "---",
        "",
        "## Beklenen Cikti",
        "",
        "- Normalized agent output json",
        "- **Cikti formati:** docs/agents/agent-outputs/$agentName-$JobId-$($Step.step_id).json",
        "",
        "---",
        "",
        "## Definition of Done",
        "",
        "- [ ] Agent output contract valid",
        "- [ ] Gerekli gate evidence alanlari icin kanit birakildi"
    )
    Set-Content -Path $handoffPath -Value $doc
    return @{
        path = $handoffPath
        ref = "docs/agents/handoffs/$handoffFileName"
    }
}

function Write-GateReportDoc {
    param(
        [string]$GateId = "none",
        [Parameter(Mandatory = $true)][hashtable]$Evidence,
        [Parameter(Mandatory = $true)][string]$Outcome,
        [Parameter(Mandatory = $true)][string]$DecisionId,
        [Parameter(Mandatory = $true)][string]$DecisionRef,
        [string]$FailureReportRef = "none",
        [string]$NextAction = "continue",
        [string]$Rationale = ""
    )

    $reportFile = "$GateId-$JobId.md"
    $reportPath = Join-Path (Join-Path $DocsPath "quality-gates") $reportFile
    $requiredFields = @{
        G1 = @("documentation_status")
        G2 = @("documentation_status")
        G3 = @("documentation_status","review_status")
        G4 = @("build_status","lint_status","security_status","documentation_status")
        G5 = @("test_status","coverage_status","documentation_status")
        G6 = @("review_status","security_status","documentation_status")
        G7 = @("documentation_status","review_status")
    }
    $defaults = @{
        build_status = "pending"
        lint_status = "pending"
        test_status = "pending"
        coverage_status = "pending"
        review_status = "pending"
        security_status = "pending"
        documentation_status = "pending"
    }
    foreach ($field in $Evidence.Keys) {
        $defaults[$field] = $Evidence[$field].status
        $script:state.evidence_status[$field] = $Evidence[$field].status
    }

    $doc = @(
        "# Quality Gate Report",
        "",
        "---",
        "",
        "## Metadata",
        "",
        "- **report_id:** GATE-$JobId-$GateId",
        "- **job_id:** $JobId",
        "- **gate_id:** $GateId",
        "- **gate_name:** runtime-$GateId",
        "- **timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
        "- **decision_id:** $DecisionId",
        "- **state_ref:** docs/agents/workflow-state.md",
        "- **outcome:** $Outcome",
        "- **execution_id:** $ExecutionId",
        "- **runtime_event_log_ref:** docs/agents/runtime/state-events.jsonl",
        "",
        "---",
        "",
        "## Decision Summary",
        "",
        "- **decision_topic:** gate_transition",
        "- **chosen_path:** $GateId $Outcome",
        "- **rationale:** $(if ($Rationale) { $Rationale } else { "$GateId decided from runtime evidence and state." })",
        "- **skip_reason:** none",
        "",
        "---",
        "",
        "## Evidence Status",
        "",
        "- **build_status:** $($defaults.build_status)",
        "- **build_evidence_ref:** $(if ($Evidence.build_status -and $Evidence.build_status.evidence_ref) { $Evidence.build_status.evidence_ref } else { 'none' })",
        "- **lint_status:** $($defaults.lint_status)",
        "- **lint_evidence_ref:** $(if ($Evidence.lint_status -and $Evidence.lint_status.evidence_ref) { $Evidence.lint_status.evidence_ref } else { 'none' })",
        "- **test_status:** $($defaults.test_status)",
        "- **test_evidence_ref:** $(if ($Evidence.test_status -and $Evidence.test_status.evidence_ref) { $Evidence.test_status.evidence_ref } else { 'none' })",
        "- **coverage_status:** $($defaults.coverage_status)",
        "- **coverage_evidence_ref:** $(if ($Evidence.coverage_status -and $Evidence.coverage_status.evidence_ref) { $Evidence.coverage_status.evidence_ref } else { 'none' })",
        "- **review_status:** $($defaults.review_status)",
        "- **review_evidence_ref:** $(if ($Evidence.review_status -and $Evidence.review_status.evidence_ref) { $Evidence.review_status.evidence_ref } else { 'none' })",
        "- **security_status:** $($defaults.security_status)",
        "- **security_evidence_ref:** $(if ($Evidence.security_status -and $Evidence.security_status.evidence_ref) { $Evidence.security_status.evidence_ref } else { 'none' })",
        "- **documentation_status:** $($defaults.documentation_status)",
        "- **documentation_evidence_ref:** $(if ($Evidence.documentation_status -and $Evidence.documentation_status.evidence_ref) { $Evidence.documentation_status.evidence_ref } else { 'none' })",
        "",
        "---",
        "",
        "## Failure / Next Action",
        "",
        "- **failed_gate:** $(if ($Outcome -eq 'failed' -or $Outcome -eq 'stopped') { $GateId } else { 'none' })",
        "- **failure_report_ref:** $FailureReportRef",
        "- **owner_agent:** @sef",
        "- **next_action:** $NextAction",
        "",
        "---",
        "",
        "## Traceability",
        "",
        "- **workflow_state_ref:** docs/agents/workflow-state.md",
        "- **related_decision_log_ref:** $(($DecisionRef).Replace('\','/'))"
    )
    Set-Content -Path $reportPath -Value $doc

    $relativeRef = "docs/agents/quality-gates/$reportFile"
    $script:state.quality_gate_refs = Merge-UniqueList -Existing $script:state.quality_gate_refs -Incoming @($relativeRef)
    $script:state.gate_results[$GateId] = @{
        status = $Outcome
        report_ref = $relativeRef
        decision_id = $DecisionId
        notes = $NextAction
    }
    if ($Outcome -eq "passed") {
        $script:state.completed_gates = Merge-UniqueList -Existing $script:state.completed_gates -Incoming @($GateId)
    } elseif ($Outcome -eq "failed" -or $Outcome -eq "stopped") {
        $script:state.failed_gates = Merge-UniqueList -Existing $script:state.failed_gates -Incoming @($GateId)
    }
    return $relativeRef
}

function Write-FailureReportDoc {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Step,
        [Parameter(Mandatory = $true)][string]$FailureType,
        [Parameter(Mandatory = $true)][hashtable]$PolicyDecision,
        [Parameter(Mandatory = $true)][string]$DecisionId,
        [Parameter(Mandatory = $true)][string]$DecisionRef,
        [string]$AgentOutputRef = "none",
        [string]$GateRef = "none",
        [string]$RootCause = ""
    )

    $failureId = "FAIL-$JobId-{0:d3}" -f ([int]$script:state.failure_count_total)
    $fileName = "$failureId.md"
    $path = Join-Path (Join-Path $DocsPath "failures") $fileName
    $doc = @(
        "# Failure Report",
        "",
        "---",
        "",
        "## Metadata",
        "",
        "- **failure_id:** $failureId",
        "- **job_id:** $JobId",
        "- **timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
        "- **agent:** $($Step.agent)",
        "- **step:** $($Step.phase)",
        "- **decision_id:** $DecisionId",
        "- **state_ref:** docs/agents/workflow-state.md",
        "- **failed_gate:** $($Step.gate)",
        "- **execution_id:** $ExecutionId",
        "- **runtime_event_log_ref:** docs/agents/runtime/state-events.jsonl",
        "",
        "---",
        "",
        "## Failure Counters",
        "",
        "- **risk_level:** $RiskLevel",
        "- **failure_count_total:** $($script:state.failure_count_total)",
        "- **failure_count_current_stage:** $($script:state.failure_count_current_stage)",
        "- **retry_attempt:** $($script:state.failure_count_current_stage)",
        "- **retry_limit:** $($PolicyDecision.retry_limit)",
        "- **retry_allowed:** $($PolicyDecision.retry_allowed)",
        "- **escalation_required:** $($PolicyDecision.escalation_required)",
        "- **human_in_loop_required:** $($PolicyDecision.human_in_loop_required)",
        "",
        "---",
        "",
        "## Failure Type",
        "",
        "- **failure_type:** $FailureType",
        "- **root_cause:** $(if ($RootCause) { $RootCause } else { "Runtime detected $FailureType." })",
        "",
        "---",
        "",
        "## Expected vs Actual",
        "",
        "| Area | Expected | Actual |",
        "|------|----------|--------|",
        "| Output | Valid normalized output | Failure detected |",
        "| Format | Contract-compliant agent output | Runtime rejected or gate failed |",
        "| Content | Gate progression can continue | Runtime paused for policy action |",
        "",
        "---",
        "",
        "## Action Taken",
        "",
        "- **action_taken:** $($PolicyDecision.action)",
        "- **resolution_status:** open",
        "- **next_action:** $($script:state.next_action)",
        "",
        "---",
        "",
        "## Prevention",
        "",
        "- **prevention_note:** Strengthen handoff, agent contract, or gate evidence for this step.",
        "",
        "---",
        "",
        "## Traceability",
        "",
        "- **decision_log_ref:** $(($DecisionRef).Replace('\','/'))",
        "- **quality_gate_ref:** $GateRef",
        "- **state_snapshot_ref:** none",
        "- **agent_output_ref:** $AgentOutputRef"
    )
    Set-Content -Path $path -Value $doc
    $relativeRef = "docs/agents/failures/$fileName"
    $script:state.failure_report_refs = Merge-UniqueList -Existing $script:state.failure_report_refs -Incoming @($relativeRef)
    return $relativeRef
}

function Write-StateSnapshotDoc {
    param(
        [string]$Reason = "checkpoint"
    )

    $snapshotId = "SNAP-$JobId-{0:d3}" -f ($script:state.state_snapshot_refs.Count + 1)
    $fileName = "$snapshotId.md"
    $path = Join-Path (Join-Path $DocsPath "state-snapshots") $fileName
    $pipelineRows = @()
    foreach ($step in $script:state.pipeline) {
        $pipelineRows += "| $($step.order) | $($step.agent) | $(if ($step.status) { $step.status } else { 'pending' }) | $(if ($step.output) { $step.output } else { '-' }) | $(if ($step.output_ref) { $step.output_ref } else { '-' }) |"
    }
    $gateRows = @()
    foreach ($gate in @("G1","G2","G3","G4","G5","G6","G7")) {
        $status = if ($script:state.gate_results.ContainsKey($gate)) { $script:state.gate_results[$gate].status } elseif (Test-GateAllowedForJobType -JobType $script:state.job_type -GateId $gate) { "pending" } else { "skipped" }
        $ref = if ($script:state.gate_results.ContainsKey($gate)) { $script:state.gate_results[$gate].report_ref } else { "-" }
        $decision = if ($script:state.gate_results.ContainsKey($gate)) { $script:state.gate_results[$gate].decision_id } else { "-" }
        $gateRows += "| $gate | $status | $ref | $decision |"
    }
    $doc = @(
        "# State Snapshot",
        "",
        "---",
        "",
        "## Metadata",
        "",
        "- **snapshot_id:** $snapshotId",
        "- **job_id:** $JobId",
        "- **timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
        "- **snapshot_reason:** $Reason",
        "- **state_ref:** docs/agents/workflow-state.md",
        "- **execution_id:** $ExecutionId",
        "- **runtime_event_log_ref:** docs/agents/runtime/state-events.jsonl",
        "",
        "---",
        "",
        "## Job Summary",
        "",
        "- **title:** $($script:state.title)",
        "- **job_type:** $($script:state.job_type)",
        "- **scope:** $($script:state.scope)",
        "- **risk_level:** $($script:state.risk_level)",
        "- **current_phase:** $($script:state.current_phase)",
        "",
        "---",
        "",
        "## Control State",
        "",
        "- **active_gate:** $($script:state.active_gate)",
        "- **next_action:** $($script:state.next_action)",
        "- **human_in_loop_status:** $($script:state.human_in_loop_status)",
        "",
        "---",
        "",
        "## Failure State",
        "",
        "- **failure_count_total:** $($script:state.failure_count_total)",
        "- **failure_count_current_stage:** $($script:state.failure_count_current_stage)",
        "- **last_failure_type:** $($script:state.last_failure_type)",
        "- **last_failed_gate:** $($script:state.last_failed_gate)",
        "",
        "---",
        "",
        "## Agent Pipeline Snapshot",
        "",
        "| # | Agent | Status | Output | Ref |",
        "|---|-------|--------|--------|-----|"
    ) + $pipelineRows + @(
        "",
        "---",
        "",
        "## Gate Snapshot",
        "",
        "| Gate | Status | Report Ref | Decision Ref |",
        "|------|--------|------------|--------------|"
    ) + $gateRows + @(
        "",
        "---",
        "",
        "## Change Summary",
        "",
        "- **changed_contracts:** $(ConvertTo-ListLiteral -Value $script:state.changed_contracts)",
        "- **changed_components:** $(ConvertTo-ListLiteral -Value $script:state.changed_components)",
        "- **changed_data_model:** $($script:state.changed_data_model)",
        "- **open_risks:** $($script:state.open_risks)",
        "",
        "---",
        "",
        "## Traceability",
        "",
        "- **decision_refs:** $(ConvertTo-ListLiteral -Value $script:state.major_decisions)",
        "- **failure_report_refs:** $(ConvertTo-RefListLiteral -Value $script:state.failure_report_refs)",
        "- **quality_gate_refs:** $(ConvertTo-RefListLiteral -Value $script:state.quality_gate_refs)"
    )
    Set-Content -Path $path -Value $doc
    $relativeRef = "docs/agents/state-snapshots/$fileName"
    $script:state.state_snapshot_refs = Merge-UniqueList -Existing $script:state.state_snapshot_refs -Incoming @($relativeRef)
    return $relativeRef
}

function Commit-Transition {
    param(
        [Parameter(Mandatory = $true)][string]$TargetState,
        [Parameter(Mandatory = $true)][string]$EventType,
        [string]$Reason = "",
        [string]$GateId = "",
        [hashtable]$ExtraPayload = @{},
        [string]$IdempotencySuffix = ""
    )

    $candidate = Copy-State -InputState $script:state
    if ([string]::IsNullOrWhiteSpace($GateId)) {
        $candidate = Invoke-OrchestrationTransition -State $candidate -TargetState $TargetState -Reason $Reason
    } else {
        $candidate = Invoke-OrchestrationTransition -State $candidate -TargetState $TargetState -GateId $GateId -Reason $Reason
    }
    $payload = Copy-State -InputState $candidate
    foreach ($key in $ExtraPayload.Keys) {
        $payload[$key] = $ExtraPayload[$key]
    }
    $idempotencyKey = if ($IdempotencySuffix) { "$ExecutionId-$IdempotencySuffix" } else { "$ExecutionId-$EventType-$($candidate.current_state)" }
    [void](Add-StateEvent -EventPath $eventPath -ExecutionId $ExecutionId -JobId $JobId -EventType $EventType -Payload $payload -IdempotencyKey $idempotencyKey -StateVersion 1)
    $script:state = $candidate
    Write-WorkflowStateDoc
}

function Add-BookkeepingEvent {
    param(
        [Parameter(Mandatory = $true)][string]$EventType,
        [Parameter(Mandatory = $true)][hashtable]$Payload,
        [Parameter(Mandatory = $true)][string]$IdempotencySuffix
    )
    [void](Add-StateEvent -EventPath $eventPath -ExecutionId $ExecutionId -JobId $JobId -EventType $EventType -Payload $Payload -IdempotencyKey "$ExecutionId-$IdempotencySuffix" -StateVersion 1)
}

function Resolve-GateEvidence {
    param(
        [string]$GateId = "none"
    )

    if ($GateId -in @("G2","G3")) {
        return @{
            build_status = @{ status = "skipped_with_reason"; evidence_ref = "none" }
            lint_status = @{ status = "skipped_with_reason"; evidence_ref = "none" }
            test_status = @{ status = "skipped_with_reason"; evidence_ref = "none" }
            coverage_status = @{ status = "skipped_with_reason"; evidence_ref = "none" }
            review_status = @{ status = $(if ($GateId -eq "G3") { "verified" } else { "skipped_with_reason" }); evidence_ref = $(if ($GateId -eq "G3") { "docs/agents/workflow-state.md" } else { "none" }) }
            security_status = @{ status = "skipped_with_reason"; evidence_ref = "none" }
            documentation_status = @{ status = "verified"; evidence_ref = "docs/agents/workflow-state.md" }
        }
    }
    if ($GateId -eq "G7") {
        return @{
            build_status = @{ status = $script:state.evidence_status.build_status; evidence_ref = "docs/agents/workflow-state.md" }
            lint_status = @{ status = $script:state.evidence_status.lint_status; evidence_ref = "docs/agents/workflow-state.md" }
            test_status = @{ status = $script:state.evidence_status.test_status; evidence_ref = "docs/agents/workflow-state.md" }
            coverage_status = @{ status = $script:state.evidence_status.coverage_status; evidence_ref = "docs/agents/workflow-state.md" }
            review_status = @{ status = $(if ($script:state.review_status_summary -eq "passed") { "verified" } else { "pending" }); evidence_ref = "docs/agents/workflow-state.md" }
            security_status = @{ status = $script:state.evidence_status.security_status; evidence_ref = "docs/agents/workflow-state.md" }
            documentation_status = @{ status = "verified"; evidence_ref = "docs/agents/workflow-state.md" }
        }
    }
    return Collect-GateEvidence -GateId $GateId -WorkingDirectory $WorkingDirectory -CommandMapPath $EvidenceCommandMapPath -StackAdapter $StackAdapter -DocsPath $DocsPath -JobId $JobId -ExecutionId $ExecutionId
}

function New-FailedGateEvidence {
    param(
        [string]$GateId = "none"
    )

    $evidence = @{
        build_status = @{ status = "pending"; evidence_ref = "none" }
        lint_status = @{ status = "pending"; evidence_ref = "none" }
        test_status = @{ status = "pending"; evidence_ref = "none" }
        coverage_status = @{ status = "pending"; evidence_ref = "none" }
        review_status = @{ status = "pending"; evidence_ref = "none" }
        security_status = @{ status = "pending"; evidence_ref = "none" }
        documentation_status = @{ status = "verified"; evidence_ref = "docs/agents/workflow-state.md" }
    }

    switch ($GateId) {
        "G2" {
            $evidence.documentation_status.status = "not_verified"
        }
        "G3" {
            $evidence.documentation_status.status = "not_verified"
            $evidence.review_status.status = "not_verified"
        }
        "G4" {
            $evidence.build_status.status = "not_verified"
            $evidence.lint_status.status = "not_verified"
            $evidence.security_status.status = "not_verified"
        }
        "G5" {
            $evidence.test_status.status = "not_verified"
            $evidence.coverage_status.status = "not_verified"
        }
        "G6" {
            $evidence.review_status.status = "not_verified"
            $evidence.security_status.status = "not_verified"
        }
        "G7" {
            $evidence.review_status.status = "not_verified"
        }
    }

    return $evidence
}

function Resolve-GateOutcome {
    param(
        [string]$GateId = "none",
        [Parameter(Mandatory = $true)][hashtable]$Evidence
    )

    $required = @{
        G2 = @("documentation_status")
        G3 = @("documentation_status","review_status")
        G4 = @("build_status","lint_status","security_status","documentation_status")
        G5 = @("test_status","coverage_status","documentation_status")
        G6 = @("review_status","security_status","documentation_status")
        G7 = @("documentation_status","review_status")
    }

    if ($GateId -eq "G7" -and $script:state.approval_status.release -eq "pending_user") {
        return @{
            outcome = "stopped"
            next_action = "waiting for release approval"
            failure_type = "insufficient_context"
        }
    }

    foreach ($field in $required[$GateId]) {
        if ($Evidence[$field].status -ne "verified") {
            return @{
                outcome = "failed"
                next_action = "fix gate evidence and retry"
                failure_type = if ($Evidence[$field].failure_type) { $Evidence[$field].failure_type } else { "test_failure" }
            }
        }
    }

    return @{
        outcome = "passed"
        next_action = "continue"
        failure_type = "none"
    }
}

function Resolve-PolicyTransition {
    param(
        [Parameter(Mandatory = $true)][hashtable]$PolicyDecision,
        [Parameter(Mandatory = $true)][string]$FailureType,
        [string]$GateId = "none"
    )

    $script:state.failure_count_total = [int]$script:state.failure_count_total + 1
    $script:state.failure_count_current_stage = [int]$script:state.failure_count_current_stage + 1
    $script:state.last_failure_type = $FailureType
    $script:state.last_failed_gate = $GateId
    $script:state.retry_allowed = $PolicyDecision.retry_allowed
    $script:state.escalation_required = $PolicyDecision.escalation_required
    $script:state.human_in_loop_required = $PolicyDecision.human_in_loop_required
    $script:state.human_in_loop_status = if ($PolicyDecision.human_in_loop_required -eq "yes") { "pending_user" } else { $script:state.human_in_loop_status }
    $script:state.next_action = $PolicyDecision.action

    Add-BookkeepingEvent -EventType "failure_policy" -Payload @{
        action = $PolicyDecision.action
        failure_type = $FailureType
        active_gate = $GateId
        retry_allowed = $PolicyDecision.retry_allowed
        escalation_required = $PolicyDecision.escalation_required
        human_in_loop_required = $PolicyDecision.human_in_loop_required
        failure_count_total = $script:state.failure_count_total
        failure_count_current_stage = $script:state.failure_count_current_stage
    } -IdempotencySuffix "failure-$GateId-$($script:state.failure_count_total)"

    switch ($PolicyDecision.action) {
        "retry" {
            Commit-Transition -TargetState "retry" -EventType "retry" -Reason "policy_retry" -GateId $GateId -IdempotencySuffix "retry-$GateId-$($script:state.failure_count_total)"
        }
        "escalate" {
            Commit-Transition -TargetState "escalate" -EventType "escalate" -Reason "policy_escalate" -GateId $GateId -IdempotencySuffix "escalate-$GateId-$($script:state.failure_count_total)"
        }
        "ask_user" {
            Commit-Transition -TargetState "escalate" -EventType "ask_user" -Reason "policy_ask_user" -GateId $GateId -IdempotencySuffix "askuser-$GateId-$($script:state.failure_count_total)"
        }
        "hard_stop" {
            Commit-Transition -TargetState "stop" -EventType "stop" -Reason "policy_hard_stop" -GateId $GateId -IdempotencySuffix "hardstop-$GateId-$($script:state.failure_count_total)"
        }
        default {
            Commit-Transition -TargetState "escalate" -EventType "escalate" -Reason "policy_default_escalate" -GateId $GateId -IdempotencySuffix "fallback-$GateId-$($script:state.failure_count_total)"
        }
    }
}

$intake = @{}
if ($ResumeExecution) {
    if (-not $ExecutionId) {
        throw "ExecutionId is required when ResumeExecution is used."
    }
    $state = Get-ReplayedState -EventPath $eventPath -ExecutionId $ExecutionId
    if ($state.Count -eq 0) {
        throw "Cannot resume execution. No event history for $ExecutionId."
    }
    if (-not $state.pipeline) {
        $state.pipeline = Resolve-OrchestrationPipeline -JobType $state.job_type -Scope $state.scope -RiskLevel $state.risk_level -CandidateAgents @($state.selected_agents) -AffectedLayers @($state.affected_layers)
    }
    if (-not $state.approval_status) {
        $state.approval_status = @{ plan = "pending_user"; release = "pending_user" }
    }
    if (-not $state.decision_records) {
        $state.decision_records = @()
    }
} else {
    if (-not $UserRequest -and (-not $JobType -or -not $Scope -or -not $RiskLevel)) {
        throw "Provide either UserRequest or manual JobType/Scope/RiskLevel inputs."
    }

    if ($UserRequest) {
        $intake = New-RequestIntake -UserRequest $UserRequest -JobType $JobType -Scope $Scope -RiskLevel $RiskLevel
        $JobType = [string]$intake.job_type
        $Scope = [string]$intake.scope
        $RiskLevel = [string]$intake.risk_level
        if (-not $JobId) {
            $JobId = New-GeneratedJobId -ResolvedJobType $JobType
        }
        if (-not $Title) {
            $Title = [string]$intake.request_summary
        }
    } else {
        if (-not $JobId) {
            $JobId = New-GeneratedJobId -ResolvedJobType $JobType
        }
        $intake = @{
            raw_request = ""
            request_summary = if ($Title) { $Title } else { $JobId }
            job_type = $JobType
            scope = $Scope
            risk_level = $RiskLevel
            affected_layers = @()
            candidate_agents = @("@sef") + @(Get-OrchestrationPipeline -JobType $JobType | ForEach-Object { $_.agent })
            approval_checkpoints = @{
                plan = "required"
                release = "required"
            }
        }
    }

    if ($JobType -notin @("feature","bugfix","refactor","integration","performance","ux-ui","devops-infra","research")) {
        throw "Unsupported JobType: $JobType"
    }
    if ($Scope -notin @("S","M","L","XL")) {
        throw "Unsupported Scope: $Scope"
    }
    if ($RiskLevel -notin @("dusuk","orta","yuksek","kritik")) {
        throw "Unsupported RiskLevel: $RiskLevel"
    }

    $state = New-OrchestrationState -ExecutionId $ExecutionId -JobId $JobId -JobType $JobType -Scope $Scope -RiskLevel $RiskLevel -IntakeContext $intake
}

$script:state = $state
$JobId = [string]$script:state.job_id
$JobType = [string]$script:state.job_type
$Scope = [string]$script:state.scope
$RiskLevel = [string]$script:state.risk_level
$script:state.request_summary = if ($script:state.request_summary) { $script:state.request_summary } else { $script:state.title }
$script:state.affected_layers = @($script:state.affected_layers)
$script:state.approval_status = if ($script:state.approval_status) { $script:state.approval_status } else { @{ plan = "pending_user"; release = "pending_user" } }
$script:state.title = if ($Title) { $Title } else { $script:state.title }
if (-not $script:state.decision_records) {
    $script:state.decision_records = @()
}
$script:decisionSequence = @($script:state.decision_records).Count

Write-WorkflowStateDoc

if (-not $ResumeExecution) {
    [void](Add-StateEvent -EventPath $eventPath -ExecutionId $ExecutionId -JobId $JobId -EventType "initialize" -Payload $script:state -IdempotencyKey "$ExecutionId-initialize")
}

if (-not $ResumeExecution -and $script:state.current_state -eq "initialize") {
    $script:state.current_phase = "classification"
    $script:state.current_status = "in_progress"
    Commit-Transition -TargetState "classify" -EventType "classify" -Reason "classification_started"

    $classificationDecision = New-DecisionLog -Topic "work_classification" -ChosenPath "$JobType / $Scope / $RiskLevel" -Rationale "Runtime converted user intent into a normalized intake record before agent execution." -RelatedGateRefs $(if ($JobType -in @("feature","integration")) { @("G1","G2") } elseif ($JobType -eq "refactor") { @("G3") } else { @("G4") }) -Outcome "$JobType / $Scope / $RiskLevel" -ImpactedAgents $script:state.selected_agents
    $script:state.current_phase = "classification"
    $script:state.next_action = "route internal agents"
    Write-WorkflowStateDoc

    if ($JobType -in @("feature","integration")) {
        $g1Evidence = @{
            build_status = @{ status = "skipped_with_reason"; evidence_ref = "none" }
            lint_status = @{ status = "skipped_with_reason"; evidence_ref = "none" }
            test_status = @{ status = "skipped_with_reason"; evidence_ref = "none" }
            coverage_status = @{ status = "skipped_with_reason"; evidence_ref = "none" }
            review_status = @{ status = "skipped_with_reason"; evidence_ref = "none" }
            security_status = @{ status = "skipped_with_reason"; evidence_ref = "none" }
            documentation_status = @{ status = "verified"; evidence_ref = "docs/agents/workflow-state.md" }
        }
        $g1Decision = New-DecisionLog -Topic "gate_transition" -ChosenPath "G1 passed" -Rationale "Classification and request clarity are recorded before execution." -RelatedGateRefs @("G1") -Outcome "G1 passed" -ImpactedAgents @("@sef")
        [void](Write-GateReportDoc -GateId "G1" -Evidence $g1Evidence -Outcome "passed" -DecisionId $g1Decision.decision_id -DecisionRef $g1Decision.ref -NextAction "continue")
    }

    if ($script:state.current_state -eq "classify") {
        $script:state.current_phase = "classification"
        $script:state.next_action = "routing completed"
        Commit-Transition -TargetState "route" -EventType "route" -Reason "routing_completed" -ExtraPayload @{
            selected_agents = $script:state.selected_agents
            affected_layers = $script:state.affected_layers
        }
    }

    $routingDecision = New-DecisionLog -Topic "agent_routing" -ChosenPath (($script:state.pipeline | ForEach-Object { $_.agent }) -join " -> ") -Rationale "Runtime selected a minimal agent pipeline from intake context, affected layers, and risk." -RelatedGateRefs (($script:state.pipeline | ForEach-Object { $_.gate } | Select-Object -Unique)) -Outcome "pipeline selected" -ImpactedAgents $script:state.selected_agents
    $script:state.next_action = "wait for plan approval"
    Write-WorkflowStateDoc

    if ($script:state.current_state -eq "route") {
        Commit-Transition -TargetState "plan" -EventType "plan" -Reason "plan_created" -ExtraPayload @{
            pipeline = $script:state.pipeline
        }
    }
}

if ($script:state.approval_status.plan -eq "pending_user") {
    $script:state.human_in_loop_status = "pending_user"
    $script:state.current_status = "waiting_for_user"
    $script:state.next_action = "user approval required before agent execution"
    Write-WorkflowStateDoc
    Add-BookkeepingEvent -EventType "plan_approval_pending" -Payload @{
        current_phase = $script:state.current_phase
        execution_id = $ExecutionId
        approval_status = $script:state.approval_status
        human_in_loop_status = $script:state.human_in_loop_status
        current_status = $script:state.current_status
        next_action = $script:state.next_action
    } -IdempotencySuffix "plan-approval-pending"

    if ($AutoApproveUserDecisions.IsPresent -or $ApprovalAction -eq "approve_plan") {
        $script:state.approval_status.plan = "approved"
        $script:state.human_in_loop_status = "resolved"
        $script:state.current_status = "in_progress"
        $script:state.next_action = "execute agent pipeline"
        Add-BookkeepingEvent -EventType "plan_approved" -Payload @{
            execution_id = $ExecutionId
            approval_status = $script:state.approval_status
            human_in_loop_status = $script:state.human_in_loop_status
            current_status = $script:state.current_status
            next_action = $script:state.next_action
        } -IdempotencySuffix "plan-approved"
        Write-WorkflowStateDoc
    } elseif ($ApprovalAction -eq "reject_plan") {
        $script:state.approval_status.plan = "rejected"
        $script:state.current_status = "stopped"
        $script:state.next_action = "plan rejected by user"
        Commit-Transition -TargetState "stop" -EventType "stop" -Reason "plan_rejected_by_user" -IdempotencySuffix "plan-rejected"
        Write-Host "Runtime orchestration stopped: plan rejected by user."
        Write-Host "Event log: $eventPath"
        exit 0
    } else {
        Add-BookkeepingEvent -EventType "await_user" -Payload @{
            reason = "plan_approval_required"
            current_phase = $script:state.current_phase
        } -IdempotencySuffix "await-user-plan"
        Write-Host "Runtime orchestration paused: waiting for plan approval."
        Write-Host "Event log: $eventPath"
        exit 0
    }
}

$script:state.human_in_loop_status = "resolved"
$script:state.current_status = "in_progress"
$script:state.next_action = "execute agent pipeline"
Write-WorkflowStateDoc

for ($index = 0; $index -lt $script:state.pipeline.Count; $index++) {
    $group = @(Get-StepGroup -StartIndex $index)
    $groupGate = [string]($group[0].gate)
    $groupPhase = [string]($group[0].phase)
    $groupSucceeded = $true

    $groupAlreadyCompleted = ($script:state.completed_gates -contains $groupGate) -and (@($group | Where-Object { $_.status -ne "completed" -and -not ($_.agent -eq "@sef" -and $_.gate -eq "G7") }).Count -eq 0)
    if ($groupAlreadyCompleted) {
        $index += ($group.Count - 1)
        continue
    }

    foreach ($step in $group) {
        if ($step.status -eq "completed") {
            continue
        }
        if ($step.agent -eq "@sef" -and $step.gate -eq "G7") {
            continue
        }

        $script:state.current_phase = $groupPhase
        $script:state.current_agent = $step.agent
        $script:state.active_gate = $groupGate
        $script:state.next_action = "execute $($step.agent)"
        Set-StepField -Agent $step.agent -StepId $step.step_id -Field "status" -Value "in_progress"
        Write-WorkflowStateDoc

        $stepDecision = New-DecisionLog -Topic "agent_routing" -ChosenPath "$($step.agent) executes $($step.step_id)" -Rationale "Runtime is delegating the next supported step to the selected agent." -RelatedGateRefs @($groupGate) -Outcome "$($step.agent) active" -ImpactedAgents @($step.agent)
        $handoff = Write-HandoffDoc -Step $step -DecisionId $stepDecision.decision_id
        Add-BookkeepingEvent -EventType "handoff_written" -Payload @{
            handoff_ref = $handoff.ref
            gate = $groupGate
            agent = $step.agent
        } -IdempotencySuffix "handoff-$($step.agent)-$($step.step_id)"

        if (-not (Test-HandoffReady -HandoffPath $handoff.path)) {
            $groupSucceeded = $false
            break
        }

        $agentName = $step.agent.TrimStart("@")
        $outputFileName = "$agentName-$JobId-$($step.step_id).json"
        $outputPath = Join-Path (Join-Path $DocsPath "agent-outputs") $outputFileName

        if ($script:state.current_state -eq "agent_call" -and $script:state.active_gate -eq $groupGate) {
            Add-BookkeepingEvent -EventType "agent_call_detail" -Payload @{
                active_gate = $groupGate
                handoff_ref = $handoff.ref
                agent = $step.agent
            } -IdempotencySuffix "agent-$($step.agent)-$($step.step_id)"
        } else {
            Commit-Transition -TargetState "agent_call" -EventType "agent_call" -GateId $groupGate -Reason "agent_called" -ExtraPayload @{
                active_gate = $groupGate
                handoff_ref = $handoff.ref
                agent = $step.agent
            } -IdempotencySuffix "agent-$($step.agent)-$($step.step_id)"
        }

        # STRICT MODE CHECK: Before executing agent, check if this is a direct quality-requiring agent
# Note: In orchestrated mode (through @sef), this check is bypassed as gates are managed by state machine
$gateCompliance = Test-DirectModeGateCompliance -Agent $step.agent -DocsPath $DocsPath -StrictMode $runtimeConfig.strict_mode
if (-not $gateCompliance.compliant -and $runtimeConfig.strict_mode -eq "enforce") {
    # In strict mode, block execution if compliance check fails
    $policy = Get-FailureAction -FailureType "insufficient_context" -RiskLevel $RiskLevel -FailureCountCurrentStage 0 -FailureCountTotal 0
    Resolve-PolicyTransition -PolicyDecision $policy -FailureType "strict_mode_violation" -GateId $groupGate
    Write-Host "STRICT MODE ENFORCED: Agent $($step.agent) blocked. Use @sef orchestrator for production work." -ForegroundColor Red
    $groupSucceeded = $false
    break
}
# Log warnings if any
if ($gateCompliance.warnings.Count -gt 0) {
    Write-Host ($gateCompliance.warnings -join "`n") -ForegroundColor Yellow
    # Write mini gate report for tracking
    $miniGateRef = Write-MiniGateReport -DocsPath $DocsPath -Agent $step.agent -GateCheck $gateCompliance
}

$execution = Invoke-AgentExecution -Agent $step.agent -JobId $JobId -ExecutionId $ExecutionId -StepId $step.step_id -GateId $groupGate -DocsPath $DocsPath -HandoffPath $handoff.path -OutputPath $outputPath -WorkingDirectory $WorkingDirectory -ExecutionMode $executionMode -CommandTemplate $AgentCommandTemplate -JobType $JobType -Scope $Scope -RiskLevel $RiskLevel -TimeoutSeconds $runtimeConfig.agent_timeout_seconds
        
        # AUTO-FOLLOWUP: Check if auto quality chain is enabled
        $autoFollowup = Test-AutoFollowupEnabled -DocsPath $DocsPath -Agent $step.agent -RuntimeConfig $runtimeConfig
        if ($autoFollowup.enabled -and $execution.ok) {
            Write-Host "`n[AUTO-FOLLOWUP] Quality chain enabled for $($step.agent). Auto-triggering @qa → @review..." -ForegroundColor Cyan
            
            $followupResults = Invoke-AutoFollowupChain `
                -Agent $step.agent `
                -JobId $JobId `
                -ExecutionId $ExecutionId `
                -DocsPath $DocsPath `
                -WorkingDirectory $WorkingDirectory `
                -ParentStep $step `
                -CommandTemplate $AgentCommandTemplate `
                -TimeoutSeconds $runtimeConfig.agent_timeout_seconds
            
            # Write auto-followup report
            $autoFollowupRef = Write-AutoFollowupReport -DocsPath $DocsPath -Agent $step.agent -Results $followupResults -JobId $JobId
            
            # Update evidence status based on followup results
            if ($followupResults.final_status -eq "success") {
                $script:state.evidence_status.test_status = "verified"
                $script:state.evidence_status.coverage_status = "verified"
                $script:state.evidence_status.review_status = "verified"
                $script:state.test_status_summary = "passed"
                $script:state.review_status_summary = "passed"
                Write-Host "[AUTO-FOLLOWUP] ✅ Quality chain completed successfully!" -ForegroundColor Green
            } else {
                Write-Host "[AUTO-FOLLOWUP] ⚠️ Quality chain incomplete: $($followupResults.final_status)" -ForegroundColor Yellow
            }
            
            Add-BookkeepingEvent -EventType "auto_followup_completed" -Payload @{
                agent = $step.agent
                followup_status = $followupResults.final_status
                qa_invoked = $followupResults.qa_invoked
                review_invoked = $followupResults.review_invoked
                report_ref = $autoFollowupRef
            } -IdempotencySuffix "followup-$($step.agent)-$($step.step_id)"
        }
        
        Add-BookkeepingEvent -EventType "agent_result" -Payload @{
            agent = $step.agent
            gate = $groupGate
            output_ref = "docs/agents/agent-outputs/$outputFileName"
            command = $execution.command
            exit_code = $execution.exit_code
            auto_followup_enabled = $autoFollowup.enabled
        } -IdempotencySuffix "agent-result-$($step.agent)-$($step.step_id)-$($script:state.failure_count_total)"

        $contractCheck = Test-AgentOutputContract -OutputPath $outputPath
        if (-not $contractCheck.ok) {
            $failureType = $contractCheck.reason
            $policy = Get-FailureAction -FailureType $failureType -RiskLevel $RiskLevel -FailureCountCurrentStage ([int]$script:state.failure_count_current_stage) -FailureCountTotal ([int]$script:state.failure_count_total)
            if ($policy.action -eq "retry" -and $execution.failure_type -eq "missing_output") {
                $policy.action = "escalate"
                $policy.retry_allowed = "no"
                $policy.escalation_required = "yes"
            }
            Resolve-PolicyTransition -PolicyDecision $policy -FailureType $failureType -GateId $groupGate
            $failureDecision = New-DecisionLog -Topic $policy.action -ChosenPath "$groupGate $($policy.action)" -Rationale "Runtime rejected agent output contract." -RelatedGateRefs @($groupGate) -Outcome "$($policy.action) after contract failure" -ImpactedAgents @($step.agent)
            $failureRef = Write-FailureReportDoc -Step $step -FailureType $failureType -PolicyDecision $policy -DecisionId $failureDecision.decision_id -DecisionRef $failureDecision.ref -AgentOutputRef "docs/agents/agent-outputs/$outputFileName" -RootCause $execution.stderr
            [void](Write-GateReportDoc -GateId $groupGate -Evidence (New-FailedGateEvidence -GateId $groupGate) -Outcome "failed" -DecisionId $failureDecision.decision_id -DecisionRef $failureDecision.ref -FailureReportRef $failureRef -NextAction $policy.action -Rationale "Agent output contract failed before gate completion.")
            [void](Write-StateSnapshotDoc -Reason "failure")
            Set-StepField -Agent $step.agent -StepId $step.step_id -Field "status" -Value "failed"
            Set-StepField -Agent $step.agent -StepId $step.step_id -Field "output_ref" -Value "docs/agents/agent-outputs/$outputFileName"
            Write-WorkflowStateDoc
            if ($script:state.current_state -eq "retry") {
                Commit-Transition -TargetState "agent_call" -EventType "agent_call" -GateId $groupGate -Reason "retry_agent_called" -IdempotencySuffix "retry-$($step.agent)-$($step.step_id)-$($script:state.failure_count_total)"
                $index--
            }
            $groupSucceeded = $false
            break
        }

        $agentOutput = Copy-State -InputState (Get-Content $outputPath -Raw | ConvertFrom-Json)
        if ([string]$agentOutput.status -ne "success") {
            $failureType = if ($agentOutput.failure_type) { [string]$agentOutput.failure_type } else { "logic_inconsistency" }
            $policy = Get-FailureAction -FailureType $failureType -RiskLevel $RiskLevel -FailureCountCurrentStage ([int]$script:state.failure_count_current_stage) -FailureCountTotal ([int]$script:state.failure_count_total)
            if ($agentOutput.retryable -eq "no" -and $policy.action -eq "retry") {
                $policy.action = "escalate"
                $policy.retry_allowed = "no"
                $policy.escalation_required = "yes"
            }
            Resolve-PolicyTransition -PolicyDecision $policy -FailureType $failureType -GateId $groupGate
            $failureDecision = New-DecisionLog -Topic $policy.action -ChosenPath "$groupGate $($policy.action)" -Rationale "Agent reported $($agentOutput.status)." -RelatedGateRefs @($groupGate) -Outcome "$($policy.action) after agent failure" -ImpactedAgents @($step.agent)
            $failureRef = Write-FailureReportDoc -Step $step -FailureType $failureType -PolicyDecision $policy -DecisionId $failureDecision.decision_id -DecisionRef $failureDecision.ref -AgentOutputRef "docs/agents/agent-outputs/$outputFileName" -RootCause $agentOutput.status_reason
            [void](Write-GateReportDoc -GateId $groupGate -Evidence (New-FailedGateEvidence -GateId $groupGate) -Outcome "failed" -DecisionId $failureDecision.decision_id -DecisionRef $failureDecision.ref -FailureReportRef $failureRef -NextAction $policy.action -Rationale "Agent returned failed or blocked status before gate completion.")
            [void](Write-StateSnapshotDoc -Reason "failure")
            Set-StepField -Agent $step.agent -StepId $step.step_id -Field "status" -Value $agentOutput.status
            Set-StepField -Agent $step.agent -StepId $step.step_id -Field "output" -Value $agentOutput.summary
            Set-StepField -Agent $step.agent -StepId $step.step_id -Field "output_ref" -Value "docs/agents/agent-outputs/$outputFileName"
            Write-WorkflowStateDoc
            if ($script:state.current_state -eq "retry") {
                Commit-Transition -TargetState "agent_call" -EventType "agent_call" -GateId $groupGate -Reason "retry_agent_called" -IdempotencySuffix "retry-$($step.agent)-$($step.step_id)-$($script:state.failure_count_total)"
                $index--
            }
            $groupSucceeded = $false
            break
        }

        $outputRef = "docs/agents/agent-outputs/$outputFileName"
        $script:state.agent_output_refs = Merge-UniqueList -Existing $script:state.agent_output_refs -Incoming @($outputRef)
        $script:state.changed_components = Merge-UniqueList -Existing $script:state.changed_components -Incoming $agentOutput.changed_components
        $script:state.changed_contracts = Merge-UniqueList -Existing $script:state.changed_contracts -Incoming $agentOutput.changed_contracts
        if ($agentOutput.changed_data_model) { $script:state.changed_data_model = [string]$agentOutput.changed_data_model }
        Set-StepField -Agent $step.agent -StepId $step.step_id -Field "status" -Value "completed"
        Set-StepField -Agent $step.agent -StepId $step.step_id -Field "output" -Value $agentOutput.summary
        Set-StepField -Agent $step.agent -StepId $step.step_id -Field "output_ref" -Value $outputRef
        Set-StepField -Agent $step.agent -StepId $step.step_id -Field "decision_ref" -Value $stepDecision.decision_id
        Write-WorkflowStateDoc

        if ($step.agent -eq "@review") {
            $reviewPath = Join-Path (Join-Path $DocsPath "reviews") ("review-$JobId.md")
            @(
                "# Review Summary",
                "",
                "- Agent: @review",
                "- Execution: $ExecutionId",
                "- Summary: $($agentOutput.summary)"
            ) | Set-Content -Path $reviewPath
        }
    }

    if (-not $groupSucceeded) {
        if ($script:state.current_state -in @("stop","escalate")) {
            Write-WorkflowStateDoc
            Write-Host "Runtime orchestration paused or stopped: $ExecutionId"
            Write-Host "Event log: $eventPath"
            exit 0
        }
        continue
    }

    $script:state.current_phase = $groupPhase
    $script:state.active_gate = $groupGate
    if ($groupGate -eq "G7" -and $script:state.approval_status.release -eq "pending_user") {
        $script:state.human_in_loop_status = "pending_user"
        $script:state.current_status = "waiting_for_user"
        $script:state.next_action = "release approval required"
        Write-WorkflowStateDoc
        Add-BookkeepingEvent -EventType "release_approval_pending" -Payload @{
            execution_id = $ExecutionId
            active_gate = $groupGate
            approval_status = $script:state.approval_status
            human_in_loop_status = $script:state.human_in_loop_status
            current_status = $script:state.current_status
            next_action = $script:state.next_action
        } -IdempotencySuffix "release-approval-pending"

        if ($AutoApproveUserDecisions.IsPresent -or $ApprovalAction -eq "approve_release") {
            $script:state.approval_status.release = "approved"
            $script:state.human_in_loop_status = "resolved"
            $script:state.current_status = "in_progress"
            Add-BookkeepingEvent -EventType "release_approved" -Payload @{
                execution_id = $ExecutionId
                active_gate = $groupGate
                approval_status = $script:state.approval_status
                human_in_loop_status = $script:state.human_in_loop_status
                current_status = $script:state.current_status
                next_action = $script:state.next_action
            } -IdempotencySuffix "release-approved"
            Write-WorkflowStateDoc
        } elseif ($ApprovalAction -eq "reject_release") {
            $script:state.approval_status.release = "rejected"
            $script:state.current_status = "stopped"
            $script:state.next_action = "release rejected by user"
            Commit-Transition -TargetState "stop" -EventType "stop" -Reason "release_rejected_by_user" -GateId $groupGate -IdempotencySuffix "release-rejected"
            Write-Host "Runtime orchestration stopped: release rejected by user."
            Write-Host "Event log: $eventPath"
            exit 0
        } else {
            Add-BookkeepingEvent -EventType "await_user" -Payload @{
                reason = "release_approval_required"
                current_phase = $groupPhase
            } -IdempotencySuffix "await-user-release"
            Write-Host "Runtime orchestration paused: waiting for release approval."
            Write-Host "Event log: $eventPath"
            exit 0
        }
    }

    $evidence = Resolve-GateEvidence -GateId $groupGate
    $gateDecision = Resolve-GateOutcome -GateId $groupGate -Evidence $evidence
    $gateDecisionLog = New-DecisionLog -Topic "gate_transition" -ChosenPath "$groupGate $($gateDecision.outcome)" -Rationale "Runtime evaluated gate $groupGate after step group completion." -RelatedGateRefs @($groupGate) -Outcome "$groupGate $($gateDecision.outcome)" -ImpactedAgents ($group | ForEach-Object { $_.agent })
    if ($script:state.current_state -eq "gate_check") {
        Add-BookkeepingEvent -EventType "gate_check_detail" -Payload @{
            gate = $groupGate
            outcome = $gateDecision.outcome
        } -IdempotencySuffix "gate-$groupGate-$index"
    } else {
        Commit-Transition -TargetState "gate_check" -EventType "gate_check" -GateId $groupGate -Reason "gate_evaluated" -ExtraPayload @{
            gate = $groupGate
            outcome = $gateDecision.outcome
        } -IdempotencySuffix "gate-$groupGate-$index"
    }

    $failureGateRef = "none"
    if ($gateDecision.outcome -eq "failed" -or $gateDecision.outcome -eq "stopped") {
        $policy = Get-FailureAction -FailureType $gateDecision.failure_type -RiskLevel $RiskLevel -FailureCountCurrentStage ([int]$script:state.failure_count_current_stage) -FailureCountTotal ([int]$script:state.failure_count_total)
        Resolve-PolicyTransition -PolicyDecision $policy -FailureType $gateDecision.failure_type -GateId $groupGate
        $failureDecision = New-DecisionLog -Topic $policy.action -ChosenPath "$groupGate $($policy.action)" -Rationale "Gate $groupGate failed or stopped." -RelatedGateRefs @($groupGate) -Outcome "$($policy.action) after gate failure" -ImpactedAgents ($group | ForEach-Object { $_.agent })
        $failureGateRef = Write-FailureReportDoc -Step $group[0] -FailureType $gateDecision.failure_type -PolicyDecision $policy -DecisionId $failureDecision.decision_id -DecisionRef $failureDecision.ref -GateRef "docs/agents/quality-gates/$groupGate-$JobId.md" -RootCause $gateDecision.next_action
        [void](Write-StateSnapshotDoc -Reason "failure")
    }

    [void](Write-GateReportDoc -GateId $groupGate -Evidence $evidence -Outcome $gateDecision.outcome -DecisionId $gateDecisionLog.decision_id -DecisionRef $gateDecisionLog.ref -FailureReportRef $failureGateRef -NextAction $gateDecision.next_action)

    if ($groupGate -eq "G5" -and $gateDecision.outcome -eq "passed") {
        $script:state.test_status_summary = "passed"
    }
    if ($groupGate -eq "G6" -and $gateDecision.outcome -eq "passed") {
        $script:state.review_status_summary = "passed"
    }
    if ($groupGate -eq "G7" -and $gateDecision.outcome -eq "passed") {
        $script:state.current_status = "completed"
    }
    $script:state.failure_count_current_stage = 0
    $script:state.current_agent = "@sef"
    $script:state.next_action = $gateDecision.next_action
    Write-WorkflowStateDoc

    if ($gateDecision.outcome -ne "passed") {
        Write-Host "Runtime orchestration paused or stopped: $ExecutionId"
        Write-Host "Event log: $eventPath"
        exit 0
    }

    $index += ($group.Count - 1)
}

if ($script:state.current_state -eq "gate_check") {
    $script:state.current_state = "gate_check"
    $script:state.current_phase = "release"
    $script:state.current_status = "completed"
    $script:state.next_action = "workflow completed"
    Commit-Transition -TargetState "complete" -EventType "complete" -Reason "workflow_completed"
}

Write-WorkflowStateDoc
Write-Host "Runtime orchestration completed: $ExecutionId"
Write-Host "Event log: $eventPath"
