<#
.SYNOPSIS
    Cursor Agents Framework - Validate Script
.DESCRIPTION
    Validates that the project's .cursor/rules/ setup matches agents.manifest.json.
    Checks for missing files, orphan rules, and configuration issues.
.PARAMETER TargetPath
    Path to target project root (default: current directory)
#>
param(
    [string]$TargetPath = (Get-Location)
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Cursor Agents Framework - Validate" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$TargetRules = Join-Path (Join-Path $TargetPath ".cursor") "rules"
$manifestPath = Join-Path $TargetPath "agents.manifest.json"
$runtimeRoot = Join-Path $TargetPath "runtime"
$scriptsRoot = Join-Path $TargetPath "scripts"

$errors = @()
$warnings = @()
$passed = @()

# -- Check 1: .cursor/rules directory exists --
if (-not (Test-Path $TargetRules)) {
    $errors += ".cursor/rules/ directory not found"
    Write-Host "  FAIL: .cursor/rules/ not found. Run install.ps1 first." -ForegroundColor Red
    exit 1
}
$passed += ".cursor/rules/ directory exists"

# -- Check 2: agents.manifest.json exists --
$manifest = $null
if (Test-Path $manifestPath) {
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $passed += "agents.manifest.json parsed successfully"
    } catch {
        $errors += "agents.manifest.json is invalid JSON: $_"
    }
} else {
    $warnings += "agents.manifest.json not found (validation will be limited)"
}

# -- Check 3: Core rules present --
$coreFiles = @("global-conventions.mdc", "orchestrator.mdc", "orchestration-policies.mdc", "code-quality.mdc")
foreach ($f in $coreFiles) {
    $path = Join-Path $TargetRules $f
    if (Test-Path $path) {
        $passed += "Core rule: $f"
    } else {
        $errors += "Missing core rule: $f"
    }
}

# -- Check 4: Process rules present --
$processFiles = @("process-analysis.mdc", "process-architecture.mdc", "process-documentation.mdc")
foreach ($f in $processFiles) {
    $path = Join-Path $TargetRules $f
    if (Test-Path $path) {
        $passed += "Process rule: $f"
    } else {
        $warnings += "Missing process rule: $f"
    }
}

# -- Check 5: Learning rule present --
$learnPath = Join-Path $TargetRules "agent-learning.mdc"
if (Test-Path $learnPath) {
    $passed += "Learning rule: agent-learning.mdc"
} else {
    $warnings += "Missing learning rule: agent-learning.mdc"
}

# -- Check 6: Project config present --
$configPath = Join-Path $TargetRules "project-config.mdc"
if (Test-Path $configPath) {
    $passed += "Project config: project-config.mdc"
} else {
    $warnings += "Missing project-config.mdc (customizations won't apply)"
}

# -- Check 7: AGENTS.md entry point --
$agentsMd = Join-Path $TargetPath "AGENTS.md"
if (Test-Path $agentsMd) {
    $passed += "AGENTS.md entry point exists"
} else {
    $warnings += "Missing AGENTS.md entry point"
}

# -- Check 8: Manifest-declared tech packs --
if ($manifest -and $manifest.layers -and $manifest.layers.technology) {
    foreach ($t in $manifest.layers.technology) {
        $file = "tech-$t.mdc"
        $path = Join-Path $TargetRules $file
        if (Test-Path $path) {
            $passed += "Tech pack: $file"
        } else {
            $errors += "Manifest declares tech '$t' but $file not found in .cursor/rules/"
        }
    }
}

# -- Check 9: Manifest-declared domain packs --
if ($manifest -and $manifest.layers -and $manifest.layers.domain) {
    foreach ($d in $manifest.layers.domain) {
        $domainFiles = Get-ChildItem (Join-Path $TargetRules "domain-$d*.mdc") -ErrorAction SilentlyContinue
        if ($domainFiles.Count -gt 0) {
            $passed += "Domain pack: $d ($($domainFiles.Count) file(s))"
        } else {
            $errors += "Manifest declares domain '$d' but no domain-$d*.mdc files found"
        }
    }
}

# -- Check 10: Orphan tech packs (installed but not in manifest) --
if ($manifest -and $manifest.layers -and $manifest.layers.technology) {
    $installedTech = Get-ChildItem (Join-Path $TargetRules "tech-*.mdc") -ErrorAction SilentlyContinue
    foreach ($f in $installedTech) {
        $techName = $f.BaseName -replace "^tech-", ""
        if ($techName -notin $manifest.layers.technology) {
            $warnings += "Orphan tech pack: $($f.Name) (installed but not in manifest)"
        }
    }
}

# -- Check 11: Project-local runtime files --
$requiredRuntimeFiles = @(
    "Invoke-Orchestration.ps1",
    "Replay-Orchestration.ps1",
    "engine\StateMachine.psm1",
    "executor\AgentExecutionAdapter.psm1",
    "intake\RequestIntake.psm1"
)
foreach ($runtimeFile in $requiredRuntimeFiles) {
    $runtimePath = Join-Path $runtimeRoot $runtimeFile
    if (Test-Path $runtimePath) {
        $passed += "Runtime file: runtime/$runtimeFile"
    } else {
        $errors += "Missing project-local runtime file: runtime/$runtimeFile"
    }
}

