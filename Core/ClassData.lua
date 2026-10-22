-- Kor'kron Heal Helper: what each healing class can cast.
--
-- Forever follows Classic rules (spell ranks, the level-20 downranking penalty, +healing gear),
-- so this is Classic data. It is only a starting point:
--   * Which ranks she knows is read from her spellbook (Spells.lua); the IDs here are a fallback.
--   * Heal amounts and mana costs are read from the game (tooltip text, GetSpellPowerCost);
--     the numbers here are only used when the game hasn't sent them yet.
-- What the game can't tell us is kept here: the level each rank is learned (for the penalty)
-- and the base cast time (for how much +healing a rank gets).
--
-- heals[name]
--   kind      "direct" (one heal), "hot" (heal over time), "shield", "group" (heals several),
--             "special" (Forever-only, behaviour not known yet); only direct heals get advice
--             and are measured
--   duration  heal over time: seconds
--   role      "efficient" = the advisor picks between these by size; "fast" = the emergency heal
--   cast      base cast time in seconds (before talents), per rank when it changes with rank
--   short     abbreviation shown on the frames ("HW" + rank)
--   ranks[n]  { id = spell ID, level = learned at, min, max, cost }
-- cleanses[name] = { types = { Poison = true, ... }, ids = { ... } }
-- others[name] = { ids = { ... } }  other spells worth a click (Rebirth, Lay on Hands, ...)
-- res = { name, ids }  the resurrection a click on a dead frame casts instead (out of combat
--                      ones only: never Rebirth)
local _, KH = ...

local ClassData = {}
KH.ClassData = ClassData

-- Shaman (tested in game first) -----------------------------------------------------------

local SHAMAN = {
    heals = {
        ["Healing Wave"] = {
            kind = "direct", role = "efficient", short = "HW",
            ranks = {
                { id = 331, level = 1, min = 34, max = 44, cost = 25, cast = 1.5 },
                { id = 332, level = 6, min = 64, max = 78, cost = 45, cast = 2.0 },
                { id = 547, level = 12, min = 129, max = 155, cost = 80, cast = 2.5 },
                { id = 913, level = 18, min = 268, max = 316, cost = 155, cast = 3.0 },
                { id = 939, level = 24, min = 376, max = 440, cost = 200, cast = 3.0 },
                { id = 959, level = 32, min = 536, max = 622, cost = 265, cast = 3.0 },
                { id = 8005, level = 40, min = 740, max = 854, cost = 340, cast = 3.0 },
                { id = 10395, level = 48, min = 1017, max = 1167, cost = 440, cast = 3.0 },
                { id = 10396, level = 56, min = 1367, max = 1561, cost = 560, cast = 3.0 },
                { id = 25357, level = 60, min = 1620, max = 1850, cost = 620, cast = 3.0 },
            },
        },
        ["Lesser Healing Wave"] = {
            kind = "direct", role = "fast", short = "LHW", cast = 1.5,
            ranks = {
                { id = 8004, level = 20, min = 162, max = 186, cost = 105 },
                { id = 8008, level = 28, min = 247, max = 281, cost = 145 },
                { id = 8010, level = 36, min = 337, max = 381, cost = 185 },
                { id = 10466, level = 44, min = 458, max = 514, cost = 235 },
                { id = 10467, level = 52, min = 631, max = 705, cost = 305 },
                { id = 10468, level = 60, min = 832, max = 928, cost = 380 },
            },
        },
        ["Chain Heal"] = {
            kind = "direct", short = "CH", cast = 2.5,
            ranks = {
                { id = 1064, level = 40, min = 320, max = 368, cost = 260 },
                { id = 10622, level = 46, min = 405, max = 465, cost = 315 },
                { id = 10623, level = 54, min = 551, max = 629, cost = 405 },
            },
        },
    },
    cleanses = {
        ["Cure Poison"] = { types = { Poison = true }, ids = { 526 } },
        ["Cure Disease"] = { types = { Disease = true }, ids = { 2870 } },
    },
    res = { name = "Ancestral Spirit", ids = { 2008, 20609, 20610, 20776, 20777 } },
    -- the frames' border colour says which click fits: plain Left (most efficient) for most
    -- heals, Shift for big ones, Ctrl for top-ups, Right (Lesser Healing Wave) when it's urgent
    defaults = {
        ["1"] = { spell = "Healing Wave", rank = "best" },
        ["shift-1"] = { spell = "Healing Wave", rank = "max" },
        ["ctrl-1"] = { spell = "Healing Wave", rank = 1 },
        ["alt-1"] = { spell = "Chain Heal", rank = "max" },
        ["2"] = { spell = "Lesser Healing Wave", rank = "max" },
        ["shift-2"] = { spell = "Cure Poison" },
        ["ctrl-2"] = { spell = "Cure Disease" },
        ["alt-2"] = { action = "menu" },
        ["3"] = { action = "target" },
    },
}

