Set-StrictMode -Version Latest

function Get-NormalizedRequestText {
    param(
        [string]$UserRequest
    )

    if (-not $UserRequest) { return "" }
    return $UserRequest.Trim().ToLowerInvariant()
}

function Get-MatchedKeywordCount {
    param(
        [string]$Text,
        [string[]]$Keywords
    )

    $count = 0
    foreach ($keyword in $Keywords) {
        if ($Text -match [regex]::Escape($keyword.ToLowerInvariant())) {
            $count++
        }
    }
    return $count
}

function Resolve-RequestSummary {
    param(
        [string]$UserRequest
    )

    $trimmed = if ($UserRequest) { $UserRequest.Trim() } else { "" }
    if (-not $trimmed) { return "Bos kullanici istegi." }
    if ($trimmed.Length -le 140) { return $trimmed }
    return $trimmed.Substring(0, 140).Trim() + "..."
}

function Resolve-JobTypeFromRequest {
    param(
        [string]$UserRequest
    )

    $text = Get-NormalizedRequestText -UserRequest $UserRequest
    if (-not $text) { return "feature" }

    $keywordMap = @{
        bugfix = @("bug", "fix", "hata", "duzelt", "error", "exception", "regression", "broken", "sorun", "issue")
        refactor = @("refactor", "temizle", "cleanup", "ayir", "restructure", "katman", "modularize", "sadele")
        performance = @("performance", "optimiz", "slow", "latency", "throughput", "memory", "cpu")
        integration = @("integration", "entegrasyon", "erp", "webhook", "sync", "external api", "3rd party", "third party")
        "ux-ui" = @("ui", "ux", "tasarim", "design", "layout", "screen", "dashboard", "sayfa", "form")
        "devops-infra" = @("devops", "infra", "infrastructure", "docker", "kubernetes", "deploy", "pipeline", "ci/cd", "staging")
        research = @("research", "arastir", "compare", "benchmark", "spike", "investigate", "evaluate")
        feature = @("add", "ekle", "new", "yeni", "implement", "gelistir", "ozellik", "feature")
    }

    $bestType = "feature"
    $bestScore = -1
    foreach ($type in $keywordMap.Keys) {
        $score = Get-MatchedKeywordCount -Text $text -Keywords $keywordMap[$type]
        if ($score -gt $bestScore) {
            $bestType = $type
            $bestScore = $score
        }
    }

    return $bestType
}

function Resolve-ScopeFromRequest {
    param(
        [string]$UserRequest
    )

    $text = Get-NormalizedRequestText -UserRequest $UserRequest
    if (-not $text) { return "M" }

    if ($text -match "xl|bounded context|from scratch|greenfield|sifirdan|platform-wide|cross-system") {
        return "XL"
    }
    if ($text -match "frontend and backend|backend and frontend|api and ui|cross-layer|multi-layer|migration|multiple modules|birden fazla mod") {
        return "L"
    }
    if ($text -match "one file|tek dosya|small|minor|quick|hotfix|tiny") {
        return "S"
    }
    return "M"
}

function Resolve-RiskLevelFromRequest {
    param(
        [string]$UserRequest,
        [string]$JobType = "feature"
    )

    $text = Get-NormalizedRequestText -UserRequest $UserRequest
    if ($text -match "security|auth|permission|payment|prod|production|critical|kritik|data loss|migration rollback") {
        return "kritik"
    }
    if ($text -match "tenant|billing|privacy|compliance|customer facing|release|schema|database|rollback") {
        return "yuksek"
    }
    if ($JobType -in @("feature", "integration", "refactor")) {
        return "orta"
    }
    return "dusuk"
}

function Resolve-AffectedLayersFromRequest {
    param(
        [string]$UserRequest,
        [string]$JobType = "feature"
    )

    $text = Get-NormalizedRequestText -UserRequest $UserRequest
    $layers = @()

    $layerKeywords = @{
        UI = @("frontend", "ui", "ux", "react", "vue", "angular", "screen", "page", "component", "layout", "dashboard")
        API = @("backend", "api", "endpoint", "service", "controller", "handler", "application", "server")
        DB = @("database", "db", "sql", "migration", "schema", "table", "index", "query")
        Infra = @("infra", "devops", "docker", "kubernetes", "pipeline", "deploy", "staging", "helm")
        Security = @("security", "auth", "authorization", "permission", "jwt", "secret", "owasp")
    }

    foreach ($layer in $layerKeywords.Keys) {
        if ((Get-MatchedKeywordCount -Text $text -Keywords $layerKeywords[$layer]) -gt 0) {
            $layers += $layer
        }
    }

    if ($layers.Count -eq 0) {
        switch ($JobType) {
            "bugfix" { $layers += "API" }
            "refactor" { $layers += "API" }
            "ux-ui" { $layers += "UI" }
            "devops-infra" { $layers += "Infra" }
            default { $layers += @("API", "UI") }
        }
    }

    return $layers | Select-Object -Unique
}

