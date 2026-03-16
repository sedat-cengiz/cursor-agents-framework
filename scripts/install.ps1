<#
.SYNOPSIS
    Cursor Agents Framework - Project Installer (Cross-Platform PowerShell)
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
Write-Host "  ==============================================" -ForegroundColor Cyan
Write-Host "    Cursor Agents Framework - Project Setup" -ForegroundColor Cyan
Write-Host "    Modular Multi-Agent System v4.0" -ForegroundColor Cyan
Write-Host "  ==============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Framework: $FrameworkPath"
Write-Host "  Project:   $ProjectPath"
Write-Host ""

$TargetRules = Join-Path (Join-Path $ProjectPath ".cursor") "rules"
$TargetDocs  = Join-Path (Join-Path $ProjectPath "docs") "agents"
$TargetRuntime = Join-Path $ProjectPath "runtime"
$TargetScripts = Join-Path $ProjectPath "scripts"

function Copy-FileIfPresent {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (Test-Path $Source) {
        $destinationDir = Split-Path $Destination -Parent
        if ($destinationDir -and -not (Test-Path $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        }
        Copy-Item $Source $Destination -Force
    }
}

if (-not (Test-Path (Join-Path $FrameworkPath "core"))) {
    Write-Host "  ERROR: Framework core not found at $FrameworkPath" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Path $TargetRules -Force | Out-Null
New-Item -ItemType Directory -Path $TargetRuntime -Force | Out-Null
New-Item -ItemType Directory -Path $TargetScripts -Force | Out-Null

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

# =======================================
# STEP 1: Core (always)
# =======================================
Write-Host "  [1/6] Core rules..." -ForegroundColor Yellow
Copy-Item (Join-Path (Join-Path $FrameworkPath "core") "*.mdc") $TargetRules -Force
Write-Host "        > global-conventions, orchestrator, orchestration-policies, code-quality" -ForegroundColor Green

# =======================================
# STEP 2: Technology
# =======================================
$techPacks = @{
    "1"  = "tech-dotnet";    "dotnet"     = "tech-dotnet"
    "2"  = "tech-react";     "react"      = "tech-react"
    "3"  = "tech-python";    "python"     = "tech-python"
    "4"  = "tech-java";      "java"       = "tech-java"
    "5"  = "tech-go";        "go"         = "tech-go"
    "6"  = "tech-angular";   "angular"    = "tech-angular"
    "7"  = "tech-vue";       "vue"        = "tech-vue"
    "8"  = "tech-nextjs";    "nextjs"     = "tech-nextjs"
    "9"  = "tech-flutter";   "flutter"    = "tech-flutter"
    "10" = "tech-sql-server";"sql-server" = "tech-sql-server"
    "11" = "tech-maui";      "maui"       = "tech-maui"
    "12" = "tech-ai-ml";     "ai-ml"      = "tech-ai-ml"
    "13" = "tech-devops";    "devops"     = "tech-devops"
    "14" = "tech-security";  "security"   = "tech-security"
    "15" = "tech-testing";   "testing"    = "tech-testing"
}

Write-Host ""
Write-Host "  [2/6] Technology packs..." -ForegroundColor Yellow

if ($manifest) {
    $selectedTech = $manifest.layers.technology
    foreach ($t in $selectedTech) {
        $file = "tech-$t.mdc"
        $src = Join-Path (Join-Path $FrameworkPath "technology") $file
        if (Test-Path $src) {
            Copy-Item $src $TargetRules -Force
            Write-Host "        > $file" -ForegroundColor Green
        } else {
            Write-Host "        > $file (NOT FOUND)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "     1) .NET Backend      2) React Frontend     3) Python Backend"
    Write-Host "     4) Java/Spring       5) Go                 6) Angular"
    Write-Host "     7) Vue               8) Next.js            9) Flutter"
    Write-Host "    10) SQL Server       11) .NET MAUI         12) AI/ML"
    Write-Host "    13) DevOps           14) Security          15) Testing"
    Write-Host "     A) ALL"
    $choice = Read-Host "  Select (e.g. 1,2,14,15 or A)"

    if ($choice -eq "A" -or $choice -eq "a") {
        Copy-Item (Join-Path (Join-Path $FrameworkPath "technology") "tech-*.mdc") $TargetRules -Force
        Write-Host "        > All technology packs installed" -ForegroundColor Green
    } else {
        $selections = $choice -split "[,\s]+" | Where-Object { $_ -ne "" }
        foreach ($c in $selections) {
            $pack = $techPacks[$c.Trim()]
            if ($pack) {
                $src = Join-Path (Join-Path $FrameworkPath "technology") "$pack.mdc"
                if (Test-Path $src) {
                    Copy-Item $src $TargetRules -Force
                    Write-Host "        > $pack.mdc" -ForegroundColor Green
                }
            }
        }
    }
}

# =======================================
# STEP 3: Process (always)
# =======================================
Write-Host ""
Write-Host "  [3/6] Process rules..." -ForegroundColor Yellow
Copy-Item (Join-Path (Join-Path $FrameworkPath "process") "*.mdc") $TargetRules -Force
Write-Host "        > process-analysis, process-architecture, process-documentation" -ForegroundColor Green

# =======================================
# STEP 4: Domain
# =======================================
Write-Host ""
Write-Host "  [4/6] Domain packs..." -ForegroundColor Yellow

$domainDirs = Get-ChildItem (Join-Path $FrameworkPath "domains") -Directory | Where-Object { $_.Name -ne "_template" }

if ($manifest) {
    if ($manifest.layers.domain -and $manifest.layers.domain.Count -gt 0) {
        foreach ($d in $manifest.layers.domain) {
            $domainPath = Join-Path (Join-Path $FrameworkPath "domains") $d
            if (Test-Path $domainPath) {
                Copy-Item (Join-Path $domainPath "*.mdc") $TargetRules -Force
                Write-Host "        > $d domain pack" -ForegroundColor Green
            } else {
                Write-Host "        > $d (NOT FOUND)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "        > No domain selected" -ForegroundColor DarkGray
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
                $domainPath = Join-Path (Join-Path $FrameworkPath "domains") $dName
                Copy-Item (Join-Path $domainPath "*.mdc") $TargetRules -Force
                Write-Host "        > $dName domain pack" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "        > No domain selected" -ForegroundColor DarkGray
    }
}

# =======================================
# STEP 5: Learning + runtime + docs structure
# =======================================
Write-Host ""
Write-Host "  [5/6] Learning system + runtime + docs structure..." -ForegroundColor Yellow

Copy-Item (Join-Path (Join-Path $FrameworkPath "learning") "agent-learning.mdc") $TargetRules -Force

$docDirs = @("", "requirements", "decisions", "contracts", "handoffs", "reviews", "quality-gates", "failures", "state-snapshots", "runtime", "agent-outputs")
foreach ($sub in $docDirs) {
    $dir = Join-Path $TargetDocs $sub
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

Copy-Item (Join-Path (Join-Path $FrameworkPath "runtime") "*") $TargetRuntime -Recurse -Force
Copy-FileIfPresent -Source (Join-Path (Join-Path $FrameworkPath "scripts") "validate.ps1") -Destination (Join-Path $TargetScripts "validate.ps1")
Copy-FileIfPresent -Source (Join-Path (Join-Path $FrameworkPath "scripts") "validate-orchestration.ps1") -Destination (Join-Path $TargetScripts "validate-orchestration.ps1")
Copy-FileIfPresent -Source (Join-Path (Join-Path $FrameworkPath "scripts") "run-agent.ps1") -Destination (Join-Path $TargetScripts "run-agent.ps1")
Copy-FileIfPresent -Source (Join-Path $FrameworkPath "agents.manifest.schema.json") -Destination (Join-Path $ProjectPath "agents.manifest.schema.json")
Copy-FileIfPresent -Source (Join-Path (Join-Path $FrameworkPath "templates\runtime") "agent-invocation.json") -Destination (Join-Path (Join-Path $TargetDocs "runtime") "agent-invocation.json")
Copy-FileIfPresent -Source (Join-Path (Join-Path $FrameworkPath "templates\runtime") "evidence-command-map.json") -Destination (Join-Path (Join-Path $TargetDocs "runtime") "evidence-command-map.json")
Copy-FileIfPresent -Source (Join-Path (Join-Path $FrameworkPath "templates\doc-templates") "_schema-agent-output.json") -Destination (Join-Path (Join-Path $TargetDocs "agent-outputs") "_schema-agent-output.json")

if (Test-Path (Join-Path $FrameworkPath "standards")) {
    Copy-Item (Join-Path (Join-Path $FrameworkPath "standards") "*.md") $TargetDocs -Force
}

$templateDir = Join-Path $FrameworkPath "templates"

$lessonsFile = Join-Path $TargetDocs "lessons-learned.md"
if (-not (Test-Path $lessonsFile)) {
    "# Proje Ogrenme Gunlugu`n`n> Bu dosya proje boyunca biriken ogrenmeleri icerir.`n" | Set-Content $lessonsFile
}

$taskboardFile = Join-Path $TargetDocs "taskboard.md"
if (-not (Test-Path $taskboardFile)) {
    Copy-Item (Join-Path (Join-Path $templateDir "doc-templates") "taskboard.md") $taskboardFile -ErrorAction SilentlyContinue
    if (-not (Test-Path $taskboardFile)) {
        "# Gorev Tablosu`nSon Guncelleme: $(Get-Date -Format 'yyyy-MM-dd')`n`n### BACKLOG`n`n### IN PROGRESS`n`n### DONE`n" | Set-Content $taskboardFile
    }
}

$wfFile = Join-Path $TargetDocs "workflow-state.md"
if (-not (Test-Path $wfFile)) {
    Copy-Item (Join-Path (Join-Path $templateDir "doc-templates") "workflow-state.md") $wfFile -ErrorAction SilentlyContinue
    if (-not (Test-Path $wfFile)) {
        "# Workflow State`n" | Set-Content $wfFile
    }
}

$runtimeEventLog = Join-Path (Join-Path $TargetDocs "runtime") "state-events.jsonl"
if (-not (Test-Path $runtimeEventLog)) {
    New-Item -ItemType File -Path $runtimeEventLog -Force | Out-Null
}

$agentGuideFile = Join-Path $TargetDocs "agent-guide.md"
if (-not (Test-Path $agentGuideFile)) {
    $agentGuideTemplatePath = Join-Path $templateDir "agent-guide.md"
    if (Test-Path $agentGuideTemplatePath) {
        $projectName = if ($manifest -and $manifest.projectName) { $manifest.projectName } else { Split-Path $ProjectPath -Leaf }
        $backendTech = if ($manifest -and $manifest.technologyStack -and $manifest.technologyStack.backend) { $manifest.technologyStack.backend } else { "backend-tech" }
        $frontendTech = if ($manifest -and $manifest.technologyStack -and $manifest.technologyStack.frontend) { $manifest.technologyStack.frontend } else { "frontend-tech" }
        $databaseTech = if ($manifest -and $manifest.technologyStack -and $manifest.technologyStack.database) { $manifest.technologyStack.database } else { "database-tech" }
        $agentGuideContent = Get-Content $agentGuideTemplatePath -Raw
        $agentGuideContent = $agentGuideContent.Replace("{{PROJE_ADI}}", $projectName)
        $agentGuideContent = $agentGuideContent.Replace("{{BACKEND}}", $backendTech)
        $agentGuideContent = $agentGuideContent.Replace("{{FRONTEND}}", $frontendTech)
        $agentGuideContent = $agentGuideContent.Replace("{{DATABASE}}", $databaseTech)
        Set-Content -Path $agentGuideFile -Value $agentGuideContent
    }
}

$projectConfigFile = Join-Path $TargetRules "project-config.mdc"
if (-not (Test-Path $projectConfigFile)) {
    $projectConfigTemplate = Join-Path $templateDir "project-config-template.mdc"
    if (Test-Path $projectConfigTemplate) {
        $projectName = if ($manifest -and $manifest.projectName) { $manifest.projectName } else { Split-Path $ProjectPath -Leaf }
        $projectConfigContent = Get-Content $projectConfigTemplate -Raw
        $projectConfigContent = $projectConfigContent.Replace("{{PROJE_ADI}}", $projectName)
        $projectConfigContent = $projectConfigContent.Replace("{{PLATFORM_TANIMI}}", "Fill this project-specific platform description.")
        $projectConfigContent = $projectConfigContent.Replace("{{DEV_TENANT_GUID}}", "FILL-ME")
        $projectConfigContent = $projectConfigContent.Replace("{{BACKEND_PORT}}", "5000")
        $projectConfigContent = $projectConfigContent.Replace("{{FRONTEND_PORT}}", "3000")
        Set-Content -Path $projectConfigFile -Value $projectConfigContent
    }
}

$agentsEntryPoint = Join-Path $ProjectPath "AGENTS.md"
if (-not (Test-Path $agentsEntryPoint)) {
    @(
        "# AGENTS"
        ""
        "Bu projede kullanici tek giris noktasi olarak `@sef` ile calisir."
        "Detayli orkestrasyon rehberi: `docs/agents/agent-guide.md`."
    ) | Set-Content -Path $agentsEntryPoint
}

Write-Host "        > Learning + docs/agents/ + project-local runtime created" -ForegroundColor Green

# =======================================
# STEP 6: Aliases
# =======================================
Write-Host ""
Write-Host "  [6/6] Creating aliases..." -ForegroundColor Yellow

$trAliases = @{
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

$enAliases = @{
    "pm"            = "orchestrator"
    "review"        = "code-quality"
    "backend"       = "tech-dotnet"
    "frontend"      = "tech-react"
    "qa"            = "tech-testing"
    "db"            = "tech-sql-server"
    "security"      = "tech-security"
    "devops"        = "tech-devops"
    "mobile"        = "tech-maui"
    "ai"            = "tech-ai-ml"
    "architect"     = "process-architecture"
    "analyst"       = "process-analysis"
    "docs"          = "process-documentation"
}

$aliasLang = "tr"
if ($manifest -and $manifest.aliasLanguage) {
    $aliasLang = $manifest.aliasLanguage
}

$defaultAliases = @{}
if ($aliasLang -eq "tr" -or $aliasLang -eq "both") {
    foreach ($k in $trAliases.Keys) { $defaultAliases[$k] = $trAliases[$k] }
}
if ($aliasLang -eq "en" -or $aliasLang -eq "both") {
    foreach ($k in $enAliases.Keys) { $defaultAliases[$k] = $enAliases[$k] }
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

# =======================================
# DONE
# =======================================
Write-Host ""
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host "   Cursor Agents Framework installed!" -ForegroundColor Green
Write-Host ""
Write-Host "   Next steps:"
Write-Host "   1. Open project in Cursor"
Write-Host "   2. Edit .cursor/rules/global-conventions.mdc"
Write-Host "      - Fill project name and platform"
Write-Host "      - Adjust technology stack if needed"
Write-Host "   3. Start with @sef for task coordination"
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host ""
