<#
.SYNOPSIS
    Cursor Agents Framework — Update Script
.DESCRIPTION
    Updates an existing project installation with the latest framework rules.
    Reads agents.manifest.json (if present) to selectively update only active packs.
    Preserves project-specific customizations in project-config.mdc.
.PARAMETER FrameworkPath
    Path to framework root (default: script parent directory)
.PARAMETER TargetPath
    Path to target project root (default: current directory)
.PARAMETER Force
    Skip confirmation prompt
#>
param(
    [string]$FrameworkPath = (Split-Path $PSScriptRoot),
    [string]$TargetPath = (Get-Location),
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Cursor Agents Framework — Update v4.0   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$TargetRules = Join-Path $TargetPath ".cursor" "rules"
if (-not (Test-Path $TargetRules)) {
    Write-Host "ERROR: .cursor/rules not found at $TargetRules" -ForegroundColor Red
    Write-Host "  Run install.ps1 first to set up the project." -ForegroundColor Yellow
    exit 1
}

$manifestPath = Join-Path $TargetPath "agents.manifest.json"
$manifest = $null
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    Write-Host "  Manifest found: $($manifest.projectName)" -ForegroundColor Green
} else {
    Write-Host "  WARNING: No agents.manifest.json — will update core/process/learning only." -ForegroundColor Yellow
}

if (-not $Force) {
    Write-Host ""
    Write-Host "  This will overwrite rules in: $TargetRules" -ForegroundColor Yellow
    Write-Host "  project-config.mdc will NOT be touched." -ForegroundColor Green
    $confirm = Read-Host "  Continue? (Y/n)"
    if ($confirm -and $confirm -ne "Y" -and $confirm -ne "y") {
        Write-Host "  Cancelled." -ForegroundColor Red
        exit 0
    }
}

Write-Host ""
$updated = 0

# Core rules (always update)
Write-Host "  [1/4] Updating core rules..." -ForegroundColor Yellow
$coreFiles = @("global-conventions.mdc", "orchestrator.mdc", "code-quality.mdc")
foreach ($f in $coreFiles) {
    $src = Join-Path $FrameworkPath "core" $f
    if (Test-Path $src) {
        Copy-Item $src $TargetRules -Force
        $updated++
        Write-Host "        > $f" -ForegroundColor Green
    }
}

# Process rules (always update)
Write-Host "  [2/4] Updating process rules..." -ForegroundColor Yellow
$processFiles = Get-ChildItem (Join-Path $FrameworkPath "process" "*.mdc") -ErrorAction SilentlyContinue
foreach ($f in $processFiles) {
    Copy-Item $f.FullName $TargetRules -Force
    $updated++
    Write-Host "        > $($f.Name)" -ForegroundColor Green
}

# Learning rules (always update)
Write-Host "  [3/4] Updating learning rules..." -ForegroundColor Yellow
$learnSrc = Join-Path $FrameworkPath "learning" "agent-learning.mdc"
if (Test-Path $learnSrc) {
    Copy-Item $learnSrc $TargetRules -Force
    $updated++
    Write-Host "        > agent-learning.mdc" -ForegroundColor Green
}

# Technology packs (only installed ones)
Write-Host "  [4/4] Updating technology packs..." -ForegroundColor Yellow
if ($manifest -and $manifest.layers.technology) {
    foreach ($t in $manifest.layers.technology) {
        $file = "tech-$t.mdc"
        $src = Join-Path $FrameworkPath "technology" $file
        if (Test-Path $src) {
            Copy-Item $src $TargetRules -Force
            $updated++
            Write-Host "        > $file" -ForegroundColor Green
        } else {
            Write-Host "        > $file NOT FOUND in framework" -ForegroundColor Red
        }
    }

    if ($manifest.layers.domain) {
        foreach ($d in $manifest.layers.domain) {
            $domainDir = Join-Path $FrameworkPath "domains" $d
            if (Test-Path $domainDir) {
                $domainFiles = Get-ChildItem (Join-Path $domainDir "*.mdc") -ErrorAction SilentlyContinue
                foreach ($f in $domainFiles) {
                    Copy-Item $f.FullName $TargetRules -Force
                    $updated++
                    Write-Host "        > $($f.Name) (domain: $d)" -ForegroundColor Green
                }
            }
        }
    }
} else {
    $techFiles = Get-ChildItem (Join-Path $TargetRules "tech-*.mdc") -ErrorAction SilentlyContinue
    foreach ($f in $techFiles) {
        $src = Join-Path $FrameworkPath "technology" $f.Name
        if (Test-Path $src) {
            Copy-Item $src $f.FullName -Force
            $updated++
            Write-Host "        > $($f.Name)" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Update complete! $updated file(s) updated." -ForegroundColor Green
Write-Host "  project-config.mdc was preserved." -ForegroundColor Green
Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
