Set-StrictMode -Version Latest

function Get-Sha256Hex {
    param(
        [Parameter(Mandatory = $true)][string]$InputText
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputText)
        $hashBytes = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function New-EventStore {
    param(
        [Parameter(Mandatory = $true)][string]$DocsPath
    )

    $runtimeDir = Join-Path $DocsPath "runtime"
    if (-not (Test-Path $runtimeDir)) {
        New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
    }
    $eventPath = Join-Path $runtimeDir "state-events.jsonl"
    if (-not (Test-Path $eventPath)) {
        New-Item -ItemType File -Path $eventPath -Force | Out-Null
    }
    return $eventPath
}

function Get-ExecutionHead {
    param(
        [Parameter(Mandatory = $true)][string]$EventPath,
        [Parameter(Mandatory = $true)][string]$ExecutionId
    )

    $events = @(Get-StateEvents -EventPath $EventPath -ExecutionId $ExecutionId -Strict)
    if ($events.Length -eq 0 -or $null -eq $events[0]) {
        return @{
            next_seq = 1
            prev_hash = "genesis"
        }
    }

    $last = $events[-1]
    return @{
        next_seq = ([int]$last.event_seq + 1)
        prev_hash = [string]$last.event_hash
    }
}

function Add-StateEvent {
    param(
        [Parameter(Mandatory = $true)][string]$EventPath,
        [Parameter(Mandatory = $true)][string]$ExecutionId,
        [Parameter(Mandatory = $true)][string]$JobId,
        [Parameter(Mandatory = $true)][string]$EventType,
        [Parameter(Mandatory = $true)][hashtable]$Payload,
        [string]$IdempotencyKey = "",
        [int]$StateVersion = 1
    )

    if ($IdempotencyKey) {
        $existing = Get-StateEvents -EventPath $EventPath -ExecutionId $ExecutionId
        foreach ($evt in $existing) {
            if (($evt.PSObject.Properties.Name -contains "idempotency_key") -and ([string]$evt.idempotency_key -eq $IdempotencyKey)) {
                return $evt
            }
        }
    }

    $head = Get-ExecutionHead -EventPath $EventPath -ExecutionId $ExecutionId
    $eventEnvelope = @{
        event_schema_version = 1
        event_seq = $head.next_seq
        timestamp = (Get-Date).ToString("o")
        execution_id = $ExecutionId
        job_id = $JobId
        event_type = $EventType
        state_version = $StateVersion
        prev_event_hash = $head.prev_hash
        idempotency_key = $IdempotencyKey
        payload = $Payload
    }
    $eventPayload = $eventEnvelope | ConvertTo-Json -Depth 12 -Compress
    $eventHash = Get-Sha256Hex -InputText $eventPayload
    $eventEnvelope.event_hash = $eventHash
    $evt = $eventEnvelope | ConvertTo-Json -Depth 12 -Compress

    $lockPath = "$EventPath.lock"
    $lockFile = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    try {
        $writer = [System.IO.StreamWriter]::new($EventPath, $true, [System.Text.Encoding]::UTF8)
        try {
            $writer.WriteLine($evt)
            $writer.Flush()
        } finally {
            $writer.Dispose()
        }
    } finally {
        $lockFile.Dispose()
    }

    return $eventEnvelope
}

function Get-StateEvents {
    param(
        [Parameter(Mandatory = $true)][string]$EventPath,
        [string]$ExecutionId = "",
        [switch]$Strict
    )

    if (-not (Test-Path $EventPath)) { return @() }
    $lines = Get-Content $EventPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $events = @()
    $seqSeen = @{}
    foreach ($line in $lines) {
        try {
            $evt = $line | ConvertFrom-Json -ErrorAction Stop
            if (-not $ExecutionId -or $evt.execution_id -eq $ExecutionId) {
                if ($Strict) {
                    if (-not $evt.event_seq -or -not $evt.event_hash -or -not $evt.prev_event_hash -or -not $evt.event_schema_version) {
                        throw "Missing strict event fields."
                    }
                    $seqKey = [string]$evt.event_seq
                    if ($seqSeen.ContainsKey($seqKey)) {
                        throw "Duplicate event_seq for execution."
                    }
                    $seqSeen[$seqKey] = $true
                }
                $events += $evt
            }
        } catch {
            if ($Strict) {
                throw "Invalid event line in ${EventPath}: $($_.Exception.Message)"
            }
            continue
        }
    }
    $events = @($events | Sort-Object -Property event_seq, timestamp)
    return $events
}

function Get-ReplayedState {
    param(
        [Parameter(Mandatory = $true)][string]$EventPath,
        [Parameter(Mandatory = $true)][string]$ExecutionId
    )

    $events = Get-StateEvents -EventPath $EventPath -ExecutionId $ExecutionId -Strict
    $state = @{}
    $expectedSeq = 1
    $previousHash = "genesis"
    foreach ($evt in $events) {
        if ([int]$evt.event_seq -ne $expectedSeq) {
            throw "Event sequence gap detected at seq $expectedSeq"
        }
        if ([string]$evt.prev_event_hash -ne $previousHash) {
            throw "Hash chain broken at seq $expectedSeq"
        }

        $verificationPayload = @{
            event_schema_version = $evt.event_schema_version
            event_seq = [int]$evt.event_seq
            timestamp = [string]$evt.timestamp
            execution_id = [string]$evt.execution_id
            job_id = [string]$evt.job_id
            event_type = [string]$evt.event_type
            state_version = [int]$evt.state_version
            prev_event_hash = [string]$evt.prev_event_hash
            idempotency_key = [string]$evt.idempotency_key
            payload = $evt.payload
        } | ConvertTo-Json -Depth 12 -Compress
        $computedHash = Get-Sha256Hex -InputText $verificationPayload
        if ([string]$evt.event_hash -ne $computedHash) {
            throw "Event hash mismatch at seq $expectedSeq"
        }

        if ($evt.payload) {
            foreach ($p in $evt.payload.PSObject.Properties) {
                $state[$p.Name] = $p.Value
            }
        }
        $state["last_event_seq"] = [int]$evt.event_seq
        $state["last_event_hash"] = [string]$evt.event_hash
        $state["last_event_type"] = $evt.event_type
        $state["last_event_timestamp"] = $evt.timestamp
        $expectedSeq++
        $previousHash = [string]$evt.event_hash
    }
    return $state
}

Export-ModuleMember -Function @(
    "Get-Sha256Hex",
    "New-EventStore",
    "Get-ExecutionHead",
    "Add-StateEvent",
    "Get-StateEvents",
    "Get-ReplayedState"
)
