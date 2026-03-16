<#
.SYNOPSIS
    Project-local agent runner invoked by @sef runtime.
.DESCRIPTION
    Resolves per-agent commands from docs/agents/runtime/agent-invocation.json or
    manifest runtime config, then runs the mapped command and expects the command
    to create the normalized agent output JSON at -OutputPath.
#>
param(
    [Parameter(Mandatory = $true)][string]$Agent,
    [Parameter(Mandatory = $true)][string]$JobId,
    [Parameter(Mandatory = $true)][string]$ExecutionId,
    [Parameter(Mandatory = $true)][string]$StepId,
    [Parameter(Mandatory = $true)][string]$GateId,
    [Parameter(Mandatory = $true)][string]$DocsPath,
    [Parameter(Mandatory = $true)][string]$HandoffPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path $PSScriptRoot -Parent
$manifestPath = Join-Path $projectRoot "agents.manifest.json"
$defaultConfigPath = Join-Path (Join-Path $DocsPath "runtime") "agent-invocation.json"

function Get-AgentInvocationConfig {
    if (Test-Path $manifestPath) {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        if ($manifest.orchestration -and $manifest.orchestration.runtime -and $manifest.orchestration.runtime.agentInvocationConfigPath) {
            $manifestConfigPath = [string]$manifest.orchestration.runtime.agentInvocationConfigPath
            if (-not [System.IO.Path]::IsPathRooted($manifestConfigPath)) {
                $manifestConfigPath = Join-Path $projectRoot $manifestConfigPath
            }
            if (Test-Path $manifestConfigPath) {
                return @{
                    manifest = $manifest
                    config = Get-Content $manifestConfigPath -Raw | ConvertFrom-Json
                }
            }
        }

        if ($manifest.orchestration -and $manifest.orchestration.runtime -and $manifest.orchestration.runtime.agentCommands) {
            return @{
                manifest = $manifest
                config = [pscustomobject]@{
                    agents = $manifest.orchestration.runtime.agentCommands
                }
            }
        }

        return @{
            manifest = $manifest
            config = $null
        }
    }

    if (Test-Path $defaultConfigPath) {
        return @{
            manifest = $null
            config = Get-Content $defaultConfigPath -Raw | ConvertFrom-Json
        }
    }

    return @{
        manifest = $null
        config = $null
    }
}

function Write-BlockedOutput {
    param(
        [string]$Reason
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
        status = "blocked"
        status_reason = $Reason
        failure_type = "insufficient_context"
        summary = "Agent command is not configured."
        produced_outputs = @()
        changed_components = @()
        changed_contracts = @()
        changed_data_model = "none"
        decision_refs = @()
        evidence_refs = @()
        next_action = "configure_agent_runner"
        retryable = "no"
        human_in_loop_required = "yes"
    } | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath
}

function Resolve-AgentCommand {
    param(
        [object]$Config
    )

    if ($null -eq $Config) {
        return $null
    }

    if ($Config.PSObject.Properties.Name -contains "agents") {
        $agents = $Config.agents
        if ($agents -and $agents.PSObject.Properties.Name -contains $Agent) {
            $agentEntry = $agents.$Agent
            if ($agentEntry -and $agentEntry.command) {
                return [string]$agentEntry.command
            }
        }
    }

    return $null
}

$runtimeConfig = Get-AgentInvocationConfig
$command = Resolve-AgentCommand -Config $runtimeConfig.config
if (-not $command) {
    Write-BlockedOutput -Reason "No command configured for $Agent. Update docs/agents/runtime/agent-invocation.json or manifest runtime agentCommands."
    exit 0
}

$tokens = @{
    "{{agent}}" = "'" + $Agent.Replace("'", "''") + "'"
    "{{job_id}}" = "'" + $JobId.Replace("'", "''") + "'"
    "{{execution_id}}" = "'" + $ExecutionId.Replace("'", "''") + "'"
    "{{step_id}}" = "'" + $StepId.Replace("'", "''") + "'"
    "{{gate_id}}" = "'" + $GateId.Replace("'", "''") + "'"
    "{{docs_path}}" = "'" + $DocsPath.Replace("'", "''") + "'"
    "{{handoff_path}}" = "'" + $HandoffPath.Replace("'", "''") + "'"
    "{{output_path}}" = "'" + $OutputPath.Replace("'", "''") + "'"
}
foreach ($token in $tokens.Keys) {
    $command = $command.Replace($token, $tokens[$token])
}

$hostCmd = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $hostCmd) {
    $hostCmd = Get-Command powershell -ErrorAction SilentlyContinue
}
if (-not $hostCmd) {
    throw "No PowerShell host found."
}

Set-Location $projectRoot
& $hostCmd.Source -NoProfile -Command $command
exit $LASTEXITCODE
