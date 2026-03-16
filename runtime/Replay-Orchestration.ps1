<#
.SYNOPSIS
    Replays runtime events and writes a deterministic snapshot.
.PARAMETER DocsPath
    Path to docs/agents.
.PARAMETER ExecutionId
    Execution id to replay.
#>
param(
    [Parameter(Mandatory = $true)][string]$DocsPath,
    [Parameter(Mandatory = $true)][string]$ExecutionId
)

$ErrorActionPreference = "Stop"
Import-Module (Join-Path $PSScriptRoot "engine\EventStore.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "engine\StateMachine.psm1") -Force

$eventPath = Join-Path (Join-Path $DocsPath "runtime") "state-events.jsonl"
if (-not (Test-Path $eventPath)) {
    throw "Runtime event log not found: $eventPath"
}

$events = Get-StateEvents -EventPath $eventPath -ExecutionId $ExecutionId -Strict
if ($events.Count -eq 0) {
    throw "No events found for execution id: $ExecutionId"
}

[void](Test-ReplayTransitions -Events $events)
$state = Get-ReplayedState -EventPath $eventPath -ExecutionId $ExecutionId
if ($state.Count -eq 0) {
    throw "No events found for execution id: $ExecutionId"
}

$state["replay_validated"] = $true
$state["event_count"] = $events.Count
$state["event_schema_version"] = [int]$events[-1].event_schema_version

$snapshotPath = Join-Path (Join-Path $DocsPath "runtime") ("snapshot-{0}.json" -f $ExecutionId)
($state | ConvertTo-Json -Depth 10) | Set-Content -Path $snapshotPath
Write-Host "Replay snapshot written: $snapshotPath"
