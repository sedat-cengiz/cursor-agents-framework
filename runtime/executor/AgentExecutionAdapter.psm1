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

# MINI GATE CHECK - Direct Mode Quality Control
# When agents are called directly (not through @sef orchestrator)

function Test-DirectModeGateCompliance {
    param(
        [Parameter(Mandatory = $true)][string]$Agent,
        [Parameter(Mandatory = $true)][string]$DocsPath,
        [string]$StrictMode = "warn"  # "warn", "enforce", "off"
    )
    
    # Agents that require G5/G5 compliance even in direct mode
    $qualityRequiringAgents = @("@backend", "@frontend", "@qa", "@review")
    
    if ($Agent -notin $qualityRequiringAgents) {
        return @{ 
            compliant = $true
            warnings = @()
            requiresMiniG5 = $false
            requiresMiniG6 = $false
        }
    }
    
    $warnings = @()
    $requiresMiniG5 = $true
    $requiresMiniG6 = $true
    
    # Check if orchestrator state exists (meaning we're in orchestrated mode)
    $statePath = Join-Path $DocsPath "workflow-state.md"
    $orchestratedMode = Test-Path $statePath
    
    if ($orchestratedMode) {
        # Check if G5 and G6 have been completed in the state
        $stateContent = Get-Content $statePath -Raw -ErrorAction SilentlyContinue
        if ($stateContent -match "G5.*?(passed|geçti|tamamlandı)") {
            $requiresMiniG5 = $false
        }
        if ($stateContent -match "G6.*?(passed|geçti|tamamlandı)") {
            $requiresMiniG6 = $false
        }
    }
    
    if ($requiresMiniG5 -or $requiresMiniG6) {
        $warnings += "⚠️ DİREKT MOD: @sef (orkestratör) kullanılmıyor. Kalite kapıları manuel takip edilmeli."
        
        if ($requiresMiniG5) {
            $warnings += "   → G5 Test Kapısı: `@qa` çağrılarak test coverage > %90 sağlanmalı"
        }
        
        if ($requiresMiniG6) {
            $warnings += "   → G6 Review Kapısı: `@review` çağrılarak kod incelemesi yapılmalı"
        }
        
        $warnings += "   → Self-review checklist: Her task sonunda geliştirici kontrol listesi doldurulmalı"
        $warnings += "   → Öneri: Production işleri için `@sef 'iş tanımı'` formatında çalışın"
    }
    
    # Strict mode enforcement
    if ($StrictMode -eq "enforce" -and ($requiresMiniG5 -or $requiresMiniG6)) {
        return @{
            compliant = $false
            warnings = $warnings
            requiresMiniG5 = $requiresMiniG5
            requiresMiniG6 = $requiresMiniG6
            action = "stop"
            message = "STRICT MODE: Direkt modda çalışma engellendi. `@sef` orkestratörü kullanın."
        }
    }
    
    return @{
        compliant = ($warnings.Count -eq 0)
        warnings = $warnings
        requiresMiniG5 = $requiresMiniG5
        requiresMiniG6 = $requiresMiniG6
        action = if ($StrictMode -eq "warn") { "warn" } else { "continue" }
        message = if ($warnings.Count -gt 0) { $warnings -join "`n" } else { "OK" }
    }
}

