# =============================================================================
# LUNA STREAM 4K IPTV - TWITTER / X AUTO-PROMOTER BOT ENGINE
# Supports:
#   1. Official X Free Developer API v2 (OAuth 1.0a HMAC-SHA1)
#   2. PC Browser Auto-Poster Mode (x.com/intent/tweet + Ctrl+Enter)
#   3. Local Visual Web Dashboard on http://localhost:8090
# =============================================================================

param(
    [int]$Port = 8090,
    [switch]$PostOnceAndExit
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RootDir = $PSScriptRoot
if (-not $RootDir) { $RootDir = (Get-Location).Path }
$DataDir = Join-Path $RootDir "data"
if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
}

$ConfigPath    = Join-Path $DataDir "bot_config.json"
$TemplatesPath = Join-Path $DataDir "tweet_templates.json"
$HistoryPath   = Join-Path $DataDir "tweet_history.json"

$script:NextScheduledRun = $null
$script:LastPostResult   = $null

function Read-JsonSafe([string]$path, $defaultObj) {
    if (Test-Path $path) {
        try {
            $raw = Get-Content $path -Raw -Encoding UTF8
            if ($raw -and $raw.Trim() -ne "") {
                return ($raw | ConvertFrom-Json)
            }
        } catch {}
    }
    return $defaultObj
}

function Write-JsonSafe([string]$path, $obj) {
    $json = ""
    if ($null -eq $obj) {
        $json = "null"
    } elseif ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string]) -and -not ($obj -is [System.Collections.IDictionary])) {
        $arr = @($obj)
        if ($arr.Count -eq 0) {
            $json = "[]"
        } elseif ($arr.Count -eq 1) {
            $json = "[`n" + ($arr[0] | ConvertTo-Json -Depth 10) + "`n]"
        } else {
            $json = $arr | ConvertTo-Json -Depth 10
        }
    } else {
        $json = $obj | ConvertTo-Json -Depth 10
    }
    [System.IO.File]::WriteAllText($path, $json, [System.Text.Encoding]::UTF8)
}

function Get-BotConfig {
    $defaultCfg = [PSCustomObject]@{
        mode                    = "browser_auto"
        auto_schedule_enabled   = $false
        interval_hours          = 3
        rotation_mode           = "smart_mix"
        rotation_index          = 0
        whatsapp_number         = "+44 7882 507089"
        whatsapp_link           = "https://wa.me/447882507089?text=Hello%20Luna%20Stream!%20I%20saw%20your%20post%20on%20X%20and%20want%20the%2024-Hour%20Free%20IPTV%20Trial."
        netlify_url             = "https://luna-4k-pass.netlify.app"
        website_url             = "https://lunaentertainment.online"
        x_api_key               = ""
        x_api_secret            = ""
        x_access_token          = ""
        x_access_secret         = ""
        browser_auto_press_send = $true
        browser_wait_seconds    = 7
        enabled_categories      = @("football", "ppv_sports", "movies_vod", "firestick_setup", "cord_cutting", "free_trial")
    }
    $cfg = Read-JsonSafe $ConfigPath $defaultCfg
    return $cfg
}

function Save-BotConfig($cfg) {
    Write-JsonSafe $ConfigPath $cfg
}

function Get-TweetCharLength([string]$text) {
    if (-not $text) { return 0 }
    # X counts any http(s) URL as 23 characters, but we also return raw length
    $replaced = [regex]::Replace($text, 'https?://\S+', '12345678901234567890123')
    return $replaced.Length
}

