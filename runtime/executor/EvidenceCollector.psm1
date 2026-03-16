Set-StrictMode -Version Latest

function ConvertTo-NativeHashtable {
    param([object]$InputObject)

    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in $InputObject.Keys) {
            $result[$key] = ConvertTo-NativeHashtable -InputObject $InputObject[$key]
        }
        return $result
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $items = @()
        foreach ($item in $InputObject) {
            $items += ConvertTo-NativeHashtable -InputObject $item
        }
        return $items
    }
    if ($InputObject -is [pscustomobject]) {
        $result = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $result[$property.Name] = ConvertTo-NativeHashtable -InputObject $property.Value
        }
        return $result
    }
    return $InputObject
}

function Get-CommandMapFromFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Evidence command map not found: $Path"
    }

    return ConvertTo-NativeHashtable -InputObject (Get-Content $Path -Raw | ConvertFrom-Json)
}

function Get-EvidenceCommandMap {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("generic","dotnet","node","python")][string]$StackAdapter,
        [Parameter(Mandatory = $true)][ValidateSet("G4","G5","G6")][string]$GateId
    )

    $maps = @{
        generic = @{
            G4 = @{
                build_status = "Write-Error 'Generic adapter cannot verify build_status'; exit 2"
                lint_status = "Write-Error 'Generic adapter cannot verify lint_status'; exit 2"
                security_status = "Write-Error 'Generic adapter cannot verify security_status'; exit 2"
                documentation_status = "if (Test-Path 'docs/agents') { exit 0 } else { exit 1 }"
            }
            G5 = @{
                test_status = "Write-Error 'Generic adapter cannot verify test_status'; exit 2"
                coverage_status = "Write-Error 'Generic adapter cannot verify coverage_status'; exit 2"
                documentation_status = "if (Test-Path 'docs/agents') { exit 0 } else { exit 1 }"
            }
            G6 = @{
                review_status = "if ((Test-Path 'docs/agents/reviews') -or (Test-Path 'docs/agents/quality-gates')) { exit 0 } else { exit 1 }"
                security_status = "Write-Error 'Generic adapter cannot verify security_status'; exit 2"
                documentation_status = "if (Test-Path 'docs/agents') { exit 0 } else { exit 1 }"
            }
        }
        dotnet = @{
            G4 = @{
                build_status = "dotnet build --nologo"
                lint_status = "dotnet format --verify-no-changes"
                security_status = "dotnet list package --vulnerable"
                documentation_status = "if (Test-Path 'docs/agents') { exit 0 } else { exit 1 }"
            }
            G5 = @{
                test_status = "dotnet test --nologo"
                coverage_status = "dotnet test --collect:`"XPlat Code Coverage`" --nologo"
                documentation_status = "if (Test-Path 'docs/agents') { exit 0 } else { exit 1 }"
            }
            G6 = @{
                review_status = "if ((Test-Path 'docs/agents/reviews') -or (Test-Path 'docs/agents/quality-gates')) { exit 0 } else { exit 1 }"
                security_status = "dotnet list package --vulnerable"
                documentation_status = "if (Test-Path 'docs/agents') { exit 0 } else { exit 1 }"
            }
        }
        node = @{
            G4 = @{
                build_status = "npm run build --if-present"
                lint_status = "npm run lint --if-present"
                security_status = "npm audit --audit-level=high"
                documentation_status = "if (Test-Path 'docs/agents') { exit 0 } else { exit 1 }"
            }
            G5 = @{
                test_status = "npm test --if-present"
                coverage_status = "npm run coverage --if-present"
                documentation_status = "if (Test-Path 'docs/agents') { exit 0 } else { exit 1 }"
            }
            G6 = @{
                review_status = "if ((Test-Path 'docs/agents/reviews') -or (Test-Path 'docs/agents/quality-gates')) { exit 0 } else { exit 1 }"
                security_status = "npm audit --audit-level=high"
                documentation_status = "if (Test-Path 'docs/agents') { exit 0 } else { exit 1 }"
            }
        }
        python = @{
            G4 = @{
                build_status = "python -m py_compile $(Get-ChildItem -Recurse -Filter *.py | Select-Object -ExpandProperty FullName)"
                lint_status = "python -m ruff check ."
                security_status = "python -m pip_audit"
                documentation_status = "if (Test-Path 'docs/agents') { exit 0 } else { exit 1 }"
            }
            G5 = @{
                test_status = "python -m pytest -q"
                coverage_status = "python -m pytest --cov"
                documentation_status = "if (Test-Path 'docs/agents') { exit 0 } else { exit 1 }"
            }
            G6 = @{
                review_status = "if ((Test-Path 'docs/agents/reviews') -or (Test-Path 'docs/agents/quality-gates')) { exit 0 } else { exit 1 }"
                security_status = "python -m pip_audit"
                documentation_status = "if (Test-Path 'docs/agents') { exit 0 } else { exit 1 }"
            }
        }
    }

    return $maps[$StackAdapter][$GateId]
}

function Test-CommandAllowed {
    param(
        [Parameter(Mandatory = $true)][string]$Command
    )

    $allowPatterns = @(
        "^\s*dotnet\s+",
        "^\s*npm\s+",
        "^\s*python\s+",
        "^\s*pytest\s+",
        "^\s*pwsh\s+",
        "^\s*powershell\s+",
        "powershell(\.exe)?\s+",
        "pwsh(\.exe)?\s+",
        "^\s*if\s+\(",
        "^\s*Test-Path\s+"
    )
    foreach ($pattern in $allowPatterns) {
        if ($Command -match $pattern) { return $true }
    }
    return $false
}

function Invoke-EvidenceProbe {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [int]$TimeoutSeconds = 120,
        [string]$Shell = "",
        [switch]$DisableAllowList
    )

    $host = $Shell
    if (-not $host) {
        $hostCmd = Get-Command pwsh -ErrorAction SilentlyContinue
        if (-not $hostCmd) { $hostCmd = Get-Command powershell -ErrorAction SilentlyContinue }
        if (-not $hostCmd) { throw "PowerShell host not found for evidence probe." }
        $host = $hostCmd.Source
    }

    if (-not $DisableAllowList -and -not (Test-CommandAllowed -Command $Command)) {
        return @{
            name = $Name
            command = $Command
            exit_code = 1001
            output = "Command rejected by allowlist."
            status = "not_verified"
            failure_type = "policy_violation"
        }
    }

    if (-not (Test-Path $WorkingDirectory)) {
        return @{
            name = $Name
            command = $Command
            exit_code = 1002
            output = "Working directory not found: $WorkingDirectory"
            status = "not_verified"
            failure_type = "insufficient_context"
        }
    }

    $job = Start-Job -ScriptBlock {
        param($shellExe, $wd, $cmd)
        Set-Location $wd
        $result = & $shellExe -NoProfile -Command $cmd 2>&1
        return @{
            output = ($result | Out-String)
            exit_code = $LASTEXITCODE
        }
    } -ArgumentList $host, $WorkingDirectory, $Command

    $finished = Wait-Job -Job $job -Timeout $TimeoutSeconds
    if (-not $finished) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue | Out-Null
        return @{
            name = $Name
            command = $Command
            exit_code = 1003
            output = "Timed out after $TimeoutSeconds seconds."
            status = "not_verified"
            failure_type = "timeout"
        }
    }

    $jobResult = Receive-Job -Job $job
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue | Out-Null
    $exitCode = if ($jobResult -and $jobResult.exit_code -ne $null) { [int]$jobResult.exit_code } else { 1 }
    $outputText = if ($jobResult -and $jobResult.output) { [string]$jobResult.output } else { "" }
    if ($outputText.Length -gt 4000) {
        $outputText = $outputText.Substring(0, 4000)
    }

    $failureType = if ($exitCode -eq 0) {
        "none"
    } elseif ($exitCode -eq 2) {
        "insufficient_context"
    } else {
        "test_failure"
    }

    return @{
        name = $Name
        command = $Command
        exit_code = $exitCode
        output = $outputText.Trim()
        status = if ($exitCode -eq 0) { "verified" } else { "not_verified" }
        failure_type = $failureType
    }
}

function Collect-GateEvidence {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("G4","G5","G6")][string]$GateId,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [hashtable]$CommandMap,
        [string]$CommandMapPath = "",
        [ValidateSet("generic","dotnet","node","python")][string]$StackAdapter = "generic",
        [string]$DocsPath = "",
        [string]$JobId = "",
        [string]$ExecutionId = "",
        [int]$TimeoutSeconds = 120
    )

    $mapping = if ($CommandMap) {
        $CommandMap
    } elseif ($CommandMapPath) {
        $loaded = Get-CommandMapFromFile -Path $CommandMapPath
        if (-not $loaded.ContainsKey($GateId)) {
            throw "Evidence command map does not contain gate $GateId"
        }
        $loaded[$GateId]
    } else {
        Get-EvidenceCommandMap -StackAdapter $StackAdapter -GateId $GateId
    }
    $results = @{}
    $evidenceDir = ""
    if ($DocsPath -and $JobId) {
        $evidenceDir = Join-Path (Join-Path $DocsPath "runtime") "evidence"
        New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null
    }

    foreach ($field in $mapping.Keys) {
        $probe = Invoke-EvidenceProbe -Name $field -Command $mapping[$field] -WorkingDirectory $WorkingDirectory -TimeoutSeconds $TimeoutSeconds
        $logRef = ""
        if ($evidenceDir) {
            $fileName = "{0}-{1}-{2}.log" -f $GateId, $JobId, $field
            $logPath = Join-Path $evidenceDir $fileName
            @(
                "gate_id=$GateId"
                "job_id=$JobId"
                "execution_id=$ExecutionId"
                "field=$field"
                "status=$($probe.status)"
                "exit_code=$($probe.exit_code)"
                "command=$($probe.command)"
                ""
                $probe.output
            ) | Set-Content -Path $logPath
            $logRef = "docs/agents/runtime/evidence/$fileName"
        }
        $results[$field] = @{
            status = $probe.status
            command = $probe.command
            exit_code = $probe.exit_code
            output = $probe.output
            failure_type = $probe.failure_type
            evidence_ref = $logRef
        }
    }

    return $results
}

Export-ModuleMember -Function @(
    "Get-CommandMapFromFile",
    "Get-EvidenceCommandMap",
    "Test-CommandAllowed",
    "Invoke-EvidenceProbe",
    "Collect-GateEvidence"
)
