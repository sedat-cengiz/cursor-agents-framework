param(
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),
    [double]$EnforcementScoreThreshold = 0.90
)

$ErrorActionPreference = "Stop"

$validator = Join-Path (Join-Path $RepoRoot "scripts") "validate-orchestration.ps1"
$runtimeRunner = Join-Path (Join-Path $RepoRoot "runtime") "Invoke-Orchestration.ps1"
$runtimeReplay = Join-Path (Join-Path $RepoRoot "runtime") "Replay-Orchestration.ps1"

$powerShellHost = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $powerShellHost) {
    $powerShellHost = Get-Command powershell -ErrorAction SilentlyContinue
}
if (-not $powerShellHost) {
    throw "No PowerShell host found to run smoke tests"
}

function Invoke-Validator {
    param(
        [string]$DocsPath,
        [bool]$ShouldPass
    )

    & $powerShellHost.Source -NoProfile -File $validator -DocsPath $DocsPath -Strict | Out-Null
    $exitCode = $LASTEXITCODE
    if ($ShouldPass -and $exitCode -ne 0) {
        throw "Expected validation to pass for $DocsPath but exit code was $exitCode"
    }
    if (-not $ShouldPass -and $exitCode -eq 0) {
        throw "Expected validation to fail for $DocsPath but it passed"
    }
}

function Assert-Match {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Message
    )
    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