function Write-MiniGateReport {
    param(
        [Parameter(Mandatory = $true)][string]$DocsPath,
        [Parameter(Mandatory = $true)][string]$Agent,
        [Parameter(Mandatory = $true)][hashtable]$GateCheck
    )
    
    $reportDir = Join-Path $DocsPath "quality-gates"
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $reportFile = "mini-gate-$Agent-$timestamp.md"
    $reportPath = Join-Path $reportDir $reportFile
    
    $complianceStatus = if ($GateCheck.compliant) { "✅ Uyumlu" } else { "⚠️ Uyarı" }
    $modeStatus = if ($GateCheck.requiresMiniG5 -or $GateCheck.requiresMiniG6) { "Direkt Mod (Orkestratör Dışı)" } else { "Orkestratör Modu" }
    
    $doc = @(
        "# Mini Gate Report — Direct Mode Quality Check",
        "",
        "---",
        "",
        "## Metadata",
        "",
        "- **agent:** $Agent",
        "- **timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
        "- **mode:** $modeStatus",
        "- **compliance:** $complianceStatus",
        "",
        "---",
        "",
        "## G5 Test Kapısı (Mini)",
        "",
        "- **required:** $(if ($GateCheck.requiresMiniG5) { 'Evet' } else { 'Hayır (Orkestratör tarafından yönetiliyor)' })",
        "- **status:** $(if ($GateCheck.requiresMiniG5) { '⬜ BEKLİYOR — @qa çağrılmalı' } else { '✅ Tamamlandı veya orkestratör modu' })",
        "",
        "---",
        "",
        "## G6 Review Kapısı (Mini)",
        "",
        "- **required:** $(if ($GateCheck.requiresMiniG6) { 'Evet' } else { 'Hayır (Orkestratör tarafından yönetiliyor)' })",
        "- **status:** $(if ($GateCheck.requiresMiniG6) { '⬜ BEKLİYOR — @review çağrılmalı' } else { '✅ Tamamlandı veya orkestratör modu' })",
        "",
        "---",
        "",
        "## Uyarılar",
        ""
    )
    
    if ($GateCheck.warnings.Count -gt 0) {
        foreach ($warning in $GateCheck.warnings) {
            $doc += "- $warning"
        }
    } else {
        $doc += "- Yok"
    }
    
    $doc += @(
        "",
        "---",
        "",
        "## Sonraki Adımlar",
        "",
        "1. Eğer direkt modda çalışılıyorsa:",
        "   - `@qa '[TASK] için testler yaz'` — Unit ve integration testleri",
        "   - `@review '[TASK] için review yap'` — Kod incelemesi",
        "",
        "2. Eğer orkestratör modunda çalışılıyorsa:",
        "   - Kalite kapıları otomatik olarak `@sef` tarafından yönetilir",
        "",
        "---",
        "",
        "## Strict Mode Notu",
        "",
        "> Framework, direkt modda G5/G6 kapılarından geçmeden kod yazılmasına izin verir,",
        "> ancak bu durum proje büyüdükçe teknik borç biriktirir.",
        "> Strict mode aktif edildiğinde, direkt modda çalışma engellenebilir."
    )
    
    Set-Content -Path $reportPath -Value $doc
    
    return "docs/agents/quality-gates/$reportFile"
}

# AUTO-FOLLOWUP — Automatic QA/Review Chain
# Automatically triggers @qa and @review after backend/frontend tasks

function Test-AutoFollowupEnabled {
    param(
        [string]$DocsPath,
        [string]$Agent,
        [hashtable]$RuntimeConfig = @{}
    )
    
    # Only backend and frontend trigger auto-followup
    $autoFollowupAgents = @("@backend", "@frontend")
    if ($Agent -notin $autoFollowupAgents) {
        return @{ enabled = $false; reason = "Agent not in auto-followup list" }
    }
    
    # Check runtime config
    if ($RuntimeConfig.autoQualityChain -eq $true -or 
        $RuntimeConfig.autoQA -eq $true -or 
        $RuntimeConfig.autoReview -eq $true) {
        return @{ enabled = $true; mode = "runtime_config" }
    }
    
    # Check manifest
    $manifestPath = Join-Path $DocsPath "../../agents.manifest.json"
    if (Test-Path $manifestPath) {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        if ($manifest.orchestration.runtime.autoQualityChain -eq $true) {
            return @{ enabled = $true; mode = "manifest" }
        }
    }
    
    # Check for auto flag in agent output
    return @{ enabled = $false; reason = "Auto-followup not enabled" }
}

