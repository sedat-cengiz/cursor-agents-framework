Set-StrictMode -Version Latest

$script:TransitionGraph = @{
    initialize      = @("classify")
    classify        = @("route", "stop")
    route           = @("plan", "stop")
    plan            = @("agent_call", "escalate", "stop")
    agent_call      = @("gate_check", "retry", "escalate", "stop")
    gate_check      = @("agent_call", "complete", "retry", "escalate", "stop")
    retry           = @("agent_call", "escalate", "stop")
    escalate        = @("plan", "stop")
    complete        = @()
    stop            = @()
}

$script:AllowedGates = @("G1", "G2", "G3", "G4", "G5", "G6", "G7")
$script:AllowedJobTypes = @("feature", "bugfix", "refactor", "integration", "performance", "ux-ui", "devops-infra", "research")

function New-OrchestrationStep {
    param(
        [int]$Order,
        [string]$Agent,
        [string]$StepId,
        [string]$Phase,
        [string]$Gate,
        [string]$ParallelGroup = "none"
    )

    return @{
        order = $Order
        agent = $Agent
        step_id = $StepId
        phase = $Phase
        gate = $Gate
        parallel_group = $ParallelGroup
    }
}

function Resolve-OrchestrationPipeline {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("feature","bugfix","refactor","integration","performance","ux-ui","devops-infra","research")][string]$JobType,
        [ValidateSet("S","M","L","XL")][string]$Scope = "M",
        [string]$RiskLevel = "orta",
        [string[]]$CandidateAgents = @(),
        [string[]]$AffectedLayers = @()
    )

    $candidates = @($CandidateAgents | Where-Object { $_ })
    if ($candidates.Count -eq 0) {
        $candidates = switch ($JobType) {
            "feature" { @("@sef","@analist","@mimari","@backend","@frontend","@qa","@review") }
            "bugfix" { @("@sef","@backend","@qa","@review") }
            "refactor" { @("@sef","@mimari","@backend","@qa","@review") }
            "integration" { @("@sef","@analist","@mimari","@backend","@qa","@review") }
            "performance" { @("@sef","@backend","@qa","@review") }
            "ux-ui" { @("@sef","@frontend","@qa","@review") }
            "devops-infra" { @("@sef","@devops","@review") }
            default { @("@sef") }
        }
    }

    $layers = @($AffectedLayers | Where-Object { $_ })
    $stepOrder = 0
    $pipeline = New-Object System.Collections.ArrayList

    function Add-Step {
        param(
            [System.Collections.ArrayList]$Pipeline,
            [Parameter(Mandatory = $true)][ref]$StepOrder,
            [string]$Agent,
            [string]$StepId,
            [string]$Phase,
            [string]$Gate,
            [string]$ParallelGroup = "none"
        )

        $StepOrder.Value = [int]$StepOrder.Value + 1
        [void]$Pipeline.Add((New-OrchestrationStep -Order $StepOrder.Value -Agent $Agent -StepId $StepId -Phase $Phase -Gate $Gate -ParallelGroup $ParallelGroup))
    }

    $includeAnalyst = $candidates -contains "@analist"
    $includeArchitect = $candidates -contains "@mimari"
    $includeBackend = ($candidates -contains "@backend") -or ($layers -contains "API") -or ($layers -contains "DB")
    $includeFrontend = ($candidates -contains "@frontend") -or ($layers -contains "UI")
    $includeSecurity = ($candidates -contains "@guvenlik") -or ($layers -contains "Security") -or ($RiskLevel -in @("yuksek", "kritik"))
    $includeDevOps = ($candidates -contains "@devops") -or ($layers -contains "Infra")
    $includeQA = $candidates -contains "@qa"
    $includeReview = $candidates -contains "@review"

    switch ($JobType) {
        "feature" {
            if ($includeAnalyst) { Add-Step -Pipeline $pipeline -StepOrder ([ref]$stepOrder) -Agent "@analist" -StepId "analysis" -Phase "analysis" -Gate "G2" }
            if ($includeArchitect) { Add-Step -Pipeline $pipeline -StepOrder ([ref]$stepOrder) -Agent "@mimari" -StepId "architecture" -Phase "architecture" -Gate "G3" }
        }
        "integration" {
            if ($includeAnalyst) { Add-Step -Pipeline $pipeline -StepOrder ([ref]$stepOrder) -Agent "@analist" -StepId "analysis" -Phase "analysis" -Gate "G2" }
            if ($includeArchitect) { Add-Step -Pipeline $pipeline -StepOrder ([ref]$stepOrder) -Agent "@mimari" -StepId "architecture" -Phase "architecture" -Gate "G3" }
        }
        "refactor" {
            if ($includeArchitect -or $Scope -ne "S") { Add-Step -Pipeline $pipeline -StepOrder ([ref]$stepOrder) -Agent "@mimari" -StepId "architecture" -Phase "architecture" -Gate "G3" }
        }
    }

    $implementationAgents = @()
    if ($includeBackend) { $implementationAgents += "@backend" }
    if ($includeFrontend) { $implementationAgents += "@frontend" }
    if ($includeDevOps -and $JobType -eq "devops-infra") { $implementationAgents += "@devops" }

    if ($implementationAgents.Count -eq 0 -and $JobType -ne "research") {
        if ($JobType -eq "ux-ui") {
            $implementationAgents += "@frontend"
        } else {
            $implementationAgents += "@backend"
        }
    }

    if ($implementationAgents.Count -gt 1 -and $implementationAgents -contains "@backend" -and $implementationAgents -contains "@frontend") {
        Add-Step -Pipeline $pipeline -StepOrder ([ref]$stepOrder) -Agent "@backend" -StepId "implementation-backend" -Phase "implementation" -Gate "G4" -ParallelGroup "implementation"
        Add-Step -Pipeline $pipeline -StepOrder ([ref]$stepOrder) -Agent "@frontend" -StepId "implementation-frontend" -Phase "implementation" -Gate "G4" -ParallelGroup "implementation"
    } else {
        foreach ($agent in $implementationAgents | Select-Object -Unique) {
            $stepId = if ($agent -eq "@devops") { "implementation-infra" } else { "implementation" }
            Add-Step -Pipeline $pipeline -StepOrder ([ref]$stepOrder) -Agent $agent -StepId $stepId -Phase "implementation" -Gate "G4"
        }
    }

    if ($includeQA -and $JobType -ne "research") {
        Add-Step -Pipeline $pipeline -StepOrder ([ref]$stepOrder) -Agent "@qa" -StepId "testing" -Phase "testing" -Gate "G5"
    }
    if ($includeSecurity -and $JobType -ne "research") {
        Add-Step -Pipeline $pipeline -StepOrder ([ref]$stepOrder) -Agent "@guvenlik" -StepId "security-review" -Phase "review" -Gate "G6"
    }
    if ($includeReview -and $JobType -ne "research") {
        Add-Step -Pipeline $pipeline -StepOrder ([ref]$stepOrder) -Agent "@review" -StepId "review" -Phase "review" -Gate "G6"
    }
    if ($JobType -ne "research") {
        Add-Step -Pipeline $pipeline -StepOrder ([ref]$stepOrder) -Agent "@sef" -StepId "release" -Phase "release" -Gate "G7"
    }

    return @($pipeline)
}