function New-RuntimeScenarioRoot {
    param([string]$Name)
    $root = Join-Path $env:TEMP "cursor-agents-runtime-smoke"
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $scenarioRoot = Join-Path $root $Name
    if (Test-Path $scenarioRoot) {
        Remove-Item $scenarioRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $scenarioRoot -Force | Out-Null
    $docsPath = Join-Path $scenarioRoot "docs\agents"
    New-Item -ItemType Directory -Path $docsPath -Force | Out-Null
    return @{
        root = $scenarioRoot
        docs = $docsPath
    }
}

function New-AgentRunnerScript {
    param(
        [string]$ScenarioRoot,
        [string]$Mode
    )

    $path = Join-Path $ScenarioRoot "run-agent.ps1"
    @'
param(
    [string]$Agent,
    [string]$JobId,
    [string]$ExecutionId,
    [string]$StepId,
    [string]$GateId,
    [string]$DocsPath,
    [string]$HandoffPath,
    [string]$OutputPath,
    [string]$Mode
)

$docsRoot = Split-Path $OutputPath -Parent | Split-Path -Parent
$modePath = Join-Path (Split-Path $OutputPath -Parent | Split-Path -Parent | Split-Path -Parent) ".mode"
if ($Mode) { Set-Content -Path $modePath -Value $Mode }
$scenarioMode = if (Test-Path $modePath) { (Get-Content $modePath -Raw).Trim() } else { "success" }
$attemptFile = Join-Path (Split-Path $OutputPath -Parent | Split-Path -Parent | Split-Path -Parent) ("attempt-" + $StepId + ".txt")
$attempt = 0
if (Test-Path $attemptFile) { $attempt = [int](Get-Content $attemptFile -Raw) }
$attempt++
Set-Content -Path $attemptFile -Value $attempt

$requirementsDir = Join-Path $docsRoot "requirements"
$contractsDir = Join-Path $docsRoot "contracts"
$decisionsDir = Join-Path $docsRoot "decisions"
$reviewsDir = Join-Path $docsRoot "reviews"
New-Item -ItemType Directory -Path $requirementsDir -Force | Out-Null
New-Item -ItemType Directory -Path $contractsDir -Force | Out-Null
New-Item -ItemType Directory -Path $decisionsDir -Force | Out-Null
New-Item -ItemType Directory -Path $reviewsDir -Force | Out-Null

$produced = @()
switch ($StepId) {
    "analysis" {
        $req = Join-Path $requirementsDir ("US-" + $JobId + ".md")
        "# User Story`n`n- runtime generated" | Set-Content -Path $req
        $produced += "docs/agents/requirements/$([System.IO.Path]::GetFileName($req))"
    }
    "architecture" {
        $adr = Join-Path $decisionsDir ("ADR-" + $JobId + ".md")
        $contract = Join-Path $contractsDir ("contract-" + $JobId + ".md")
        "# ADR`n`n- runtime generated" | Set-Content -Path $adr
        "# Contract`n`n- runtime generated" | Set-Content -Path $contract
        $produced += "docs/agents/decisions/$([System.IO.Path]::GetFileName($adr))"
        $produced += "docs/agents/contracts/$([System.IO.Path]::GetFileName($contract))"
    }
    "review" {
        $review = Join-Path $reviewsDir ("review-" + $JobId + ".md")
        "# Review`n`n- runtime generated" | Set-Content -Path $review
        $produced += "docs/agents/reviews/$([System.IO.Path]::GetFileName($review))"
    }
    default {
        $produced += "src/" + ($Agent.TrimStart("@")) + "-" + $StepId + ".txt"
    }
}

$status = "success"
$statusReason = "Completed successfully."
$failureType = "none"
$retryable = "no"
$humanLoop = "no"

switch ($scenarioMode) {
    "missing-output" {
        if ($StepId -eq "implementation") { exit 0 }
    }
    "retry-once" {
        if ($StepId -eq "implementation" -and $attempt -eq 1) {
            $status = "failed"
            $statusReason = "Temporary failure for retry path."
            $failureType = "test_failure"
            $retryable = "yes"
        }
    }
    "escalate" {
        if ($StepId -eq "implementation") {
            $status = "blocked"
            $statusReason = "Needs explicit user decision."
            $failureType = "insufficient_context"
            $retryable = "no"
            $humanLoop = "yes"
        }
    }
    "hard-stop" {
        if ($StepId -eq "implementation") {
            $status = "failed"
            $statusReason = "Security risk detected."
            $failureType = "security_risk"
            $retryable = "no"
            $humanLoop = "yes"
        }
    }
}

$payload = @{
    agent = $Agent
    job_id = $JobId
    execution_id = $ExecutionId
    step_id = $StepId
    gate_id = $GateId
    status = $status
    status_reason = $statusReason
    failure_type = $failureType
    summary = "$Agent completed $StepId."
    produced_outputs = $produced
    changed_components = @($StepId)
    changed_contracts = @()
    changed_data_model = "none"
    decision_refs = @("DEC-SMOKE-001")
    evidence_refs = @()
    next_action = "continue"
    retryable = $retryable
    human_in_loop_required = $humanLoop
}
$payload | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath
exit 0
'@ | Set-Content -Path $path
    return $path
}

function New-EvidenceScripts {
    param(
        [string]$ScenarioRoot,
        [string]$Mode
    )

    $scripts = @{
        build = Join-Path $ScenarioRoot "verify-build.ps1"
        lint = Join-Path $ScenarioRoot "verify-lint.ps1"
        test = Join-Path $ScenarioRoot "verify-test.ps1"
        coverage = Join-Path $ScenarioRoot "verify-coverage.ps1"
        security = Join-Path $ScenarioRoot "verify-security.ps1"
        review = Join-Path $ScenarioRoot "verify-review.ps1"
        doc = Join-Path $ScenarioRoot "verify-docs.ps1"
    }

    foreach ($key in $scripts.Keys) {
        $body = if ($Mode -eq "gate-fail" -and $key -eq "build") {
            "exit 1"
        } else {
            "exit 0"
        }
        Set-Content -Path $scripts[$key] -Value $body
    }

    $mapPath = Join-Path $ScenarioRoot "evidence-map.json"
    @{
        G4 = @{
            build_status = "$($powerShellHost.Source) -NoProfile -File ./verify-build.ps1"
            lint_status = "$($powerShellHost.Source) -NoProfile -File ./verify-lint.ps1"
            security_status = "$($powerShellHost.Source) -NoProfile -File ./verify-security.ps1"
            documentation_status = "$($powerShellHost.Source) -NoProfile -File ./verify-docs.ps1"
        }
        G5 = @{
            test_status = "$($powerShellHost.Source) -NoProfile -File ./verify-test.ps1"
            coverage_status = "$($powerShellHost.Source) -NoProfile -File ./verify-coverage.ps1"
            documentation_status = "$($powerShellHost.Source) -NoProfile -File ./verify-docs.ps1"
        }
        G6 = @{
            review_status = "$($powerShellHost.Source) -NoProfile -File ./verify-review.ps1"
            security_status = "$($powerShellHost.Source) -NoProfile -File ./verify-security.ps1"
            documentation_status = "$($powerShellHost.Source) -NoProfile -File ./verify-docs.ps1"
        }
    } | ConvertTo-Json -Depth 8 | Set-Content -Path $mapPath
    return $mapPath
}

function Invoke-RuntimeScenario {
    param(
        [string]$Name,
        [string]$JobId,
        [string]$JobType = "",
        [string]$Scope = "",
        [string]$RiskLevel = "",
        [string]$UserRequest = "",
        [string]$AgentMode,
        [string]$EvidenceMode = "success",
        [bool]$ExpectValidationPass = $true
    )

    $scenario = New-RuntimeScenarioRoot -Name $Name
    $runnerScript = New-AgentRunnerScript -ScenarioRoot $scenario.root -Mode $AgentMode
    $evidenceMap = New-EvidenceScripts -ScenarioRoot $scenario.root -Mode $EvidenceMode
    $commandTemplate = "& `"$($powerShellHost.Source)`" -NoProfile -File `"$runnerScript`" -Agent {{agent}} -JobId {{job_id}} -ExecutionId {{execution_id}} -StepId {{step_id}} -GateId {{gate_id}} -DocsPath {{docs_path}} -HandoffPath {{handoff_path}} -OutputPath {{output_path}} -Mode `"$AgentMode`""

    $runtimeArgs = @(
        "-NoProfile", "-File", $runtimeRunner,
        "-DocsPath", $scenario.docs,
        "-JobId", $JobId,
        "-Title", "$Name title",
        "-AgentCommandTemplate", $commandTemplate,
        "-EvidenceCommandMapPath", $evidenceMap,
        "-WorkingDirectory", $scenario.root,
        "-AutoApproveUserDecisions"
    )
    if ($UserRequest) {
        $runtimeArgs += @("-UserRequest", $UserRequest)
    } else {
        $runtimeArgs += @("-JobType", $JobType, "-Scope", $Scope, "-RiskLevel", $RiskLevel)
    }

    & $powerShellHost.Source @runtimeArgs | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Runtime scenario failed to execute: $Name"
    }

    Invoke-Validator -DocsPath $scenario.docs -ShouldPass $ExpectValidationPass
    return $scenario
}

