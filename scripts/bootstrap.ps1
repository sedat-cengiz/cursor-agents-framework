<#
.SYNOPSIS
    Proje klasorunden tek komutla framework kurar (sorusuz, -Quick).
.DESCRIPTION
    Bu scripti PROJE klasorunuzden calistirin. Framework'un skills'ta kurulu olmasi gerekir.
    Ornek: cd D:\MyProject; .\bootstrap.ps1
    Veya:  cd D:\MyProject; & "$env:USERPROFILE\.cursor\skills\cursor-agents-framework\scripts\bootstrap.ps1"
#>
$ErrorActionPreference = "Stop"
$projectPath = Get-Location
$frameworkPath = if ($env:CURSOR_AGENTS_FRAMEWORK) { $env:CURSOR_AGENTS_FRAMEWORK } else { Join-Path $env:USERPROFILE ".cursor\skills\cursor-agents-framework" }
$installScript = Join-Path $frameworkPath "scripts\install.ps1"
if (-not (Test-Path $installScript)) {
    Write-Host "Framework bulunamadi: $frameworkPath" -ForegroundColor Red
    Write-Host "Once kurun: git clone https://github.com/sedat-cengiz/cursor-agents-framework.git `"$frameworkPath`"" -ForegroundColor Yellow
    exit 1
}
& $installScript -ProjectPath $projectPath -Quick