-- Other healers (prep pass, not tested in game yet) ------------------------------------------
-- Spell IDs per rank come from the beta's own rank list (ForeverAuras SecretAuraRanks.lua).
-- Levels and cast times are Classic data. Forever-only spells (Penance, Prayer of Mending,
-- Binding Heal, Wild Growth, Revive, ...) have no level here: unknown until someone plays them.
-- Their amounts come from the tooltip or her real heals like every other spell.

local function Ranks(cast, list)
    local out = {}
    for i, r in ipairs(list) do
        out[i] = { id = r[1], level = r[2], cast = r[3] or cast }
    end
    return out
end

-- ranks without known levels (Forever-only spells): just the IDs
local function IDs(cast, ids)
    local out = {}
    for i, id in ipairs(ids) do out[i] = { id = id, cast = cast } end
    return out
end

local PRIEST = {
    heals = {
        ["Lesser Heal"] = { kind = "direct", role = "efficient", short = "LH",
            ranks = Ranks(nil, { { 2050, 1, 1.5 }, { 2052, 4, 2.0 }, { 2053, 10, 2.5 } }) },
        ["Heal"] = { kind = "direct", role = "efficient", short = "H",
            ranks = Ranks(3.0, { { 2054, 16 }, { 2055, 22 }, { 6063, 28 }, { 6064, 34 } }) },
        ["Greater Heal"] = { kind = "direct", role = "efficient", short = "GH",
            ranks = Ranks(3.0, { { 2060, 40 }, { 10963, 46 }, { 10964, 52 }, { 10965, 58 }, { 25314, 60 } }) },
        ["Flash Heal"] = { kind = "direct", role = "fast", short = "FH",
            ranks = Ranks(1.5, { { 2061, 20 }, { 9472, 26 }, { 9473, 32 }, { 9474, 38 }, { 10915, 44 }, { 10916, 50 }, { 10917, 56 } }) },
        ["Renew"] = { kind = "hot", short = "Rn", duration = 15,
            ranks = Ranks(1.5, { { 139, 8 }, { 6074, 14 }, { 6075, 20 }, { 6076, 26 }, { 6077, 32 }, { 6078, 38 }, { 10927, 44 }, { 10928, 50 }, { 10929, 56 }, { 25315, 60 } }) },
        ["Power Word: Shield"] = { kind = "shield", short = "PWS",
            ranks = Ranks(1.5, { { 17, 6 }, { 592, 12 }, { 600, 18 }, { 3747, 24 }, { 6065, 30 }, { 6066, 36 }, { 10898, 42 }, { 10899, 48 }, { 10900, 54 }, { 10901, 60 } }) },
        ["Prayer of Healing"] = { kind = "group", short = "PoH",
            ranks = Ranks(3.0, { { 596, 30 }, { 996, 40 }, { 10960, 50 }, { 10961, 60 }, { 25316, 60 } }) },
        ["Holy Nova"] = { kind = "group", short = "HN",
            ranks = Ranks(1.5, { { 15237, 20 }, { 15430, 28 }, { 15431, 36 }, { 27799, 44 }, { 27800, 52 }, { 27801, 60 } }) },
        -- Forever-only (what they do is still to be seen in game)
        ["Penance"] = { kind = "special", short = "Pen", ranks = IDs(nil, { 402174, 1240720, 1240721, 1316995 }) },
        ["Prayer of Mending"] = { kind = "special", short = "PoM", ranks = IDs(nil, { 401859, 1240826, 1240827 }) },
        ["Binding Heal"] = { kind = "direct", short = "BH", ranks = IDs(1.5, { 401937, 1240770, 1240771, 1240772, 1240773, 1240774 }) },
    },
    cleanses = {
        ["Dispel Magic"] = { types = { Magic = true }, ids = { 527, 988 } },
        ["Cure Disease"] = { types = { Disease = true }, ids = { 528 } },
        ["Abolish Disease"] = { types = { Disease = true }, ids = { 552 } },
    },
    others = {
        ["Fear Ward"] = { ids = { 6346 } },
        ["Power Infusion"] = { ids = { 10060 } },
    },
    res = { name = "Resurrection", ids = { 2006, 2010, 10880, 10881, 20770 } },
    -- same idea as the Shaman: main heal on Left/Shift/Ctrl, fast heal on Right; the frame's
    -- border shows which fits. Heal until Greater Heal is learned at 40, Lesser Heal before 16.
    defaults = {
        ["1"] = { spell = "Greater Heal", rank = "best", fallback = { "Heal", "Lesser Heal" } },
        ["shift-1"] = { spell = "Greater Heal", rank = "max", fallback = { "Heal", "Lesser Heal" } },
        ["ctrl-1"] = { spell = "Lesser Heal", rank = "max" },
        ["alt-1"] = { spell = "Power Word: Shield", rank = "max" },
        ["2"] = { spell = "Flash Heal", rank = "max" },
        ["shift-2"] = { spell = "Dispel Magic", rank = "max" },
        ["ctrl-2"] = { spell = "Abolish Disease", fallback = { "Cure Disease" } },
        ["alt-2"] = { action = "menu" },
        ["3"] = { action = "target" },
        ["shift-3"] = { spell = "Renew", rank = "max" },
        ["ctrl-3"] = { spell = "Prayer of Healing", rank = "max" },
    },
}

