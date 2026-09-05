#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $HOME ".aiwff-mini"),
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$BrainName,
    [string]$KitSource = $PSScriptRoot
)

$ErrorActionPreference = "Stop"
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$script:Failed = $false

function Write-Check {
    param(
        [string]$Name,
        [bool]$Ok,
        [string]$Detail = ""
    )

    if ($Ok) {
        Write-Output ("✅ " + $Name)
    } else {
        $script:Failed = $true
        if ($Detail) {
            Write-Output ("❌ " + $Name + " - " + $Detail)
        } else {
            Write-Output ("❌ " + $Name)
        }
    }
}

function Write-Utf8BomFile {
    param(
        [string]$Path,
        [string]$Text
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $encoding = New-Object System.Text.UTF8Encoding -ArgumentList $true
    [System.IO.File]::WriteAllText($Path, $Text, $encoding)
}

function Get-Sha256 {
    param([string]$Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Clear-ReadOnlyAttribute {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $item = Get-Item -LiteralPath $Path
        if (($item.Attributes -band [System.IO.FileAttributes]::ReadOnly) -ne 0) {
            Set-ItemProperty -LiteralPath $Path -Name IsReadOnly -Value $false
        }
    }
}

function Backup-ExistingFile {
    param(
        [string]$Path,
        [string]$Timestamp
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    Clear-ReadOnlyAttribute -Path $Path
    $backup = $Path + ".bak." + $Timestamp
    Copy-Item -LiteralPath $Path -Destination $backup -Force
    Write-Output ("備份既有檔案: " + $Path + " -> " + $backup)
}

function Copy-ManagedFile {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Timestamp
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "missing kit file: $Source"
    }

    $sourceText = Get-Content -LiteralPath $Source -Raw -Encoding UTF8
    $needsCopy = $true
    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        Clear-ReadOnlyAttribute -Path $Destination
        $destinationText = Get-Content -LiteralPath $Destination -Raw -Encoding UTF8
        $needsCopy = ($sourceText -ne $destinationText)
        if ($needsCopy) {
            Backup-ExistingFile -Path $Destination -Timestamp $Timestamp
        } else {
            Write-Output ("保留既有檔案（內容相同）: " + $Destination)
        }
    }

    if ($needsCopy) {
        Write-Utf8BomFile -Path $Destination -Text $sourceText
        Write-Output ("寫入檔案: " + $Destination)
    }
}

function Write-ManagedTextFile {
    param(
        [string]$Path,
        [string]$Text,
        [string]$Timestamp,
        [switch]$AlwaysRewrite,
        [switch]$PreserveExisting
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        if ($PreserveExisting) {
            Write-Output ("保留既有檔案: " + $Path)
            return
        }

        $current = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ((-not $AlwaysRewrite) -and ($current -eq $Text)) {
            Write-Output ("保留既有檔案（內容相同）: " + $Path)
            return
        }

        Backup-ExistingFile -Path $Path -Timestamp $Timestamp
    }

    Write-Utf8BomFile -Path $Path -Text $Text
    Write-Output ("寫入檔案: " + $Path)
}

function Set-JsonPropertyValue {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Value
    )

    if ($Object.PSObject.Properties[$Name]) {
        $Object.$Name = $Value
    } else {
        Add-Member -InputObject $Object -MemberType NoteProperty -Name $Name -Value $Value
    }
}

function Find-PwshExe {
    $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if ($pwsh) { return $pwsh.Source }

    $pwshNoExtension = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshNoExtension) { return $pwshNoExtension.Source }

    throw "PowerShell 7 not found. Install it with: winget install --id Microsoft.PowerShell"
}

function ConvertTo-HookPath {
    param([string]$Path)
    return ($Path -replace '\\', '/')
}

function Quote-CommandArgument {
    param([string]$Value)
    return '"' + ($Value -replace '"', '\"') + '"'
}

function ConvertTo-PowerShellSingleQuotedString {
    param([string]$Value)
    return "'" + ($Value -replace "'", "''") + "'"
}

function Get-OptionalGitOutput {
    param([string[]]$Arguments)

    try {
        $git = Get-Command git -ErrorAction SilentlyContinue
        if (-not $git) { return $null }

        $output = & $git.Source @Arguments 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }

        return (($output | Out-String).Trim())
    } catch {
        return $null
    }
}

