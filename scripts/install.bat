@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "PROJECT_PATH=%~1"
if "%PROJECT_PATH%"=="" set "PROJECT_PATH=%CD%"
set "SCRIPT_DIR=%~dp0"
set "FRAMEWORK_PATH=%SCRIPT_DIR%.."
set "TARGET_PATH=%PROJECT_PATH%\.cursor\rules"

echo.
echo  ╔══════════════════════════════════════════════╗
echo  ║  Cursor Agents Framework — Project Setup     ║
echo  ║  Modular Multi-Agent System v3.0             ║
echo  ╚══════════════════════════════════════════════╝
echo.
echo  Framework: %FRAMEWORK_PATH%
echo  Project: %PROJECT_PATH%
echo.

if not exist "%FRAMEWORK_PATH%\core" (
    echo  ERROR: Framework core not found!
    pause
    exit /b 1
)

if not exist "%TARGET_PATH%" mkdir "%TARGET_PATH%"

:: STEP 1: Core
echo  [1/6] Core rules...
for %%f in ("%FRAMEWORK_PATH%\core\*.mdc") do copy /Y "%%f" "%TARGET_PATH%\" >nul
echo        Done: global-conventions, orchestrator, code-quality

:: STEP 2: Technology
echo.
echo  [2/6] Technology packs:
echo    1) .NET Backend      2) React Frontend    3) Python Backend
echo    4) SQL Server        5) .NET MAUI Mobile  6) AI/ML
echo    7) DevOps            8) Security          9) Testing
echo    A) ALL
echo.
set /p TECH_CHOICE="  Select (e.g. 1289 or A): "

if /i "%TECH_CHOICE%"=="A" (
    for %%f in ("%FRAMEWORK_PATH%\technology\*.mdc") do copy /Y "%%f" "%TARGET_PATH%\" >nul
    echo        Done: All technology packs
) else (
    if not "!TECH_CHOICE:1=!"=="%TECH_CHOICE%" copy /Y "%FRAMEWORK_PATH%\technology\tech-dotnet.mdc" "%TARGET_PATH%\" >nul 2>nul
    if not "!TECH_CHOICE:2=!"=="%TECH_CHOICE%" copy /Y "%FRAMEWORK_PATH%\technology\tech-react.mdc" "%TARGET_PATH%\" >nul 2>nul
    if not "!TECH_CHOICE:3=!"=="%TECH_CHOICE%" copy /Y "%FRAMEWORK_PATH%\technology\tech-python.mdc" "%TARGET_PATH%\" >nul 2>nul
    if not "!TECH_CHOICE:4=!"=="%TECH_CHOICE%" copy /Y "%FRAMEWORK_PATH%\technology\tech-sql-server.mdc" "%TARGET_PATH%\" >nul 2>nul
    if not "!TECH_CHOICE:5=!"=="%TECH_CHOICE%" copy /Y "%FRAMEWORK_PATH%\technology\tech-maui.mdc" "%TARGET_PATH%\" >nul 2>nul
    if not "!TECH_CHOICE:6=!"=="%TECH_CHOICE%" copy /Y "%FRAMEWORK_PATH%\technology\tech-ai-ml.mdc" "%TARGET_PATH%\" >nul 2>nul
    if not "!TECH_CHOICE:7=!"=="%TECH_CHOICE%" copy /Y "%FRAMEWORK_PATH%\technology\tech-devops.mdc" "%TARGET_PATH%\" >nul 2>nul
    if not "!TECH_CHOICE:8=!"=="%TECH_CHOICE%" copy /Y "%FRAMEWORK_PATH%\technology\tech-security.mdc" "%TARGET_PATH%\" >nul 2>nul
    if not "!TECH_CHOICE:9=!"=="%TECH_CHOICE%" copy /Y "%FRAMEWORK_PATH%\technology\tech-testing.mdc" "%TARGET_PATH%\" >nul 2>nul
    echo        Done: Selected technology packs
)

:: STEP 3: Process
echo.
echo  [3/6] Process rules...
for %%f in ("%FRAMEWORK_PATH%\process\*.mdc") do copy /Y "%%f" "%TARGET_PATH%\" >nul
echo        Done: process-analysis, process-architecture, process-documentation

:: STEP 4: Domain
echo.
echo  [4/6] Domain selection:
echo    1) WMS (Warehouse Management)
echo    2) E-Commerce
echo    3) Both
echo    0) None
echo.
set /p DOMAIN_CHOICE="  Select: "