function Invoke-AutoFollowupChain {
    param(
        [Parameter(Mandatory = $true)][string]$Agent,
        [Parameter(Mandatory = $true)][string]$JobId,
        [Parameter(Mandatory = $true)][string]$ExecutionId,
        [Parameter(Mandatory = $true)][string]$DocsPath,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][hashtable]$ParentStep,
        [string]$CommandTemplate = "",
        [int]$TimeoutSeconds = 300,
        [int]$MaxLoopCount = 3
    )
    
    $results = @{
        qa_invoked = $false
        review_invoked = $false
        qa_success = $false
        review_success = $false
        loop_count = 0
        final_status = "unknown"
    }
    
    Write-Host "`n🤖 AUTO-FOLLOWUP: Starting quality chain for $Agent..." -ForegroundColor Cyan
    
    # Step 1: Auto-invoke @qa
    Write-Host "[AUTO] Step 1: Invoking @qa for test coverage..." -ForegroundColor Yellow
    
    $qaStepId = "qa-auto-$(Get-Date -Format 'HHmmss')"
    $qaOutputPath = Join-Path $DocsPath "agent-outputs/qa-$JobId-$qaStepId.json"
    $qaHandoffPath = Join-Path $DocsPath "handoffs/handoff-$JobId-qa-$qaStepId.md"
    
    # Write QA handoff
    $taskName = $ParentStep.task -replace '"', '\"'
    $qaHandoff = @(
        "# Handoff: Auto-Followup → @qa",
        "",
        "**Job:** $JobId | **Triggered by:** $Agent",
        "**Task:** AUTO-QA-$qaStepId",
        "**Execution:** $ExecutionId",
        "",
        "## Auto-Generated Task",
        "",
        "Write unit and integration tests for: $taskName",
        "",
        "## Requirements",
        "- Coverage target: > 90% (Domain + Application) for backend, > 80% (Components) for frontend",
        "- Test all business rules and edge cases",
        "- Ensure all tests pass",
        "",
        "## Evidence Required",
        "- test_status: verified",
        "- coverage_status: verified with percentage",
        "",
        "**This task was auto-generated by the quality chain.**"
    ) -join "`n"
    
    Set-Content -Path $qaHandoffPath -Value $qaHandoff
    
    # Invoke QA agent
    $qaResult = Invoke-AgentExecution `
        -Agent "@qa" `
        -JobId $JobId `
        -ExecutionId $ExecutionId `
        -StepId $qaStepId `
        -GateId "G5" `
        -DocsPath $DocsPath `
        -HandoffPath $qaHandoffPath `
        -OutputPath $qaOutputPath `
        -WorkingDirectory $WorkingDirectory `
        -ExecutionMode "command" `
        -CommandTemplate $CommandTemplate `
        -TimeoutSeconds $TimeoutSeconds
    
    $results.qa_invoked = $true
    $results.qa_success = $qaResult.ok
    
    if (-not $qaResult.ok) {
        Write-Host "[AUTO] ❌ @qa failed. Stopping quality chain." -ForegroundColor Red
        $results.final_status = "qa_failed"
        return $results
    }
    
    # Check coverage from QA output
    $qaOutput = Get-Content $qaOutputPath -Raw | ConvertFrom-Json
    $coverageStatus = $qaOutput.evidence_status.coverage_status
    
    if ($coverageStatus -ne "verified") {
        Write-Host "[AUTO] ⚠️ Coverage not verified. Quality chain incomplete." -ForegroundColor Yellow
        $results.final_status = "coverage_insufficient"
        return $results
    }
    
    Write-Host "[AUTO] ✅ @qa completed successfully (coverage verified)" -ForegroundColor Green
    
    # Step 2: Auto-invoke @review
    Write-Host "[AUTO] Step 2: Invoking @review for code review..." -ForegroundColor Yellow
    
    $reviewStepId = "review-auto-$(Get-Date -Format 'HHmmss')"
    $reviewOutputPath = Join-Path $DocsPath "agent-outputs/review-$JobId-$reviewStepId.json"
    $reviewHandoffPath = Join-Path $DocsPath "handoffs/handoff-$JobId-review-$reviewStepId.md"
    
    # Write Review handoff
    $reviewHandoff = @(
        "# Handoff: Auto-Followup → @review",
        "",
        "**Job:** $JobId | **Triggered by:** $Agent",
        "**Task:** AUTO-REVIEW-$reviewStepId",
        "**Execution:** $ExecutionId",
        "",
        "## Auto-Generated Task",
        "",
        "Perform 360° code review for: $taskName",
        "",
        "## Context",
        "- G5 Test Gate: PASSED (tests written and coverage verified)",
        "- QA Output: $qaOutputPath",
        "",
        "## Review Requirements",
        "- Design, Functionality, Security, Performance",
        "- Tests quality and coverage",
        "- Type safety and best practices",
        "",
        "## Output",
        "- MUST-FIX items (if any)",
        "- Review approval status",
        "",
        "**This task was auto-generated by the quality chain.**"
    ) -join "`n"
    
    Set-Content -Path $reviewHandoffPath -Value $reviewHandoff
    
    # Invoke Review agent
    $reviewResult = Invoke-AgentExecution `
        -Agent "@review" `
        -JobId $JobId `
        -ExecutionId $ExecutionId `
        -StepId $reviewStepId `
        -GateId "G6" `
        -DocsPath $DocsPath `
        -HandoffPath $reviewHandoffPath `
        -OutputPath $reviewOutputPath `
        -WorkingDirectory $WorkingDirectory `
        -ExecutionMode "command" `
        -CommandTemplate $CommandTemplate `
        -TimeoutSeconds $TimeoutSeconds
    
    $results.review_invoked = $true
    $results.review_success = $reviewResult.ok
    
    if (-not $reviewResult.ok) {
        Write-Host "[AUTO] ❌ @review failed. Quality chain incomplete." -ForegroundColor Red
        $results.final_status = "review_failed"
        return $results
    }
    
    # Check for MUST-FIX items
    $reviewOutput = Get-Content $reviewOutputPath -Raw | ConvertFrom-Json
    $hasMustFix = $reviewOutput.must_fix_count -gt 0 -or 
                   ($reviewOutput.review_status -eq "approved" -and $reviewOutput.must_fix_items)
    
    # SEMI-AUTOMATIC FIX LOOP (Mode B)
    $fixLoopCount = 0
    while ($hasMustFix -and $fixLoopCount -lt $MaxLoopCount) {
        $fixLoopCount++
        $results.loop_count = $fixLoopCount
        
        Write-Host "`n[AUTO-FIX] Loop $fixLoopCount/$MaxLoopCount: MUST-FIX items found. Auto-invoking $Agent for fixes..." -ForegroundColor Magenta
        
        # Extract MUST-FIX items from review output
        $mustFixItems = @()
        if ($reviewOutput.must_fix_items) {
            $mustFixItems = $reviewOutput.must_fix_items
        } elseif ($reviewOutput.review_comments) {
            $mustFixItems = $reviewOutput.review_comments | Where-Object { $_.type -eq "MUST-FIX" } | ForEach-Object { $_.message }
        }
        
        if ($mustFixItems.Count -eq 0) {
            $mustFixItems = @("Review identified issues that need to be addressed")
        }
        
        Write-Host "[AUTO-FIX] MUST-FIX Items ($($mustFixItems.Count) found):" -ForegroundColor Yellow
        $mustFixItems | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
        
        # Step 3: Auto-invoke @backend/@frontend for fixes
        $fixStepId = "fix-auto-$fixLoopCount-$(Get-Date -Format 'HHmmss')"
        $fixOutputPath = Join-Path $DocsPath "agent-outputs/$($Agent.TrimStart('@'))-$JobId-fix-$fixStepId.json"
        $fixHandoffPath = Join-Path $DocsPath "handoffs/handoff-$JobId-$($Agent.TrimStart('@'))-fix-$fixStepId.md"
        
        # Write Fix handoff with MUST-FIX items
        $fixHandoffLines = @(
            "# Handoff: Auto-Fix Loop → $Agent",
            "",
            "**Job:** $JobId | **Fix Loop:** $fixLoopCount/$MaxLoopCount",
            "**Task:** AUTO-FIX-$fixStepId",
            "**Execution:** $ExecutionId",
            "",
            "## Context",
            "- Original Task: $($ParentStep.task)",
            "- @review found MUST-FIX items that need to be addressed",
            "- Review Output: $reviewOutputPath",
            "",
            "## MUST-FIX Items (Auto-Detected)",
            ""
        )
        
        $itemNumber = 1
        foreach ($item in $mustFixItems) {
            $fixHandoffLines += "$itemNumber. $item"
            $itemNumber++
        }
        
        $fixHandoffLines += @(
            "",
            "## Fix Requirements",
            "- Address ALL MUST-FIX items listed above",
            "- Do NOT change functionality beyond what's needed for fixes",
            "- Ensure tests still pass after fixes",
            "- Re-run self-review checklist",
            "",
            "## Definition of Done",
            "- [ ] All MUST-FIX items resolved",
            "- [ ] Code compiles/builds successfully",
            "- [ ] Tests pass (if existing)",
            "- [ ] Ready for re-review",
            "",
            "**This task was auto-generated by the quality chain to address MUST-FIX items.**"
        )
        
        $fixHandoff = $fixHandoffLines -join "`n"
        Set-Content -Path $fixHandoffPath -Value $fixHandoff
        
        Write-Host "[AUTO-FIX] Invoking $Agent to fix MUST-FIX items..." -ForegroundColor Cyan
        
        # Invoke the original agent (backend/frontend) for fixes
        $fixResult = Invoke-AgentExecution `
            -Agent $Agent `
            -JobId $JobId `
            -ExecutionId $ExecutionId `
            -StepId "fix-$fixStepId" `
            -GateId "G4" `
            -DocsPath $DocsPath `
            -HandoffPath $fixHandoffPath `
            -OutputPath $fixOutputPath `
            -WorkingDirectory $WorkingDirectory `
            -ExecutionMode "command" `
            -CommandTemplate $CommandTemplate `
            -TimeoutSeconds $TimeoutSeconds
        
        if (-not $fixResult.ok) {
            Write-Host "[AUTO-FIX] ❌ $Agent failed to apply fixes. Stopping auto-fix loop." -ForegroundColor Red
            $results.final_status = "fix_failed"
            return $results
        }
        
        Write-Host "[AUTO-FIX] ✅ $Agent completed fixes. Re-running @review..." -ForegroundColor Green
        
        # Step 4: Re-invoke @review to verify fixes
        $reReviewStepId = "review-auto-fix$fixLoopCount-$(Get-Date -Format 'HHmmss')"
        $reReviewOutputPath = Join-Path $DocsPath "agent-outputs/review-$JobId-rereview-$reReviewStepId.json"
        $reReviewHandoffPath = Join-Path $DocsPath "handoffs/handoff-$JobId-review-rereview-$reReviewStepId.md"
        
        $reReviewHandoff = @(
            "# Handoff: Re-Review After Fixes → @review",
            "",
            "**Job:** $JobId | **Fix Loop:** $fixLoopCount/$MaxLoopCount",
            "**Task:** AUTO-RE-REVIEW-$reReviewStepId",
            "**Execution:** $ExecutionId",
            "",
            "## Context",
            "- Previous Review: $reviewOutputPath",
            "- Fixes Applied By: $Agent",
            "- Fix Output: $fixOutputPath",
            "",
            "## Task",
            "Re-review the code to verify that ALL previous MUST-FIX items have been resolved.",
            "",
            "## Focus Areas",
            "- Check that each MUST-FIX item is properly addressed",
            "- Ensure no new issues were introduced",
            "- Verify tests still pass",
            "",
            "## Output",
            "- MUST-FIX items status (resolved/pending)",
            "- Any NEW issues found",
            "- Final approval status",
            "",
            "**This is a re-review after auto-fix loop $fixLoopCount.**"
        ) -join "`n"
        
        Set-Content -Path $reReviewHandoffPath -Value $reReviewHandoff
        
        Write-Host "[AUTO-FIX] Re-invoking @review to verify fixes..." -ForegroundColor Cyan
        
        $reReviewResult = Invoke-AgentExecution `
            -Agent "@review" `
            -JobId $JobId `
            -ExecutionId $ExecutionId `
            -StepId "rereview-$reReviewStepId" `
            -GateId "G6" `
            -DocsPath $DocsPath `
            -HandoffPath $reReviewHandoffPath `
            -OutputPath $reReviewOutputPath `
            -WorkingDirectory $WorkingDirectory `
            -ExecutionMode "command" `
            -CommandTemplate $CommandTemplate `
            -TimeoutSeconds $TimeoutSeconds
        
        if (-not $reReviewResult.ok) {
            Write-Host "[AUTO-FIX] ❌ Re-review failed. Stopping auto-fix loop." -ForegroundColor Red
            $results.final_status = "rereview_failed"
            return $results
        }
        
        # Check if MUST-FIX items remain after fixes
        $reReviewOutput = Get-Content $reReviewOutputPath -Raw | ConvertFrom-Json
        $hasMustFix = $reReviewOutput.must_fix_count -gt 0 -or 
                       ($reReviewOutput.review_status -eq "approved" -and $reReviewOutput.must_fix_items)
        
        if ($hasMustFix) {
            Write-Host "[AUTO-FIX] ⚠️ MUST-FIX items still remain after fix loop $fixLoopCount." -ForegroundColor Yellow
            $reviewOutput = $reReviewOutput
            $reviewOutputPath = $reReviewOutputPath
        } else {
            Write-Host "[AUTO-FIX] ✅ All MUST-FIX items resolved after fix loop $fixLoopCount!" -ForegroundColor Green
            break
        }
    }
    
    # Final check after fix loops
    if ($hasMustFix) {
        if ($fixLoopCount -ge $MaxLoopCount) {
            Write-Host "`n[AUTO-FIX] ⛔ Maximum fix loops ($MaxLoopCount) reached. MUST-FIX items still remain." -ForegroundColor Red
            Write-Host "[AUTO-FIX] Manual intervention required. Please review and fix remaining issues." -ForegroundColor Red
            $results.final_status = "max_fix_loops_reached"
            $results.remaining_must_fix = $true
            return $results
        }
    }
    
    Write-Host "[AUTO] ✅ @review completed successfully (no MUST-FIX)" -ForegroundColor Green
    
    # Success!
    $results.final_status = "success"
    $results.fix_loops_executed = $fixLoopCount
    Write-Host "`n🎉 AUTO-FOLLOWUP: Quality chain completed successfully!" -ForegroundColor Green
    Write-Host "   G5 Test: ✅ | G6 Review: ✅" -ForegroundColor Green
    if ($fixLoopCount -gt 0) {
        Write-Host "   Auto-Fix Loops: $fixLoopCount ✅" -ForegroundColor Green
    }
    
    return $results
}