local DRUID = {
    heals = {
        ["Healing Touch"] = { kind = "direct", role = "efficient", short = "HT",
            ranks = Ranks(3.5, { { 5185, 1, 1.5 }, { 5186, 8, 2.0 }, { 5187, 14, 2.5 }, { 5188, 20, 3.0 }, { 5189, 26 }, { 6778, 32 }, { 8903, 38 }, { 9758, 44 }, { 9888, 50 }, { 9889, 56 }, { 25297, 60 } }) },
        ["Regrowth"] = { kind = "direct", role = "fast", short = "RG",
            ranks = Ranks(2.0, { { 8936, 12 }, { 8938, 18 }, { 8939, 24 }, { 8940, 30 }, { 8941, 36 }, { 9750, 42 }, { 9856, 48 }, { 9857, 54 }, { 9858, 60 } }) },
        ["Rejuvenation"] = { kind = "hot", short = "Rj", duration = 12,
            ranks = Ranks(1.5, { { 774, 4 }, { 1058, 10 }, { 1430, 16 }, { 2090, 22 }, { 2091, 28 }, { 3627, 34 }, { 8910, 40 }, { 9839, 46 }, { 9840, 52 }, { 9841, 58 }, { 25299, 60 } }) },
        ["Tranquility"] = { kind = "group", short = "Tq",
            ranks = Ranks(10, { { 740, 30 }, { 8918, 40 }, { 9862, 50 }, { 9863, 60 } }) },
        ["Swiftmend"] = { kind = "special", short = "SM", ranks = Ranks(nil, { { 18562, 40 } }) },
        -- Forever-only
        ["Wild Growth"] = { kind = "hot", short = "WG", duration = 7, ranks = IDs(nil, { 408120, 1238214, 1238215 }) },
    },
    cleanses = {
        ["Remove Curse"] = { types = { Curse = true }, ids = { 2782 } },
        ["Cure Poison"] = { types = { Poison = true }, ids = { 8946 } },
        ["Abolish Poison"] = { types = { Poison = true }, ids = { 2893 } },
    },
    -- Rebirth (combat resurrection: reagent, 30 min cooldown) is never cast by a plain click on a
    -- dead frame; bind it to a click of its own if wanted
    others = {
        ["Rebirth"] = { ids = { 20484, 20739, 20742, 20747, 20748 } },
        ["Innervate"] = { ids = { 29166 } },
    },
    -- Forever's out-of-combat resurrection
    res = { name = "Revive", ids = { 437138, 1237948, 1237949, 1237950, 1237951 } },
    defaults = {
        ["1"] = { spell = "Healing Touch", rank = "best" },
        ["shift-1"] = { spell = "Healing Touch", rank = "max" },
        ["ctrl-1"] = { spell = "Healing Touch", rank = 1 },
        ["alt-1"] = { spell = "Rejuvenation", rank = "max" },
        ["2"] = { spell = "Regrowth", rank = "max" },
        ["shift-2"] = { spell = "Remove Curse" },
        ["ctrl-2"] = { spell = "Abolish Poison", fallback = { "Cure Poison" } },
        ["alt-2"] = { action = "menu" },
        ["3"] = { action = "target" },
        ["shift-3"] = { spell = "Wild Growth", rank = "max" },
    },
}

