Set-StrictMode -Version Latest

function Resolve-OrchestrationRuntimeConfig {
    param(
        [string]$DocsPath,
        [string]$ManifestPath = "",
        [string]$ExecutionMode = "",
        [string]$AgentCommandTemplate = "",
        [string]$EvidenceCommandMapPath = "",
        [string]$WorkingDirectory = "",
        [string]$StackAdapter = "",
        [int]$AgentTimeoutSeconds = 0
    )

    $projectRoot = if ($DocsPath) {
        $docsLeaf = Split-Path $DocsPath -Leaf
        $docsParent = Split-Path $DocsPath -Parent
        $docsParentLeaf = Split-Path $docsParent -Leaf
        if ($docsLeaf -eq "agents" -and $docsParentLeaf -eq "docs") {
            Split-Path $docsParent -Parent
        } else {
            Split-Path $DocsPath -Parent
        }
    } else {
        Get-Location
    }

    if (-not $ManifestPath) {
        $candidate = Join-Path $projectRoot "agents.manifest.json"
        if (Test-Path $candidate) {
            $ManifestPath = $candidate
        }
    }

    $manifest = $null
    if ($ManifestPath -and (Test-Path $ManifestPath)) {
        $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    }

    $runtimeConfig = $null
    if ($manifest -and $manifest.orchestration -and $manifest.orchestration.runtime) {
        $runtimeConfig = $manifest.orchestration.runtime
    }

    $resolvedWorkingDirectory = if ($WorkingDirectory) {
        $WorkingDirectory
    } elseif ($runtimeConfig -and $runtimeConfig.workingDirectory) {
        $runtimeConfig.workingDirectory
    } else {
        $projectRoot
    }
    if (-not [System.IO.Path]::IsPathRooted($resolvedWorkingDirectory)) {
        $resolvedWorkingDirectory = Join-Path $projectRoot $resolvedWorkingDirectory
    }

    $resolvedEvidenceMap = if ($EvidenceCommandMapPath) {
        $EvidenceCommandMapPath
    } elseif ($runtimeConfig -and $runtimeConfig.evidenceCommandMapPath) {
        $runtimeConfig.evidenceCommandMapPath
    } else {
        ""
    }
    if ($resolvedEvidenceMap -and -not [System.IO.Path]::IsPathRooted($resolvedEvidenceMap)) {
        $resolvedEvidenceMap = Join-Path $projectRoot $resolvedEvidenceMap
    }

    $resolvedMode = if ($ExecutionMode) {
        $ExecutionMode
    } elseif ($runtimeConfig -and $runtimeConfig.executionMode) {
        [string]$runtimeConfig.executionMode
    } else {
        "command"
    }

    $resolvedRunnerScript = if ($runtimeConfig -and $runtimeConfig.agentRunnerScriptPath) {
        [string]$runtimeConfig.agentRunnerScriptPath
    } else {
        "scripts/run-agent.ps1"
    }
    if ($resolvedRunnerScript -and -not [System.IO.Path]::IsPathRooted($resolvedRunnerScript)) {
        $resolvedRunnerScript = Join-Path $projectRoot $resolvedRunnerScript
    }

    $resolvedInvocationConfigPath = if ($runtimeConfig -and $runtimeConfig.agentInvocationConfigPath) {
        [string]$runtimeConfig.agentInvocationConfigPath
    } else {
        "docs/agents/runtime/agent-invocation.json"
    }
    if ($resolvedInvocationConfigPath -and -not [System.IO.Path]::IsPathRooted($resolvedInvocationConfigPath)) {
        $resolvedInvocationConfigPath = Join-Path $projectRoot $resolvedInvocationConfigPath
    }

    $resolvedTemplate = if ($AgentCommandTemplate) {
        $AgentCommandTemplate
    } elseif ($runtimeConfig -and $runtimeConfig.agentCommandTemplate) {
        [string]$runtimeConfig.agentCommandTemplate
    } elseif (Test-Path $resolvedRunnerScript) {
        "powershell -NoProfile -File ""$resolvedRunnerScript"" -Agent {{agent}} -JobId {{job_id}} -ExecutionId {{execution_id}} -StepId {{step_id}} -GateId {{gate_id}} -DocsPath {{docs_path}} -HandoffPath {{handoff_path}} -OutputPath {{output_path}}"
    } else {
        ""
    }

    $resolvedStackAdapter = if ($StackAdapter) {
        $StackAdapter
    } elseif ($runtimeConfig -and $runtimeConfig.stackAdapter) {
        [string]$runtimeConfig.stackAdapter
    } else {
        "generic"
    }

    $resolvedTimeout = if ($AgentTimeoutSeconds -gt 0) {
        $AgentTimeoutSeconds
    } elseif ($runtimeConfig -and $runtimeConfig.agentTimeoutSeconds) {
        [int]$runtimeConfig.agentTimeoutSeconds
    } else {
        300
    }

    return @{
        manifest = $manifest
        manifest_path = $ManifestPath
        project_root = $projectRoot
        working_directory = $resolvedWorkingDirectory
        evidence_command_map_path = $resolvedEvidenceMap
        agent_runner_script_path = $resolvedRunnerScript
        agent_invocation_config_path = $resolvedInvocationConfigPath
        execution_mode = $resolvedMode
        agent_command_template = $resolvedTemplate
        stack_adapter = $resolvedStackAdapter
        agent_timeout_seconds = $resolvedTimeout
    }
}