function Get-OrchestrationPipeline {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("feature","bugfix","refactor","integration","performance","ux-ui","devops-infra","research")][string]$JobType
    )

    return Resolve-OrchestrationPipeline -JobType $JobType
}

function New-OrchestrationState {
    param(
        [Parameter(Mandatory = $true)][string]$ExecutionId,
        [Parameter(Mandatory = $true)][string]$JobId,
        [Parameter(Mandatory = $true)][ValidateSet("feature","bugfix","refactor","integration","performance","ux-ui","devops-infra","research")][string]$JobType,
        [Parameter(Mandatory = $true)][ValidateSet("S","M","L","XL")][string]$Scope,
        [Parameter(Mandatory = $true)][ValidateSet("dusuk","orta","yuksek","kritik")][string]$RiskLevel,
        [hashtable]$IntakeContext = @{}
    )

    $candidateAgents = @()
    $affectedLayers = @()
    $approvalCheckpoints = @{ plan = "required"; release = "required" }
    if ($IntakeContext.ContainsKey("candidate_agents")) {
        $candidateAgents = @($IntakeContext["candidate_agents"])
    }
    if ($IntakeContext.ContainsKey("affected_layers")) {
        $affectedLayers = @($IntakeContext["affected_layers"])
    }
    if ($IntakeContext.ContainsKey("approval_checkpoints") -and $IntakeContext["approval_checkpoints"]) {
        $approvalCheckpoints = $IntakeContext["approval_checkpoints"]
    }

    $pipeline = Resolve-OrchestrationPipeline -JobType $JobType -Scope $Scope -RiskLevel $RiskLevel -CandidateAgents $candidateAgents -AffectedLayers $affectedLayers
    $selectedAgents = @("@sef") + @($pipeline | ForEach-Object { $_.agent })
    return @{
        execution_id = $ExecutionId
        job_id = $JobId
        job_type = $JobType
        scope = $Scope
        risk_level = $RiskLevel
        title = if ($IntakeContext.ContainsKey("request_summary") -and $IntakeContext["request_summary"]) { $IntakeContext["request_summary"] } else { $JobId }
        raw_request = if ($IntakeContext.ContainsKey("raw_request") -and $IntakeContext["raw_request"]) { $IntakeContext["raw_request"] } else { "" }
        request_summary = if ($IntakeContext.ContainsKey("request_summary") -and $IntakeContext["request_summary"]) { $IntakeContext["request_summary"] } else { $JobId }
        affected_layers = $affectedLayers
        current_state = "initialize"
        current_phase = "classification"
        current_status = "pending"
        active_gate = "none"
        current_agent = "@sef"
        selected_agents = $selectedAgents | Select-Object -Unique
        pipeline = $pipeline
        completed_gates = @()
        failed_gates = @()
        gate_results = @{}
        quality_gate_refs = @()
        agent_output_refs = @()
        failure_report_refs = @()
        state_snapshot_refs = @()
        major_decisions = @()
        changed_contracts = @()
        changed_components = @()
        changed_data_model = "none"
        test_status_summary = "pending"
        review_status_summary = "pending"
        open_risks = "none"
        next_action = "classify and route request"
        human_in_loop_status = "not_required"
        approval_status = @{
            plan = if ($approvalCheckpoints.plan -eq "required") { "pending_user" } else { "not_required" }
            release = if ($approvalCheckpoints.release -eq "required") { "pending_user" } else { "not_required" }
        }
        failure_count_total = 0
        failure_count_current_stage = 0
        last_failure_type = "none"
        last_failed_gate = "none"
        retry_allowed = if ($RiskLevel -in @("yuksek","kritik")) { "no" } else { "yes" }
        escalation_required = if ($RiskLevel -in @("yuksek","kritik")) { "yes" } else { "no" }
        human_in_loop_required = if ($RiskLevel -in @("yuksek","kritik")) { "yes" } else { "no" }
        evidence_status = @{
            build_status = "pending"
            lint_status = "pending"
            test_status = "pending"
            coverage_status = "pending"
            review_status = "pending"
            security_status = "pending"
            documentation_status = "pending"
        }
    }
}

