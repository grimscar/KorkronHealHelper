-- Kor'kron Heal Helper: saved data.
--
-- KorkronHealHelperDB (account-wide)
--   settings        options, see DEFAULTS
--   probe           last "what does the game hide?" snapshots (Probe.lua): calm, combat
--
-- KorkronHealHelperCharDB (per character: every class has its own spells)
--   bindings[key]   click-casting: key is the click ("1" = left, "shift-2" = shift + right, ...)
--                   value { spell = "Healing Wave", rank = 4 | "max" | "max-1" | "best", fallback = { names } }
--                   or { action = "target" | "menu" }
--   class           the class the bindings were made for
--   layout          version of the default clicks last given to this character
--   measured        real heal results (Measure.lua): { bonus, spells[spellID] = { n, sum, min, max } }
local _, KH = ...

local DB = {}
KH.DB = DB

DB.SCHEMA = 2
DB.LAYOUT = 2   -- bump to hand every character the class default clicks again

local DEFAULTS = {
    debug = false,
    minimap = { angle = 200, hide = false },
    tooltips = true,      -- heal amount and mana efficiency on spell tooltips
    frames = {
        enabled = true,
        locked = false,
        point = "TOPLEFT", x = 260, y = -180,
        width = 112, height = 44,
        scale = 1,
        spacingX = 4, spacingY = 3,  -- gap between frames
        groupsAs = "columns",    -- each group a "columns" or a "rows"
        powerHeight = 4,         -- mana/rage/energy bar height (0 hides it)
        shieldHeight = 5,        -- shield bar height across the top (0 hides it)
        showPower = "all",       -- "all", "mana" (only for mana users) or "none"
        healthText = "missing",  -- "missing", "percent", "current", "both" or "none"
        powerText = "none",      -- "current", "percent", "both" or "none"
        nameSize = 10, textSize = 10,
        showSolo = true,      -- show your own frame when not in a group (handy for testing)
        classColors = true,   -- health bars in class colours (else green)
        rangeAlpha = 0.4,     -- how faded someone out of range is
        showIncoming = true,  -- faint bar for heals on the way
        showShields = true,   -- gold bar for damage shields (Power Word: Shield)
        plateShields = true,  -- a shield bar with its number under friendly nameplates
    },
    advisor = {
        enabled = true,
        overheal = 0.10,      -- a heal may overheal by this much and still be the pick (0.10 = 10%)
        emergency = 0.35,     -- below this health, suggest the fast heal instead (when damage is hidden)
        emergencyByTime = true, -- fast heal only when they'd reach 0 before the slow heal lands
        safety = 1.0,         -- seconds added to the slow heal's cast time for that
        predicted = true,     -- count heals already on the way
        countHots = true,     -- count the healing her HoTs on them will still do
        countShields = true,  -- a shield on them buys time before the fast heal is needed
    },
    cleanse = {
        enabled = true,
        maxIcons = 3,
        showMine = true,      -- also show your own buffs and heals over time on each frame
        mineMaxMinutes = 5,   -- ...but not ones lasting longer than this (0 = show all)
    },
    -- how a click casts: "macro" = /cast [@unit] Healing Wave(Rank 3) then /stopspelltarget (so a
    -- cast that can't land never waits on the cursor); "name" or "id" = the plain secure spell click
    castBy = "macro",
    smartRes = true,          -- a spell click on a dead person casts your resurrection (macro mode)
    selfCastWarning = true,   -- warn at login while the game's Auto Self Cast is on
    tab = "SPELLS",
}

local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = {}
                ApplyDefaults(target[k], v)
            else
                target[k] = v
            end
        elseif type(v) == "table" and type(target[k]) == "table" then
            ApplyDefaults(target[k], v)
        end
    end
end

function DB:Init()
    KorkronHealHelperDB = KorkronHealHelperDB or {}
    local db = KorkronHealHelperDB
    db.settings = db.settings or {}
    -- 0.1.0 cast by name; 0.2.0 casts through a macro by default
    if (db.schema or DB.SCHEMA) < 2 then db.settings.castBy = "macro" end
    db.schema = DB.SCHEMA
    ApplyDefaults(db.settings, DEFAULTS)
    db.probe = db.probe or {}
    KH.db = db

    KorkronHealHelperCharDB = KorkronHealHelperCharDB or {}
    local char = KorkronHealHelperCharDB
    -- 0.4.0 has new default clicks (most efficient rank on Left, colours on the frames) and
    -- drops 0.3.0's simple/advanced sets: everyone starts again from the new defaults once
    if (char.layout or 1) < DB.LAYOUT then
        char.relaidOut = char.class ~= nil
        char.class, char.sets, char.clickMode = nil, nil, nil
        char.layout = DB.LAYOUT
    end
    char.bindings = char.bindings or {}
    KH.char = char
end

function DB.Defaults()
    return DEFAULTS
end
