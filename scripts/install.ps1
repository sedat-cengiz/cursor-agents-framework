<#
.SYNOPSIS
    Cursor Agents Framework — Project Installer (Cross-Platform PowerShell)
.DESCRIPTION
    Installs agent rules into a project's .cursor/rules/ directory.
    Supports interactive mode (prompts for tech/domain selection) or
    manifest-driven mode (reads agents.manifest.json).
.PARAMETER ProjectPath
    Target project root directory. Defaults to current directory.
.PARAMETER ManifestPath
    Path to agents.manifest.json. If present, skips interactive prompts.
.EXAMPLE
    .\install.ps1 -ProjectPath "D:\MyProject"
    .\install.ps1 -ManifestPath "D:\MyProject\agents.manifest.json"
#>

param(
    [string]$ProjectPath = (Get-Location).Path,
    [string]$ManifestPath = ""
)

$ErrorActionPreference = "Stop"
$FrameworkPath = Split-Path -Parent $PSScriptRoot

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  Cursor Agents Framework — Project Setup     ║" -ForegroundColor Cyan
Write-Host "  ║  Modular Multi-Agent System v3.0             ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Framework: $FrameworkPath"
Write-Host "  Project:   $ProjectPath"
Write-Host ""

$TargetRules = Join-Path $ProjectPath ".cursor" "rules"
$TargetDocs  = Join-Path $ProjectPath "docs" "agents"

if (-not (Test-Path (Join-Path $FrameworkPath "core"))) {
    Write-Host "  ERROR: Framework core not found at $FrameworkPath" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Path $TargetRules -Force | Out-Null

# --- Manifest-driven or interactive ---
$manifest = $null
if ($ManifestPath -and (Test-Path $ManifestPath)) {
    $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    Write-Host "  Using manifest: $ManifestPath" -ForegroundColor Green
} elseif (Test-Path (Join-Path $ProjectPath "agents.manifest.json")) {
    $ManifestPath = Join-Path $ProjectPath "agents.manifest.json"
    $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    Write-Host "  Using manifest: $ManifestPath" -ForegroundColor Green
}

# ═══════════════════════════════════════
# STEP 1: Core (always)
# ═══════════════════════════════════════
Write-Host "  [1/6] Core rules..." -ForegroundColor Yellow
Copy-Item (Join-Path $FrameworkPath "core" "*.mdc") $TargetRules -Force
Write-Host "        > global-conventions, orchestrator, code-quality" -ForegroundColor Green

# ═══════════════════════════════════════
# STEP 2: Technology
# ═══════════════════════════════════════
$techPacks = @{
    "1" = "tech-dotnet";    "dotnet"     = "tech-dotnet"
    "2" = "tech-react";     "react"      = "tech-react"
    "3" = "tech-python";    "python"     = "tech-python"
    "4" = "tech-sql-server";"sql-server" = "tech-sql-server"
    "5" = "tech-maui";      "maui"       = "tech-maui"
    "6" = "tech-ai-ml";     "ai-ml"      = "tech-ai-ml"
    "7" = "tech-devops";    "devops"     = "tech-devops"
    "8" = "tech-security";  "security"   = "tech-security"
    "9" = "tech-testing";   "testing"    = "tech-testing"
}

Write-Host ""
Write-Host "  [2/6] Technology packs..." -ForegroundColor Yellow

if ($manifest) {
    $selectedTech = $manifest.layers.technology
    foreach ($t in $selectedTech) {
        $file = "tech-$t.mdc"
        $src = Join-Path $FrameworkPath "technology" $file
        if (Test-Path $src) {
            Copy-Item $src $TargetRules -Force
            Write-Host "        > $file" -ForegroundColor Green
        } else {
            Write-Host "        > $file (NOT FOUND)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "    1) .NET Backend      2) React Frontend    3) Python Backend"
    Write-Host "    4) SQL Server        5) .NET MAUI Mobile  6) AI/ML"
    Write-Host "    7) DevOps            8) Security          9) Testing"
    Write-Host "    A) ALL"
    $choice = Read-Host "  Select (e.g. 1289 or A)"

    if ($choice -eq "A" -or $choice -eq "a") {
        Copy-Item (Join-Path $FrameworkPath "technology" "*.mdc") $TargetRules -Force
        Write-Host "        > All technology packs installed" -ForegroundColor Green
    } else {
        foreach ($c in $choice.ToCharArray()) {
            $pack = $techPacks["$c"]
            if ($pack) {
                $src = Join-Path $FrameworkPath "technology" "$pack.mdc"
                if (Test-Path $src) {
                    Copy-Item $src $TargetRules -Force
                    Write-Host "        > $pack.mdc" -ForegroundColor Green
                }
            }
        }
    }
}

# ═══════════════════════════════════════
# STEP 3: Process (always)
# ═══════════════════════════════════════
Write-Host ""
Write-Host "  [3/6] Process rules..." -ForegroundColor Yellow
Copy-Item (Join-Path $FrameworkPath "process" "*.mdc") $TargetRules -Force
Write-Host "        > process-analysis, process-architecture, process-documentation" -ForegroundColor Green

# ═══════════════════════════════════════
# STEP 4: Domain
# ═══════════════════════════════════════
Write-Host ""
Write-Host "  [4/6] Domain packs..." -ForegroundColor Yellow

$domainDirs = Get-ChildItem (Join-Path $FrameworkPath "domains") -Directory | Where-Object { $_.Name -ne "_template" }