if "%DOMAIN_CHOICE%"=="1" for %%f in ("%FRAMEWORK_PATH%\domains\wms\*.mdc") do copy /Y "%%f" "%TARGET_PATH%\" >nul
if "%DOMAIN_CHOICE%"=="2" for %%f in ("%FRAMEWORK_PATH%\domains\ecommerce\*.mdc") do copy /Y "%%f" "%TARGET_PATH%\" >nul
if "%DOMAIN_CHOICE%"=="3" (
    for %%f in ("%FRAMEWORK_PATH%\domains\wms\*.mdc") do copy /Y "%%f" "%TARGET_PATH%\" >nul
    for %%f in ("%FRAMEWORK_PATH%\domains\ecommerce\*.mdc") do copy /Y "%%f" "%TARGET_PATH%\" >nul
)
echo        Done

:: STEP 5: Learning + Docs
echo.
echo  [5/6] Learning system + docs structure...
copy /Y "%FRAMEWORK_PATH%\learning\agent-learning.mdc" "%TARGET_PATH%\" >nul

for %%d in (agents agents\requirements agents\decisions agents\contracts agents\handoffs agents\reviews) do (
    if not exist "%PROJECT_PATH%\docs\%%d" mkdir "%PROJECT_PATH%\docs\%%d"
)

if exist "%FRAMEWORK_PATH%\standards" (
    for %%f in ("%FRAMEWORK_PATH%\standards\*.md") do copy /Y "%%f" "%PROJECT_PATH%\docs\agents\" >nul
)

if not exist "%PROJECT_PATH%\docs\agents\lessons-learned.md" (
    echo # Proje Ogrenme Gunlugu > "%PROJECT_PATH%\docs\agents\lessons-learned.md"
)
echo        Done

:: STEP 6: Aliases
echo.
echo  [6/6] Creating aliases...
if exist "%TARGET_PATH%\orchestrator.mdc"          copy /Y "%TARGET_PATH%\orchestrator.mdc"          "%TARGET_PATH%\sef.mdc" >nul
if exist "%TARGET_PATH%\code-quality.mdc"          copy /Y "%TARGET_PATH%\code-quality.mdc"          "%TARGET_PATH%\review.mdc" >nul
if exist "%TARGET_PATH%\tech-dotnet.mdc"           copy /Y "%TARGET_PATH%\tech-dotnet.mdc"           "%TARGET_PATH%\backend.mdc" >nul
if exist "%TARGET_PATH%\tech-react.mdc"            copy /Y "%TARGET_PATH%\tech-react.mdc"            "%TARGET_PATH%\frontend.mdc" >nul
if exist "%TARGET_PATH%\tech-testing.mdc"          copy /Y "%TARGET_PATH%\tech-testing.mdc"          "%TARGET_PATH%\qa.mdc" >nul
if exist "%TARGET_PATH%\tech-sql-server.mdc"       copy /Y "%TARGET_PATH%\tech-sql-server.mdc"       "%TARGET_PATH%\db.mdc" >nul
if exist "%TARGET_PATH%\tech-security.mdc"         copy /Y "%TARGET_PATH%\tech-security.mdc"         "%TARGET_PATH%\guvenlik.mdc" >nul
if exist "%TARGET_PATH%\tech-devops.mdc"           copy /Y "%TARGET_PATH%\tech-devops.mdc"           "%TARGET_PATH%\devops.mdc" >nul
if exist "%TARGET_PATH%\tech-maui.mdc"             copy /Y "%TARGET_PATH%\tech-maui.mdc"             "%TARGET_PATH%\mobil.mdc" >nul
if exist "%TARGET_PATH%\tech-ai-ml.mdc"            copy /Y "%TARGET_PATH%\tech-ai-ml.mdc"            "%TARGET_PATH%\ai.mdc" >nul
if exist "%TARGET_PATH%\process-architecture.mdc"  copy /Y "%TARGET_PATH%\process-architecture.mdc"  "%TARGET_PATH%\mimari.mdc" >nul
if exist "%TARGET_PATH%\process-analysis.mdc"      copy /Y "%TARGET_PATH%\process-analysis.mdc"      "%TARGET_PATH%\analist.mdc" >nul
if exist "%TARGET_PATH%\process-documentation.mdc" copy /Y "%TARGET_PATH%\process-documentation.mdc" "%TARGET_PATH%\dokumantasyon.mdc" >nul
echo        Done: @sef @backend @frontend @qa @db @guvenlik @mimari @analist ...

:: DONE
echo.
echo  ════════════════════════════════════════════════
echo   Cursor Agents Framework installed!
echo.
echo   Next steps:
echo   1. Open project in Cursor
echo   2. Edit .cursor/rules/global-conventions.mdc
echo   3. Start with @sef for task coordination
echo  ════════════════════════════════════════════════
echo.
pause
