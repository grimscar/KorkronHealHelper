local _, KH = ...

local Advisor = {}
KH.Advisor = Advisor

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
    if #normal == 0 then normal, fast = fast, {} end
    table.sort(normal, function(a, b)
        if a.amount ~= b.amount then return a.amount < b.amount end
        return (a.info.cost or 0) < (b.info.cost or 0)
    end)
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

function Advisor.Choose(plan, fraction)
    for _, band in ipairs(plan) do
        if fraction >= band.lo and fraction < band.hi then return band end
        if band.lo == 0 and fraction <= 0 and band.hi > 0 then return band end
    end
end

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

function Advisor.Thresholds(options, settings, hot)
    local overheal = 1 + (settings.overheal or 0)
    local out = {}
    for _, option in ipairs(options.normal) do
        out[#out + 1] = { option = option, threshold = option.amount / overheal + (hot or 0) }
    end
    return out
end

function Advisor.DangerLine(options, dps, settings)
    if not options.emergency or not dps or dps <= 0 then return 0 end
    local cast = 0
    for _, option in ipairs(options.normal) do
        cast = math.max(cast, option.info.castTime or 0)
    end
    return dps * (math.max(cast, 1.5) + KH.Tracker.CastDelay() + (settings.safety or 1))
end

function Advisor.ByTime(settings)
    return settings.emergencyByTime and KH.Tracker.DamageReadable()
end