function Test-GateAllowedForJobType {
    param(
        [Parameter(Mandatory = $true)][string]$JobType,
        [Parameter(Mandatory = $true)][string]$GateId
    )

    $matrix = @{
        feature      = @("G1","G2","G3","G4","G5","G6","G7")
        bugfix       = @("G4","G5","G6","G7")
        refactor     = @("G3","G4","G5","G6","G7")
        integration  = @("G1","G2","G3","G4","G5","G6","G7")
        performance  = @("G4","G5","G6","G7")
        "ux-ui"      = @("G4","G5","G6","G7")
        "devops-infra" = @("G4","G6","G7")
        research     = @()
    }

    if (-not $matrix.ContainsKey($JobType)) { return $false }
    return $matrix[$JobType] -contains $GateId
}

function Invoke-OrchestrationTransition {
    param(
        [Parameter(Mandatory = $true)][hashtable]$State,
        [Parameter(Mandatory = $true)][string]$TargetState,
        [string]$GateId = "",
        [string]$Reason = ""
    )

    $current = [string]$State.current_state
    if (-not $script:TransitionGraph.ContainsKey($current)) {
        throw "Unknown current_state: $current"
    }

    $allowed = $script:TransitionGraph[$current]
    if ($allowed -notcontains $TargetState) {
        throw "Invalid transition: $current -> $TargetState"
    }

    if ($GateId) {
        if ($script:AllowedGates -notcontains $GateId) {
            throw "Invalid gate id: $GateId"
        }
        if (-not (Test-GateAllowedForJobType -JobType $State.job_type -GateId $GateId)) {
            throw "Gate $GateId is not allowed for job type $($State.job_type)"
        }
        $State.active_gate = $GateId
    }

    # Hard-stop policy guard.
    if (($State.failure_count_total -ge 3) -and ($TargetState -ne "stop")) {
        throw "Hard stop required when failure_count_total >= 3"
    }
    if (($State.risk_level -in @("yuksek", "kritik")) -and ($TargetState -eq "retry")) {
        throw "Retry is not allowed for high/critical risk"
    }

    $State.current_state = $TargetState
    if ($Reason) {
        $State.last_transition_reason = $Reason
    }
    $State.last_transition_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    return $State
}

