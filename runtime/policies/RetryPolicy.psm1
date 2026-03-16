Set-StrictMode -Version Latest

function Get-RetryLimitForRisk {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("dusuk","orta","yuksek","kritik")][string]$RiskLevel
    )

    switch ($RiskLevel) {
        "dusuk" { return 2 }
        "orta" { return 1 }
        "yuksek" { return 0 }
        "kritik" { return 0 }
        default { return 0 }
    }
}

function Get-FailureAction {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("format_error","missing_output","logic_inconsistency","architecture_violation","test_failure","security_risk","insufficient_context","timeout","policy_violation")][string]$FailureType,
        [Parameter(Mandatory = $true)][ValidateSet("dusuk","orta","yuksek","kritik")][string]$RiskLevel,
        [Parameter(Mandatory = $true)][int]$FailureCountCurrentStage,
        [Parameter(Mandatory = $true)][int]$FailureCountTotal
    )

    $retryLimit = Get-RetryLimitForRisk -RiskLevel $RiskLevel
    $retryAllowed = $FailureCountCurrentStage -lt $retryLimit

    $action = "retry"
    $escalationRequired = "no"
    $humanInLoopRequired = "no"

    if ($FailureType -eq "security_risk" -or $FailureType -eq "policy_violation") {
        $action = "hard_stop"
        $retryAllowed = $false
        $escalationRequired = "yes"
        $humanInLoopRequired = "yes"
    } elseif ($FailureType -eq "timeout") {
        $action = if ($retryAllowed) { "retry" } else { "escalate" }
        if (-not $retryAllowed) {
            $escalationRequired = "yes"
        }
    } elseif ($FailureType -eq "architecture_violation" -and $RiskLevel -in @("yuksek","kritik")) {
        $action = "hard_stop"
        $retryAllowed = $false
        $escalationRequired = "yes"
        $humanInLoopRequired = "yes"
    } elseif ($FailureType -eq "insufficient_context") {
        $action = "ask_user"
        $retryAllowed = $false
        $escalationRequired = "yes"
        $humanInLoopRequired = "yes"
    } elseif ($FailureCountTotal -ge 3) {
        $action = "hard_stop"
        $retryAllowed = $false
        $escalationRequired = "yes"
        $humanInLoopRequired = "yes"
    } elseif (-not $retryAllowed) {
        $action = "escalate"
        $escalationRequired = "yes"
        $humanInLoopRequired = if ($RiskLevel -in @("yuksek","kritik")) { "yes" } else { "no" }
    }

    return @{
        action = $action
        retry_limit = $retryLimit
        retry_allowed = if ($retryAllowed) { "yes" } else { "no" }
        escalation_required = $escalationRequired
        human_in_loop_required = $humanInLoopRequired
    }
}

Export-ModuleMember -Function @(
    "Get-RetryLimitForRisk",
    "Get-FailureAction"
)
