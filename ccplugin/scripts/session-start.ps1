# session-start.ps1
# SessionStart hook: 加载全局经验库领域概览并注入到 Claude 上下文
# 仅在新会话启动时触发（matcher: startup）

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

    # 发现全局经验库路径
    function Get-GlobalMemoryPath {
        param([string]$WorkDir)

        # 1. 检查项目级配置
        $projectConfig = Join-Path $WorkDir ".claude\longmemory.json"
        if (Test-Path $projectConfig) {
            try {
                $cfg = Get-Content $projectConfig -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($cfg.PSObject.Properties['globalMemoryPath'] -and $cfg.globalMemoryPath) {
                    return $cfg.globalMemoryPath
                }
            } catch {}
        }

        # 2. 检查用户级配置
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

        # 3. 默认路径
        return Join-Path $HOME ".claude\longmemory"
    }

    $globalMemoryPath = Get-GlobalMemoryPath -WorkDir $cwd
    $configFile = Join-Path $globalMemoryPath "config.json"

    # 检查全局库是否存在
    if (-not (Test-Path $configFile)) {
        exit 0
    }

    # 检查 autoRecall
    $config = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $autoRecall = if ($config.PSObject.Properties['autoRecall']) { $config.autoRecall } else { $false }
    if (-not $autoRecall) {
        exit 0
    }

    # 从 triggers.json 读取领域信息和关键词明细
    $domainSummary = ""
    $keywordDetail = ""
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

                    # 提取每个领域的关键词列表
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

    # 如果 triggers.json 不可用，从 catalog.md 解析
    $catalogFile = Join-Path $globalMemoryPath "catalog.md"
    if ([string]::IsNullOrWhiteSpace($domainSummary) -and (Test-Path $catalogFile)) {
        try {
            $catalogContent = Get-Content $catalogFile -Encoding UTF8
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

    # 检测技术栈
    $stackParts = @()
    if (Test-Path (Join-Path $cwd "package.json")) { $stackParts += "Node.js/TypeScript" }
    if (Test-Path (Join-Path $cwd "Cargo.toml")) { $stackParts += "Rust" }
    if (Test-Path (Join-Path $cwd "go.mod")) { $stackParts += "Go" }
    if ((Test-Path (Join-Path $cwd "requirements.txt")) -or (Test-Path (Join-Path $cwd "pyproject.toml"))) { $stackParts += "Python" }
    if (Get-ChildItem -Path $cwd -Filter "*.csproj" -ErrorAction SilentlyContinue | Select-Object -First 1) { $stackParts += ".NET/C#" }
    if (Test-Path (Join-Path $cwd "pom.xml")) { $stackParts += "Java/Maven" }
    if (Test-Path (Join-Path $cwd "build.gradle")) { $stackParts += "Java/Gradle" }
    $techStack = if ($stackParts.Count -gt 0) { $stackParts -join ", " } else { "" }

    # 构建上下文消息
    $msg = "[LongMemory] 全局经验库已加载。"
    if (-not [string]::IsNullOrWhiteSpace($domainSummary)) {
        $msg += "`n可用领域: $domainSummary。"
    }
    if (-not [string]::IsNullOrWhiteSpace($keywordDetail)) {
        $msg += "`n触发关键词:`n$keywordDetail"
    }
    if (-not [string]::IsNullOrWhiteSpace($techStack)) {
        $msg += "`n技术栈检测: $techStack。"
    }
    $msg += "`n当用户消息中出现上述触发关键词时，自动运行 /longmemory:recall <匹配的关键词> 获取相关经验并参考。无需等用户要求，主动召回。"

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
