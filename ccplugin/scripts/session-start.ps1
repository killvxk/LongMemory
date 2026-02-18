# session-start.ps1
# SessionStart hook: 加载全局经验库领域概览并注入到系统消息

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
    $catalogFile = Join-Path $globalMemoryPath "catalog.md"

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

    # 读取 catalog.md 提取领域信息
    $domainSummary = ""
    if (Test-Path $catalogFile) {
        $catalogContent = Get-Content $catalogFile -Encoding UTF8
        $domainParts = @()
        foreach ($line in $catalogContent) {
            if ($line -match '^##\s+(.+)$') {
                $domainParts += $Matches[1].Trim()
            }
        }
        if ($domainParts.Count -gt 0) {
            $domainSummary = $domainParts -join ", "
        }
    }

    # 如果 catalog 没有领域信息，尝试从 triggers.json 读取
    if ([string]::IsNullOrWhiteSpace($domainSummary)) {
        $triggersFile = Join-Path $globalMemoryPath "triggers.json"
        if (Test-Path $triggersFile) {
            try {
                $triggers = Get-Content $triggersFile -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($triggers.PSObject.Properties['domains']) {
                    $domainParts = @()
                    foreach ($domain in $triggers.domains.PSObject.Properties) {
                        $kwCount = if ($domain.Value.PSObject.Properties['keywords']) {
                            $domain.Value.keywords.Count
                        } else { 0 }
                        $domainParts += "$($domain.Name)($($kwCount)个关键词)"
                    }
                    $domainSummary = $domainParts -join ", "
                }
            } catch {}
        }
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

    # 构建系统消息
    $msg = "[LongMemory] 全局经验库已加载。"
    if (-not [string]::IsNullOrWhiteSpace($domainSummary)) {
        $msg += "可用领域: $domainSummary。"
    }
    if (-not [string]::IsNullOrWhiteSpace($techStack)) {
        $msg += "技术栈检测: $techStack。"
    }
    $msg += "使用 /longmemory:recall <关键词> 查询经验。"

    $response = @{
        decision      = "allow"
        systemMessage = $msg
    }
    $response | ConvertTo-Json -Depth 10 -Compress
    exit 0

} catch {
    exit 0
}
