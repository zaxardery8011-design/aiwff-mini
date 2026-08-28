# Measure-ContextSegments.ps1 — context window analyzer (read-only)
#
# 讀一個 session history.jsonl，計算 per-turn token estimate（chars / 3.5）
# 列 segment size + freshness (turns ago) + tool type；輸出 markdown report
# Read-only: never edits history, never prunes anything.
#
# Instrumentation only. Collect data first, decide what to prune later.
# Accumulate samples for a week or two before deciding on any pruning strategy.
#
# Usage:
#   pwsh -NoProfile -File Measure-ContextSegments.ps1 -HistoryPath <jsonl>
#   pwsh -NoProfile -File Measure-ContextSegments.ps1 -HistoryPath <jsonl> -OutputJsonl <path>
#
# 退 0 即 PASS（即使 history 空也 0；真 IO error 才非 0）。

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$HistoryPath,
    [int]$LargeBytesThreshold = 5120,
    [int]$OldTurnThreshold = 20,
    [string]$OutputJsonl = '',
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Estimate-Tokens([int]$bytes) {
    if ($bytes -le 0) { return 0 }
    return [int][Math]::Ceiling($bytes / 3.5)
}

function Get-SegmentBytes($obj) {
    # 粗估：把 obj 重新序列化算 char 長度
    try {
        $s = $obj | ConvertTo-Json -Depth 20 -Compress
        return [System.Text.Encoding]::UTF8.GetByteCount($s)
    } catch {
        return 0
    }
}

function Get-ToolName($contentBlock) {
    if ($contentBlock.type -eq 'tool_use') { return $contentBlock.name }
    if ($contentBlock.type -eq 'tool_result') { return 'tool_result' }
    if ($contentBlock.type -eq 'text') { return 'text' }
    if ($contentBlock.type -eq 'thinking') { return 'thinking' }
    return $contentBlock.type
}

if (-not (Test-Path -LiteralPath $HistoryPath)) {
    Write-Error "HistoryPath not found: $HistoryPath"
    exit 2
}

$turns = New-Object System.Collections.ArrayList
$currentTurn = $null
$turnIdx = 0
$lineNo = 0
$totalBytes = 0
$largeSegments = New-Object System.Collections.ArrayList
$refCount = 0

# memory ref pattern: [[name]]
$refRegex = [regex]'\[\[[a-z0-9_\-]+\]\]'

$reader = [System.IO.File]::OpenText($HistoryPath)
try {
    while (-not $reader.EndOfStream) {
        $line = $reader.ReadLine()
        $lineNo++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $obj = $null
        try { $obj = $line | ConvertFrom-Json -ErrorAction Stop } catch { continue }

        $type = $obj.type
        if (-not $type) { continue }

        # user message starts a new turn (excluding queue-operation noise)
        if ($type -eq 'user') {
            if ($null -ne $currentTurn) { [void]$turns.Add($currentTurn) }
            $turnIdx++
            $currentTurn = [pscustomobject]@{
                idx = $turnIdx
                ts = $obj.timestamp
                bytes = 0
                tokens_est = 0
                segments = New-Object System.Collections.ArrayList
                tools = New-Object System.Collections.ArrayList
                has_large = $false
            }
        }

        if ($null -eq $currentTurn) {
            # pre-first-turn (queue-ops, attachments) — count into a phantom turn 0
            $currentTurn = [pscustomobject]@{
                idx = 0
                ts = $obj.timestamp
                bytes = 0
                tokens_est = 0
                segments = New-Object System.Collections.ArrayList
                tools = New-Object System.Collections.ArrayList
                has_large = $false
            }
        }

        # walk content blocks if assistant/user message
        $blocks = $null
        if ($obj.message -and $obj.message.content) {
            $blocks = $obj.message.content
        } elseif ($obj.content) {
            $blocks = $obj.content
        }

        if ($blocks) {
            foreach ($b in $blocks) {
                $bytes = Get-SegmentBytes $b
                $tool = Get-ToolName $b
                $currentTurn.bytes += $bytes
                $totalBytes += $bytes
                [void]$currentTurn.segments.Add([pscustomobject]@{ tool = $tool; bytes = $bytes })
                if ($tool -and $tool -notin $currentTurn.tools) { [void]$currentTurn.tools.Add($tool) }
                if ($bytes -ge $LargeBytesThreshold) {
                    $currentTurn.has_large = $true
                    [void]$largeSegments.Add([pscustomobject]@{
                        turn = $currentTurn.idx
                        tool = $tool
                        bytes = $bytes
                    })
                }
                # crude reference count via [[name]] in text/tool_result
                if ($b.text) {
                    $matches = $refRegex.Matches($b.text)
                    if ($matches.Count -gt 0) { $refCount += $matches.Count }
                }
                if ($b.content -is [string]) {
                    $matches = $refRegex.Matches($b.content)
                    if ($matches.Count -gt 0) { $refCount += $matches.Count }
                }
            }
        } else {
            # attachment / queue-op — count attachment payload size cheaply
            $bytes = Get-SegmentBytes $obj
            $currentTurn.bytes += $bytes
            $totalBytes += $bytes
            $kind = if ($obj.attachment.type) { $obj.attachment.type } else { $type }
            [void]$currentTurn.segments.Add([pscustomobject]@{ tool = $kind; bytes = $bytes })
            if ($bytes -ge $LargeBytesThreshold) {
                $currentTurn.has_large = $true
                [void]$largeSegments.Add([pscustomobject]@{
                    turn = $currentTurn.idx
                    tool = $kind
                    bytes = $bytes
                })
            }
        }
    }
    if ($null -ne $currentTurn) { [void]$turns.Add($currentTurn) }
} finally {
    $reader.Dispose()
}

