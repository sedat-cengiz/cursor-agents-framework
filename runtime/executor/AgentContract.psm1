Set-StrictMode -Version Latest

$script:AllowedFailureTypes = @(
    "none",
    "format_error",
    "missing_output",
    "logic_inconsistency",
    "architecture_violation",
    "test_failure",
    "security_risk",
    "insufficient_context",
    "timeout",
    "policy_violation"
)

function Test-HandoffReady {
    param(
        [Parameter(Mandatory = $true)][string]$HandoffPath
    )

    if (-not (Test-Path $HandoffPath)) { return $false }
    $content = Get-Content $HandoffPath -Raw
    $requiredSections = @(
        "## Is Ozeti",
        "## Bu Agent'in Gorevi",
        "## Kesinlesmis Kararlar",
        "## Teknik Baglam",
        "## Beklenen Cikti",
        "## Definition of Done"
    )
    foreach ($section in $requiredSections) {
        if ($content -notmatch [regex]::Escape($section)) {
            return $false
        }
    }
    return $true
}

function Test-AgentOutputContract {
    param(
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    if (-not (Test-Path $OutputPath)) {
        return @{ ok = $false; reason = "missing_output" }
    }

    try {
        $json = Get-Content $OutputPath -Raw | ConvertFrom-Json
    } catch {
        return @{ ok = $false; reason = "format_error" }
    }

    $required = @(
        "agent",
        "job_id",
        "execution_id",
        "step_id",
        "gate_id",
        "status",
        "status_reason",
        "failure_type",
        "summary",
        "produced_outputs",
        "changed_components",
        "changed_contracts",
        "changed_data_model",
        "decision_refs",
        "evidence_refs",
        "next_action",
        "retryable",
        "human_in_loop_required"
    )
    foreach ($f in $required) {
        if (-not $json.PSObject.Properties.Name.Contains($f)) {
            return @{ ok = $false; reason = "missing_output" }
        }
    }

    if ($json.status -notin @("success", "failed", "blocked")) {
        return @{ ok = $false; reason = "logic_inconsistency" }
    }

    if ($json.retryable -notin @("yes", "no")) {
        return @{ ok = $false; reason = "logic_inconsistency" }
    }

    if ($json.human_in_loop_required -notin @("yes", "no")) {
        return @{ ok = $false; reason = "logic_inconsistency" }
    }

    if ($json.failure_type -notin $script:AllowedFailureTypes) {
        return @{ ok = $false; reason = "logic_inconsistency" }
    }

    foreach ($arrayField in @("produced_outputs", "changed_components", "changed_contracts", "decision_refs", "evidence_refs")) {
        if ($json.$arrayField -eq $null) {
            return @{ ok = $false; reason = "missing_output" }
        }
        if (-not ($json.$arrayField -is [System.Array])) {
            return @{ ok = $false; reason = "format_error" }
        }
    }

    return @{ ok = $true; reason = "none" }
}

Export-ModuleMember -Function @(
    "Test-HandoffReady",
    "Test-AgentOutputContract"
)