function Test-ReplayTransitions {
    param(
        [Parameter(Mandatory = $true)][object[]]$Events
    )

    if ($Events.Count -eq 0) {
        throw "No events provided for replay validation."
    }

    $simState = @{
        current_state = "initialize"
        failure_count_total = 0
        risk_level = "dusuk"
        job_type = "feature"
    }

    foreach ($evt in $Events) {
        if ($evt.payload -and $evt.payload.PSObject.Properties.Name -contains "risk_level") {
            $simState.risk_level = [string]$evt.payload.risk_level
        }
        if ($evt.payload -and $evt.payload.PSObject.Properties.Name -contains "job_type") {
            $simState.job_type = [string]$evt.payload.job_type
        }
        if ($evt.payload -and $evt.payload.PSObject.Properties.Name -contains "failure_count_total") {
            $simState.failure_count_total = [int]$evt.payload.failure_count_total
        }

        switch ([string]$evt.event_type) {
            "initialize" { continue }
            "classify" {
                $simState = Invoke-OrchestrationTransition -State $simState -TargetState "classify" -Reason "replay"
            }
            "route" {
                $simState = Invoke-OrchestrationTransition -State $simState -TargetState "route" -Reason "replay"
            }
            "plan" {
                $simState = Invoke-OrchestrationTransition -State $simState -TargetState "plan" -Reason "replay"
            }
            "agent_call" {
                $gate = if ($evt.payload -and $evt.payload.PSObject.Properties.Name -contains "active_gate") { [string]$evt.payload.active_gate } else { "" }
                $simState = Invoke-OrchestrationTransition -State $simState -TargetState "agent_call" -GateId $gate -Reason "replay"
            }
            "gate_check" {
                $gate = if ($evt.payload -and $evt.payload.PSObject.Properties.Name -contains "gate") { [string]$evt.payload.gate } else { "" }
                $simState = Invoke-OrchestrationTransition -State $simState -TargetState "gate_check" -GateId $gate -Reason "replay"
            }
            "retry" {
                $simState = Invoke-OrchestrationTransition -State $simState -TargetState "retry" -Reason "replay"
            }
            "escalate" {
                $simState = Invoke-OrchestrationTransition -State $simState -TargetState "escalate" -Reason "replay"
            }
            "stop" {
                $simState = Invoke-OrchestrationTransition -State $simState -TargetState "stop" -Reason "replay"
            }
            "complete" {
                $simState = Invoke-OrchestrationTransition -State $simState -TargetState "complete" -Reason "replay"
            }
            default {
                # Non-transition bookkeeping events are allowed.
                continue
            }
        }
    }

    return $true
}

Export-ModuleMember -Function @(
    "New-OrchestrationStep",
    "Resolve-OrchestrationPipeline",
    "Get-OrchestrationPipeline",
    "New-OrchestrationState",
    "Invoke-OrchestrationTransition",
    "Test-GateAllowedForJobType",
    "Test-ReplayTransitions"
)
