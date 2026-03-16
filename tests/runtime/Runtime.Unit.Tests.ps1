$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $repoRoot "runtime\engine\StateMachine.psm1") -Force
Import-Module (Join-Path $repoRoot "runtime\engine\EventStore.psm1") -Force
Import-Module (Join-Path $repoRoot "runtime\policies\RetryPolicy.psm1") -Force
Import-Module (Join-Path $repoRoot "runtime\executor\AgentContract.psm1") -Force
Import-Module (Join-Path $repoRoot "runtime\executor\AgentExecutionAdapter.psm1") -Force
Import-Module (Join-Path $repoRoot "runtime\intake\RequestIntake.psm1") -Force

Describe "StateMachine" {
    It "allows valid transition path" {
        $state = New-OrchestrationState -ExecutionId "EXEC-UNIT-1" -JobId "WORK-UNIT-1" -JobType feature -Scope M -RiskLevel orta
        $state = Invoke-OrchestrationTransition -State $state -TargetState classify
        $state = Invoke-OrchestrationTransition -State $state -TargetState route
        $state.current_state | Should Be "route"
    }

    It "blocks invalid transition path" {
        $state = New-OrchestrationState -ExecutionId "EXEC-UNIT-2" -JobId "WORK-UNIT-2" -JobType feature -Scope M -RiskLevel orta
        { Invoke-OrchestrationTransition -State $state -TargetState gate_check } | Should Throw
    }

    It "returns supported feature pipeline" {
        $pipeline = Get-OrchestrationPipeline -JobType feature
        $pipeline.Count | Should Be 7
        $pipeline[0].agent | Should Be "@analist"
        $pipeline[2].parallel_group | Should Be "implementation"
        $pipeline[3].agent | Should Be "@frontend"
    }

    It "reduces routing for backend-only bugfix context" {
        $pipeline = Resolve-OrchestrationPipeline -JobType bugfix -Scope S -RiskLevel dusuk -CandidateAgents @("@sef","@backend","@qa","@review") -AffectedLayers @("API")
        ($pipeline | ForEach-Object { $_.agent }) -contains "@frontend" | Should Be $false
        $pipeline[0].agent | Should Be "@backend"
    }
}

Describe "EventStore" {
    It "writes sequential events with hash chain" {
        $docsPath = Join-Path $env:TEMP "eventstore-unit-docs"
        if (Test-Path $docsPath) { Remove-Item $docsPath -Recurse -Force }
        New-Item -ItemType Directory -Path $docsPath -Force | Out-Null

        $eventPath = New-EventStore -DocsPath $docsPath
        $e1 = Add-StateEvent -EventPath $eventPath -ExecutionId "EXEC-UNIT-3" -JobId "WORK-UNIT-3" -EventType "initialize" -Payload @{ current_state = "initialize" } -IdempotencyKey "unit-init"
        $e2 = Add-StateEvent -EventPath $eventPath -ExecutionId "EXEC-UNIT-3" -JobId "WORK-UNIT-3" -EventType "classify" -Payload @{ current_state = "classify"; risk_level = "orta" } -IdempotencyKey "unit-classify"

        [int]$e1.event_seq | Should Be 1
        [int]$e2.event_seq | Should Be 2
        [string]$e2.prev_event_hash | Should Be ([string]$e1.event_hash)
    }
}

Describe "RetryPolicy" {
    It "returns hard stop for security risk" {
        $decision = Get-FailureAction -FailureType security_risk -RiskLevel orta -FailureCountCurrentStage 0 -FailureCountTotal 0
        $decision.action | Should Be "hard_stop"
    }

    It "disables retry for critical risk" {
        $decision = Get-FailureAction -FailureType test_failure -RiskLevel kritik -FailureCountCurrentStage 1 -FailureCountTotal 1
        $decision.retry_allowed | Should Be "no"
    }
}

Describe "AgentContract" {
    It "accepts expanded runtime output contract" {
        $outputPath = Join-Path $env:TEMP "agent-output-unit.json"
        @{
            agent = "@backend"
            job_id = "WORK-UNIT-4"
            execution_id = "EXEC-UNIT-4"
            step_id = "implementation"
            gate_id = "G4"
            status = "success"
            status_reason = "ok"
            failure_type = "none"
            summary = "done"
            produced_outputs = @("src/file.cs")
            changed_components = @("OrderService")
            changed_contracts = @()
            changed_data_model = "none"
            decision_refs = @("DEC-UNIT-1")
            evidence_refs = @()
            next_action = "continue"
            retryable = "no"
            human_in_loop_required = "no"
        } | ConvertTo-Json -Depth 6 | Set-Content -Path $outputPath

        $result = Test-AgentOutputContract -OutputPath $outputPath
        $result.ok | Should Be $true
    }
}

Describe "AgentExecutionAdapter" {
    It "resolves synthetic runtime mode" {
        $docsPath = Join-Path $env:TEMP "agent-adapter-docs"
        New-Item -ItemType Directory -Path $docsPath -Force | Out-Null
        $config = Resolve-OrchestrationRuntimeConfig -DocsPath $docsPath -ExecutionMode synthetic -StackAdapter generic
        $config.execution_mode | Should Be "synthetic"
    }

    It "falls back to project-local run-agent script" {
        $projectRoot = Join-Path $env:TEMP "agent-adapter-project"
        $docsPath = Join-Path $projectRoot "docs\agents"
        $scriptsPath = Join-Path $projectRoot "scripts"
        New-Item -ItemType Directory -Path $docsPath -Force | Out-Null
        New-Item -ItemType Directory -Path $scriptsPath -Force | Out-Null
        Set-Content -Path (Join-Path $scriptsPath "run-agent.ps1") -Value "# stub"
        $config = Resolve-OrchestrationRuntimeConfig -DocsPath $docsPath
        $config.agent_command_template | Should Match "run-agent.ps1"
    }
}

Describe "RequestIntake" {
    It "derives normalized intake from user request" {
        $intake = New-RequestIntake -UserRequest "Login bugfix for backend auth flow with security impact"
        $intake.job_type | Should Be "bugfix"
        $intake.risk_level | Should Be "kritik"
        $intake.affected_layers -contains "API" | Should Be $true
        $intake.candidate_agents -contains "@guvenlik" | Should Be $true
    }
}