function Resolve-AgentCandidatesFromRequest {
    param(
        [string]$JobType,
        [string[]]$AffectedLayers,
        [string]$Scope,
        [string]$RiskLevel,
        [string]$UserRequest
    )

    $agents = @("@sef")
    $text = Get-NormalizedRequestText -UserRequest $UserRequest

    if ($JobType -in @("feature", "integration")) {
        $agents += "@analist"
    }

    $needsArchitecture = ($JobType -in @("feature", "refactor", "integration")) -or ($Scope -in @("L", "XL")) -or ($text -match "contract|adr|architecture|mimari|schema|boundary|ddd")
    if ($needsArchitecture) {
        $agents += "@mimari"
    }

    if ($AffectedLayers -contains "API" -or $AffectedLayers -contains "DB" -or $JobType -in @("bugfix", "refactor", "performance")) {
        $agents += "@backend"
    }
    if ($AffectedLayers -contains "UI") {
        $agents += "@frontend"
    }
    if ($AffectedLayers -contains "Infra" -or $JobType -eq "devops-infra") {
        $agents += "@devops"
    }
    if ($AffectedLayers -contains "Security" -or $RiskLevel -in @("yuksek", "kritik")) {
        $agents += "@guvenlik"
    }

    if ($JobType -notin @("research")) {
        $agents += "@qa"
        $agents += "@review"
    }

    return $agents | Select-Object -Unique
}

function Resolve-ApprovalCheckpoints {
    param(
        [string]$JobType,
        [string]$Scope,
        [string]$RiskLevel
    )

    $planRequired = ($JobType -in @("feature", "refactor", "integration", "devops-infra")) -or ($Scope -in @("L", "XL")) -or ($RiskLevel -in @("yuksek", "kritik"))
    $releaseRequired = $true

    return @{
        plan = if ($planRequired) { "required" } else { "not_required" }
        release = if ($releaseRequired) { "required" } else { "not_required" }
    }
}

function New-RequestIntake {
    param(
        [Parameter(Mandatory = $true)][string]$UserRequest,
        [string]$JobType = "",
        [string]$Scope = "",
        [string]$RiskLevel = ""
    )

    $resolvedJobType = if ($JobType) { $JobType } else { Resolve-JobTypeFromRequest -UserRequest $UserRequest }
    $resolvedScope = if ($Scope) { $Scope } else { Resolve-ScopeFromRequest -UserRequest $UserRequest }
    $resolvedRisk = if ($RiskLevel) { $RiskLevel } else { Resolve-RiskLevelFromRequest -UserRequest $UserRequest -JobType $resolvedJobType }
    $affectedLayers = Resolve-AffectedLayersFromRequest -UserRequest $UserRequest -JobType $resolvedJobType
    $approvalCheckpoints = Resolve-ApprovalCheckpoints -JobType $resolvedJobType -Scope $resolvedScope -RiskLevel $resolvedRisk
    $candidateAgents = Resolve-AgentCandidatesFromRequest -JobType $resolvedJobType -AffectedLayers $affectedLayers -Scope $resolvedScope -RiskLevel $resolvedRisk -UserRequest $UserRequest

    return @{
        request_summary = Resolve-RequestSummary -UserRequest $UserRequest
        raw_request = $UserRequest.Trim()
        job_type = $resolvedJobType
        scope = $resolvedScope
        risk_level = $resolvedRisk
        affected_layers = $affectedLayers
        candidate_agents = $candidateAgents
        approval_checkpoints = $approvalCheckpoints
    }
}

Export-ModuleMember -Function @(
    "Resolve-JobTypeFromRequest",
    "Resolve-ScopeFromRequest",
    "Resolve-RiskLevelFromRequest",
    "Resolve-AffectedLayersFromRequest",
    "Resolve-AgentCandidatesFromRequest",
    "Resolve-ApprovalCheckpoints",
    "New-RequestIntake"
)
