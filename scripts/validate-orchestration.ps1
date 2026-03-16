<#
.SYNOPSIS
    Cursor Agents Framework - Orchestration Enforcement Validator
.DESCRIPTION
    Validates workflow-state, decision logs, quality gate reports, failure reports,
    and state snapshots for minimum enforcement and traceability guarantees.
.PARAMETER DocsPath
    Path to docs/agents folder. Defaults to ./docs/agents if present.
.PARAMETER Strict
    Require active orchestration artifacts and validate cross references strictly.
#>
param(
    [string]$DocsPath = "",
    [switch]$Strict
)

$ErrorActionPreference = "Stop"

if (-not $DocsPath) {
    $defaultDocsPath = Join-Path (Join-Path (Get-Location) "docs") "agents"
    if (Test-Path $defaultDocsPath) {
        $DocsPath = $defaultDocsPath
    } else {
        $DocsPath = Get-Location
    }
}

$DocsPath = (Resolve-Path $DocsPath).Path
$docsLeaf = Split-Path $DocsPath -Leaf
$docsParent = Split-Path $DocsPath -Parent
$docsParentLeaf = Split-Path $docsParent -Leaf
if ($docsLeaf -eq "agents" -and $docsParentLeaf -eq "docs") {
    $ProjectRoot = Split-Path $docsParent -Parent
} else {
    $ProjectRoot = Split-Path $DocsPath -Parent
}

$errors = @()
$warnings = @()
$passed = @()
$eventLogsToCheck = @{}
$allowedEvidence = @("verified", "not_verified", "pending", "skipped_with_reason")
$gateRequirements = @{
    "G1" = @("documentation_status")
    "G2" = @("documentation_status")
    "G3" = @("documentation_status", "review_status")
    "G4" = @("build_status", "lint_status", "security_status", "documentation_status")
    "G5" = @("test_status", "coverage_status", "documentation_status")
    "G6" = @("review_status", "security_status", "documentation_status")
    "G7" = @("documentation_status", "review_status")
}

function Get-Sha256Hex {
    param([string]$InputText)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputText)
        $hashBytes = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Add-Result {
    param(
        [string]$Level,
        [string]$Message
    )

    if ($Level -eq "error") { $script:errors += $Message; return }
    if ($Level -eq "warning") { $script:warnings += $Message; return }
    $script:passed += $Message
}

function Get-FieldValue {
    param(
        [string]$Content,
        [string]$FieldName
    )

    $pattern = "(?im)^\s*-\s+\*\*" + [regex]::Escape($FieldName) + ":\*\*\s*(.+?)\s*$"
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return $null
}

function Test-Fields {
    param(
        [string]$Content,
        [string[]]$Fields,
        [string]$Label
    )

    foreach ($field in $Fields) {
        $value = Get-FieldValue -Content $Content -FieldName $field
        if ([string]::IsNullOrWhiteSpace($value)) {
            Add-Result -Level "error" -Message ($Label + " missing field: " + $field)
        }
    }
}

function Get-TableRowNames {
    param(
        [string]$Content
    )

    $rows = @()
    $lines = $Content -split "`r?`n"
    foreach ($line in $lines) {
        if ($line -match "^\|\s*([A-Za-z0-9_\-]+)\s*\|") {
            $rows += $matches[1]
        }
    }

    return $rows
}

function Normalize-Ref {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }

    $normalized = $Value.Trim()
    $normalized = $normalized.Trim("'")
    $normalized = $normalized.Trim('"')
    $normalized = $normalized.Replace([string][char]96, "")
    if ($normalized.StartsWith("[")) { $normalized = $normalized.Substring(1) }
    if ($normalized.EndsWith("]")) { $normalized = $normalized.Substring(0, $normalized.Length - 1) }

    if ($normalized -eq "-" -or $normalized -eq "none" -or $normalized -eq "[]") {
        return $null
    }

    return $normalized
}

