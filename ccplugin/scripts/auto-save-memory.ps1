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

    # 构建 systemMessage - 指示 Claude 按 save 命令逻辑保存
    $systemMessage = @"
<AUTO-SAVE-MEMORY>
检测到 git 仓库中有文件变更。在停止前,你必须保存工作记忆。

请按照以下步骤执行(等同于 /longmemory:save 命令的逻辑):

1. 收集 git 变更上下文:
   git status --porcelain
   git diff --stat HEAD
   git log --oneline -5

2. 分析当前会话内容,生成 memory 文件,写入 docs/memory/YYYY-MM-DD-description.md
   使用标准 7 section 模板: Summary, Changes Made, Decisions & Rationale, Technical Details, Testing, Open Items / Follow-ups, Learnings

3. 更新 docs/memory/index.json:
   - 如果不存在,创建初始索引(version: 1.0)
   - 添加新 entry(layer: L0, compacted: false)
   - 从内容提取 3-5 个 tags
   - 更新 stats(total, l0/l1/l2 计数, totalSizeBytes)

完成保存和索引更新后,你可以停止。
</AUTO-SAVE-MEMORY>
"@

    $response = @{
        decision = "block"
        reason = "Need to save work memory and update index before stopping"
        systemMessage = $systemMessage
    }

    $response | ConvertTo-Json -Depth 10 -Compress
    exit 0

} catch {
    exit 0
}