function Get-RotatedCtaAndLink($cfg, [switch]$AdvanceIndex) {
    $waNum  = if ($cfg.whatsapp_number) { [string]$cfg.whatsapp_number } else { "+44 7882 507089" }
    $waDigits = ($waNum -replace '[^0-9]', '')
    if (-not $waDigits) { $waDigits = "447882507089" }
    $shortWaUrl = "https://wa.me/$waDigits"
    $netUrl = if ($cfg.netlify_url) { [string]$cfg.netlify_url } else { "https://luna-4k-pass.netlify.app" }
    $webUrl = if ($cfg.website_url) { [string]$cfg.website_url } else { "https://lunaentertainment.online" }

    $mode = if ($cfg.rotation_mode) { [string]$cfg.rotation_mode } else { "smart_mix" }
    $idx  = if ($null -ne $cfg.rotation_index) { [int]$cfg.rotation_index } else { 0 }

    if ($AdvanceIndex) {
        $cfg.rotation_index = ($idx + 1) % 4
        Save-BotConfig $cfg
    }

    $ePoint = [char]::ConvertFromUtf32(0x1F449)
    $eChat  = [char]::ConvertFromUtf32(0x1F4AC)
    $eGlobe = [char]::ConvertFromUtf32(0x1F310)
    $ePhone = [char]::ConvertFromUtf32(0x1F4F2)

    if ($mode -eq "whatsapp_only") {
        return @{
            cta       = "$eChat 24H Free Trial on WhatsApp: $shortWaUrl"
            link_type = "whatsapp"
            target    = $shortWaUrl
        }
    }
    if ($mode -eq "netlify_only") {
        return @{
            cta       = "$ePoint Get 24H Trial & Passes: $netUrl"
            link_type = "netlify"
            target    = $netUrl
        }
    }
    if ($mode -eq "website_only") {
        return @{
            cta       = "$eGlobe View IPTV Plans: $webUrl"
            link_type = "website"
            target    = $webUrl
        }
    }

    # Default: smart_mix (4-way rotation across Netlify, WhatsApp, Main Website, and Combo)
    $slot = $idx % 4
    switch ($slot) {
        0 {
            return @{
                cta       = "$ePoint 24H Trial & Info: $netUrl"
                link_type = "netlify"
                target    = $netUrl
            }
        }
        1 {
            return @{
                cta       = "$eChat WhatsApp 24H Free Trial: $shortWaUrl"
                link_type = "whatsapp"
                target    = $shortWaUrl
            }
        }
        2 {
            return @{
                cta       = "$eGlobe Official Plans & Trial: $webUrl"
                link_type = "website"
                target    = $webUrl
            }
        }
        default {
            return @{
                cta       = "$ePhone WhatsApp $waNum | $netUrl"
                link_type = "combo_netlify_wa"
                target    = $netUrl
            }
        }
    }
}

