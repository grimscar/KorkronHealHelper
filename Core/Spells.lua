-- Kor'kron Heal Helper: the heals and cleanses you know, and what each rank is worth.
--
-- Spells.heals[name]    = { def = ClassData entry, ranks = { [n] = info }, maxRank = n }
-- Spells.cleanses[name] = { def = ClassData entry, info = info }
-- Spells.others[name]   = { def = ClassData entry, info = info }  (Rebirth, Lay on Hands, ...)
-- Spells.dispels[type]  = true for every debuff type you can remove ("Poison", "Disease", ...)
-- Spells.byID[spellID]  = info
-- Spells.res            = name of your resurrection spell, if you know it
--
-- info = { id, name, rank, castName, min, max, cost, castTime, coef, bonus, amount, hpm, hps, best }
--   amount  average heal including +healing (Classic coefficients, see ClassData.Coefficient)
--   hpm     heal per mana, the number that says which rank is mana-efficient
--   best    true for the rank with the best heal per mana of that spell
local _, KH = ...

local Spells = {}
KH.Spells = Spells

Spells.heals = {}
Spells.cleanses = {}
Spells.others = {}
Spells.dispels = {}
Spells.byID = {}
Spells.bonus = 0

local ClassData = KH.ClassData

-- spellbook ------------------------------------------------------------------------------