local PALADIN = {
    heals = {
        ["Holy Light"] = { kind = "direct", role = "efficient", short = "HL",
            ranks = Ranks(2.5, { { 635, 1 }, { 639, 6 }, { 647, 14 }, { 1026, 22 }, { 1042, 30 }, { 3472, 38 }, { 10328, 46 }, { 10329, 54 }, { 25292, 60 } }) },
        -- the paladin's fast heal (orange advice below the emergency health)
        ["Flash of Light"] = { kind = "direct", role = "fast", short = "FoL",
            ranks = Ranks(1.5, { { 19750, 20 }, { 19939, 26 }, { 19940, 34 }, { 19941, 42 }, { 19942, 50 }, { 19943, 58 } }) },
        -- in the beta's list order (1311606 may be a Forever-only low rank)
        ["Holy Shock"] = { kind = "direct", short = "HS", ranks = IDs(1.5, { 1311606, 20473, 20929, 20930 }) },
    },
    cleanses = {
        ["Purify"] = { types = { Poison = true, Disease = true }, ids = { 1152 } },
        ["Cleanse"] = { types = { Poison = true, Disease = true, Magic = true }, ids = { 4987 } },
    },
    others = {
        ["Lay on Hands"] = { ids = { 633, 2800, 10310 } },
        ["Blessing of Protection"] = { ids = { 1022, 5599, 10278 } },
        ["Blessing of Freedom"] = { ids = { 1044 } },
        ["Blessing of Sacrifice"] = { ids = { 6940, 20729 } },
    },
    res = { name = "Redemption", ids = { 7328, 10322, 10324, 20772, 20773 } },
    -- Flash of Light comes at 20; before that Right casts Holy Light's highest rank
    defaults = {
        ["1"] = { spell = "Holy Light", rank = "best" },
        ["shift-1"] = { spell = "Holy Light", rank = "max" },
        ["ctrl-1"] = { spell = "Holy Light", rank = 1 },
        ["alt-1"] = { spell = "Holy Shock", rank = "max" },
        ["2"] = { spell = "Flash of Light", rank = "max", fallback = { "Holy Light" } },
        ["shift-2"] = { spell = "Cleanse", fallback = { "Purify" } },
        ["ctrl-2"] = { spell = "Blessing of Freedom" },
        ["alt-2"] = { action = "menu" },
        ["3"] = { action = "target" },
        ["shift-3"] = { spell = "Lay on Hands" },
    },
}

ClassData.classes = { SHAMAN = SHAMAN, PRIEST = PRIEST, DRUID = DRUID, PALADIN = PALADIN }

-- dispel colours (same as the game's debuff borders)
ClassData.DISPEL_COLORS = {
    Magic = { 0.20, 0.60, 1.00 },
    Curse = { 0.60, 0.00, 1.00 },
    Disease = { 0.60, 0.40, 0.00 },
    Poison = { 0.00, 0.60, 0.00 },
}

function ClassData.ForPlayer()
    local _, classTag = UnitClass("player")
    return ClassData.classes[classTag], classTag
end

-- Classic's rule for how much +healing a direct heal gets: cast time / 3.5 (1.5s to 3.5s),
-- and spells learned before level 20 get less: -3.75% per level below 20.
function ClassData.Coefficient(spell, rank)
    local cast = rank.cast or spell.cast or 3.0
    local coef
    if spell.kind == "hot" then
        coef = (spell.duration or 15) / 15
    elseif spell.kind == "shield" then
        coef = 0.1
    else
        coef = math.min(3.5, math.max(1.5, cast)) / 3.5
    end
    local level = rank.level or 20
    if level < 20 then
        coef = coef * (1 - (20 - level) * 0.0375)
    end
    return coef
end
