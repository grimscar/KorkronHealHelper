-- Kor'kron Heal Helper: click-casting on the healer frames.
--
-- A binding says what a click on a frame does: cast a heal or cleanse on that person, target
-- them, or open their menu. Keys follow the game's secure button attributes: "1" = left click,
-- "shift-2" = shift + right click, and so on. Bindings name a spell and a rank ("max", "max-1",
-- or a number), so they keep working as she levels and learns new ranks. A binding may list
-- fallback spells for while the first isn't learned yet (Greater Heal, else Heal, else Lesser Heal).
-- Rank "best" is the most mana-efficient rank (from her real heals once the addon has seen them).
--
-- The game doesn't let a click choose its rank by itself (it can't change in combat, and health is
-- hidden), so several ranks sit on modifier clicks and the frames show, by colour, which one fits.
--
-- Click-casting uses protected (secure) frames, which the game only lets addons change out of
-- combat. Changes made in combat are applied the moment combat ends.
local _, KH = ...

local Bindings = {}
KH.Bindings = Bindings

-- every click we offer, in display order
-- color: the frame border and advice text when this click is the one that fits
Bindings.CLICKS = {
    { key = "1", label = "Left", short = "L", color = { 0.3, 1, 0.4 } },
    { key = "shift-1", label = "Shift + Left", short = "S-L", color = { 0.3, 0.6, 1 } },
    { key = "ctrl-1", label = "Ctrl + Left", short = "C-L", color = { 0.8, 0.4, 1 } },
    { key = "alt-1", label = "Alt + Left", short = "A-L", color = { 1, 0.9, 0.2 } },
    { key = "2", label = "Right", short = "R", color = { 1, 0.5, 0.15 } },
    { key = "shift-2", label = "Shift + Right", short = "S-R", color = { 0.2, 0.9, 0.9 } },
    { key = "ctrl-2", label = "Ctrl + Right", short = "C-R", color = { 1, 0.4, 0.7 } },
    { key = "alt-2", label = "Alt + Right", short = "A-R", color = { 0.9, 0.9, 0.9 } },
    { key = "3", label = "Middle", short = "M", color = { 0.9, 0.9, 0.9 } },
    { key = "shift-3", label = "Shift + Middle", short = "S-M", color = { 0.9, 0.9, 0.9 } },
    { key = "ctrl-3", label = "Ctrl + Middle", short = "C-M", color = { 0.9, 0.9, 0.9 } },
    { key = "4", label = "Mouse 4", short = "M4", color = { 0.9, 0.9, 0.9 } },
    { key = "5", label = "Mouse 5", short = "M5", color = { 0.9, 0.9, 0.9 } },
}

local CLICK_BY_KEY = {}
for _, c in ipairs(Bindings.CLICKS) do CLICK_BY_KEY[c.key] = c end

local ACTION_TYPES = { target = "target", menu = "togglemenu" }
Bindings.ACTION_LABELS = { target = "Target", menu = "Open menu" }

local function Copy(b)
    local fallback = b.fallback and { unpack(b.fallback) } or nil
    return { spell = b.spell, rank = b.rank, action = b.action, fallback = fallback }
end

-- the saved bindings; the first time (or after a class change) they start from the class defaults
function Bindings.Get()
    local char = KH.char
    local data, classTag = KH.ClassData.ForPlayer()
    if char.class ~= classTag then
        char.class = classTag
        char.bindings = {}
        for key, b in pairs(data and data.defaults or { ["3"] = { action = "target" } }) do
            char.bindings[key] = Copy(b)
        end
    end
    return char.bindings
end

function Bindings.Click(key)
    return CLICK_BY_KEY[key]
end