function Merge-SessionStartHook {
    param(
        [string]$SettingsPath,
        [string]$Command,
        [string]$Timestamp
    )

    $settingsDir = Split-Path -Parent $SettingsPath
    if (-not (Test-Path -LiteralPath $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    }

    if (Test-Path -LiteralPath $SettingsPath -PathType Leaf) {
        $raw = Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8
        if ($raw.Trim()) {
            $settings = $raw | ConvertFrom-Json
        } else {
            $settings = New-Object PSObject
        }
    } else {
        $settings = New-Object PSObject
    }

    if (-not $settings.PSObject.Properties["hooks"] -or -not $settings.hooks) {
        Set-JsonPropertyValue -Object $settings -Name "hooks" -Value (New-Object PSObject)
    }

    $sessionStart = @()
    if ($settings.hooks.PSObject.Properties["SessionStart"] -and $settings.hooks.SessionStart) {
        $sessionStart = @($settings.hooks.SessionStart)
    }

    $alreadyInstalled = $false
    foreach ($entry in $sessionStart) {
        if ($entry -and $entry.PSObject.Properties["hooks"]) {
            foreach ($hook in @($entry.hooks)) {
                if ($hook -and $hook.PSObject.Properties["command"] -and $hook.command -eq $Command) {
                    $alreadyInstalled = $true
                }
            }
        }
    }

    if (-not $alreadyInstalled) {
        $newHook = New-Object PSObject -Property ([ordered]@{
            type = "command"
            command = $Command
            timeout = 10
        })
        $newEntry = New-Object PSObject -Property ([ordered]@{
            hooks = @($newHook)
        })
        $sessionStart += $newEntry
    }

    Set-JsonPropertyValue -Object $settings.hooks -Name "SessionStart" -Value @($sessionStart)
    $json = ($settings | ConvertTo-Json -Depth 20) + "`r`n"
    Write-ManagedTextFile -Path $SettingsPath -Text $json -Timestamp $Timestamp
}

try {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "PowerShell 7.0 or newer is required. Install it with: winget install --id Microsoft.PowerShell"
    }
    if (-not $KitSource) { $KitSource = $PSScriptRoot }
    if (-not $BrainName.Trim()) { throw "BrainName is required." }

    $InstallRoot = [System.IO.Path]::GetFullPath($InstallRoot)
    $KitSource = [System.IO.Path]::GetFullPath($KitSource)
    $sourceRoot = Split-Path -Parent $KitSource
    $devTreeMarker = Join-Path $KitSource ".dev-tree"

    if (Test-Path -LiteralPath $devTreeMarker -PathType Leaf) {
        throw "Refusing to install from the author's development tree: found kit/.dev-tree at $devTreeMarker"
    }

    Write-Output "開發樹防呆檢查: kit/.dev-tree 未命中（唯一停止條件）"
    if (($sourceRoot -replace '\\', '/') -match '(^|/)(docs|dist-src|open_source_prep)(/|$)') {
        Write-Output ("輔助訊號: source path contains docs/dist-src/open_source_prep fragment: " + $sourceRoot + "（只提示，不作為停止條件）")
    } else {
        Write-Output ("輔助訊號: source path fragment 未命中: " + $sourceRoot)
    }

    $gitRemote = Get-OptionalGitOutput -Arguments @("-C", $sourceRoot, "remote", "get-url", "origin")
    if ($gitRemote) {
        Write-Output ("輔助訊號: git origin remote=" + $gitRemote + "（clone copy 會命中，這只提示，不作為停止條件）")
    } else {
        Write-Output "輔助訊號: git origin remote 不可查或不存在（只提示，不作為停止條件）"
    }

    $gitChanges = Get-OptionalGitOutput -Arguments @("-C", $sourceRoot, "status", "--porcelain")
    if ($gitChanges) {
        Write-Output "輔助訊號: git local changes present（只提示，不作為停止條件）"
    } else {
        Write-Output "輔助訊號: git local changes 未命中或不可查（只提示，不作為停止條件）"
    }

    Write-Output ("aiwff-mini 安裝目標: " + $InstallRoot)
    Write-Output ("主腦名稱: " + $BrainName)
    Write-Output ("Kit source: " + $KitSource)

    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null

    $requiredDirs = @("memory", ".soul_baseline", ".claude")
    foreach ($dirName in $requiredDirs) {
        New-Item -ItemType Directory -Path (Join-Path $InstallRoot $dirName) -Force | Out-Null
    }
    $dirsOk = $true
    foreach ($dirName in $requiredDirs) {
        if (-not (Test-Path -LiteralPath (Join-Path $InstallRoot $dirName) -PathType Container)) {
            $dirsOk = $false
        }
    }
    Write-Check -Name "T1 目錄結構" -Ok $dirsOk

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
    $soulPath = Join-Path $InstallRoot "SOUL.md"
    $claudePath = Join-Path $InstallRoot "CLAUDE.md"
    $memoryIndexPath = Join-Path $InstallRoot "memory\MEMORY.md"

    Copy-ManagedFile -Source (Join-Path $KitSource "SOUL.template.md") -Destination $soulPath -Timestamp $timestamp
    Copy-ManagedFile -Source (Join-Path $KitSource "CLAUDE.md") -Destination $claudePath -Timestamp $timestamp
    Write-ManagedTextFile -Path $memoryIndexPath -Text "# Memory Index`r`n" -Timestamp $timestamp -PreserveExisting

    $suiteOk = (
        (Test-Path -LiteralPath $soulPath -PathType Leaf) -and
        (Test-Path -LiteralPath $claudePath -PathType Leaf) -and
        (Test-Path -LiteralPath $memoryIndexPath -PathType Leaf)
    )
    Write-Check -Name "T2 核心檔案" -Ok $suiteOk

    $brainNameLiteral = ConvertTo-PowerShellSingleQuotedString -Value $BrainName
    $sessionStartTemplate = @'
# aiwff-mini SessionStart hook: inject SOUL.md and warn on baseline drift.

$ErrorActionPreference = "SilentlyContinue"
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
} catch {}

