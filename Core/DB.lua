local _, KH = ...

local DB = {}
KH.DB = DB

DB.SCHEMA = 2
DB.LAYOUT = 2

local DEFAULTS = {
    debug = false,
    minimap = { angle = 200, hide = false },
    tooltips = true,
    frames = {
        enabled = true,
        locked = false,
        point = "TOPLEFT", x = 260, y = -180,
        width = 112, height = 44,
        scale = 1,
        spacingX = 4, spacingY = 3,
        groupsAs = "columns",
        order = "group",
        powerHeight = 4,
        shieldHeight = 5,
        showPower = "all",
        healthText = "missing",
        powerText = "none",
        nameSize = 10, textSize = 10,
        showSolo = true,
        classColors = true,
        rangeAlpha = 0.4,
        showIncoming = true,
        showShields = true,
        plateShields = true,
    },
    advisor = {
        enabled = true,
        overheal = 0.10,
        emergency = 0.35,
        emergencyByTime = true,
        safety = 1.0,
        predicted = true,
        countHots = true,
        countShields = true,
    },
    cleanse = {
        enabled = true,
        maxIcons = 3,
        showMine = true,
        mineMaxMinutes = 5,
    },
    castBy = "macro",
    smartRes = true,
    selfCastWarning = true,
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
    if (db.schema or DB.SCHEMA) < 2 then db.settings.castBy = "macro" end
    db.schema = DB.SCHEMA
    ApplyDefaults(db.settings, DEFAULTS)
    db.probe = db.probe or {}
    db.roles = db.roles or {}
    KH.db = db

    KorkronHealHelperCharDB = KorkronHealHelperCharDB or {}
    local char = KorkronHealHelperCharDB
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