if ($manifest -and $manifest.layers.domain) {
    foreach ($d in $manifest.layers.domain) {
        $domainPath = Join-Path $FrameworkPath "domains" $d
        if (Test-Path $domainPath) {
            Copy-Item (Join-Path $domainPath "*.mdc") $TargetRules -Force
            Write-Host "        > $d domain pack" -ForegroundColor Green
        } else {
            Write-Host "        > $d (NOT FOUND)" -ForegroundColor Red
        }
    }
} else {
    $i = 1
    $domainMap = @{}
    foreach ($d in $domainDirs) {
        Write-Host "    $i) $($d.Name)"
        $domainMap["$i"] = $d.Name
        $i++
    }
    Write-Host "    0) None"
    $dChoice = Read-Host "  Select domain(s) (e.g. 12 or 0)"

    if ($dChoice -ne "0") {
        foreach ($c in $dChoice.ToCharArray()) {
            $dName = $domainMap["$c"]
            if ($dName) {
                $domainPath = Join-Path $FrameworkPath "domains" $dName
                Copy-Item (Join-Path $domainPath "*.mdc") $TargetRules -Force
                Write-Host "        > $dName domain pack" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "        > No domain selected" -ForegroundColor DarkGray
    }
}

# ═══════════════════════════════════════
# STEP 5: Learning + Docs structure
# ═══════════════════════════════════════
Write-Host ""
Write-Host "  [5/6] Learning system + docs structure..." -ForegroundColor Yellow

Copy-Item (Join-Path $FrameworkPath "learning" "agent-learning.mdc") $TargetRules -Force

$docDirs = @("", "requirements", "decisions", "contracts", "handoffs", "reviews")
foreach ($sub in $docDirs) {
    $dir = Join-Path $TargetDocs $sub
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

if (Test-Path (Join-Path $FrameworkPath "standards")) {
    Copy-Item (Join-Path $FrameworkPath "standards" "*.md") $TargetDocs -Force
}

$templateDir = Join-Path $FrameworkPath "templates"

$lessonsFile = Join-Path $TargetDocs "lessons-learned.md"
if (-not (Test-Path $lessonsFile)) {
    "# Proje Ogrenme Gunlugu`n`n> Bu dosya proje boyunca biriken ogrenmeleri icerir.`n" | Set-Content $lessonsFile
}

$taskboardFile = Join-Path $TargetDocs "taskboard.md"
if (-not (Test-Path $taskboardFile)) {
    Copy-Item (Join-Path $templateDir "doc-templates" "taskboard.md") $taskboardFile -ErrorAction SilentlyContinue
    if (-not (Test-Path $taskboardFile)) {
        "# Gorev Tablosu`nSon Guncelleme: $(Get-Date -Format 'yyyy-MM-dd')`n`n### BACKLOG`n`n### IN PROGRESS`n`n### DONE`n" | Set-Content $taskboardFile
    }
}

$wfFile = Join-Path $TargetDocs "workflow-state.md"
if (-not (Test-Path $wfFile)) {
    "# Workflow State`nAktif Faz: Analiz`nSon Guncelleme: $(Get-Date -Format 'yyyy-MM-dd')`n" | Set-Content $wfFile
}

Write-Host "        > Learning + docs/agents/ structure created" -ForegroundColor Green

# ═══════════════════════════════════════
# STEP 6: Aliases
# ═══════════════════════════════════════
Write-Host ""
Write-Host "  [6/6] Creating aliases..." -ForegroundColor Yellow

$defaultAliases = @{
    "sef"           = "orchestrator"
    "review"        = "code-quality"
    "backend"       = "tech-dotnet"
    "frontend"      = "tech-react"
    "qa"            = "tech-testing"
    "db"            = "tech-sql-server"
    "guvenlik"      = "tech-security"
    "devops"        = "tech-devops"
    "mobil"         = "tech-maui"
    "ai"            = "tech-ai-ml"
    "mimari"        = "process-architecture"
    "analist"       = "process-analysis"
    "dokumantasyon" = "process-documentation"
}

if ($manifest -and $manifest.aliases) {
    $manifest.aliases.PSObject.Properties | ForEach-Object {
        $defaultAliases[$_.Name] = $_.Value
    }
}

$aliasCreated = @()
foreach ($alias in $defaultAliases.GetEnumerator()) {
    $sourceFile = Join-Path $TargetRules "$($alias.Value).mdc"
    $aliasFile  = Join-Path $TargetRules "$($alias.Key).mdc"
    if ((Test-Path $sourceFile) -and ($alias.Key -ne $alias.Value)) {
        Copy-Item $sourceFile $aliasFile -Force
        $aliasCreated += "@$($alias.Key)"
    }
}

Write-Host "        > Aliases: $($aliasCreated -join ', ')" -ForegroundColor Green

# ═══════════════════════════════════════
# DONE
# ═══════════════════════════════════════
Write-Host ""
Write-Host "  ════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   Cursor Agents Framework installed!" -ForegroundColor Green
Write-Host ""
Write-Host "   Next steps:"
Write-Host "   1. Open project in Cursor"
Write-Host "   2. Edit .cursor/rules/global-conventions.mdc"
Write-Host "      - Fill project name and platform"
Write-Host "      - Adjust technology stack if needed"
Write-Host "   3. Start with @sef for task coordination"
Write-Host "  ════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
