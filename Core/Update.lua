local _, KH = ...

local Update = {}
KH.Update = Update

local PREFIX = "KorkronHeal"
local URL = "https://github.com/grimscar/KorkronHealHelper"
local AFTER_LOGIN = 20

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

local function Parts(version)
    local out = {}
    for n in string.gmatch(version, "%d+") do out[#out + 1] = tonumber(n) end
    return out
end

function Update.Newer(a, b)
    local x, y = Parts(a), Parts(b)
    for i = 1, math.max(#x, #y) do
        if (x[i] or 0) ~= (y[i] or 0) then return (x[i] or 0) > (y[i] or 0) end
    end
    return false
end

local function Send()
    if IsInGuild() and not IsInInstance() then
        C_ChatInfo.SendAddonMessage(PREFIX, "V^" .. KH.version, "GUILD")
    end
end

local told

local function Tell(version)
    if told == version then return end
    told = version
    KH:Print("version %s is out (you have %s): update it in WowUp, or get it from %s", version, KH.version, URL)
end

local function Seen(version)
    if not Update.Newer(version, KH.version) then return end
    if not KH.db.newestSeen or Update.Newer(version, KH.db.newestSeen) then
        KH.db.newestSeen = version
    end
    Tell(KH.db.newestSeen)
end

local heard = {}
local replying

local function OnVersion(version)
    local asked = GetTime()
    heard[version] = asked
    Seen(version)
    if replying or not Update.Newer(KH.version, version) then return end
    replying = true
    KH:After(math.random(2, 10), function()
        replying = false
        for v, at in pairs(heard) do
            if at > asked and not Update.Newer(KH.version, v) then return end
        end
        Send()
    end)
end

KH:RegisterEvent("CHAT_MSG_ADDON", function(prefix, msg, channel)
    prefix, msg, channel = KH.Text(prefix), KH.Text(msg), KH.Text(channel)
    if prefix ~= PREFIX or channel ~= "GUILD" or not msg then return end
    local version = string.match(msg, "^V%^(%d+%.%d+[%d%.]*)$")
    if version then OnVersion(version) end
end)

KH:RegisterEvent("PLAYER_LOGIN", function()
    KH:After(AFTER_LOGIN, function()
        local newest = KH.db.newestSeen
        if newest and Update.Newer(newest, KH.version) then
            Tell(newest)
        else
            KH.db.newestSeen = nil
        end
        Send()
    end)
end)
