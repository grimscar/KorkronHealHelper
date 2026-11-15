local _, KH = ...

local Tracker = {}
KH.Tracker = Tracker

Tracker.WINDOW = 5
Tracker.TICK = 3
Tracker.CLICK_WINDOW = 1
Tracker.stats = { damage = 0, hiddenDamage = 0, hots = 0, hotsUnplaced = 0, timed = 0, pushbacks = 0,
    kinds = {} }

Tracker.DELAYS = 5
local delays = {}
local casting

local damage = {}
local hots = {}
local sent
local lastClick

local function GUID(unit)
    return unit and (KH.Text(UnitGUID(unit)) or unit)
end

function Tracker.DamageReadable()
    return Tracker.lastDamageHidden ~= true
end

local function Recent(guid)
    local list = damage[guid]
    if not list then return 0 end
    local since, sum = GetTime() - Tracker.WINDOW, 0
    for i = #list, 1, -1 do
        if list[i][1] < since then
            table.remove(list, i)
        else
            sum = sum + list[i][2]
        end
    end
    if #list == 0 then damage[guid] = nil end
    return sum
end

function Tracker.DamagePerSecond(unit)
    local guid = GUID(unit)
    return guid and Recent(guid) / Tracker.WINDOW or 0
end

function Tracker.CastDelay()
    if #delays == 0 or Tracker.DamagePerSecond("player") <= 0 then return 0 end
    local sum = 0
    for _, d in ipairs(delays) do sum = sum + d end
    return sum / #delays
end

function Tracker.HotRemaining(unit)
    local mine = hots[GUID(unit) or ""]
    if not mine then return 0 end
    local now, total = GetTime(), 0
    for name, h in pairs(mine) do
        local left = h.start + h.duration - now
        if left <= 0 then
            mine[name] = nil
        else
            local ticks = math.max(1, KH.Round(h.duration / Tracker.TICK))
            total = total + h.amount * math.min(ticks, math.ceil(left / Tracker.TICK - 0.001)) / ticks
        end
    end
    return total
end

function Tracker.Busy()
    for guid in pairs(damage) do Recent(guid) end
    for guid, mine in pairs(hots) do
        if next(mine) == nil then hots[guid] = nil end
    end
    return next(damage) ~= nil or next(hots) ~= nil
end

function Tracker.Clear()
    wipe(damage)
    wipe(hots)
end

function Tracker.Clicked(unit)
    lastClick = { unit = unit, time = GetTime() }
end

local function HotOf(spellID)
    local info = KH.Spells.byID[spellID]
    local def = info and KH.Spells.Def(info.name)
    if not def then return nil end
    if def.kind == "hot" and def.duration and info.amount then return info.name, info.amount, def.duration end
    if def.hot and info.hotAmount then return info.name .. " (HoT)", info.hotAmount, def.hot end
end

