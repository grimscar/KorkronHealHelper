-- Kor'kron Heal Helper: "which heal should I click?"
--
-- The choices are the heals bound to clicks (Bindings.lua), so a suggestion always names a
-- click she has. The rule:
--   * the biggest "efficient" heal that fits the missing health (allowing a little overheal),
--     after the healing her own HoTs on them will still do (Tracker.lua);
--   * the fast heal instead when they'd reach 0 before her slowest efficient heal could land
--     (damage per second from Tracker.lua), or, while damage numbers are hidden, below the
--     emergency health line;
--   * nothing while the missing health is smaller than the smallest heal.
--
-- In combat the game hides health from addons, so Lua can't compare numbers. Instead every
-- choice becomes a band of health percentage (Plan) and each band becomes a curve that the game
-- evaluates itself (UnitHealthPercent(unit, predicted, curve)): 1 inside the band, 0 outside.
-- Turning missing health into a percentage needs the person's maximum health. The frames remember
-- it while it's readable, out of combat.
local _, KH = ...

local Advisor = {}
KH.Advisor = Advisor

-- the heal choices from the current click bindings:
--   { normal = { option, ... } (smallest heal first), emergency = option or nil }
--   option = { key, label, short, info, amount }
function Advisor.Options()
    local normal, fast = {}, {}
    for _, b in ipairs(KH.Bindings.Resolved()) do
        local info = b.info
        local def = info and KH.Spells.Def(info.name)
        if def and def.kind == "direct" and info.amount and info.amount > 0 then
            local option = { key = b.key, label = b.label, short = b.short, info = info, amount = info.amount }
            if def.role == "efficient" then
                normal[#normal + 1] = option
            elseif def.role == "fast" then
                fast[#fast + 1] = option
            end
        end
    end
    -- no efficient heal bound: the fast ones are the choices
    if #normal == 0 then normal, fast = fast, {} end
    table.sort(normal, function(a, b)
        if a.amount ~= b.amount then return a.amount < b.amount end
        return (a.info.cost or 0) < (b.info.cost or 0)
    end)
    -- the same heal bound twice: keep one
    local unique = {}
    for _, o in ipairs(normal) do
        local last = unique[#unique]
        if not (last and last.amount == o.amount) then unique[#unique + 1] = o end
    end
    local emergency
    for _, o in ipairs(fast) do
        if not emergency or o.amount > emergency.amount then emergency = o end
    end
    return { normal = unique, emergency = emergency }
end

-- Bands of health fraction (0 = dead, 1 = full) for one person:
--   { { option, lo, hi }, ... }   option shows while lo <= health < hi
function Advisor.Plan(options, maxHealth, settings)
    local plan = {}
    if not maxHealth or maxHealth <= 0 then return plan end
    local overheal = 1 + (settings.overheal or 0)
    local emergency = (options.emergency and settings.emergency) or 0
    local normal = options.normal
    local function HealthAt(option)
        return 1 - (option.amount / overheal) / maxHealth
    end
    for k, option in ipairs(normal) do
        local hi = HealthAt(option)
        local lo = normal[k + 1] and HealthAt(normal[k + 1]) or 0
        lo = math.max(lo, emergency, 0)
        if hi > lo then
            plan[#plan + 1] = { option = option, lo = lo, hi = hi }
        end
    end
    if emergency > 0 then
        plan[#plan + 1] = { option = options.emergency, lo = 0, hi = emergency, emergency = true }
    end
    return plan
end

-- Lua version of the same rule, for when health is readable (and for the tests)
function Advisor.Choose(plan, fraction)
    for _, band in ipairs(plan) do
        if fraction >= band.lo and fraction < band.hi then return band end
        if band.lo == 0 and fraction <= 0 and band.hi > 0 then return band end
    end
end

-- a step curve that is 1 inside the band and 0 outside
function Advisor.Curve(band)
    local curve = C_CurveUtil.CreateCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    if band.lo <= 0 then
        curve:AddPoint(0, 1)
    else
        curve:AddPoint(0, 0)
        curve:AddPoint(band.lo, 1)
    end
    curve:AddPoint(band.hi, 0)
    return curve
end

-- missing health at which each efficient heal "fits", smallest first (the frames' gates use
-- these; they need no maximum health): { { option, threshold }, ... }
-- `hot` = healing her HoTs on them will still do: a heal only fits the health they still need.
function Advisor.Thresholds(options, settings, hot)
    local overheal = 1 + (settings.overheal or 0)
    local out = {}
    for _, option in ipairs(options.normal) do
        out[#out + 1] = { option = option, threshold = option.amount / overheal + (hot or 0) }
    end
    return out
end

-- Emergency by time: the fast heal is only worth its mana when they'd reach 0 before her slowest
-- efficient heal could land. With `dps` damage per second, that's below this much health
-- (the slowest cast plus a safety margin, times the damage rate). While she's being hit herself,
-- her casts get pushed back: the delay she has really had lately is added. 0 = no danger.
function Advisor.DangerLine(options, dps, settings)
    if not options.emergency or not dps or dps <= 0 then return 0 end
    local cast = 0
    for _, option in ipairs(options.normal) do
        cast = math.max(cast, option.info.castTime or 0)
    end
    return dps * (math.max(cast, 1.5) + KH.Tracker.CastDelay() + (settings.safety or 1))
end

-- true while the emergency follows the danger line (damage numbers readable), else the health %
function Advisor.ByTime(settings)
    return settings.emergencyByTime and KH.Tracker.DamageReadable()
end
