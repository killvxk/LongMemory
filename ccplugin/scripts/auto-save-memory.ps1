# auto-save-memory.ps1
# Stop hook: 检测 git 变更，提示 Claude 保存工作记忆并更新索引

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 读取 stdin 获取 hook 事件
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

    $sessionId = if ($event.PSObject.Properties['session_id']) { $event.session_id } else { "unknown" }

    $cwd = if ($event.PSObject.Properties['cwd'] -and $event.cwd) {
        $event.cwd
    } elseif ($env:CLAUDE_WORKING_DIR) {
        $env:CLAUDE_WORKING_DIR
    } else {
        Get-Location | Select-Object -ExpandProperty Path
    }

    # 防止无限循环：使用基于 session_id 的临时文件作为锁
    $lockFile = Join-Path $env:TEMP "longmemory-stop-$sessionId"
    if (Test-Path $lockFile) {
        exit 0
    }

    # 检测是否有需要保存的工作
    $hasWork = $false

    # 方式1: git 有未提交变更
    Push-Location $cwd
    try {
        $isGitRepo = git rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -eq 0) {
            $gitStatus = git status --porcelain 2>$null
            if (-not [string]::IsNullOrWhiteSpace($gitStatus)) {
                $hasWork = $true
            }
        }
    } finally {
        Pop-Location
    }

    # 方式2: transcript 存在且有内容（说明会话有实质工作）
    if (-not $hasWork) {
        $transcriptPath = if ($event.PSObject.Properties['transcript_path']) { $event.transcript_path } else { $null }
        if ($transcriptPath -and (Test-Path $transcriptPath)) {
            $fileInfo = Get-Item $transcriptPath
            if ($fileInfo.Length -gt 0) {
                $hasWork = $true
            }
        }
    }

    if (-not $hasWork) {
        exit 0
    }

    # 确保 docs/memory 目录存在
    $memoryDir = Join-Path $cwd "docs\memory"
    if (-not (Test-Path $memoryDir)) {
        New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null
    }

    # 创建锁文件，防止再次触发时重复 block
    New-Item -ItemType File -Path $lockFile -Force | Out-Null

    $response = @{
        decision      = "block"
        reason        = "检测到未提交的 git 变更，需要先保存工作记忆。"
        systemMessage = "请运行 /longmemory:save 保存当前工作记忆后再结束会话。"
    }

    $response | ConvertTo-Json -Depth 10 -Compress
    exit 0

} catch {
    exit 0
}
