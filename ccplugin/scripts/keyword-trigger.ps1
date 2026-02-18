# keyword-trigger.ps1
# UserPromptSubmit hook: 检测触发词，自动注入匹配的经验

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

    # 获取用户消息内容
    $prompt = $null
    if ($event.PSObject.Properties['prompt'] -and $event.prompt) {
        $prompt = $event.prompt
    } elseif ($event.PSObject.Properties['content'] -and $event.content) {
        $prompt = $event.content
    }
    if ([string]::IsNullOrWhiteSpace($prompt)) {
        exit 0
    }

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

        $projectConfig = Join-Path $WorkDir ".claude\longmemory.json"
        if (Test-Path $projectConfig) {
            try {
                $cfg = Get-Content $projectConfig -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($cfg.PSObject.Properties['globalMemoryPath'] -and $cfg.globalMemoryPath) {
                    return $cfg.globalMemoryPath
                }
            } catch {}
        }

        $userConfig = Join-Path $HOME ".claude\longmemory\config.json"
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

    $globalMemoryPath = Get-GlobalMemoryPath -WorkDir $cwd
    $configFile = Join-Path $globalMemoryPath "config.json"
    $triggersFile = Join-Path $globalMemoryPath "triggers.json"

    # 快速检查
    if (-not (Test-Path $triggersFile)) { exit 0 }
    if (-not (Test-Path $configFile)) { exit 0 }

    # 检查 autoRecall
    $config = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $autoRecall = if ($config.PSObject.Properties['autoRecall']) { $config.autoRecall } else { $false }
    if (-not $autoRecall) { exit 0 }

    # 读取最大注入 token 数
    $maxInjectTokens = if ($config.PSObject.Properties['maxInjectTokens']) { $config.maxInjectTokens } else { 500 }
    $maxInjectBytes = $maxInjectTokens * 4

    # 加载 triggers.json
    $triggers = Get-Content $triggersFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $triggers.PSObject.Properties['domains']) { exit 0 }

    $promptLower = $prompt.ToLower()
    $matchedContent = ""
    $totalBytes = 0

    # 遍历所有域
    foreach ($domainProp in $triggers.domains.PSObject.Properties) {
        $domainName = $domainProp.Name
        $domainData = $domainProp.Value

        if (-not $domainData.PSObject.Properties['keywords']) { continue }
        if (-not $domainData.PSObject.Properties['file']) { continue }

        $domainFile = $domainData.file
        $keywords = $domainData.keywords

        # 匹配关键词
        $matchedKw = $null
        foreach ($kw in $keywords) {
            if ($promptLower.Contains($kw.ToLower())) {
                $matchedKw = $kw
                break
            }
        }

        if ($null -eq $matchedKw) { continue }

        $fullDomainFile = Join-Path $globalMemoryPath $domainFile
        if (-not (Test-Path $fullDomainFile)) { continue }

        if ($totalBytes -ge $maxInjectBytes) { break }

        # 从域文件中提取包含匹配关键词的条目区块
        $fileLines = Get-Content $fullDomainFile -Encoding UTF8
        $currentBlock = @()
        $inBlock = $false
        $blockFound = $false

        foreach ($fileLine in $fileLines) {
            if ($fileLine -match '^## ') {
                # 保存上一个命中的块
                if ($inBlock -and $blockFound) {
                    $blockText = ($currentBlock -join "`n") + "`n"
                    $blockBytes = [System.Text.Encoding]::UTF8.GetByteCount($blockText)
                    $remaining = $maxInjectBytes - $totalBytes
                    if ($blockBytes -gt $remaining) {
                        $blockText = $blockText.Substring(0, [Math]::Min($blockText.Length, $remaining / 2))
                    }
                    $matchedContent += $blockText
                    $totalBytes += $blockBytes
                }
                $currentBlock = @($fileLine)
                $inBlock = $true
                $blockFound = $false
            } elseif ($fileLine -match '^---') {
                if ($inBlock -and $blockFound) {
                    $blockText = ($currentBlock -join "`n") + "`n"
                    $blockBytes = [System.Text.Encoding]::UTF8.GetByteCount($blockText)
                    $remaining = $maxInjectBytes - $totalBytes
                    if ($blockBytes -gt $remaining) {
                        $blockText = $blockText.Substring(0, [Math]::Min($blockText.Length, $remaining / 2))
                    }
                    $matchedContent += $blockText
                    $totalBytes += $blockBytes
                }
                $inBlock = $false
                $currentBlock = @()
                $blockFound = $false
            } elseif ($inBlock) {
                $currentBlock += $fileLine
                if ($fileLine.ToLower().Contains($matchedKw.ToLower())) {
                    $blockFound = $true
                }
            }
        }
        # 处理文件末尾未闭合的块
        if ($inBlock -and $blockFound) {
            $blockText = ($currentBlock -join "`n") + "`n"
            $blockBytes = [System.Text.Encoding]::UTF8.GetByteCount($blockText)
            $remaining = $maxInjectBytes - $totalBytes
            if ($blockBytes -gt $remaining) {
                $blockText = $blockText.Substring(0, [Math]::Min($blockText.Length, $remaining / 2))
            }
            $matchedContent += $blockText
            $totalBytes += $blockBytes
        }
    }

    if ([string]::IsNullOrWhiteSpace($matchedContent)) {
        exit 0
    }

    $finalMsg = "[LongMemory 经验召回]`n`n$matchedContent"

    $response = @{
        decision      = "allow"
        systemMessage = $finalMsg
    }
    $response | ConvertTo-Json -Depth 10 -Compress
    exit 0

} catch {
    exit 0
}