function Get-ExecutionId {
    param([string]$DocsPath)
    $workflow = Get-Content (Join-Path $DocsPath "workflow-state.md") -Raw
    if ($workflow -match "(?m)^- \*\*execution_id:\*\*\s+(.+?)\s*$") {
        return $Matches[1].Trim()
    }
    throw "Execution id not found in workflow-state.md"
}

$checks = @()

$feature = Invoke-RuntimeScenario -Name "feature-live" -JobId "WORK-FEATURE-LIVE-001" -JobType feature -Scope L -RiskLevel orta -AgentMode success
$featureState = Get-Content (Join-Path $feature.docs "workflow-state.md") -Raw
Assert-Match -Content $featureState -Pattern "@analist" -Message "Feature runtime flow must include @analist"
Assert-Match -Content $featureState -Pattern "@backend" -Message "Feature runtime flow must include @backend"
Assert-Match -Content $featureState -Pattern "@frontend" -Message "Feature runtime flow must include @frontend"
$featureExecutionId = Get-ExecutionId -DocsPath $feature.docs
& $powerShellHost.Source -NoProfile -File $runtimeReplay -DocsPath $feature.docs -ExecutionId $featureExecutionId | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Runtime replay failed for feature scenario" }
$checks += $true

$intakeDriven = Invoke-RuntimeScenario -Name "intake-live" -JobId "WORK-INTAKE-LIVE-001" -UserRequest "Fix backend authentication bug with security impact" -AgentMode success
$intakeState = Get-Content (Join-Path $intakeDriven.docs "workflow-state.md") -Raw
Assert-Match -Content $intakeState -Pattern "request_summary:\*\*" -Message "Intake-driven scenario must write request summary"
Assert-Match -Content $intakeState -Pattern "@guvenlik" -Message "Security-sensitive intake must route @guvenlik"
$checks += $true