if ([Console]::IsInputRedirected) {
    try { [Console]::In.ReadToEnd() | Out-Null } catch {}
}

$BrainName = __BRAIN_NAME_LITERAL__
$InstallRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
}

$warnings = @()
$soulPath = Join-Path $InstallRoot "SOUL.md"
$baselinePath = Join-Path $InstallRoot ".soul_baseline\baseline.json"

try {
    if (-not (Test-Path -LiteralPath $baselinePath -PathType Leaf)) {
        $warnings += "⚠️ $BrainName SOUL.md baseline 不存在，無法驗完整性: $baselinePath"
    } else {
        $baseline = Get-Content -LiteralPath $baselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $soulEntry = @($baseline.files | Where-Object { $_.name -eq "SOUL.md" }) | Select-Object -First 1
        if (-not $soulEntry) {
            $warnings += "⚠️ $BrainName SOUL.md baseline 缺少 SOUL.md 條目"
        } elseif (-not (Test-Path -LiteralPath $soulPath -PathType Leaf)) {
            $warnings += "⚠️ $BrainName SOUL.md 不存在: $soulPath"
        } else {
            $actualHash = Get-Sha256 -Path $soulPath
            $expectedHash = [string]$soulEntry.sha256
            if ($actualHash -ne $expectedHash.ToLowerInvariant()) {
                $warnings += ("🚨 ⚠️ " + $BrainName + " SOUL.md 與 baseline 不符: expected=" + $expectedHash.Substring(0, 16) + ", actual=" + $actualHash.Substring(0, 16) + "；可能被誤改或竄改，請回報給你的人。")
            }
        }
    }
} catch {
    $warnings += "⚠️ $BrainName SOUL.md baseline 驗證無法完成: $($_.Exception.Message)"
}

try {
    if (-not (Test-Path -LiteralPath $soulPath -PathType Leaf)) {
        throw "SOUL.md not found: $soulPath"
    }
    $soulText = Get-Content -LiteralPath $soulPath -Raw -Encoding UTF8
    $parts = @()
    if ($warnings.Count -gt 0) { $parts += ($warnings -join "`n") }
    $parts += "【$BrainName SOUL.md 靈魂錨 / 每 turn 必讀】`n$soulText"
    $ctx = ($parts -join "`n`n").Trim()
} catch {
    $ctx = (($warnings + @("⚠️ SOUL.md 載入失敗: $($_.Exception.Message)")) -join "`n").Trim()
}