local function TargetOf(castGUID)
    local matched = sent and castGUID and sent.castGUID == castGUID
    local name = matched and sent.target
    sent = nil
    if lastClick and GetTime() - lastClick.time <= Tracker.CLICK_WINDOW then
        return lastClick.unit
    end
    if not matched then return nil, "no target sent with the cast" end
    if not KH.Readable(name) then return nil, "target name hidden" end
    if name == nil or name == "" then
        if KH.AutoSelfCast() then return "player" end
        return nil, "no target name"
    end
    if KH.AutoSelfCast() and KH.Bool(UnitCanAttack("player", "target"))
        and KH.Text((UnitName("target"))) == name then
        return "player"
    end
    local short = string.match(name, "^([^%-]+)%-") or name
    local units = { "player" }
    if IsInRaid() then
        for i = 1, 40 do units[#units + 1] = "raid" .. i end
    else
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end
    for _, unit in ipairs(units) do
        local n = KH.Text((UnitName(unit)))
        if n and (n == name or n == short) then return unit end
    end
    return nil, "\"" .. name .. "\" isn't in the group"
end

KH:RegisterEvent("UNIT_SPELLCAST_SENT", function(unit, target, castGUID)
    if unit ~= "player" or not KH.Readable(castGUID) or castGUID == nil then return end
    sent = { castGUID = castGUID, target = target }
end)

KH:RegisterEvent("UNIT_SPELLCAST_START", function(unit, castGUID, spellID)
    if unit ~= "player" or not KH.Readable(spellID) or not KH.Readable(castGUID) then return end
    local info = KH.Spells.byID[spellID]
    if not (info and info.castTime and info.castTime > 0) then
        casting = nil
        return
    end
    casting = { castGUID = castGUID, start = GetTime(), expected = info.castTime, hit = false }
end)

KH:RegisterEvent("UNIT_SPELLCAST_DELAYED", function(unit)
    if unit ~= "player" or not casting then return end
    casting.hit = true
    Tracker.stats.pushbacks = Tracker.stats.pushbacks + 1
end)

local function CastDone(castGUID)
    local c = casting
    casting = nil
    if not (c and castGUID and c.castGUID == castGUID) then return end
    Tracker.stats.timed = Tracker.stats.timed + 1
    if not c.hit then return end
    table.insert(delays, math.max(0, GetTime() - c.start - c.expected))
    if #delays > Tracker.DELAYS then table.remove(delays, 1) end
end

for _, event in ipairs({ "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_STOP" }) do
    KH:RegisterEvent(event, function(unit, castGUID)
        if unit == "player" and casting and event ~= "UNIT_SPELLCAST_STOP" then casting = nil end
    end)
end

function Tracker.DelayStats()
    local sum, most = 0, 0
    for _, d in ipairs(delays) do sum, most = sum + d, math.max(most, d) end
    return #delays, #delays > 0 and sum / #delays or 0, most
end

KH:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(unit, castGUID, spellID)
    if unit ~= "player" then return end
    CastDone(KH.Readable(castGUID) and castGUID or nil)
    if not KH.Readable(spellID) then return end
    local name, amount, duration = HotOf(spellID)
    if not name then return end
    local target, why = TargetOf(KH.Readable(castGUID) and castGUID or nil)
    local guid = GUID(target)
    if not guid then
        Tracker.stats.hotsUnplaced = Tracker.stats.hotsUnplaced + 1
        Tracker.stats.lastUnplaced = name .. ": " .. tostring(why)
        return
    end
    hots[guid] = hots[guid] or {}
    hots[guid][name] = { amount = amount, start = GetTime(), duration = duration }
    Tracker.stats.hots = Tracker.stats.hots + 1
    KH:Fire("TRACKER_UPDATED")
end)

KH:RegisterEvent("UNIT_COMBAT", function(unit, action, _, amount)
    if not KH.WatchedUnit(unit) or not KH.Readable(action) then return end
    local kinds = Tracker.stats.kinds
    kinds[action] = (kinds[action] or 0) + 1
    if action == "ABSORB" then action = "WOUND" end
    if action ~= "WOUND" then return end
    if unit == "player" and casting then casting.hit = true end
    local value = KH.Num(amount)
    if not value then
        Tracker.stats.hiddenDamage = Tracker.stats.hiddenDamage + 1
        Tracker.lastDamageHidden = true
        return
    end
    Tracker.lastDamageHidden = false
    local guid = GUID(unit)
    if not guid or value <= 0 then return end
    Tracker.stats.damage = Tracker.stats.damage + 1
    damage[guid] = damage[guid] or {}
    table.insert(damage[guid], { GetTime(), value })
end)

KH:RegisterEvent("UNIT_HEALTH", function(unit)
    if next(hots) == nil then return end
    local guid = GUID(unit)
    if guid and hots[guid] and KH.Bool(UnitIsDeadOrGhost(unit)) then hots[guid] = nil end
end)