function Write-AutoFollowupReport {
    param(
        [Parameter(Mandatory = $true)][string]$DocsPath,
        [Parameter(Mandatory = $true)][string]$Agent,
        [Parameter(Mandatory = $true)][hashtable]$Results,
        [string]$JobId = ""
    )
    
    # Extract JobId from Results if not provided
    if (-not $JobId -and $Results.JobId) {
        $JobId = $Results.JobId
    }
    if (-not $JobId) {
        $JobId = "unknown"
    }
    
    $reportDir = Join-Path $DocsPath "quality-gates"
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $reportFile = "auto-followup-$Agent-$timestamp.md"
    $reportPath = Join-Path $reportDir $reportFile
    
    $statusEmoji = switch ($Results.final_status) {
        "success" { "✅" }
        "qa_failed" { "❌" }
        "review_failed" { "❌" }
        "coverage_insufficient" { "⚠️" }
        "must_fix_found" { "⚠️" }
        "fix_failed" { "❌" }
        "rereview_failed" { "❌" }
        "max_fix_loops_reached" { "⛔" }
        default { "❓" }
    }
    
    $doc = @(
        "# Auto-Followup Quality Chain Report",
        "",
        "---",
        "",
        "## Metadata",
        "",
        "- **agent:** $Agent",
        "- **timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
        "- **final_status:** $statusEmoji $($Results.final_status)",
        "",
        "---",
        "",
        "## Quality Chain Steps",
        "",
        "### Step 1: @qa (Test Coverage)",
        "- **invoked:** $(if ($Results.qa_invoked) { '✅ Yes' } else { '❌ No' })",
        "- **success:** $(if ($Results.qa_success) { '✅ Yes' } else { '❌ No' })",
        "",
        "### Step 2: @review (Code Review)",
        "- **invoked:** $(if ($Results.review_invoked) { '✅ Yes' } else { '❌ No' })",
        "- **success:** $(if ($Results.review_success) { '✅ Yes' } else { '❌ No' })",
        "",
        "---",
        "",
        "## Summary",
        ""
    )
    
    switch ($Results.final_status) {
        "success" {
            $doc += @(
                "✅ **Quality chain completed successfully!**",
                "",
                "All quality gates passed:",
                "- G5 Test: Coverage verified by @qa",
                "- G6 Review: Approved by @review (no MUST-FIX items)"
            )
        }
        "qa_failed" {
            $doc += @(
                "❌ **Quality chain stopped at @qa.**",
                "",
                "Test writing failed. Manual intervention required.",
                "",
                "### Suggested Actions",
                "1. Check @qa output for failure reason",
                "2. Retry with clearer requirements",
                "3. Or manually write tests"
            )
        }
        "coverage_insufficient" {
            $doc += @(
                "⚠️ **Quality chain incomplete: Coverage insufficient.**",
                "",
                "@qa completed but coverage target not met.",
                "",
                "### Suggested Actions",
                "1. Ask @qa to improve coverage",
                "2. Check which areas are uncovered",
                "3. Add missing tests"
            )
        }
        "review_failed" {
            $doc += @(
                "❌ **Quality chain stopped at @review.**",
                "",
                "Code review failed. Manual intervention required.",
                "",
                "### Suggested Actions",
                "1. Check @review output for failure reason",
                "2. Address review findings",
                "3. Request re-review"
            )
        }
        "must_fix_found" {
            $doc += @(
                "⚠️ **Quality chain: MUST-FIX items found.**",
                "",
                "@review completed but identified critical issues.",
                "",
                "### Next Steps",
                "1. Return to $Agent to fix MUST-FIX items",
                "2. Re-run quality chain",
                "3. Continue until no MUST-FIX remains"
            )
        }
        "fix_failed" {
            $doc += @(
                "❌ **Auto-fix failed.**",
                "",
                "$Agent could not apply the MUST-FIX items automatically.",
                "",
                "### Next Steps",
                "1. Manually review the MUST-FIX items",
                "2. Apply fixes manually",
                "3. Re-run the quality chain"
            )
        }
        "rereview_failed" {
            $doc += @(
                "❌ **Re-review failed.**",
                "",
                "The re-review after fixes could not be completed.",
                "",
                "### Next Steps",
                "1. Check the re-review handoff and output files",
                "2. Address any technical issues",
                "3. Manually trigger a new review"
            )
        }
        "max_fix_loops_reached" {
            $doc += @(
                "⛔ **Maximum auto-fix loops reached.**",
                "",
                "MUST-FIX items still remain after $($Results.loop_count) auto-fix attempts.",
                "",
                "### Next Steps",
                "1. **Manual intervention required**",
                "2. Review remaining MUST-FIX items",
                "3. Apply complex fixes manually",
                "4. Re-run quality chain when ready"
            )
        }
        default {
            $doc += @(
                "❓ **Quality chain status unknown.**",
                "",
                "Please check individual agent outputs for details."
            )
        }
    }
    
    $doc += @(
        "",
        "---",
        "",
        "## Loop Information",
        "",
        "- **total_loops:** $($Results.loop_count)",
        "- **fix_loops_executed:** $(if ($Results.fix_loops_executed) { $Results.fix_loops_executed } else { '0' })",
        "- **max_loops:** 3 (prevents infinite cycles)",
        "",
        "### Mode: B (Semi-Automatic)",
        "This quality chain uses **Yarı-Otomatik** mode:",
        "- MUST-FIX items are automatically detected by @review",
        "- @backend/@frontend is auto-invoked to apply fixes",
        "- @review re-checks after each fix loop",
        "- Max 3 loops to prevent infinite cycles",
        "",
        "---",
        "",
        "## Evidence References",
        "",
        "- QA Output: `docs/agents/agent-outputs/qa-$JobId-*.json`",
        "- Review Output: `docs/agents/agent-outputs/review-$JobId-*.json`",
        "- Fix Outputs: `docs/agents/agent-outputs/$($Agent.TrimStart('@'))-$JobId-fix-*.json`",
        "- Re-Review Outputs: `docs/agents/agent-outputs/review-$JobId-rereview-*.json`",
        "- Handoffs: `docs/agents/handoffs/handoff-$JobId-*.md`",
        "",
        "---",
        "",
        "> This report was auto-generated by the quality chain system."
    )
    
    Set-Content -Path $reportPath -Value ($doc -join "`n")
    
    return "docs/agents/quality-gates/$reportFile"
}

Export-ModuleMember -Function @(
    "Resolve-OrchestrationRuntimeConfig",
    "Write-SyntheticAgentOutput",
    "Invoke-AgentExecution",
    "Test-DirectModeGateCompliance",
    "Write-MiniGateReport",
    "Test-AutoFollowupEnabled",
    "Invoke-AutoFollowupChain",
    "Write-AutoFollowupReport"
)
