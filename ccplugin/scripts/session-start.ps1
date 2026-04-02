# session-start.ps1
# SessionStart hook: 加载全局经验库领域概览 + 注入项目记忆概览到 Claude 上下文
# 参考 remember 插件模式：直接注入记忆内容，而非仅注入元数据

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 读取 stdin
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

    # 获取工作目录
    $cwd = if ($event.PSObject.Properties['cwd'] -and $event.cwd) {
        $event.cwd
    } elseif ($env:CLAUDE_WORKING_DIR) {
        $env:CLAUDE_WORKING_DIR
    } else {
        Get-Location | Select-Object -ExpandProperty Path
    }

    # ── 全局经验库 ────────────────────────────────────────────

    function Get-GlobalMemoryPath {
        param([string]$WorkDir)
        $projectConfig = Join-Path $WorkDir ".claude\longmemory.json"
        if (Test-Path $projectConfig) {
            try {
                $cfg = Get-Content $projectConfig -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($cfg.PSObject.Properties['globalMemoryPath'] -and $cfg.globalMemoryPath) {
                    return $cfg.globalMemoryPath
                }
            } catch {}
        }
        $userConfig = Join-Path $env:USERPROFILE ".claude\longmemory\config.json"
        if (-not (Test-Path $userConfig)) {
            $userConfig = Join-Path $HOME ".claude\longmemory\config.json"
        }
        if (Test-Path $userConfig) {
            try {
                $cfg = Get-Content $userConfig -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($cfg.PSObject.Properties['globalMemoryPath'] -and $cfg.globalMemoryPath) {
                    return $cfg.globalMemoryPath
                }
            } catch {}
        }
        return Join-Path $HOME ".claude\longmemory"
    }

    $hasGlobal = $false
    $domainSummary = ""
    $keywordDetail = ""

    $globalMemoryPath = Get-GlobalMemoryPath -WorkDir $cwd
    $configFile = Join-Path $globalMemoryPath "config.json"

    if (Test-Path $configFile) {
        $config = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $autoRecall = if ($config.PSObject.Properties['autoRecall']) { $config.autoRecall } else { $false }

        if ($autoRecall) {
            $hasGlobal = $true

            # 从 triggers.json 读取领域信息和关键词明细
            $triggersFile = Join-Path $globalMemoryPath "triggers.json"
            if (Test-Path $triggersFile) {
                try {
                    $triggers = Get-Content $triggersFile -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($triggers.PSObject.Properties['domains']) {
                        $domainParts = @()
                        $kwDetailParts = @()
                        foreach ($domain in $triggers.domains.PSObject.Properties) {
                            $kwCount = if ($domain.Value.PSObject.Properties['keywords']) {
                                $domain.Value.keywords.Count
                            } else { 0 }
                            $domainParts += "$($domain.Name)($($kwCount)个关键词)"
                            if ($domain.Value.PSObject.Properties['keywords'] -and $domain.Value.keywords.Count -gt 0) {
                                $kwList = $domain.Value.keywords -join ", "
                                $kwDetailParts += "  - $($domain.Name): $kwList"
                            }
                        }
                        $domainSummary = $domainParts -join ", "
                        if ($kwDetailParts.Count -gt 0) {
                            $keywordDetail = $kwDetailParts -join "`n"
                        }
                    }
                } catch {}
            }

            # 如果 triggers.json 不可用，从全局 catalog.md 解析
            $globalCatalog = Join-Path $globalMemoryPath "catalog.md"
            if ([string]::IsNullOrWhiteSpace($domainSummary) -and (Test-Path $globalCatalog)) {
                try {
                    $catalogContent = Get-Content $globalCatalog -Encoding UTF8
                    $domainParts = @()
                    foreach ($line in $catalogContent) {
                        if ($line -match '^\|\s*([^|]+?)\s*\|\s*(\d+)\s*\|') {
                            $domainName = $Matches[1].Trim()
                            if ($domainName -ne "领域" -and $domainName -ne "" -and $domainName -ne "---") {
                                $domainParts += $domainName
                            }
                        }
                    }
                    if ($domainParts.Count -gt 0) {
                        $domainSummary = $domainParts -join ", "
                    }
                } catch {}
            }
        }
    }

    # ── 项目记忆 ──────────────────────────────────────────────

    $projectMemory = ""
    $memoryStats = ""
    $projectCatalog = Join-Path $cwd "docs\memory\catalog.md"
    $projectIndex = Join-Path $cwd "docs\memory\index.json"

    # 从 catalog.md 提取 Recent Overviews 段落
    if (Test-Path $projectCatalog) {
        try {
            $lines = Get-Content $projectCatalog -Encoding UTF8
            $inSection = $false
            $overviewLines = @()
            foreach ($line in $lines) {
                if ($line -match '^## Recent Overviews') {
                    $inSection = $true
                    continue
                }
                if ($inSection -and $line -match '^## ') {
                    break
                }
                if ($inSection) {
                    $overviewLines += $line
                }
            }
            if ($overviewLines.Count -gt 0) {
                $projectMemory = ($overviewLines -join "`n").Trim()
            }
        } catch {}
    }

    # 从 index.json 读取统计信息
    if (Test-Path $projectIndex) {
        try {
            $idx = Get-Content $projectIndex -Raw -Encoding UTF8 | ConvertFrom-Json
            $total = if ($idx.stats.PSObject.Properties['total']) { $idx.stats.total } else { 0 }
            $lastUpdated = if ($idx.PSObject.Properties['lastUpdated']) { $idx.lastUpdated.Substring(0, 10) } else { "" }
            if ($total -gt 0) {
                $memoryStats = "共 $total 条，最近更新 $lastUpdated"
            }
        } catch {}
    }

    # ── 技术栈检测 ────────────────────────────────────────────

    $stackParts = @()
    if (Test-Path (Join-Path $cwd "package.json")) { $stackParts += "Node.js/TypeScript" }
    if (Test-Path (Join-Path $cwd "Cargo.toml")) { $stackParts += "Rust" }
    if (Test-Path (Join-Path $cwd "go.mod")) { $stackParts += "Go" }
    if ((Test-Path (Join-Path $cwd "requirements.txt")) -or (Test-Path (Join-Path $cwd "pyproject.toml"))) { $stackParts += "Python" }
    if (Get-ChildItem -Path $cwd -Filter "*.csproj" -ErrorAction SilentlyContinue | Select-Object -First 1) { $stackParts += ".NET/C#" }
    if (Test-Path (Join-Path $cwd "pom.xml")) { $stackParts += "Java/Maven" }
    if (Test-Path (Join-Path $cwd "build.gradle")) { $stackParts += "Java/Gradle" }
    $techStack = if ($stackParts.Count -gt 0) { $stackParts -join ", " } else { "" }

    # ── 判断是否有内容需要注入 ────────────────────────────────

    if (-not $hasGlobal -and [string]::IsNullOrWhiteSpace($projectMemory) -and [string]::IsNullOrWhiteSpace($memoryStats)) {
        exit 0
    }

    # ── 构建上下文消息 ────────────────────────────────────────

    $msg = ""

    # 全局经验库部分
    if ($hasGlobal) {
        $msg = "[LongMemory] 全局经验库已加载。"
        if (-not [string]::IsNullOrWhiteSpace($domainSummary)) {
            $msg += "`n可用领域: $domainSummary。"
        }
        if (-not [string]::IsNullOrWhiteSpace($keywordDetail)) {
            $msg += "`n触发关键词:`n$keywordDetail"
        }
    }

    # 项目记忆部分（直接注入 L1 概览内容）
    if (-not [string]::IsNullOrWhiteSpace($projectMemory)) {
        if (-not [string]::IsNullOrWhiteSpace($msg)) { $msg += "`n" }
        $msg += "[LongMemory] 项目记忆概览 ($( if ($memoryStats) { $memoryStats } else { '未知' } )):`n$projectMemory"
    } elseif (-not [string]::IsNullOrWhiteSpace($memoryStats)) {
        if (-not [string]::IsNullOrWhiteSpace($msg)) { $msg += "`n" }
        $msg += "[LongMemory] 项目记忆: $memoryStats。使用 /longmemory:list 查看目录。"
    }

    # 技术栈
    if (-not [string]::IsNullOrWhiteSpace($techStack)) {
        $msg += "`n技术栈检测: $techStack。"
    }

    # 自动召回指令（仅在全局库可用时）
    if ($hasGlobal) {
        $msg += "`n当用户消息中出现上述触发关键词时，自动运行 /longmemory:recall <匹配的关键词> 获取相关经验并参考。无需等用户要求，主动召回。"
    }

    # 使用 hookSpecificOutput.additionalContext 注入 Claude 上下文
    $response = @{
        hookSpecificOutput = @{
            hookEventName     = "SessionStart"
            additionalContext = $msg
        }
    }
    $response | ConvertTo-Json -Depth 10 -Compress
    exit 0

} catch {
    exit 0
}