function New-PromotionalTweet([string]$RequestedCategory = "random", [switch]$AdvanceRotation) {
    $cfg = Get-BotConfig
    $tplData = Read-JsonSafe $TemplatesPath $null
    if (-not $tplData -or -not $tplData.templates) {
        throw "tweet_templates.json is missing or invalid."
    }

    $enabledCats = @($cfg.enabled_categories)
    if ($enabledCats.Count -eq 0) {
        $enabledCats = @("football", "ppv_sports", "movies_vod", "firestick_setup", "cord_cutting", "free_trial")
    }

    $candidates = @($tplData.templates)
    if ($RequestedCategory -and $RequestedCategory -ne "random" -and $RequestedCategory -ne "all") {
        $filtered = @($candidates | Where-Object { $_.category -eq $RequestedCategory })
        if ($filtered.Count -gt 0) { $candidates = $filtered }
    } else {
        $filtered = @($candidates | Where-Object { $enabledCats -contains $_.category })
        if ($filtered.Count -gt 0) { $candidates = $filtered }
    }

    $history = @(Read-JsonSafe $HistoryPath @())
    $recentTexts = @($history | Select-Object -First 25 | ForEach-Object { $_.text })

    $ctaInfo = Get-RotatedCtaAndLink $cfg -AdvanceIndex:$AdvanceRotation
    $chosenTweet = ""
    $chosenCat   = "football"
    $chosenId    = "custom"

    for ($attempt = 0; $attempt -lt 12; $attempt++) {
        $tpl = $candidates | Get-Random
        $chosenCat = [string]$tpl.category
        $chosenId  = [string]$tpl.id

        $hook = ""
        if ($tplData.hooks -and $tplData.hooks.Count -gt 0) {
            $hook = [string]($tplData.hooks | Get-Random)
        }

        $tagPool = @("#IPTV", "#FireStick", "#SmartTV", "#4KStreaming")
        if ($tplData.hashtags_by_category -and $tplData.hashtags_by_category.$chosenCat) {
            $tagPool = @($tplData.hashtags_by_category.$chosenCat)
        }
        $pickedTags = @($tagPool | Get-Random -Count ([Math]::Min(3, $tagPool.Count)))
        $hashtagStr = ($pickedTags -join " ")

        $draft = [string]$tpl.body
        $draft = $draft.Replace("{hook}", $hook)
        $draft = $draft.Replace("{cta}", $ctaInfo.cta)
        $draft = $draft.Replace("{hashtags}", $hashtagStr)
        $draft = ($draft -replace "\r\n", "`n" -replace "\n{3,}", "`n`n").Trim()

        # Ensure tweet is <= 275 raw chars & <= 275 X-weighted chars
        if ($draft.Length -gt 275) {
            # Try with 2 hashtags
            $shortTags = ($pickedTags | Select-Object -First 2) -join " "
            $draft = ([string]$tpl.body).Replace("{hook}", $hook).Replace("{cta}", $ctaInfo.cta).Replace("{hashtags}", $shortTags).Trim()
        }
        if ($draft.Length -gt 275) {
            $draft = ([string]$tpl.body).Replace("{hook}", $hook).Replace("{cta}", $ctaInfo.cta).Replace("{hashtags}", "#IPTV #FireStick").Trim()
        }

        if ($recentTexts -notcontains $draft) {
            $chosenTweet = $draft
            break
        }
        $chosenTweet = $draft
    }

    return @{
        text        = $chosenTweet
        category    = $chosenCat
        template_id = $chosenId
        link_type   = $ctaInfo.link_type
        char_count  = $chosenTweet.Length
        x_weight    = (Get-TweetCharLength $chosenTweet)
    }
}

function ConvertTo-OAuthPercentEncoded([string]$str) {
    if ($null -eq $str) { return "" }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($str)
    $sb = New-Object System.Text.StringBuilder
    foreach ($b in $bytes) {
        if (($b -ge 0x30 -and $b -le 0x39) -or
            ($b -ge 0x41 -and $b -le 0x5A) -or
            ($b -ge 0x61 -and $b -le 0x7A) -or
            $b -eq 0x2D -or $b -eq 0x2E -or $b -eq 0x5F -or $b -eq 0x7E) {
            [void]$sb.Append([char]$b)
        } else {
            [void]$sb.Append([string]::Format("%{0:X2}", $b))
        }
    }
    return $sb.ToString()
}

