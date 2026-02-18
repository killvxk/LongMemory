# pre-compact.ps1
# PreCompact hook: 压缩前检查是否有未保存的 git 变更，提示保存记忆

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$inputLines = @()
while ($null -ne ($line = [Console]::ReadLine())) {
    $inputLines += $line
}
$eventJson = $inputLines -join "`n"

if ([string]::IsNullOrWhiteSpace($eventJson)) {
    exit 0
}

try {
    $event = $eventJson | ConvertFrom-Json

    $cwd = if ($event.PSObject.Properties['cwd'] -and $event.cwd) {
        $event.cwd
    } elseif ($env:CLAUDE_WORKING_DIR) {
        $env:CLAUDE_WORKING_DIR
    } else {
        Get-Location | Select-Object -ExpandProperty Path
    }

    # 检测 git 变更
    $hasChanges = $false
    Push-Location $cwd
    try {
        $isGitRepo = git rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -eq 0) {
            $gitStatus = git status --porcelain 2>$null
            if (-not [string]::IsNullOrWhiteSpace($gitStatus)) {
                $hasChanges = $true
            }
        }
    } finally {
        Pop-Location
    }

    if (-not $hasChanges) {
        exit 0
    }

    # 不阻塞压缩，仅注入建议性系统消息
    $response = @{
        decision      = "allow"
        systemMessage = "[LongMemory] 检测到未提交的 git 变更。建议在压缩前运行 /longmemory:save 保存当前工作记忆，避免上下文压缩后丢失关键信息。"
    }
    $response | ConvertTo-Json -Depth 10 -Compress
    exit 0

} catch {
    exit 0
}