# Tally per-turn token estimates
foreach ($t in $turns) { $t.tokens_est = Estimate-Tokens $t.bytes }

$totalTokens = Estimate-Tokens $totalBytes
$turnCount = ($turns | Where-Object { $_.idx -gt 0 }).Count
$latestIdx = if ($turnCount -gt 0) { ($turns[-1]).idx } else { 0 }

# Build markdown report
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# Context Segment Report")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("History: ``$HistoryPath``")
[void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Summary")
[void]$sb.AppendLine("- lines parsed: $lineNo")
[void]$sb.AppendLine("- turns (user-message anchored): $turnCount")
[void]$sb.AppendLine("- total bytes: $totalBytes")
[void]$sb.AppendLine("- total tokens est (chars/3.5): $totalTokens")
[void]$sb.AppendLine("- large segments (>= ${LargeBytesThreshold} bytes): $($largeSegments.Count)")
[void]$sb.AppendLine("- memory refs ``[[name]]`` seen: $refCount")
[void]$sb.AppendLine("- old turn threshold: > $OldTurnThreshold turns ago is 'old'")
[void]$sb.AppendLine("")

if ($turnCount -gt 0) {
    [void]$sb.AppendLine("## Top 10 heaviest turns")
    [void]$sb.AppendLine("| turn | bytes | tokens_est | age | tools | large? |")
    [void]$sb.AppendLine("|---|---|---|---|---|---|")
    $sortedTurns = $turns | Where-Object { $_.idx -gt 0 } | Sort-Object -Property bytes -Descending | Select-Object -First 10
    foreach ($t in $sortedTurns) {
        $age = $latestIdx - $t.idx
        $isOld = if ($age -gt $OldTurnThreshold) { 'OLD' } else { '' }
        $toolList = ($t.tools -join ',')
        if ($toolList.Length -gt 50) { $toolList = $toolList.Substring(0, 47) + '...' }
        $large = if ($t.has_large) { 'Y' } else { '' }
        [void]$sb.AppendLine("| $($t.idx) | $($t.bytes) | $($t.tokens_est) | $age $isOld | $toolList | $large |")
    }
    [void]$sb.AppendLine("")
}

if ($largeSegments.Count -gt 0) {
    [void]$sb.AppendLine("## Top 10 largest segments")
    [void]$sb.AppendLine("| turn | tool | bytes |")
    [void]$sb.AppendLine("|---|---|---|")
    $top = $largeSegments | Sort-Object -Property bytes -Descending | Select-Object -First 10
    foreach ($s in $top) {
        [void]$sb.AppendLine("| $($s.turn) | $($s.tool) | $($s.bytes) |")
    }
    [void]$sb.AppendLine("")
}

# Old (>OldTurnThreshold) large tool output — the obvious pruning candidates
$oldLarge = $largeSegments | Where-Object {
    $age = $latestIdx - $_.turn
    ($age -gt $OldTurnThreshold) -and ($_.tool -notin @('text','thinking','user','message'))
}
[void]$sb.AppendLine("## Pruning candidates (old + large tool output)")
[void]$sb.AppendLine("- count: $($oldLarge.Count)")
[void]$sb.AppendLine("- combined bytes: $(($oldLarge | Measure-Object -Property bytes -Sum).Sum)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("> This tool is read-only: nothing is pruned. The list above is informational.")

$report = $sb.ToString()
if (-not $Quiet) { Write-Output $report }

# Optional jsonl append (one summary line)
if ($OutputJsonl) {
    $rec = [pscustomobject]@{
        ts = (Get-Date).ToString('o')
        kind = 'measure'
        history_path = $HistoryPath
        lines = $lineNo
        turn_count = $turnCount
        total_bytes = $totalBytes
        total_tokens_est = $totalTokens
        large_segments = $largeSegments.Count
        reference_count = $refCount
        old_large_candidates = $oldLarge.Count
        old_large_bytes = (($oldLarge | Measure-Object -Property bytes -Sum).Sum)
    }
    $json = ($rec | ConvertTo-Json -Compress -Depth 10)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::AppendAllText($OutputJsonl, ($json + "`n"), $utf8)
}

exit 0