$bugfix = Invoke-RuntimeScenario -Name "bugfix-live" -JobId "WORK-BUGFIX-LIVE-001" -JobType bugfix -Scope S -RiskLevel orta -AgentMode success
$bugfixState = Get-Content (Join-Path $bugfix.docs "workflow-state.md") -Raw
Assert-Match -Content $bugfixState -Pattern "@backend" -Message "Bugfix runtime flow must include @backend"
if ($bugfixState -match "@analist|@mimari") { throw "Bugfix runtime flow should skip @analist and @mimari" }
$checks += $true

$refactor = Invoke-RuntimeScenario -Name "refactor-live" -JobId "WORK-REFACTOR-LIVE-001" -JobType refactor -Scope M -RiskLevel orta -AgentMode success
$refactorState = Get-Content (Join-Path $refactor.docs "workflow-state.md") -Raw
Assert-Match -Content $refactorState -Pattern "@mimari" -Message "Refactor runtime flow must include @mimari"
$checks += $true

$retry = Invoke-RuntimeScenario -Name "retry-live" -JobId "WORK-RETRY-LIVE-001" -JobType bugfix -Scope S -RiskLevel orta -AgentMode retry-once
$retryState = Get-Content (Join-Path $retry.docs "workflow-state.md") -Raw
Assert-Match -Content $retryState -Pattern "failure_count_total:\*\* 1" -Message "Retry scenario must record exactly one failure before recovery"
if ((Get-ChildItem (Join-Path $retry.docs "failures") "*.md").Count -lt 1) { throw "Retry scenario must create a failure report" }
$checks += $true

$escalate = Invoke-RuntimeScenario -Name "escalate-live" -JobId "WORK-ESCALATE-LIVE-001" -JobType bugfix -Scope S -RiskLevel orta -AgentMode escalate
$escalateState = Get-Content (Join-Path $escalate.docs "workflow-state.md") -Raw
Assert-Match -Content $escalateState -Pattern "human_in_loop_required:\*\* yes" -Message "Escalation scenario must require human loop"
$checks += $true

$hardStop = Invoke-RuntimeScenario -Name "hard-stop-live" -JobId "WORK-HARDSTOP-LIVE-001" -JobType bugfix -Scope S -RiskLevel kritik -AgentMode hard-stop
$hardStopState = Get-Content (Join-Path $hardStop.docs "workflow-state.md") -Raw
Assert-Match -Content $hardStopState -Pattern "last_failure_type:\*\* security_risk" -Message "Hard stop scenario must record security risk"
$checks += $true

$missingOutput = Invoke-RuntimeScenario -Name "missing-output-live" -JobId "WORK-MISSING-LIVE-001" -JobType bugfix -Scope S -RiskLevel orta -AgentMode missing-output -ExpectValidationPass $false
$checks += $true

$totalChecks = $checks.Count
$successfulChecks = ($checks | Where-Object { $_ }).Count
$enforcementScore = [math]::Round(($successfulChecks / $totalChecks), 4)

Write-Host ("ENFORCEMENT_SCORE=" + $enforcementScore)
$scoreReport = Join-Path (Join-Path (Join-Path $RepoRoot "tests") "smoke") "enforcement-score.json"
@{
    enforcement_score = $enforcementScore
    threshold = $EnforcementScoreThreshold
    successful_checks = $successfulChecks
    total_checks = $totalChecks
    live_runtime_checks = $totalChecks
} | ConvertTo-Json -Depth 5 | Set-Content -Path $scoreReport

if ($enforcementScore -lt $EnforcementScoreThreshold) {
    throw ("Enforcement score below threshold. Score=" + $enforcementScore + ", threshold=" + $EnforcementScoreThreshold)
}

Write-Host ""
Write-Host "Smoke tests passed." -ForegroundColor Green
exit 0
