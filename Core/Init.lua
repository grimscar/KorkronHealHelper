local ADDON_NAME, KH = ...

KorkronHealHelper = KH

local GetMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

KH.name = ADDON_NAME
KH.version = (GetMetadata and GetMetadata(ADDON_NAME, "Version")) or "dev"
KH.TITLE = "|cffc41f3bKor'kron|r Heal Helper"

local CHAT_TAG = "|cffc41f3bKor'kron Heal:|r "

local function Format(fmt, ...)
    local n = select("#", ...)
    if n == 0 then return tostring(fmt) end
    local args = { ... }
    for i = 1, n do args[i] = tostring(args[i]) end
    return string.format(fmt, unpack(args, 1, n))
end

function KH:Print(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage(CHAT_TAG .. Format(fmt, ...))
end

function KH:Debug(fmt, ...)
    if not (self.db and self.db.settings and self.db.settings.debug) then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cff888888[KHH debug]|r " .. Format(fmt, ...))
end

function KH.Readable(value)
    return not (issecretvalue and issecretvalue(value))
end

function KH.Num(value)
    if type(value) == "number" and KH.Readable(value) then return value end
    return nil
end

function KH.Text(value)
    if type(value) == "string" and KH.Readable(value) then return value end
    return nil
end

function KH.Bool(value)
    if not KH.Readable(value) then return nil end
    return value and true or false
end

KH.API = {
    curves = (C_CurveUtil and C_CurveUtil.CreateCurve and UnitHealthPercent and Enum and Enum.LuaCurveType) and true or false,
    pickFromBool = (C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean) and true or false,
    auraContainers = (C_XMLUtil and C_XMLUtil.GetTemplateInfo
        and C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate")) and true or false,
    healthMissing = UnitHealthMissing ~= nil,
    absorbs = UnitGetTotalAbsorbs ~= nil,
}

local GROUP_UNITS = { player = true }
for i = 1, 4 do GROUP_UNITS["party" .. i] = true end
for i = 1, 40 do GROUP_UNITS["raid" .. i] = true end

function KH.WatchedUnit(unit)
    if GROUP_UNITS[unit] then return true end
    if unit ~= "target" then return false end
    if KH.Bool(UnitIsUnit("target", "player")) ~= false then return false end
    return KH.Bool(UnitInParty("target")) == false and KH.Bool(UnitInRaid("target")) == false
end

KH.errors = {}

local function RecordError(err)
    err = tostring(err)
    for _, e in ipairs(KH.errors) do
        if e.message == err then
            e.count = e.count + 1
            return
        end
    end
    local first = #KH.errors == 0
    table.insert(KH.errors, { message = err, count = 1, time = time() })
    if #KH.errors > 20 then table.remove(KH.errors, 1) end
    if first and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(CHAT_TAG .. "something went wrong. Type |cffffd100/khh errors|r to see what.")
    end
end

local function Traceback(e)
    local stack = debugstack and debugstack(2, 4, 0)
    return tostring(e) .. (stack and ("\n" .. stack) or "")
end

function KH.Safe(fn, ...)
    local n = select("#", ...)
    local ok, result
    if n == 0 then
        ok, result = xpcall(fn, Traceback)
    else
        local args = { ... }
        ok, result = xpcall(function() return fn(unpack(args, 1, n)) end, Traceback)
    end
    if not ok then
        RecordError(result)
        return nil
    end
    return result
end

local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

function KH:RegisterEvent(event, handler)
    if not eventHandlers[event] then
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then return false end
        eventHandlers[event] = {}
    end
    table.insert(eventHandlers[event], handler)
    return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = eventHandlers[event]
    if not list then return end
    for i = 1, #list do
        KH.Safe(list[i], ...)
    end
end)

local callbacks = {}

function KH:On(message, fn)
    callbacks[message] = callbacks[message] or {}
    table.insert(callbacks[message], fn)
end

function KH:Fire(message, ...)
    local list = callbacks[message]
    if not list then return end
    for i = 1, #list do
        KH.Safe(list[i], ...)
    end
end

function KH:After(delay, fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, function() KH.Safe(fn) end)
    else
        KH.Safe(fn)
    end
end

local debounceTokens = {}
function KH:Debounce(key, delay, fn)
    local token = (debounceTokens[key] or 0) + 1
    debounceTokens[key] = token
    self:After(delay, function()
        if debounceTokens[key] == token then fn() end
    end)
end

local afterCombat = {}
function KH:OutOfCombat(key, fn)
    if not InCombatLockdown() then
        fn()
        return true
    end
    afterCombat[key] = fn
    return false
end

KH:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    local queued = afterCombat
    afterCombat = {}
    for _, fn in pairs(queued) do KH.Safe(fn) end
end)

function KH.AutoSelfCast()
    local get = (C_CVar and C_CVar.GetCVarBool) or GetCVarBool
    if not get then return nil end
    local ok, on = pcall(get, "autoSelfCast")
    return ok and KH.Bool(on) or false
end

function KH.SetAutoSelfCast(on)
    local set = (C_CVar and C_CVar.SetCVar) or SetCVar
    if set then pcall(set, "autoSelfCast", on and "1" or "0") end
end

function KH.SelfCastKey()
    return GetModifiedClick("SELFCAST")
end

function KH.SetSelfCastKey(key)
    local now = KH:OutOfCombat("selfCastKey", function()
        SetModifiedClick("SELFCAST", key)
        SaveBindings(GetCurrentBindingSet())
    end)
    if not now then KH:Print("The Self Cast key will change when this fight ends.") end
end

function KH.Round(n)
    return math.floor(n + 0.5)
end

function KH.Short(n)
    if n >= 10000 then return string.format("%dk", KH.Round(n / 1000)) end
    if n >= 1000 then return string.format("%.1fk", n / 1000) end
    return tostring(KH.Round(n))
end

function KH.ClassColor(classTag)
    local c = classTag and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classTag]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classTag]))
    if not c then return 0.4, 0.8, 0.4 end
    return c.r, c.g, c.b
end

function KH.ClassColorHex(classTag)
    local r, g, b = KH.ClassColor(classTag)
    return string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
end