$requiredScriptFiles = @("validate.ps1", "validate-orchestration.ps1", "run-agent.ps1")
foreach ($scriptFile in $requiredScriptFiles) {
    $scriptPath = Join-Path $scriptsRoot $scriptFile
    if (Test-Path $scriptPath) {
        $passed += "Script file: scripts/$scriptFile"
    } else {
        $errors += "Missing project-local script: scripts/$scriptFile"
    }
}

# -- Check 12: docs/agents/ structure --
$agentsDocs = Join-Path (Join-Path $TargetPath "docs") "agents"
if (Test-Path $agentsDocs) {
    $subDirs = @("requirements", "contracts", "decisions", "handoffs", "quality-gates", "failures", "state-snapshots", "runtime", "agent-outputs")
    foreach ($d in $subDirs) {
        $dPath = Join-Path $agentsDocs $d
        if (Test-Path $dPath) {
            $passed += "Docs: docs/agents/$d/"
        } else {
            $warnings += "Missing docs/agents/$d/ directory"
        }
    }

    $requiredDocs = @("taskboard.md", "workflow-state.md", "agent-guide.md")
    foreach ($f in $requiredDocs) {
        $fPath = Join-Path $agentsDocs $f
        if (Test-Path $fPath) {
            $passed += "Docs: $f"
        } else {
            $warnings += "Missing docs/agents/$f"
        }
    }

    $eventLogPath = Join-Path (Join-Path $agentsDocs "runtime") "state-events.jsonl"
    if (Test-Path $eventLogPath) {
        $passed += "Docs: runtime/state-events.jsonl"
    } else {
        $warnings += "Missing docs/agents/runtime/state-events.jsonl"
    }

    $runnerConfigPath = Join-Path (Join-Path $agentsDocs "runtime") "agent-invocation.json"
    if (Test-Path $runnerConfigPath) {
        $passed += "Docs: runtime/agent-invocation.json"
    } else {
        $errors += "Missing docs/agents/runtime/agent-invocation.json"
    }

    $evidenceMapPath = Join-Path (Join-Path $agentsDocs "runtime") "evidence-command-map.json"
    if (Test-Path $evidenceMapPath) {
        $passed += "Docs: runtime/evidence-command-map.json"
    } else {
        $errors += "Missing docs/agents/runtime/evidence-command-map.json"
    }

    $outputSchemaPath = Join-Path (Join-Path $agentsDocs "agent-outputs") "_schema-agent-output.json"
    if (Test-Path $outputSchemaPath) {
        $passed += "Docs: agent-outputs/_schema-agent-output.json"
    } else {
        $errors += "Missing docs/agents/agent-outputs/_schema-agent-output.json"
    }
} else {
    $warnings += "docs/agents/ directory not found"
}

# -- Check 13: Orchestration artifact structure --
if (Test-Path $agentsDocs) {
    $orchestrationValidator = Join-Path $scriptsRoot "validate-orchestration.ps1"
    if (-not (Test-Path $orchestrationValidator)) {
        $orchestrationValidator = Join-Path $PSScriptRoot "validate-orchestration.ps1"
    }

    if (Test-Path $orchestrationValidator) {
        $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
        if (-not $pwshCmd) {
            $pwshCmd = Get-Command powershell -ErrorAction SilentlyContinue
        }

        if ($pwshCmd) {
            & $pwshCmd.Source -NoProfile -File $orchestrationValidator -DocsPath $agentsDocs | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $passed += "Orchestration validator completed"
            } else {
                $errors += "Orchestration validation failed with exit code $LASTEXITCODE"
            }
        } else {
            $warnings += "No PowerShell host found for validate-orchestration.ps1"
        }
    } else {
        $warnings += "validate-orchestration.ps1 not found"
    }
}

# =======================================
# REPORT
# =======================================
Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  VALIDATION REPORT" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "  STATUS: ALL CHECKS PASSED" -ForegroundColor Green
} elseif ($errors.Count -gt 0) {
    Write-Host "  STATUS: FAILED ($($errors.Count) error(s))" -ForegroundColor Red
} else {
    Write-Host "  STATUS: PASSED WITH WARNINGS ($($warnings.Count))" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Passed: $($passed.Count)" -ForegroundColor Green
foreach ($p in $passed) {
    Write-Host "    [OK] $p" -ForegroundColor DarkGreen
}

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "  Errors: $($errors.Count)" -ForegroundColor Red
    foreach ($e in $errors) {
        Write-Host "    [ERROR] $e" -ForegroundColor Red
    }
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "  Warnings: $($warnings.Count)" -ForegroundColor Yellow
    foreach ($w in $warnings) {
        Write-Host "    [WARN] $w" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan

if ($errors.Count -gt 0) { exit 1 }
exit 0