function Write-SyntheticAgentOutput {
    param(
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][string]$Agent,
        [Parameter(Mandatory = $true)][string]$JobId,
        [Parameter(Mandatory = $true)][string]$ExecutionId,
        [Parameter(Mandatory = $true)][string]$StepId,
        [Parameter(Mandatory = $true)][string]$GateId
    )

    $directory = Split-Path $OutputPath -Parent
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    @{
        agent = $Agent
        job_id = $JobId
        execution_id = $ExecutionId
        step_id = $StepId
        gate_id = $GateId
        status = "success"
        status_reason = "synthetic execution completed"
        failure_type = "none"
        summary = "Synthetic agent execution completed."
        produced_outputs = @()
        changed_components = @()
        changed_contracts = @()
        changed_data_model = "none"
        decision_refs = @()
        evidence_refs = @()
        next_action = "continue"
        retryable = "no"
        human_in_loop_required = "no"
    } | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath
}

function Invoke-AgentExecution {
    param(
        [Parameter(Mandatory = $true)][string]$Agent,
        [Parameter(Mandatory = $true)][string]$JobId,
        [Parameter(Mandatory = $true)][string]$ExecutionId,
        [Parameter(Mandatory = $true)][string]$StepId,
        [string]$GateId = "none",
        [Parameter(Mandatory = $true)][string]$DocsPath,
        [Parameter(Mandatory = $true)][string]$HandoffPath,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [string]$ExecutionMode = "command",
        [string]$CommandTemplate = "",
        [string]$JobType = "",
        [string]$Scope = "",
        [string]$RiskLevel = "",
        [int]$TimeoutSeconds = 300
    )

    if ($ExecutionMode -eq "synthetic") {
        Write-SyntheticAgentOutput -OutputPath $OutputPath -Agent $Agent -JobId $JobId -ExecutionId $ExecutionId -StepId $StepId -GateId $GateId
        return @{
            ok = $true
            execution_mode = "synthetic"
            output_path = $OutputPath
            exit_code = 0
            stdout = "Synthetic output created."
            stderr = ""
            command = "synthetic"
            failure_type = "none"
        }
    }

    if (-not $CommandTemplate) {
        return @{
            ok = $false
            execution_mode = $ExecutionMode
            output_path = $OutputPath
            exit_code = 1004
            stdout = ""
            stderr = "Agent command template is not configured."
            command = ""
            failure_type = "insufficient_context"
        }
    }

    if (-not (Test-Path $WorkingDirectory)) {
        return @{
            ok = $false
            execution_mode = $ExecutionMode
            output_path = $OutputPath
            exit_code = 1005
            stdout = ""
            stderr = "Working directory not found: $WorkingDirectory"
            command = ""
            failure_type = "insufficient_context"
        }
    }

    function ConvertTo-ShellLiteral {
        param([string]$Value)
        return "'" + (($Value -replace "'", "''")) + "'"
    }

    $resolvedCommand = $CommandTemplate
    $tokens = @{
        "{{agent}}" = ConvertTo-ShellLiteral -Value $Agent
        "{{job_id}}" = ConvertTo-ShellLiteral -Value $JobId
        "{{execution_id}}" = ConvertTo-ShellLiteral -Value $ExecutionId
        "{{step_id}}" = ConvertTo-ShellLiteral -Value $StepId
        "{{gate_id}}" = ConvertTo-ShellLiteral -Value $GateId
        "{{docs_path}}" = ConvertTo-ShellLiteral -Value $DocsPath
        "{{handoff_path}}" = ConvertTo-ShellLiteral -Value $HandoffPath
        "{{output_path}}" = ConvertTo-ShellLiteral -Value $OutputPath
        "{{working_directory}}" = ConvertTo-ShellLiteral -Value $WorkingDirectory
        "{{job_type}}" = ConvertTo-ShellLiteral -Value $JobType
        "{{scope}}" = ConvertTo-ShellLiteral -Value $Scope
        "{{risk_level}}" = ConvertTo-ShellLiteral -Value $RiskLevel
    }
    foreach ($token in $tokens.Keys) {
        $resolvedCommand = $resolvedCommand.Replace($token, [string]$tokens[$token])
    }

    $hostCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $hostCmd) {
        $hostCmd = Get-Command powershell -ErrorAction SilentlyContinue
    }
    if (-not $hostCmd) {
        throw "PowerShell host not found for agent execution."
    }

    $job = Start-Job -ScriptBlock {
        param($shellExe, $wd, $cmd)
        Set-Location $wd
        $result = & $shellExe -NoProfile -Command $cmd 2>&1
        return @{
            output = ($result | Out-String)
            exit_code = $LASTEXITCODE
        }
    } -ArgumentList $hostCmd.Source, $WorkingDirectory, $resolvedCommand

    $finished = Wait-Job -Job $job -Timeout $TimeoutSeconds
    if (-not $finished) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue | Out-Null
        return @{
            ok = $false
            execution_mode = $ExecutionMode
            output_path = $OutputPath
            exit_code = 1003
            stdout = ""
            stderr = "Timed out after $TimeoutSeconds seconds."
            command = $resolvedCommand
            failure_type = "timeout"
        }
    }

    $result = Receive-Job -Job $job
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue | Out-Null
    $exitCode = if ($result -and $result.exit_code -ne $null) { [int]$result.exit_code } else { 1 }
    $stdout = if ($result -and $result.output) { [string]$result.output } else { "" }

    if (-not (Test-Path $OutputPath)) {
        return @{
            ok = $false
            execution_mode = $ExecutionMode
            output_path = $OutputPath
            exit_code = $exitCode
            stdout = $stdout.Trim()
            stderr = "Agent command completed without creating output file."
            command = $resolvedCommand
            failure_type = if ($exitCode -eq 0) { "missing_output" } else { "test_failure" }
        }
    }

    return @{
        ok = ($exitCode -eq 0)
        execution_mode = $ExecutionMode
        output_path = $OutputPath
        exit_code = $exitCode
        stdout = $stdout.Trim()
        stderr = ""
        command = $resolvedCommand
        failure_type = if ($exitCode -eq 0) { "none" } else { "test_failure" }
    }
}

Export-ModuleMember -Function @(
    "Resolve-OrchestrationRuntimeConfig",
    "Write-SyntheticAgentOutput",
    "Invoke-AgentExecution"
)
