<#
.SYNOPSIS
    Cursor Agents Framework — Uninstall Script
.DESCRIPTION
    Removes framework-managed rules from the target project.
    Preserves project-specific files (project-config.mdc, custom rules).
.PARAMETER TargetPath
    Path to target project root (default: current directory)
.PARAMETER KeepDocs
    If set, preserves docs/agents/ directory
.PARAMETER Force
    Skip confirmation prompt
#>
param(
    [string]$TargetPath = (Get-Location),
    [switch]$KeepDocs,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║  Cursor Agents Framework — Uninstall     ║" -ForegroundColor Red
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""

$TargetRules = Join-Path $TargetPath ".cursor" "rules"
if (-not (Test-Path $TargetRules)) {
    Write-Host "  No .cursor/rules directory found. Nothing to uninstall." -ForegroundColor Yellow
    exit 0
}

$frameworkFiles = @(
    # Core
    "global-conventions.mdc",
    "orchestrator.mdc",
    "code-quality.mdc",
    # Process
    "process-analysis.mdc",
    "process-architecture.mdc",
    "process-documentation.mdc",
    # Learning
    "agent-learning.mdc"
)

$techGlob = Get-ChildItem (Join-Path $TargetRules "tech-*.mdc") -ErrorAction SilentlyContinue
$domainGlob = Get-ChildItem (Join-Path $TargetRules "domain-*.mdc") -ErrorAction SilentlyContinue

$toRemove = @()
foreach ($f in $frameworkFiles) {
    $path = Join-Path $TargetRules $f
    if (Test-Path $path) { $toRemove += $path }
}
foreach ($f in $techGlob) { $toRemove += $f.FullName }
foreach ($f in $domainGlob) { $toRemove += $f.FullName }

Write-Host "  Files to remove:" -ForegroundColor Yellow
foreach ($f in $toRemove) {
    Write-Host "    - $(Split-Path $f -Leaf)" -ForegroundColor Gray
}
Write-Host ""
Write-Host "  Files preserved:" -ForegroundColor Green
Write-Host "    - project-config.mdc (project-specific)" -ForegroundColor Green
Write-Host "    - Any custom .mdc files" -ForegroundColor Green
if ($KeepDocs) {
    Write-Host "    - docs/agents/ (--KeepDocs)" -ForegroundColor Green
}

if (-not $Force) {
    Write-Host ""
    $confirm = Read-Host "  Remove $($toRemove.Count) framework files? (Y/n)"
    if ($confirm -and $confirm -ne "Y" -and $confirm -ne "y") {
        Write-Host "  Cancelled." -ForegroundColor Red
        exit 0
    }
}

$removed = 0
foreach ($f in $toRemove) {
    Remove-Item $f -Force
    $removed++
}

# Remove AGENTS.md if it exists
$agentsMd = Join-Path $TargetPath "AGENTS.md"
if (Test-Path $agentsMd) {
    Remove-Item $agentsMd -Force
    $removed++
    Write-Host "  Removed AGENTS.md" -ForegroundColor Gray
}

# Remove docs/agents if requested
if (-not $KeepDocs) {
    $agentsDocs = Join-Path $TargetPath "docs" "agents"
    if (Test-Path $agentsDocs) {
        $docConfirm = Read-Host "  Also remove docs/agents/ directory? (Y/n)"
        if (-not $docConfirm -or $docConfirm -eq "Y" -or $docConfirm -eq "y") {
            Remove-Item $agentsDocs -Recurse -Force
            Write-Host "  Removed docs/agents/" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Uninstall complete! $removed file(s) removed." -ForegroundColor Green
Write-Host "  project-config.mdc and custom rules preserved." -ForegroundColor Green
Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