function Resolve-ArtifactRef {
    param(
        [string]$Value
    )

    $normalized = Normalize-Ref -Value $Value
    if (-not $normalized) { return $null }

    if ([System.IO.Path]::IsPathRooted($normalized)) {
        return $normalized
    }

    if ($normalized.StartsWith("docs/agents/")) {
        $relative = $normalized.Substring("docs/agents/".Length)
        return Join-Path $DocsPath $relative
    }

    if ($normalized.StartsWith("docs\agents\")) {
        $relative = $normalized.Substring("docs\agents\".Length)
        return Join-Path $DocsPath $relative
    }

    return Join-Path $ProjectRoot $normalized
}

function Test-RefFile {
    param(
        [string]$Value,
        [string]$Label
    )

    $resolved = Resolve-ArtifactRef -Value $Value
    if (-not $resolved) { return }

    if (-not (Test-Path $resolved)) {
        Add-Result -Level "error" -Message ($Label + " references missing file: " + $Value)
    }
}

function Get-DecisionIdMap {
    param(
        [System.IO.FileInfo[]]$Files
    )

    $map = @{}
    foreach ($file in $Files) {
        $content = Get-Content $file.FullName -Raw
        $decisionId = Get-FieldValue -Content $content -FieldName "decision_id"
        if ($decisionId) {
            $map[$decisionId] = $file.FullName
        }
    }

    return $map
}

function Test-AgentOutputContract {
    param(
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        Add-Result -Level "error" -Message ("Agent output file missing: " + $FilePath)
        return
    }

    try {
        $json = Get-Content $FilePath -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Add-Result -Level "error" -Message ("Invalid JSON in agent output: " + $FilePath)
        return
    }

    $required = @(
        "agent","job_id","execution_id","step_id","gate_id","status","status_reason","failure_type","produced_outputs","summary",
        "changed_components","changed_contracts","changed_data_model","decision_refs","evidence_refs","next_action","retryable","human_in_loop_required"
    )
    foreach ($field in $required) {
        if (-not $json.PSObject.Properties.Name.Contains($field)) {
            Add-Result -Level "error" -Message ("Agent output missing field '" + $field + "': " + $FilePath)
        }
    }

    if ($json.PSObject.Properties.Name.Contains("status") -and $json.status -notin @("success","failed","blocked")) {
        Add-Result -Level "error" -Message ("Agent output has invalid status: " + $FilePath)
    }
    if ($json.PSObject.Properties.Name.Contains("retryable") -and $json.retryable -notin @("yes","no")) {
        Add-Result -Level "error" -Message ("Agent output has invalid retryable value: " + $FilePath)
    }
    if ($json.PSObject.Properties.Name.Contains("human_in_loop_required") -and $json.human_in_loop_required -notin @("yes","no")) {
        Add-Result -Level "error" -Message ("Agent output has invalid human_in_loop_required value: " + $FilePath)
    }
    if ($json.PSObject.Properties.Name.Contains("failure_type") -and $json.failure_type -notin @("none","format_error","missing_output","logic_inconsistency","architecture_violation","test_failure","security_risk","insufficient_context","timeout","policy_violation")) {
        Add-Result -Level "error" -Message ("Agent output has invalid failure_type: " + $FilePath)
    }

    foreach ($arrayField in @("produced_outputs","changed_components","changed_contracts","decision_refs","evidence_refs")) {
        if ($json.PSObject.Properties.Name.Contains($arrayField) -and $json.$arrayField -ne $null -and -not ($json.$arrayField -is [System.Array])) {
            Add-Result -Level "error" -Message ("Agent output field '" + $arrayField + "' must be an array: " + $FilePath)
        }
    }
}

function Test-EventLogIntegrity {
    param(
        [string]$EventLogPath,
        [string]$Label
    )

    if (-not (Test-Path $EventLogPath)) {
        Add-Result -Level "error" -Message ($Label + " runtime event log missing: " + $EventLogPath)
        return
    }

    $lines = Get-Content $EventLogPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($lines.Count -eq 0) {
        Add-Result -Level "error" -Message ($Label + " runtime event log is empty")
        return
    }

    $byExecution = @{}
    foreach ($line in $lines) {
        try {
            $evt = $line | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Add-Result -Level "error" -Message ($Label + " invalid runtime event JSON line")
            continue
        }

        foreach ($required in @("event_schema_version","event_seq","execution_id","job_id","event_type","state_version","prev_event_hash","event_hash")) {
            if (-not $evt.PSObject.Properties.Name.Contains($required)) {
                Add-Result -Level "error" -Message ($Label + " runtime event missing field: " + $required)
            }
        }

        if (-not $byExecution.ContainsKey($evt.execution_id)) {
            $byExecution[$evt.execution_id] = @()
        }
        $byExecution[$evt.execution_id] += $evt
    }

    foreach ($executionId in $byExecution.Keys) {
        $events = @($byExecution[$executionId] | Sort-Object -Property event_seq, timestamp)
        $expectedSeq = 1
        $previousHash = "genesis"
        $sawRisk = ""
        foreach ($evt in $events) {
            if ([int]$evt.event_seq -ne $expectedSeq) {
                Add-Result -Level "error" -Message ($Label + " execution " + $executionId + " has sequence gap at " + $expectedSeq)
            }
            if ([string]$evt.prev_event_hash -ne $previousHash) {
                Add-Result -Level "error" -Message ($Label + " execution " + $executionId + " has broken prev_event_hash at seq " + $expectedSeq)
            }

            $verificationPayload = @{
                event_schema_version = $evt.event_schema_version
                event_seq = [int]$evt.event_seq
                timestamp = [string]$evt.timestamp
                execution_id = [string]$evt.execution_id
                job_id = [string]$evt.job_id
                event_type = [string]$evt.event_type
                state_version = [int]$evt.state_version
                prev_event_hash = [string]$evt.prev_event_hash
                idempotency_key = [string]$evt.idempotency_key
                payload = $evt.payload
            } | ConvertTo-Json -Depth 12 -Compress
            $computedHash = Get-Sha256Hex -InputText $verificationPayload
            if ([string]$evt.event_hash -ne $computedHash) {
                Add-Result -Level "error" -Message ($Label + " execution " + $executionId + " has hash mismatch at seq " + $expectedSeq)
            }

            if ($evt.payload -and $evt.payload.PSObject.Properties.Name -contains "risk_level") {
                $sawRisk = [string]$evt.payload.risk_level
            }
            if (($sawRisk -in @("yuksek","kritik")) -and [string]$evt.event_type -eq "retry") {
                Add-Result -Level "error" -Message ($Label + " execution " + $executionId + " violates policy: retry on high/critical risk")
            }

            $previousHash = [string]$evt.event_hash
            $expectedSeq++
        }
    }

    Add-Result -Level "pass" -Message ($Label + " runtime event log integrity validated")
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Cursor Agents Framework - Orchestration" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host ("  Docs path: " + $DocsPath)
Write-Host ("  Strict:    " + $Strict.IsPresent)

$workflowStatePath = Join-Path $DocsPath "workflow-state.md"
if (-not (Test-Path $workflowStatePath)) {
    Add-Result -Level "error" -Message "workflow-state.md not found under docs path"
} else {
    $workflowState = Get-Content $workflowStatePath -Raw
    $requiredWorkflowFields = @(
        "state_version","last_updated","state_ref","job_id","title","request_summary","job_type","scope","risk_level","affected_layers",
        "execution_id","runtime_event_log_ref",
        "current_phase","current_status","selected_agents","active_gate","completed_gates","failed_gates",
        "failure_count_total","failure_count_current_stage","last_failure_type","last_failed_gate",
        "retry_allowed","escalation_required","human_in_loop_required","changed_contracts",
        "changed_components","changed_data_model","test_status_summary","review_status_summary",
        "open_risks","next_action","human_in_loop_status","plan_approval_status","release_approval_status","agent_output_refs"
    )
    Test-Fields -Content $workflowState -Fields $requiredWorkflowFields -Label "workflow-state.md"
    $workflowEventRef = Get-FieldValue -Content $workflowState -FieldName "runtime_event_log_ref"
    Test-RefFile -Value $workflowEventRef -Label "workflow-state.md"
    $resolvedWorkflowEventLog = Resolve-ArtifactRef -Value $workflowEventRef
    if ($resolvedWorkflowEventLog) { $eventLogsToCheck[$resolvedWorkflowEventLog] = "workflow-state.md" }

    $evidenceRows = Get-TableRowNames -Content $workflowState
    foreach ($row in @("build_status","lint_status","test_status","coverage_status","review_status","security_status","documentation_status")) {
        if ($evidenceRows -notcontains $row) {
            Add-Result -Level "error" -Message ("workflow-state.md missing evidence row: " + $row)
        }
    }

    $risk = Get-FieldValue -Content $workflowState -FieldName "risk_level"
    $stageFailureString = Get-FieldValue -Content $workflowState -FieldName "failure_count_current_stage"
    $totalFailureString = Get-FieldValue -Content $workflowState -FieldName "failure_count_total"
    $retryAllowed = Get-FieldValue -Content $workflowState -FieldName "retry_allowed"
    $escalationRequired = Get-FieldValue -Content $workflowState -FieldName "escalation_required"
    $humanLoopRequired = Get-FieldValue -Content $workflowState -FieldName "human_in_loop_required"

    if (-not $stageFailureString) { $stageFailureString = "0" }
    if (-not $totalFailureString) { $totalFailureString = "0" }

    $stageFailures = [int]$stageFailureString
    $totalFailures = [int]$totalFailureString
    $retryLimits = @{ "dusuk" = 2; "orta" = 1; "yuksek" = 0; "kritik" = 0 }

    if ($retryLimits.ContainsKey($risk)) {
        $limit = $retryLimits[$risk]
        if ($stageFailures -gt $limit -and $retryAllowed -eq "yes") {
            Add-Result -Level "error" -Message ("workflow-state.md retry_allowed=yes exceeds limit for risk level " + $risk)
        }
        if (($risk -eq "yuksek" -or $risk -eq "kritik") -and $retryAllowed -eq "yes") {
            Add-Result -Level "error" -Message "workflow-state.md high or critical risk cannot keep retry_allowed=yes"
        }
    }

    if ($totalFailures -ge 3 -and $humanLoopRequired -ne "yes" -and $escalationRequired -ne "yes") {
        Add-Result -Level "error" -Message "workflow-state.md reached hard-stop threshold without escalation or human loop"
    }

    if ($Strict) {
        $handoffDir = Join-Path $DocsPath "handoffs"
        $handoffFiles = @()
        if (Test-Path $handoffDir) {
            $handoffFiles = @(Get-ChildItem $handoffDir "*.md" -File -ErrorAction SilentlyContinue)
        }
        if ($handoffFiles.Count -eq 0) {
            Add-Result -Level "error" -Message "No handoff files found under docs/agents/handoffs"
        }

        $agentOutputDir = Join-Path $DocsPath "agent-outputs"
        $agentOutputFiles = @()
        if (Test-Path $agentOutputDir) {
            $agentOutputFiles = @(Get-ChildItem $agentOutputDir "*.json" -File -ErrorAction SilentlyContinue)
        }
        if ($agentOutputFiles.Count -eq 0) {
            Add-Result -Level "error" -Message "No agent output files found under docs/agents/agent-outputs"
        } else {
            foreach ($outputFile in $agentOutputFiles) {
                Test-AgentOutputContract -FilePath $outputFile.FullName
            }
        }
    }

    Add-Result -Level "pass" -Message "workflow-state.md validated"
}

$decisionFiles = @()
$decisionDir = Join-Path $DocsPath "decisions"
if (Test-Path $decisionDir) {
    $decisionFiles = @(Get-ChildItem $decisionDir "decision-log-*.md" -File -ErrorAction SilentlyContinue)
}
if ($decisionFiles.Count -eq 0) {
    if ($Strict) {
        Add-Result -Level "error" -Message "No decision-log files found"
    } else {
        Add-Result -Level "warning" -Message "No decision-log files found"
    }
}

$decisionIds = Get-DecisionIdMap -Files $decisionFiles
foreach ($file in $decisionFiles) {
    $content = Get-Content $file.FullName -Raw
    Test-Fields -Content $content -Fields @(
        "decision_id","timestamp","job_id","decision_topic","chosen_path","rationale",
        "risk_level","impacted_agents_or_layers","related_gate_refs","related_state_ref"
    ) -Label $file.Name

    Test-RefFile -Value (Get-FieldValue -Content $content -FieldName "related_state_ref") -Label $file.Name
    Test-RefFile -Value (Get-FieldValue -Content $content -FieldName "quality_gate_ref") -Label $file.Name
    Test-RefFile -Value (Get-FieldValue -Content $content -FieldName "failure_report_ref") -Label $file.Name
    Test-RefFile -Value (Get-FieldValue -Content $content -FieldName "adr_ref") -Label $file.Name
    Add-Result -Level "pass" -Message ($file.Name + " validated")
}

$gateFiles = @()
$gateDir = Join-Path $DocsPath "quality-gates"
if (Test-Path $gateDir) {
    $gateFiles = @(Get-ChildItem $gateDir "*.md" -File -ErrorAction SilentlyContinue)
}
if ($gateFiles.Count -eq 0) {
    if ($Strict) {
        Add-Result -Level "error" -Message "No quality gate reports found"
    } else {
        Add-Result -Level "warning" -Message "No quality gate reports found"
    }
}

foreach ($file in $gateFiles) {
    $content = Get-Content $file.FullName -Raw
    Test-Fields -Content $content -Fields @(
        "report_id","job_id","gate_id","gate_name","timestamp","decision_id","state_ref","outcome",
        "execution_id","runtime_event_log_ref",
        "decision_topic","chosen_path","rationale","skip_reason","build_status","lint_status",
        "build_evidence_ref","lint_evidence_ref","test_status","test_evidence_ref","coverage_status","coverage_evidence_ref","review_status","review_evidence_ref","security_status","security_evidence_ref","documentation_status","documentation_evidence_ref",
        "failed_gate","failure_report_ref","owner_agent","next_action","workflow_state_ref","related_decision_log_ref"
    ) -Label $file.Name

    $gateId = Get-FieldValue -Content $content -FieldName "gate_id"
    $outcome = Get-FieldValue -Content $content -FieldName "outcome"
    $decisionId = Get-FieldValue -Content $content -FieldName "decision_id"

    foreach ($field in @("build_status","lint_status","test_status","coverage_status","review_status","security_status","documentation_status")) {
        $value = Get-FieldValue -Content $content -FieldName $field
        if ($value -and $allowedEvidence -notcontains $value) {
            Add-Result -Level "error" -Message ($file.Name + " has invalid " + $field + " value: " + $value)
        }
    }

    if ($decisionId -and -not $decisionIds.ContainsKey($decisionId)) {
        Add-Result -Level "error" -Message ($file.Name + " references unknown decision_id: " + $decisionId)
    }

    if ($outcome -eq "passed" -and $gateRequirements.ContainsKey($gateId)) {
        foreach ($requiredField in $gateRequirements[$gateId]) {
            if ((Get-FieldValue -Content $content -FieldName $requiredField) -ne "verified") {
                Add-Result -Level "error" -Message ($file.Name + " requires " + $requiredField + "=verified when outcome=passed")
            }
            $refField = $requiredField -replace "_status$", "_evidence_ref"
            $refValue = Get-FieldValue -Content $content -FieldName $refField
            if ([string]::IsNullOrWhiteSpace($refValue) -or $refValue -eq "none" -or $refValue -eq "-") {
                Add-Result -Level "error" -Message ($file.Name + " requires " + $refField + " when outcome=passed")
            } else {
                Test-RefFile -Value $refValue -Label $file.Name
            }
        }
    }

    if ($outcome -eq "skipped" -and $gateRequirements.ContainsKey($gateId)) {
        $hasSkippedReason = $false
        foreach ($requiredField in $gateRequirements[$gateId]) {
            if ((Get-FieldValue -Content $content -FieldName $requiredField) -eq "skipped_with_reason") {
                $hasSkippedReason = $true
            }
        }
        if (-not $hasSkippedReason) {
            Add-Result -Level "error" -Message ($file.Name + " must mark at least one required evidence as skipped_with_reason when outcome=skipped")
        }
    }

    if ($gateId -eq "G7" -and $outcome -eq "passed") {
        foreach ($field in @("build_status","lint_status","test_status","coverage_status","review_status","security_status","documentation_status")) {
            $value = Get-FieldValue -Content $content -FieldName $field
            if ($value -eq "pending" -or $value -eq "not_verified") {
                Add-Result -Level "error" -Message ($file.Name + " release gate passed cannot keep " + $field + "=" + $value)
            }
        }
    }

    Test-RefFile -Value (Get-FieldValue -Content $content -FieldName "state_ref") -Label $file.Name
    $gateEventRef = Get-FieldValue -Content $content -FieldName "runtime_event_log_ref"
    Test-RefFile -Value $gateEventRef -Label $file.Name
    $resolvedGateEventLog = Resolve-ArtifactRef -Value $gateEventRef
    if ($resolvedGateEventLog) { $eventLogsToCheck[$resolvedGateEventLog] = $file.Name }
    Test-RefFile -Value (Get-FieldValue -Content $content -FieldName "failure_report_ref") -Label $file.Name
    Test-RefFile -Value (Get-FieldValue -Content $content -FieldName "workflow_state_ref") -Label $file.Name
    Test-RefFile -Value (Get-FieldValue -Content $content -FieldName "related_decision_log_ref") -Label $file.Name
    Add-Result -Level "pass" -Message ($file.Name + " validated")
}

$failureFiles = @()
$failureDir = Join-Path $DocsPath "failures"
if (Test-Path $failureDir) {
    $failureFiles = @(Get-ChildItem $failureDir "*.md" -File -ErrorAction SilentlyContinue)
}

foreach ($file in $failureFiles) {
    $content = Get-Content $file.FullName -Raw
    Test-Fields -Content $content -Fields @(
        "failure_id","job_id","timestamp","agent","step","decision_id","state_ref","failed_gate",
        "execution_id","runtime_event_log_ref",
        "risk_level","failure_count_total","failure_count_current_stage","retry_attempt","retry_limit",
        "retry_allowed","escalation_required","human_in_loop_required","failure_type","root_cause",
        "action_taken","resolution_status","next_action","prevention_note","decision_log_ref",
        "quality_gate_ref","state_snapshot_ref","agent_output_ref"
    ) -Label $file.Name

    $decisionId = Get-FieldValue -Content $content -FieldName "decision_id"
    if ($decisionId -and -not $decisionIds.ContainsKey($decisionId)) {
        Add-Result -Level "error" -Message ($file.Name + " references unknown decision_id: " + $decisionId)
    }

    Test-RefFile -Value (Get-FieldValue -Content $content -FieldName "state_ref") -Label $file.Name
    $failureEventRef = Get-FieldValue -Content $content -FieldName "runtime_event_log_ref"
    Test-RefFile -Value $failureEventRef -Label $file.Name
    $resolvedFailureEventLog = Resolve-ArtifactRef -Value $failureEventRef
    if ($resolvedFailureEventLog) { $eventLogsToCheck[$resolvedFailureEventLog] = $file.Name }
    Test-RefFile -Value (Get-FieldValue -Content $content -FieldName "decision_log_ref") -Label $file.Name
    Test-RefFile -Value (Get-FieldValue -Content $content -FieldName "quality_gate_ref") -Label $file.Name
    Test-RefFile -Value (Get-FieldValue -Content $content -FieldName "state_snapshot_ref") -Label $file.Name
    Add-Result -Level "pass" -Message ($file.Name + " validated")
}

$snapshotFiles = @()
$snapshotDir = Join-Path $DocsPath "state-snapshots"
if (Test-Path $snapshotDir) {
    $snapshotFiles = @(Get-ChildItem $snapshotDir "*.md" -File -ErrorAction SilentlyContinue)
}

foreach ($file in $snapshotFiles) {
    $content = Get-Content $file.FullName -Raw
    Test-Fields -Content $content -Fields @(
        "snapshot_id","job_id","timestamp","snapshot_reason","state_ref","execution_id","runtime_event_log_ref","title","job_type","scope",
        "risk_level","current_phase","active_gate","next_action","human_in_loop_status",
        "failure_count_total","failure_count_current_stage","last_failure_type","last_failed_gate",
        "changed_contracts","changed_components","changed_data_model","open_risks",
        "decision_refs","failure_report_refs","quality_gate_refs"
    ) -Label $file.Name

    Test-RefFile -Value (Get-FieldValue -Content $content -FieldName "state_ref") -Label $file.Name
    $snapshotEventRef = Get-FieldValue -Content $content -FieldName "runtime_event_log_ref"
    Test-RefFile -Value $snapshotEventRef -Label $file.Name
    $resolvedSnapshotEventLog = Resolve-ArtifactRef -Value $snapshotEventRef
    if ($resolvedSnapshotEventLog) { $eventLogsToCheck[$resolvedSnapshotEventLog] = $file.Name }
    Add-Result -Level "pass" -Message ($file.Name + " validated")
}

foreach ($eventLogPath in $eventLogsToCheck.Keys) {
    Test-EventLogIntegrity -EventLogPath $eventLogPath -Label $eventLogsToCheck[$eventLogPath]
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Orchestration Validation Report" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "  STATUS: ALL CHECKS PASSED" -ForegroundColor Green
} elseif ($errors.Count -gt 0) {
    Write-Host ("  STATUS: FAILED (" + $errors.Count + " errors)") -ForegroundColor Red
} else {
    Write-Host ("  STATUS: PASSED WITH WARNINGS (" + $warnings.Count + ")") -ForegroundColor Yellow
}

Write-Host ""
Write-Host ("  Passed: " + $passed.Count) -ForegroundColor Green
foreach ($item in $passed) {
    Write-Host ("    [OK] " + $item) -ForegroundColor DarkGreen
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host ("  Warnings: " + $warnings.Count) -ForegroundColor Yellow
    foreach ($item in $warnings) {
        Write-Host ("    [WARN] " + $item) -ForegroundColor Yellow
    }
}

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host ("  Errors: " + $errors.Count) -ForegroundColor Red
    foreach ($item in $errors) {
        Write-Host ("    [ERROR] " + $item) -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan

if ($errors.Count -gt 0) { exit 1 }
exit 0