try {
    $out = @{ hookSpecificOutput = @{ hookEventName = "SessionStart"; additionalContext = $ctx } } | ConvertTo-Json -Depth 5 -Compress
    Write-Output $out
} catch {
    Write-Output $ctx
}

exit 0
'@
    $sessionStartScript = $sessionStartTemplate.Replace("__BRAIN_NAME_LITERAL__", $brainNameLiteral)
    $sessionStartPath = Join-Path $InstallRoot "session-start.ps1"
    Write-ManagedTextFile -Path $sessionStartPath -Text ($sessionStartScript + "`r`n") -Timestamp $timestamp

    $settingsPath = Join-Path $InstallRoot ".claude\settings.json"
    $pwshExe = Find-PwshExe
    $hookCommand = (Quote-CommandArgument (ConvertTo-HookPath $pwshExe)) + " -NoProfile -File " + (Quote-CommandArgument (ConvertTo-HookPath $sessionStartPath))
    Merge-SessionStartHook -SettingsPath $settingsPath -Command $hookCommand -Timestamp $timestamp

    Set-ItemProperty -LiteralPath $soulPath -Name IsReadOnly -Value $true
    $isReadOnly = (Get-Item -LiteralPath $soulPath).IsReadOnly

    $baselineFiles = @()
    foreach ($fileName in @("SOUL.md", "CLAUDE.md")) {
        $path = Join-Path $InstallRoot $fileName
        $item = Get-Item -LiteralPath $path
        $baselineFiles += [ordered]@{
            name = $fileName
            sha256 = (Get-Sha256 -Path $path)
            size = $item.Length
            created_at = $item.CreationTimeUtc.ToString("o")
        }
    }
    $baseline = [ordered]@{
        brain_name = $BrainName
        baseline_created_at = (Get-Date).ToUniversalTime().ToString("o")
        files = $baselineFiles
    }
    $baselinePath = Join-Path $InstallRoot ".soul_baseline\baseline.json"
    $baselineJson = ($baseline | ConvertTo-Json -Depth 10) + "`r`n"
    Write-ManagedTextFile -Path $baselinePath -Text $baselineJson -Timestamp $timestamp -AlwaysRewrite

    $baselineOk = $false
    if (Test-Path -LiteralPath $baselinePath -PathType Leaf) {
        $baselineReadback = Get-Content -LiteralPath $baselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $soulEntry = @($baselineReadback.files | Where-Object { $_.name -eq "SOUL.md" }) | Select-Object -First 1
        $baselineOk = ($null -ne $soulEntry) -and (([string]$soulEntry.sha256).ToLowerInvariant() -eq (Get-Sha256 -Path $soulPath))
    }

    $settingsRaw = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8
    $settingsOk = (($settingsRaw -match [regex]::Escape((ConvertTo-HookPath $sessionStartPath))) -and (Test-Path -LiteralPath $sessionStartPath -PathType Leaf))
    $memoryOk = (Test-Path -LiteralPath $memoryIndexPath -PathType Leaf)

    Write-Output ""
    Write-Output "驗收結果"
    Write-Check -Name "目錄結構建好了" -Ok $dirsOk
    Write-Check -Name "SOUL.md 設成唯讀" -Ok $isReadOnly
    Write-Check -Name "baseline 簽章存在且對得上 SOUL.md" -Ok $baselineOk
    Write-Check -Name "SessionStart hook 設定好了" -Ok $settingsOk
    Write-Check -Name "記憶索引檔建好了" -Ok $memoryOk
    Write-Output ""
    Write-Output ("開新對話時，Claude Code 要開在安裝根目錄: " + $InstallRoot)
    Write-Output ("可先驗證: pwsh -NoProfile -Command ""(Resolve-Path '" + ($InstallRoot -replace "'", "''") + "').Path""")

    if ($script:Failed) {
        exit 1
    }
    exit 0
} catch {
    Write-Output ("❌ 安裝流程中止 - " + $_.Exception.Message)
    exit 1
}