-- every spell in the spellbook as { id, name, subName }
local function ReadSpellbook()
    local out = {}
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() or 0 do
            local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if lineInfo then
                local offset, count = lineInfo.itemIndexOffset or 0, lineInfo.numSpellBookItems or 0
                for index = offset + 1, offset + count do
                    local item = C_SpellBook.GetSpellBookItemInfo(index, bank)
                    if item and item.spellID and (spellType == nil or item.itemType == spellType) then
                        out[#out + 1] = { id = item.spellID, name = KH.Text(item.name), subName = KH.Text(item.subName) }
                    end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(tab)
            for index = offset + 1, offset + count do
                local kind, id = GetSpellBookItemInfo(index, BOOKTYPE_SPELL or "spell")
                if kind == "SPELL" and id then
                    local name, subName = GetSpellBookItemName(index, BOOKTYPE_SPELL or "spell")
                    out[#out + 1] = { id = id, name = KH.Text(name), subName = KH.Text(subName) }
                end
            end
        end
    end
    return out
end

local function Known(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if IsSpellKnown and IsSpellKnown(id) then return true end
    return false
end

local function RankFromText(subName)
    return subName and tonumber(string.match(subName, "(%d+)"))
end

-- the rank number of a spellbook entry: by its ID in our table, else its "Rank 3" text
local function RankOf(def, id, subName)
    for n, r in ipairs(def.ranks or {}) do
        if r.id == id then return n end
    end
    return RankFromText(subName)
end

-- spell details from the game --------------------------------------------------------------

local function Description(id)
    local text
    if C_Spell and C_Spell.GetSpellDescription then
        text = C_Spell.GetSpellDescription(id)
    elseif GetSpellDescription then
        text = GetSpellDescription(id)
    end
    text = KH.Text(text)
    if (not text or text == "") and C_Spell and C_Spell.RequestLoadSpellData then
        C_Spell.RequestLoadSpellData(id) -- SPELL_DATA_LOAD_RESULT triggers a rescan
    end
    return text
end

local function Number(s)
    return s and tonumber((string.gsub(s, "[,%.]", "")))
end

-- "Heals a friendly target for 268 to 316." -> 268, 316
function Spells.ParseAmount(text, kind)
    if not text then return nil end
    -- "Heals the target of 45 damage over 15 sec." / "Heals the target for 32 over 12 sec."
    if kind == "hot" then
        local total = string.match(text, "(%d[%d,%.]*) damage over") or string.match(text, "(%d[%d,%.]*) over %d")
        if total then return Number(total), Number(total) end
    elseif kind == "shield" then
        local absorb = string.match(text, "absorbing (%d[%d,%.]*)")
        if absorb then return Number(absorb), Number(absorb) end
    end
    local lo, hi = string.match(text, "for (%d[%d,%.]*) to (%d[%d,%.]*)")
    if lo then return Number(lo), Number(hi) end
    local one = string.match(text, "for (%d[%d,%.]*)")
    if one then return Number(one), Number(one) end
    return nil
end

local function ManaCost(id)
    local costs
    if C_Spell and C_Spell.GetSpellPowerCost then
        costs = C_Spell.GetSpellPowerCost(id)
    elseif GetSpellPowerCost then
        costs = GetSpellPowerCost(id)
    end
    for _, c in ipairs(costs or {}) do
        local cost = KH.Num(c.cost)
        if cost and (c.type == nil or c.type == 0) then return cost end
    end
    return nil
end

-- seconds, after talents (Improved Healing Wave and the like)
local function CastTime(id)
    local ms
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        ms = info and info.castTime
    elseif GetSpellInfo then
        ms = select(4, GetSpellInfo(id))
    end
    ms = KH.Num(ms)
    return ms and ms / 1000 or nil
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return KH.Text(C_Spell.GetSpellName(id)) end
    if GetSpellInfo then return KH.Text((GetSpellInfo(id))) end
end

-- nil while the game hides it (in combat): keep the last known value then
local function BonusHealing()
    if not GetSpellBonusHealing then return 0 end
    return KH.Num(GetSpellBonusHealing())
end

-- what a click-cast or macro uses to cast this exact rank
local function CastName(name, rank, subName, rankCount)
    if subName and subName ~= "" then return name .. "(" .. subName .. ")" end
    if rank and rankCount > 1 then return name .. "(Rank " .. rank .. ")" end
    return name
end

-- scanning ---------------------------------------------------------------------------------

local function BuildInfo(name, def, rank, id, subName)
    local rdef = def.ranks and def.ranks[rank] or {}
    local info = { id = id, name = name, rank = rank, subName = subName }
    info.castName = CastName(name, rank, subName, def.ranks and #def.ranks or 1)
    info.level = rdef.level

    local text = Description(id)
    local lo, hi = Spells.ParseAmount(text, def.kind)
    info.parsed = lo ~= nil
    -- Regrowth: "... for 93 to 107 and another 98 over 21 sec."
    if def.hot and text then
        local rest = string.match(text, "for %d[%d,%.]* to %d[%d,%.]*(.*)")
        info.hotAmount = rest and Spells.ParseAmount(rest, "hot")
    end
    info.min, info.max = lo or rdef.min, hi or rdef.max
    info.cost = ManaCost(id) or rdef.cost
    info.castTime = CastTime(id) or rdef.cast or def.cast
    info.coef = ClassData.Coefficient(def, rdef)
    -- where the amount comes from, best first: her real heals ("seen"), the tooltip (which
    -- already includes +healing on Forever), or the Classic base values plus +healing ("estimate")
    info.seen = KH.Measure and KH.Measure.Seen(id)
    local seenAverage = KH.Measure and KH.Measure.Average(id)
    if seenAverage then
        info.amount, info.source = seenAverage, "seen"
    elseif info.min and info.max then
        info.amount, info.source = (info.min + info.max) / 2, "tooltip"
        if not info.parsed then
            info.amount, info.source = info.amount + Spells.bonus * info.coef, "estimate"
        end
    end
    if info.amount and info.cost and info.cost > 0 then
        info.hpm = info.amount / info.cost
    end
    if info.amount and def.kind == "hot" and def.duration then
        info.hps = info.amount / def.duration
    elseif info.amount and info.castTime and info.castTime > 0 then
        info.hps = info.amount / math.max(1.5, info.castTime)
    end
    return info
end

function Spells.Scan()
    local data = ClassData.ForPlayer()
    Spells.heals, Spells.cleanses, Spells.others, Spells.dispels, Spells.byID = {}, {}, {}, {}, {}
    Spells.res = nil
    Spells.bonus = BonusHealing() or Spells.bonus
    if not data then
        KH:Fire("SPELLS_UPDATED")
        return
    end

    -- name -> rank -> { id, subName }
    local found = {}
    local function Add(name, rank, id, subName)
        found[name] = found[name] or {}
        rank = rank or 1
        if not found[name][rank] then found[name][rank] = { id = id, subName = subName } end
    end

    local res = data.res
    for _, entry in ipairs(ReadSpellbook()) do
        local name = entry.name or SpellName(entry.id)
        if res and name == res.name then Spells.res = res.name end
        local others = data.others or {}
        local def = name and (data.heals[name] or data.cleanses[name] or others[name])
        if def then
            Add(name, data.heals[name] and RankOf(def, entry.id, entry.subName) or 1, entry.id, entry.subName)
        end
    end
    -- ranks the spellbook didn't list (some clients only show the highest rank)
    for name, def in pairs(data.heals) do
        for n, r in ipairs(def.ranks) do
            if r.id and Known(r.id) then Add(name, n, r.id) end
        end
    end
    for _, list in ipairs({ data.cleanses, data.others or {} }) do
        for name, def in pairs(list) do
            for n, id in ipairs(def.ids or {}) do
                if Known(id) then Add(name, n, id) end
            end
        end
    end
    for _, id in ipairs(res and res.ids or {}) do
        if Known(id) then Spells.res = res.name end
    end

    for name, ranks in pairs(found) do
        local healDef, cleanseDef, otherDef = data.heals[name], data.cleanses[name], data.others and data.others[name]
        if healDef then
            local entry = { def = healDef, ranks = {}, maxRank = 0 }
            for rank, r in pairs(ranks) do
                local info = BuildInfo(name, healDef, rank, r.id, r.subName)
                entry.ranks[rank] = info
                Spells.byID[r.id] = info
                if rank > entry.maxRank then entry.maxRank = rank end
            end
            -- flag the most mana-efficient rank
            local best
            for _, info in pairs(entry.ranks) do
                if info.hpm and (not best or info.hpm > best.hpm) then best = info end
            end
            if best then best.best = true end
            Spells.heals[name] = entry
        elseif cleanseDef or otherDef then
            -- the highest rank known; cast by name (the game picks the highest rank too)
            local highest
            for rank, r in pairs(ranks) do
                if not highest or rank > highest.rank then highest = { rank = rank, id = r.id, subName = r.subName } end
            end
            local info = { id = highest.id, name = name, rank = highest.rank, castName = name, cost = ManaCost(highest.id) }
            Spells.byID[highest.id] = info
            if cleanseDef then
                Spells.cleanses[name] = { def = cleanseDef, info = info }
                for t in pairs(cleanseDef.types) do Spells.dispels[t] = true end
            else
                Spells.others[name] = { def = otherDef, info = info }
            end
        end
    end
    KH:Fire("SPELLS_UPDATED")
end

-- lookups ------------------------------------------------------------------------------------

-- rank: a number, "max", "max-1", "max-2" ... ; returns the info for that rank or the closest known
function Spells.Resolve(name, rank)
    local single = Spells.cleanses[name] or Spells.others[name]
    if single then return single.info end
    local heal = Spells.heals[name]
    if not heal then return nil end
    if rank == "best" then
        for _, info in pairs(heal.ranks) do
            if info.best then return info end
        end
        rank = "max"
    end
    local n
    if type(rank) == "number" then
        n = rank
    elseif rank == nil or rank == "max" then
        n = heal.maxRank
    else
        local back = tonumber(string.match(tostring(rank), "^max%-(%d+)$")) or 0
        n = heal.maxRank - back
    end
    n = math.max(1, math.min(n, heal.maxRank))
    -- known ranks can have gaps (an untrained rank): take the nearest known one at or below
    for i = n, 1, -1 do
        if heal.ranks[i] then return heal.ranks[i] end
    end
    for i = n + 1, heal.maxRank do
        if heal.ranks[i] then return heal.ranks[i] end
    end
end

function Spells.Def(name)
    local heal = Spells.heals[name]
    if heal then return heal.def, "heal" end
    local cleanse = Spells.cleanses[name]
    if cleanse then return cleanse.def, "cleanse" end
    local other = Spells.others[name]
    if other then return other.def, "other" end
end

-- spellbook spells this addon has no data for whose tooltip talks about healing, shielding or
-- restoring health (Forever-only spells, for the game check report): { { id, name, text }, ... }
function Spells.UnknownHealingSpells()
    local data = ClassData.ForPlayer()
    local knownNames = {}
    if data then
        for _, list in ipairs({ data.heals, data.cleanses, data.others or {} }) do
            for name in pairs(list) do knownNames[name] = true end
        end
        if data.res then knownNames[data.res.name] = true end
    end
    local out, seen = {}, {}
    for _, entry in ipairs(ReadSpellbook()) do
        local name = entry.name or SpellName(entry.id)
        if name and not knownNames[name] and not seen[name] then
            local text = Description(entry.id)
            -- "Health by 180" (Bear Form) isn't healing
            local lower = text and string.gsub(string.lower(text), "health", "")
            if lower and (lower:find("heal") or lower:find("absorb") or lower:find("restor")) then
                seen[name] = true
                out[#out + 1] = { id = entry.id, name = name, text = text }
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- every known heal rank, sorted by spell then rank (for the Spells tab)
function Spells.AllHealRanks()
    local out = {}
    for _, entry in pairs(Spells.heals) do
        for _, info in pairs(entry.ranks) do out[#out + 1] = info end
    end
    table.sort(out, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.rank < b.rank
    end)
    return out
end

-- the biggest shield she can cast (a full shield bar), nil when she has none
function Spells.BiggestShield()
    local most
    for _, entry in pairs(Spells.heals) do
        if entry.def.kind == "shield" then
            for _, info in pairs(entry.ranks) do
                if info.amount and (not most or info.amount > most) then most = info.amount end
            end
        end
    end
    return most
end

function Spells.Short(info)
    local def = Spells.Def(info.name)
    local short = def and def.short or string.sub(info.name, 1, 3)
    if Spells.heals[info.name] then return short .. info.rank end
    return short
end

-- events -------------------------------------------------------------------------------------

-- in combat the game may hide +healing and spell details: rescan after the fight
local function Rescan()
    KH:Debounce("spellScan", 0.5, function()
        if InCombatLockdown() then
            KH:OutOfCombat("spellScan", Spells.Scan)
        else
            Spells.Scan()
        end
    end)
end

for _, event in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED",
    "PLAYER_TALENT_UPDATE", "SPELL_DATA_LOAD_RESULT" }) do
    KH:RegisterEvent(event, Rescan)
end

-- gear changes +healing
KH:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function()
    KH:Debounce("bonusCheck", 1, function()
        local bonus = BonusHealing()
        if bonus == nil then
            Rescan()
        elseif bonus ~= Spells.bonus then
            Spells.Scan()
        end
    end)
end)
