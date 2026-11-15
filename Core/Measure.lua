local _, KH = ...

local Measure = {}
KH.Measure = Measure

Measure.MIN = 3
Measure.WINDOW = 0.5
Measure.stats = { seen = 0, hidden = 0, crits = 0,
    casts = 0, castHidden = 0, events = 0, actionHidden = 0, heals = 0, late = 0, odd = 0 }

local pending
local lastHeal

local function Data()
    local m = KH.char.measured
    if not m or m.bonus ~= KH.Spells.bonus then
        m = { bonus = KH.Spells.bonus, spells = {} }
        KH.char.measured = m
    end
    return m.spells
end

function Measure.Seen(id)
    local m = KH.char and KH.char.measured
    if not m or m.bonus ~= KH.Spells.bonus then return nil end
    return m.spells[id]
end

function Measure.Average(id)
    local e = Measure.Seen(id)
    if e and e.n >= Measure.MIN then return e.sum / e.n end
end

function Measure.Record(id, amount)
    local spells = Data()
    local e = spells[id]
    if not e then
        e = { n = 0, sum = 0, min = amount, max = amount }
        spells[id] = e
    end
    e.n, e.sum = e.n + 1, e.sum + amount
    e.min, e.max = math.min(e.min, amount), math.max(e.max, amount)
    Measure.stats.seen = Measure.stats.seen + 1
    KH:OutOfCombat("measured", KH.Spells.Scan)
end

function Measure.Clear()
    if KH.char then KH.char.measured = nil end
    KH.Spells.Scan()
end

local function Use(id, amount, indicator)
    local value = KH.Num(amount)
    if not value or not KH.Readable(indicator) then
        Measure.stats.hidden = Measure.stats.hidden + 1
    elseif indicator == "CRITICAL" then
        Measure.stats.crits = Measure.stats.crits + 1
    elseif value > 0 then
        Measure.Record(id, value)
    end
end

local function Fits(id, amount, indicator)
    if KH.Readable(indicator) and indicator == "CRITICAL" then return true end
    local value = KH.Num(amount)
    local info = KH.Spells.byID[id]
    if not value or not (info and info.parsed and info.min and info.max) then return true end
    return value >= info.min * 0.5 and value <= info.max * 1.6
end

Measure.castEvent = KH:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" then return end
    if not KH.Readable(spellID) then
        Measure.stats.castHidden = Measure.stats.castHidden + 1
        return
    end
    local info = KH.Spells.byID[spellID]
    local def = info and KH.Spells.Def(info.name)
    if not def or def.kind ~= "direct" then return end
    Measure.stats.casts = Measure.stats.casts + 1
    local heal = lastHeal
    lastHeal = nil
    if heal and GetTime() - heal.time <= Measure.WINDOW and Fits(spellID, heal.amount, heal.indicator) then
        Use(spellID, heal.amount, heal.indicator)
    else
        pending = { id = spellID, time = GetTime() }
    end
end)

Measure.combatEvent = KH:RegisterEvent("UNIT_COMBAT", function(unit, action, indicator, amount)
    if not KH.WatchedUnit(unit) then return end
    local stats = Measure.stats
    stats.events = stats.events + 1
    if not KH.Readable(action) then
        stats.actionHidden = stats.actionHidden + 1
        return
    end
    if action ~= "HEAL" then return end
    stats.heals = stats.heals + 1
    local cast = pending
    if cast and GetTime() - cast.time <= Measure.WINDOW then
        if not Fits(cast.id, amount, indicator) then
            stats.odd = stats.odd + 1
            return
        end
        pending = nil
        Use(cast.id, amount, indicator)
        return
    end
    pending = nil
    if cast then stats.late = stats.late + 1 end
    lastHeal = { amount = amount, indicator = indicator, time = GetTime() }
end)
