param([Parameter(Mandatory=$true)][string]$OutPath)
$big = 'L' * 7000
$lines = @(
'{"type":"user","timestamp":"2026-01-01T00:00:00Z","message":{"content":[{"type":"text","text":"turn one question about [[memory_alpha]]"}]}}'
'{"type":"assistant","timestamp":"2026-01-01T00:00:01Z","message":{"content":[{"type":"thinking","thinking":"short reasoning"},{"type":"text","text":"answer one"}]}}'
'{"type":"user","timestamp":"2026-01-01T00:01:00Z","message":{"content":[{"type":"text","text":"turn two please read a file"}]}}'
'{"type":"assistant","timestamp":"2026-01-01T00:01:01Z","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/x"}}]}}'
('{"type":"user","timestamp":"2026-01-01T00:01:02Z","message":{"content":[{"type":"tool_result","content":"' + $big + '"}]}}')
'{"type":"user","timestamp":"2026-01-01T00:02:00Z","message":{"content":[{"type":"text","text":"turn three wrap up, see [[memory_beta]] and [[memory_alpha]]"}]}}'
'{"type":"assistant","timestamp":"2026-01-01T00:02:01Z","message":{"content":[{"type":"text","text":"done"}]}}'
)
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutPath, (($lines -join "`n") + "`n"), $utf8)
Write-Output "wrote $OutPath"
