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

    $stopHookActive = if ($event.PSObject.Properties['stop_hook_active']) {
        $event.stop_hook_active
    } else {
        $false
    }

    $cwd = if ($event.PSObject.Properties['cwd']) {
        $event.cwd
    } else {
        if ($env:CLAUDE_WORKING_DIR) {
            $env:CLAUDE_WORKING_DIR
        } else {
            Get-Location | Select-Object -ExpandProperty Path
        }
    }

    # 防止无限循环
    if ($stopHookActive -eq $true) {
        exit 0
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

    # 确保 docs/memory 目录存在
    $memoryDir = Join-Path $cwd "docs\memory"
    if (-not (Test-Path $memoryDir)) {
        New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null
    }

    $response = @{
        decision = "block"
        reason = "/longmemory:save"
    }

    $response | ConvertTo-Json -Depth 10 -Compress
    exit 0

} catch {
    exit 0
}
