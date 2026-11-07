-- Kor'kron Heal Helper: "a new version is out". The game can't see WowUp, so guildmates' copies of the addon tell
-- each other their version over the guild's hidden addon channel; a newer one than hers gets a line in chat, once a
-- session, and again at each login until she updates (KorkronHealHelperDB.newestSeen).
--   V^version   sent once, 20 seconds after login (outside instances). A copy with a newer version answers once, a
--               few seconds later, unless another copy already did.
-- This is the addon's only addon message. Versions before 0.7.1 don't send or read it.
local _, KH = ...

local Update = {}
KH.Update = Update

local PREFIX = "KorkronHeal" -- the game allows at most 16 characters
local URL = "https://github.com/grimscar/KorkronHealHelper"
local AFTER_LOGIN = 20 -- seconds: chat and the guild channel settle first

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

-- "0.7.1" -> { 0, 7, 1 }
local function Parts(version)
    local out = {}
    for n in string.gmatch(version, "%d+") do out[#out + 1] = tonumber(n) end
    return out
end

-- whether version a is newer than b
function Update.Newer(a, b)
    local x, y = Parts(a), Parts(b)
    for i = 1, math.max(#x, #y) do
        if (x[i] or 0) ~= (y[i] or 0) then return (x[i] or 0) > (y[i] or 0) end
    end
    return false
end

-- one message, no queue needed; one the server turns away (throttled) is simply not sent this time
local function Send()
    if IsInGuild() and not IsInInstance() then
        C_ChatInfo.SendAddonMessage(PREFIX, "V^" .. KH.version, "GUILD")
    end
end

local told -- the version she was told about this session

local function Tell(version)
    if told == version then return end
    told = version
    KH:Print("version %s is out (you have %s): update it in WowUp, or get it from %s", version, KH.version, URL)
end

-- a version a guildmate's copy has: remembered and told when it's newer than hers
local function Seen(version)
    if not Update.Newer(version, KH.version) then return end
    if not KH.db.newestSeen or Update.Newer(version, KH.db.newestSeen) then
        KH.db.newestSeen = version
    end
    Tell(KH.db.newestSeen)
end

local heard = {} -- [version] = GetTime() a V with it last came in
local replying   -- an answer is waiting

local function OnVersion(version)
    local asked = GetTime()
    heard[version] = asked
    Seen(version)
    if replying or not Update.Newer(KH.version, version) then return end
    replying = true
    KH:After(math.random(2, 10), function()
        replying = false
        -- another copy already answered with hers or a newer one: nothing to add
        for v, at in pairs(heard) do
            if at > asked and not Update.Newer(KH.version, v) then return end
        end
        Send()
    end)
end

KH:RegisterEvent("CHAT_MSG_ADDON", function(prefix, msg, channel)
    -- the game can hide these inside instances; a hidden message can't be read, so it's skipped
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
            KH.db.newestSeen = nil -- updated since
        end
        Send()
    end)
end)