function Get-AccurateUnixTimestamp {
    foreach ($probeUrl in @("https://api.twitter.com", "https://www.google.com")) {
        try {
            $req = [System.Net.WebRequest]::Create($probeUrl)
            $req.Method = "HEAD"
            $req.Timeout = 4000
            $resp = $req.GetResponse()
            $dateHdr = $resp.Headers["Date"]
            $resp.Close()
            if ($dateHdr) {
                $dto = [DateTimeOffset]::Parse($dateHdr, [System.Globalization.CultureInfo]::InvariantCulture)
                return [string]$dto.ToUnixTimeSeconds()
            }
        } catch [System.Net.WebException] {
            if ($_.Exception.Response -and $_.Exception.Response.Headers) {
                $dateHdr = $_.Exception.Response.Headers["Date"]
                if ($dateHdr) {
                    try {
                        $dto = [DateTimeOffset]::Parse($dateHdr, [System.Globalization.CultureInfo]::InvariantCulture)
                        return [string]$dto.ToUnixTimeSeconds()
                    } catch {}
                }
            }
        } catch {}
    }
    return [string][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
}

function Invoke-XApiTweet([string]$tweetText, $cfg) {
    $apiKey       = ([string]$cfg.x_api_key).Trim()
    $apiSecret    = ([string]$cfg.x_api_secret).Trim()
    $accessToken  = ([string]$cfg.x_access_token).Trim()
    $accessSecret = ([string]$cfg.x_access_secret).Trim()

    if (-not $apiKey -or -not $apiSecret -or -not $accessToken -or -not $accessSecret) {
        return @{
            success = $false
            error   = "Missing X Developer API credentials. Please enter all 4 keys (API Key, API Secret, Access Token, Access Token Secret) or switch to PC Browser Mode."
        }
    }

    $url = "https://api.twitter.com/2/tweets"
    $method = "POST"
    $nonce = [Guid]::NewGuid().ToString("N")
    $timestamp = Get-AccurateUnixTimestamp

    $oauthParams = @{
        oauth_consumer_key     = $apiKey
        oauth_nonce            = $nonce
        oauth_signature_method = "HMAC-SHA1"
        oauth_timestamp        = $timestamp
        oauth_token            = $accessToken
        oauth_version          = "1.0"
    }

    $sortedKeys = @($oauthParams.Keys | Sort-Object)
    $paramParts = @()
    foreach ($k in $sortedKeys) {
        $paramParts += "$(ConvertTo-OAuthPercentEncoded $k)=$(ConvertTo-OAuthPercentEncoded $oauthParams[$k])"
    }
    $paramString = $paramParts -join "&"
    $baseString  = "$method&$(ConvertTo-OAuthPercentEncoded $url)&$(ConvertTo-OAuthPercentEncoded $paramString)"
    $signingKey  = "$(ConvertTo-OAuthPercentEncoded $apiSecret)&$(ConvertTo-OAuthPercentEncoded $accessSecret)"

    $hmac = New-Object System.Security.Cryptography.HMACSHA1
    $hmac.Key = [System.Text.Encoding]::ASCII.GetBytes($signingKey)
    $sigBytes = $hmac.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($baseString))
    $signature = [Convert]::ToBase64String($sigBytes)
    $oauthParams["oauth_signature"] = $signature

    $headerParts = @()
    foreach ($k in ($oauthParams.Keys | Sort-Object)) {
        $headerParts += "$(ConvertTo-OAuthPercentEncoded $k)=`"$(ConvertTo-OAuthPercentEncoded $oauthParams[$k])`""
    }
    $authHeader = "OAuth " + ($headerParts -join ", ")

    $payloadJson = (@{ text = $tweetText } | ConvertTo-Json -Compress)
    $bodyBytes   = [System.Text.Encoding]::UTF8.GetBytes($payloadJson)

    try {
        $resp = Invoke-RestMethod -Uri $url -Method Post -Headers @{ Authorization = $authHeader } -Body $bodyBytes -ContentType "application/json; charset=utf-8" -TimeoutSec 20
        $tweetId = if ($resp -and $resp.data -and $resp.data.id) { [string]$resp.data.id } else { "posted" }
        return @{
            success  = $true
            mode     = "x_api"
            tweet_id = $tweetId
            url      = if ($tweetId -ne "posted") { "https://x.com/i/web/status/$tweetId" } else { "https://x.com" }
            message  = "Tweet published via Official X API v2!"
        }
    } catch {
        $errMsg = $_.Exception.Message
        try {
            if ($_.Exception.Response) {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $errBody = $reader.ReadToEnd()
                if ($errBody) { $errMsg = "$errMsg - $errBody" }
            }
        } catch {}
        return @{
            success = $false
            mode    = "x_api"
            error   = "X API Error: $errMsg"
        }
    }
}

function Invoke-BrowserTweet([string]$tweetText, $cfg) {
    try {
        $encoded = [System.Uri]::EscapeDataString($tweetText)
        $intentUrl = "https://x.com/intent/tweet?text=$encoded"
        Start-Process $intentUrl | Out-Null

        $autoSend = ($cfg.browser_auto_press_send -ne $false)
        $waitSec  = if ($cfg.browser_wait_seconds -and [int]$cfg.browser_wait_seconds -ge 3) { [int]$cfg.browser_wait_seconds } else { 7 }

        if ($autoSend) {
            Start-Sleep -Seconds $waitSec
            $wshell = New-Object -ComObject WScript.Shell
            # Ctrl+Enter is X/Twitter's official keyboard shortcut to submit the open compose tweet
            $wshell.SendKeys("^{ENTER}")
            Start-Sleep -Milliseconds 600
        }

        return @{
            success  = $true
            mode     = "browser_auto"
            tweet_id = "browser_" + (Get-Date -Format "yyyyMMddHHmmss")
            url      = "https://x.com"
            message  = if ($autoSend) { "Opened X in browser and triggered auto-post (Ctrl+Enter) after ${waitSec}s!" } else { "Opened pre-filled tweet in your X browser tab!" }
        }
    } catch {
        return @{
            success = $false
            mode    = "browser_auto"
            error   = "Browser launch error: $($_.Exception.Message)"
        }
    }
}

function Publish-TweetNow([string]$customText = "", [string]$category = "random", [string]$overrideMode = "") {
    $cfg = Get-BotConfig
    $tweetObj = $null
    if ($customText -and $customText.Trim() -ne "") {
        $clean = $customText.Trim()
        $tweetObj = @{
            text        = $clean
            category    = if ($category) { $category } else { "custom" }
            template_id = "manual"
            link_type   = "custom"
            char_count  = $clean.Length
        }
    } else {
        $tweetObj = New-PromotionalTweet -RequestedCategory $category -AdvanceRotation
    }

    $useMode = if ($overrideMode -and $overrideMode -ne "") { $overrideMode } elseif ($cfg.mode) { [string]$cfg.mode } else { "browser_auto" }
    $result = $null
    if ($useMode -eq "x_api") {
        $result = Invoke-XApiTweet -tweetText $tweetObj.text -cfg $cfg
        if (-not $result.success -and $result.error -match "403") {
            Write-Host "[Notice] X API returned 403 Forbidden (Read-only token or X free-tier write restriction). Automatically falling back to PC Browser Mode..." -ForegroundColor Yellow
            $browserRes = Invoke-BrowserTweet -tweetText $tweetObj.text -cfg $cfg
            if ($browserRes.success) {
                $result = @{
                    success  = $true
                    mode     = "browser_fallback"
                    tweet_id = $browserRes.tweet_id
                    url      = $browserRes.url
                    message  = "X API returned 403 Forbidden, so the bot automatically switched to PC Browser Mode and posted your tweet! (Tip: Keep Default Mode on 'PC Browser Mode' to avoid X API 403 limits.)"
                }
                $useMode = "browser_auto"
            }
        }
    } else {
        $result = Invoke-BrowserTweet -tweetText $tweetObj.text -cfg $cfg
    }

    $history = [System.Collections.ArrayList]@(Read-JsonSafe $HistoryPath @())
    $entry = [PSCustomObject]@{
        id          = "TWT-" + (Get-Date -Format "yyyyMMdd-HHmmss")
        timestamp   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        text        = $tweetObj.text
        category    = $tweetObj.category
        link_type   = $tweetObj.link_type
        mode        = $useMode
        status      = if ($result.success) { "Posted" } else { "Failed" }
        tweet_id    = if ($result.tweet_id) { $result.tweet_id } else { "" }
        message     = if ($result.success) { $result.message } else { $result.error }
    }
    $history.Insert(0, $entry)
    while ($history.Count -gt 100) {
        $history.RemoveAt($history.Count - 1)
    }
    Write-JsonSafe $HistoryPath $history

    $script:LastPostResult = $entry
    return @{
        success = $result.success
        entry   = $entry
        error   = $result.error
        message = $result.message
    }
}

if ($PostOnceAndExit) {
    $res = Publish-TweetNow
    if ($res.success) {
        Write-Host "[OK] $($res.message)"
        exit 0
    } else {
        Write-Host "[ERROR] $($res.error)"
        exit 1
    }
}

# Initialize Scheduler if enabled
$initCfg = Get-BotConfig
if ($initCfg.auto_schedule_enabled -eq $true) {
    $hrs = if ($initCfg.interval_hours -and [double]$initCfg.interval_hours -gt 0) { [double]$initCfg.interval_hours } else { 3 }
    $script:NextScheduledRun = (Get-Date).AddHours($hrs)
}

# Stop any older instance of bot_engine.ps1 so port 8090 is free and latest code runs
try {
    $oldProcs = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like "*bot_engine.ps1*" }
    foreach ($p in $oldProcs) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 400
} catch {}

$listener = $null
$prefix = ""
for ($tryPort = $Port; $tryPort -lt ($Port + 10); $tryPort++) {
    try {
        $candidate = New-Object System.Net.HttpListener
        $candidatePrefix = "http://localhost:$tryPort/"
        $candidate.Prefixes.Add($candidatePrefix)
        $candidate.Start()
        $listener = $candidate
        $prefix = $candidatePrefix
        $Port = $tryPort
        break
    } catch {
        try { $candidate.Close() } catch {}
    }
}

if (-not $listener) {
    Write-Host "[ERROR] Could not start local web server on ports 8090-8099." -ForegroundColor Red
    exit 1
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  LUNA STREAM 4K IPTV - TWITTER / X AUTO-PROMOTER BOT" -ForegroundColor Green
Write-Host "  Control Panel URL: $prefix" -ForegroundColor Yellow
Write-Host "  Keep this window open while using PC Auto-Scheduler." -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Cyan

try {
    Start-Process $prefix | Out-Null
} catch {}

function Send-JsonResponse($response, $data, [int]$statusCode = 200) {
    $response.StatusCode = $statusCode
    $response.ContentType = "application/json; charset=utf-8"
    $response.Headers.Add("Cache-Control", "no-store")
    $json = $data | ConvertTo-Json -Depth 10
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $response.ContentLength64 = $bytes.Length
    $response.OutputStream.Write($bytes, 0, $bytes.Length)
    $response.OutputStream.Close()
}

function Read-RequestBody($request) {
    $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
    $body = $reader.ReadToEnd()
    $reader.Close()
    if (-not $body -or $body.Trim() -eq "") { return $null }
    return ($body | ConvertFrom-Json)
}

try {
    $asyncResult = $listener.BeginGetContext($null, $null)
    while ($listener.IsListening) {
        if ($asyncResult.AsyncWaitHandle.WaitOne(1000)) {
            $context = $listener.EndGetContext($asyncResult)
            $asyncResult = $listener.BeginGetContext($null, $null)

            $req  = $context.Request
            $resp = $context.Response
            $path = $req.Url.AbsolutePath.ToLower()
            $method = $req.HttpMethod.ToUpper()

            try {
                if ($path -eq "/" -or $path -eq "/index.html" -or $path -eq "/dashboard.html") {
                    $dashFile = Join-Path $RootDir "dashboard.html"
                    $html = Get-Content $dashFile -Raw -Encoding UTF8
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($html)
                    $resp.StatusCode = 200
                    $resp.ContentType = "text/html; charset=utf-8"
                    $resp.ContentLength64 = $bytes.Length
                    $resp.OutputStream.Write($bytes, 0, $bytes.Length)
                    $resp.OutputStream.Close()
                    continue
                }

                if ($path -eq "/api/status" -and $method -eq "GET") {
                    $cfg = Get-BotConfig
                    $history = @(Read-JsonSafe $HistoryPath @())
                    $tplData = Read-JsonSafe $TemplatesPath $null
                    $hasApiKeys = [bool]($cfg.x_api_key -and $cfg.x_api_secret -and $cfg.x_access_token -and $cfg.x_access_secret)

                    $maskedCfg = [ordered]@{
                        mode                    = $cfg.mode
                        auto_schedule_enabled   = [bool]$cfg.auto_schedule_enabled
                        interval_hours          = $cfg.interval_hours
                        rotation_mode           = $cfg.rotation_mode
                        rotation_index          = $cfg.rotation_index
                        whatsapp_number         = $cfg.whatsapp_number
                        whatsapp_link           = $cfg.whatsapp_link
                        netlify_url             = $cfg.netlify_url
                        website_url             = $cfg.website_url
                        has_x_api_keys          = $hasApiKeys
                        x_api_key_preview       = if ($cfg.x_api_key) { $cfg.x_api_key.Substring(0, [Math]::Min(5, $cfg.x_api_key.Length)) + "..." } else { "" }
                        browser_auto_press_send = [bool]($cfg.browser_auto_press_send -ne $false)
                        browser_wait_seconds    = if ($cfg.browser_wait_seconds) { [int]$cfg.browser_wait_seconds } else { 7 }
                        enabled_categories      = @($cfg.enabled_categories)
                    }

                    Send-JsonResponse $resp @{
                        config         = $maskedCfg
                        next_run_utc   = if ($script:NextScheduledRun) { $script:NextScheduledRun.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") } else { $null }
                        history        = @($history | Select-Object -First 30)
                        templates      = if ($tplData -and $tplData.templates) { @($tplData.templates) } else { @() }
                        server_time    = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                    }
                    continue
                }

                if ($path -eq "/api/preview" -and $method -eq "POST") {
                    $body = Read-RequestBody $req
                    $cat = if ($body -and $body.category) { [string]$body.category } else { "random" }
                    $preview = New-PromotionalTweet -RequestedCategory $cat
                    Send-JsonResponse $resp @{
                        success = $true
                        preview = $preview
                    }
                    continue
                }

                if ($path -eq "/api/post-now" -and $method -eq "POST") {
                    $body = Read-RequestBody $req
                    $text = if ($body -and $body.text) { [string]$body.text } else { "" }
                    $cat  = if ($body -and $body.category) { [string]$body.category } else { "random" }
                    $mode = if ($body -and $body.mode) { [string]$body.mode } else { "" }

                    $res = Publish-TweetNow -customText $text -category $cat -overrideMode $mode
                    Send-JsonResponse $resp $res
                    continue
                }

                if ($path -eq "/api/config" -and $method -eq "POST") {
                    $body = Read-RequestBody $req
                    $cfg = Get-BotConfig

                    if ($null -ne $body.mode) { $cfg.mode = [string]$body.mode }
                    if ($null -ne $body.interval_hours) { $cfg.interval_hours = [double]$body.interval_hours }
                    if ($null -ne $body.rotation_mode) { $cfg.rotation_mode = [string]$body.rotation_mode }
                    if ($null -ne $body.whatsapp_number) { $cfg.whatsapp_number = [string]$body.whatsapp_number }
                    if ($null -ne $body.netlify_url) { $cfg.netlify_url = [string]$body.netlify_url }
                    if ($null -ne $body.website_url) { $cfg.website_url = [string]$body.website_url }
                    if ($null -ne $body.browser_auto_press_send) { $cfg.browser_auto_press_send = [bool]$body.browser_auto_press_send }
                    if ($null -ne $body.browser_wait_seconds) { $cfg.browser_wait_seconds = [int]$body.browser_wait_seconds }
                    if ($null -ne $body.enabled_categories) { $cfg.enabled_categories = @($body.enabled_categories) }

                    if ($body.x_api_key -and ([string]$body.x_api_key).Trim() -ne "") {
                        $cfg.x_api_key = ([string]$body.x_api_key).Trim()
                    }
                    if ($body.x_api_secret -and ([string]$body.x_api_secret).Trim() -ne "") {
                        $cfg.x_api_secret = ([string]$body.x_api_secret).Trim()
                    }
                    if ($body.x_access_token -and ([string]$body.x_access_token).Trim() -ne "") {
                        $cfg.x_access_token = ([string]$body.x_access_token).Trim()
                    }
                    if ($body.x_access_secret -and ([string]$body.x_access_secret).Trim() -ne "") {
                        $cfg.x_access_secret = ([string]$body.x_access_secret).Trim()
                    }

                    if ($null -ne $body.auto_schedule_enabled) {
                        $cfg.auto_schedule_enabled = [bool]$body.auto_schedule_enabled
                        if ($cfg.auto_schedule_enabled) {
                            $hrs = if ($cfg.interval_hours -gt 0) { [double]$cfg.interval_hours } else { 3 }
                            if ($body.run_first_immediately -eq $true) {
                                $script:NextScheduledRun = (Get-Date).AddSeconds(5)
                            } else {
                                $script:NextScheduledRun = (Get-Date).AddHours($hrs)
                            }
                        } else {
                            $script:NextScheduledRun = $null
                        }
                    }

                    Save-BotConfig $cfg
                    Send-JsonResponse $resp @{
                        success      = $true
                        message      = "Bot settings saved!"
                        next_run_utc = if ($script:NextScheduledRun) { $script:NextScheduledRun.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") } else { $null }
                    }
                    continue
                }

                if ($path -eq "/api/templates/add" -and $method -eq "POST") {
                    $body = Read-RequestBody $req
                    if (-not $body -or -not $body.body) {
                        Send-JsonResponse $resp @{ success = $false; error = "Template body is required." } 400
                        continue
                    }
                    $tplData = Read-JsonSafe $TemplatesPath $null
                    $list = [System.Collections.ArrayList]@($tplData.templates)
                    $newTpl = [PSCustomObject]@{
                        id       = "cust_" + (Get-Date -Format "HHmmss")
                        category = if ($body.category) { [string]$body.category } else { "free_trial" }
                        body     = ([string]$body.body).Trim()
                    }
                    $list.Insert(0, $newTpl)
                    $tplData.templates = @($list)
                    Write-JsonSafe $TemplatesPath $tplData
                    Send-JsonResponse $resp @{ success = $true; template = $newTpl }
                    continue
                }

                Send-JsonResponse $resp @{ error = "Not Found" } 404
            } catch {
                Send-JsonResponse $resp @{ success = $false; error = $_.Exception.Message } 500
            }
        }

        # Check Background Auto-Scheduler
        $cfgNow = Get-BotConfig
        if ($cfgNow.auto_schedule_enabled -eq $true -and $null -ne $script:NextScheduledRun) {
            if ((Get-Date) -ge $script:NextScheduledRun) {
                $hrs = if ($cfgNow.interval_hours -and [double]$cfgNow.interval_hours -gt 0) { [double]$cfgNow.interval_hours } else { 3 }
                $script:NextScheduledRun = (Get-Date).AddHours($hrs)
                Write-Host "[Auto-Scheduler] Posting scheduled promotional tweet..." -ForegroundColor Green
                try {
                    $autoRes = Publish-TweetNow
                    Write-Host "[Auto-Scheduler] Result: $($autoRes.message) $($autoRes.error)" -ForegroundColor Yellow
                } catch {
                    Write-Host "[Auto-Scheduler] Error: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }
} finally {
    $listener.Stop()
}
