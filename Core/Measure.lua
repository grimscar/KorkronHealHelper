-- Kor'kron Heal Helper: learns what her heals really heal for.
--
-- On Forever the tooltip doesn't always match the real heal: low ranks heal less than their
-- tooltip says. So a "HEAL" combat text within half a second of one of her direct heals finishing
-- is taken as that heal's result. Either can come first: the beta sent the cast first, the
-- release sends the heal first. Critical heals are skipped. When the game hides the
-- amount nothing is learned (the probe counts those). Results are kept per character and spell
-- ID, and thrown away when her +healing changes. Once a rank has a few results, Spells uses their
-- average instead of the tooltip.
local _, KH = ...

local Measure = {}
KH.Measure = Measure

Measure.MIN = 3          -- results needed before they replace the tooltip
Measure.WINDOW = 0.5     -- seconds between the cast finishing and its heal (either order)
Measure.stats = { seen = 0, hidden = 0, crits = 0,
    -- where results get lost, for the probe: her direct heal casts, casts whose spell ID was
    -- hidden, combat-text events of any kind, ones whose type was hidden, heals, heals too late
    casts = 0, castHidden = 0, events = 0, actionHidden = 0, heals = 0, late = 0 }

local pending   -- { id, time } of her last direct heal, waiting for its heal
local lastHeal  -- { amount, indicator, time } of the last heal, waiting for its cast

local function Data()
    local m = KH.char.measured
    if not m or m.bonus ~= KH.Spells.bonus then
        m = { bonus = KH.Spells.bonus, spells = {} }
        KH.char.measured = m
    end
    return m.spells
end

-- the results for a spell ID (any count), or nil
function Measure.Seen(id)
    local m = KH.char and KH.char.measured
    if not m or m.bonus ~= KH.Spells.bonus then return nil end
    return m.spells[id]
end

-- the average real heal, once there are enough results to trust
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
    -- new numbers for the Spells tab and the frames' advice
    KH:OutOfCombat("measured", KH.Spells.Scan)
end

function Measure.Clear()
    if KH.char then KH.char.measured = nil end
    KH.Spells.Scan()
end

-- one heal result for a spell: learned, or counted as hidden or critical
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
    if heal and GetTime() - heal.time <= Measure.WINDOW then
        Use(spellID, heal.amount, heal.indicator)
    else
        pending = { id = spellID, time = GetTime() }
    end
end)

Measure.combatEvent = KH:RegisterEvent("UNIT_COMBAT", function(_, action, indicator, amount)
    local stats = Measure.stats
    stats.events = stats.events + 1
    if not KH.Readable(action) then
        stats.actionHidden = stats.actionHidden + 1
        return
    end
    if action ~= "HEAL" then return end
    stats.heals = stats.heals + 1
    local cast = pending
    pending = nil
    if cast and GetTime() - cast.time <= Measure.WINDOW then
        Use(cast.id, amount, indicator)
        return
    end
    if cast then stats.late = stats.late + 1 end
    -- maybe her cast's event is still to come
    lastHeal = { amount = amount, indicator = indicator, time = GetTime() }
end)