-- the spell a binding casts right now: its first learned spell (the binding's, then fallbacks)
function Bindings.Spell(b)
    if not (b and b.spell) then return nil end
    local info = KH.Spells.Resolve(b.spell, b.rank)
    if info then return info end
    for _, name in ipairs(b.fallback or {}) do
        info = KH.Spells.Resolve(name, b.rank)
        if info then return info end
    end
end

function Bindings.Set(key, binding)
    if not CLICK_BY_KEY[key] then return false end
    Bindings.Get()[key] = binding
    KH:Fire("BINDINGS_UPDATED")
    return true
end

function Bindings.Reset()
    KH.char.class = nil
    Bindings.Get()
    KH:Fire("BINDINGS_UPDATED")
end

-- "Healing Wave rank 3 (max-2)" style description of a saved binding
function Bindings.Describe(b)
    if not b then return "|cff808080nothing|r" end
    if b.action then return Bindings.ACTION_LABELS[b.action] or b.action end
    local info = Bindings.Spell(b)
    local text = info and info.name or b.spell
    if KH.Spells.heals[text] then
        if info then text = text .. " (Rank " .. info.rank .. ")" end
        if type(b.rank) == "string" then
            local how = b.rank == "best" and "most efficient" or b.rank == "max" and "highest" or string.gsub(b.rank, "max%-(%d+)", "highest -%1")
            text = text .. " |cff808080" .. how .. "|r"
        end
    end
    if not info then text = text .. " |cffff6060(not learned)|r" end
    return text
end

-- bindings with their spells looked up: { { key, label, short, binding, info }, ... } in CLICKS order
function Bindings.Resolved()
    local out = {}
    local saved = Bindings.Get()
    for _, click in ipairs(Bindings.CLICKS) do
        local b = saved[click.key]
        if b then
            local info = Bindings.Spell(b)
            out[#out + 1] = { key = click.key, label = click.label, short = click.short, binding = b, info = info }
        end
    end
    return out
end

-- "shift-2" -> "shift-", "2"
local function SplitKey(key)
    local mod, button = string.match(key, "^(.-)(%d)$")
    return mod or "", button
end

-- The macro a spell click runs on `unit`:
--   /cast [@party2,help,dead] Ancestral Spirit; [@party2,help,nodead] Healing Wave(Rank 3)
--   /stopspelltarget
-- The resurrect part only when smart resurrect is on and she knows one. /stopspelltarget
-- cancels a cast that couldn't land, so it never waits on the cursor for the next click.
function Bindings.CastMacro(unit, castName)
    local res = KH.db.settings.smartRes and KH.Spells.res
    local line = "[@" .. unit .. ",help,nodead] " .. castName
    if res and res ~= castName then
        line = "[@" .. unit .. ",help,dead] " .. res .. "; " .. line
    end
    return "/cast " .. line .. "\n/stopspelltarget"
end

-- the secure attributes for every click on a frame showing `unit`: { { name, value }, ... };
-- unbound clicks are cleared
function Bindings.Attributes(unit)
    local attrs = {}
    local saved = Bindings.Get()
    local mode = KH.db.settings.castBy
    for _, click in ipairs(Bindings.CLICKS) do
        local mod, button = SplitKey(click.key)
        local b = saved[click.key]
        local kind, spell, macro
        if b and b.action then
            kind = ACTION_TYPES[b.action]
        elseif b and b.spell then
            local info = Bindings.Spell(b)
            if info and mode == "macro" and unit then
                kind, macro = "macro", Bindings.CastMacro(unit, info.castName)
            elseif info then
                kind, spell = "spell", (mode == "id" and info.id or info.castName)
            end
        end
        attrs[#attrs + 1] = { mod .. "type" .. button, kind }
        attrs[#attrs + 1] = { mod .. "spell" .. button, spell }
        attrs[#attrs + 1] = { mod .. "macrotext" .. button, macro }
    end
    return attrs
end

-- out of combat only (protected frame)
function Bindings.ApplyTo(button)
    for _, a in ipairs(Bindings.Attributes(button:GetAttribute("unit"))) do
        button:SetAttribute(a[1], a[2])
    end
end

KH:On("SPELLS_UPDATED", function() KH:Fire("BINDINGS_UPDATED") end)
