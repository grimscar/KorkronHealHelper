-- Kor'kron Heal Helper: "what does the game hide from addons right now?"
--
-- Forever hides values from addons in combat and sometimes inside instances, and which ones
-- exactly isn't documented. The probe writes down, for the player, a party member and the
-- target, whether each value an addon healer needs is readable or hidden, plus which
-- secret-safe tools the client offers.
--
-- It takes a snapshot by itself a moment after each fight starts (combat) and after loading
-- into the world (calm). /khh probe shows the current state and the last fight's snapshot in a
-- copyable window.
local _, KH = ...

local Probe = {}
KH.Probe = Probe

local function Describe(ok, value)
    if not ok then return "error" end
    if value == nil then return "nil" end
    if not KH.Readable(value) then return "|cffff6060HIDDEN|r" end
    if type(value) == "string" and #value > 30 then value = string.sub(value, 1, 30) .. "..." end
    return "|cff60ff60ok|r (" .. tostring(value) .. ")"
end

local function Try(fn, ...)
    if not fn then return "missing" end
    return Describe(pcall(fn, ...))
end

local function Yes(v) return v and "|cff60ff60yes|r" or "|cffff6060no|r" end

local function UnitLines(lines, unit)
    if not UnitExists(unit) then
        lines[#lines + 1] = unit .. ": (nobody)"
        return
    end
    lines[#lines + 1] = unit .. ":"
    lines[#lines + 1] = "  name " .. Try(UnitName, unit) .. ", class " .. Describe(pcall(function() return select(2, UnitClass(unit)) end))
    lines[#lines + 1] = "  health " .. Try(UnitHealth, unit) .. ", max " .. Try(UnitHealthMax, unit)
    lines[#lines + 1] = "  missing " .. Try(UnitHealthMissing, unit) .. ", percent " .. Try(UnitHealthPercent, unit)
    lines[#lines + 1] = "  incoming heals " .. Try(UnitGetIncomingHeals, unit) .. ", shield " .. Try(UnitGetTotalAbsorbs, unit)
    lines[#lines + 1] = "  mana " .. Try(UnitPower, unit, 0) .. ", in range " .. Try(UnitInRange, unit)
    lines[#lines + 1] = "  dead " .. Try(UnitIsDeadOrGhost, unit) .. ", online " .. Try(UnitIsConnected, unit)
    lines[#lines + 1] = "  guid " .. Try(UnitGUID, unit)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, 1, "HARMFUL")
        if not ok then
            lines[#lines + 1] = "  first debuff: blocked (the game refused the read)"
        elseif aura == nil then
            lines[#lines + 1] = "  first debuff: none (or hidden)"
        else
            lines[#lines + 1] = "  first debuff: name " .. Describe(true, aura.name) .. ", type " .. Describe(true, aura.dispelName)
                .. ", instance " .. Describe(true, aura.auraInstanceID)
        end
    end
end

function Probe.Collect()
    local lines = {}
    local _, _, _, toc = GetBuildInfo()
    local inInstance, instanceType = IsInInstance()
    lines[#lines + 1] = string.format("Kor'kron Heal Helper %s probe, %s", KH.version, date and date("%Y-%m-%d %H:%M") or "")
    lines[#lines + 1] = string.format("class %s, level %s", tostring(KH.Text(select(2, UnitClass("player")))),
        tostring(KH.Num(UnitLevel("player"))))
    lines[#lines + 1] = string.format("client %s, project %s, in combat %s, instance %s (%s), zone %s",
        tostring(toc), tostring(WOW_PROJECT_ID), Yes(InCombatLockdown()), Yes(inInstance), tostring(instanceType), tostring(GetRealZoneText and GetRealZoneText()))
    lines[#lines + 1] = "tools: secret values " .. Yes(issecretvalue ~= nil) .. ", health curves " .. Yes(KH.API.curves)
        .. ", aura containers " .. Yes(KH.API.auraContainers) .. ", bool pick " .. Yes(KH.API.pickFromBool)
        .. ", missing health " .. Yes(KH.API.healthMissing)
    lines[#lines + 1] = "spell APIs: spellbook " .. Yes(C_SpellBook ~= nil) .. ", bonus healing " .. Try(GetSpellBonusHealing)
        .. ", tooltip hook " .. Yes(TooltipDataProcessor ~= nil)

    local secrets = C_Secrets and C_Secrets.ShouldUnitStatsBeSecret
    lines[#lines + 1] = "game says health is hidden now: " .. (secrets and Try(secrets) or "missing")
    local s = KH.db.settings
    lines[#lines + 1] = string.format("clicks cast by %s, auto self cast %s, click-to-resurrect %s (%s)",
        tostring(s.castBy), Yes(KH.AutoSelfCast()), Yes(s.smartRes), tostring(KH.Spells.res or "no resurrection known"))
    local b = KH.Frames.buttons[1]
    if b then
        lines[#lines + 1] = string.format("frame 1: unit %s, shown %s, debuff icons %s, tint %s",
            tostring(b:GetAttribute("unit")), Yes(b:IsShown()), b.dispelContainer and "game-drawn" or "simple (out of combat only)",
            Yes(b.tintContainer ~= nil))
        lines[#lines + 1] = "frame 1 left click: " .. tostring(b:GetAttribute("type1")) .. " "
            .. string.gsub(tostring(b:GetAttribute("macrotext1") or b:GetAttribute("spell1")), "\n", " | ")
        lines[#lines + 1] = string.format("advice: %s, %d heal labels, emergency %s",
            KH.Frames.AdviceMode(), b.gateCount or #(b.plan or {}), Yes(b.emergencyGate and b.emergencyGate.on))
    end
    local m = KH.Measure.stats
    lines[#lines + 1] = string.format("heal results this session: %d learned, %d hidden, %d crits skipped", m.seen, m.hidden, m.crits)
    lines[#lines + 1] = string.format("  measuring: %d direct heal casts (%d more with hidden spell ID), %d combat-text events"
        .. " (%d with hidden type), %d heals (%d too late, %d not matching the tooltip)%s%s", m.casts, m.castHidden,
        m.events, m.actionHidden, m.heals, m.late, m.odd, KH.Measure.castEvent and "" or ", cast event refused",
        KH.Measure.combatEvent and "" or ", UNIT_COMBAT refused")

    local t = KH.Tracker.stats
    lines[#lines + 1] = string.format("tracking: emergency by %s, %d hits readable, %d hidden; your HoTs placed %d, not placed %d%s",
        KH.Advisor.ByTime(KH.db.settings.advisor) and "time" or "health %", t.damage, t.hiddenDamage, t.hots, t.hotsUnplaced,
        t.lastUnplaced and (" (last: " .. t.lastUnplaced .. ")") or "")
    local n, avg, most = KH.Tracker.DelayStats()
    lines[#lines + 1] = string.format("  your casts: %d timed, %d pushbacks; last %d slowed by hits: %.1fs longer on average (most %.1fs)",
        t.timed, t.pushbacks, n, avg, most)
    local kinds = {}
    for kind, count in pairs(t.kinds) do kinds[#kinds + 1] = kind .. " " .. count end
    table.sort(kinds)
    lines[#lines + 1] = "  combat text (you, group, target): " .. (#kinds > 0 and table.concat(kinds, ", ") or "none")
    local p = KH.Plates.stats
    lines[#lines + 1] = string.format("shields: on frames %s, nameplate bars %s (%d now, %d made, %d refused by the game)",
        Yes(KH.API.absorbs and KH.db.settings.frames.showShields), Yes(KH.API.absorbs and KH.db.settings.frames.plateShields),
        KH.Plates.Count(), p.added, p.forbidden)

    UnitLines(lines, "player")
    local other = IsInRaid() and "raid2" or "party1"
    UnitLines(lines, other)
    UnitLines(lines, "target")

    local count, parsed = 0, 0
    for _, info in ipairs(KH.Spells.AllHealRanks()) do
        count = count + 1
        if info.parsed then parsed = parsed + 1 end
    end
    lines[#lines + 1] = string.format("heal ranks known %s (amount read from the tooltip for %s), +healing %s, can remove: %s",
        count, parsed, KH.Spells.bonus, Probe.DispelList())
    for _, info in ipairs(KH.Spells.AllHealRanks()) do
        local seen = info.seen and string.format("seen %d-%d x%d", info.seen.min, info.seen.max, info.seen.n) or "not seen yet"
        lines[#lines + 1] = string.format("  %s id %s: tooltip %s-%s, %s, uses %s (%s), %s mana, %.1fs cast, cast as \"%s\"",
            Probe.Name(info), info.id, tostring(info.min), tostring(info.max), seen, tostring(info.amount and KH.Round(info.amount)),
            tostring(info.source), tostring(info.cost), info.castTime or 0, info.castName)
    end
    local others = {}
    for name in pairs(KH.Spells.others) do others[#others + 1] = name end
    table.sort(others)
    lines[#lines + 1] = "other spells known: " .. (#others > 0 and table.concat(others, ", ") or "none")
        .. "; resurrection: " .. tostring(KH.Spells.res or "none")
    lines[#lines + 1] = "talents: " .. Probe.Talents()
    -- healing spells the addon has no data for yet (Forever-only): their tooltips say what they do
    local unknown = KH.Spells.UnknownHealingSpells()
    lines[#lines + 1] = string.format("healing spells the addon doesn't know yet: %d", #unknown)
    for i, s in ipairs(unknown) do
        if i > 15 then break end
        local text = string.gsub(s.text or "", "%s+", " ")
        lines[#lines + 1] = string.format("  %s (id %s): %s", s.name, tostring(s.id), string.sub(text, 1, 200))
    end
    return lines
end

-- one talent tree's name and points: Forever answers through C_SpecializationInfo (a table),
-- older clients through the globals (Classic and Cata return orders)
local function TalentTab(i)
    local spec = C_SpecializationInfo
    if spec and spec.GetTalentTabInfo then
        local ok, info = pcall(spec.GetTalentTabInfo, i)
        if ok and type(info) == "table" then return info.name, info.pointsSpent end
        return nil
    end
    local r = { pcall(GetTalentTabInfo, i) }
    if not r[1] then return nil end
    if type(r[2]) == "string" then return r[2], r[4] end
    return r[3], r[6]
end

-- the talent window's trees, left to right
local TREES = {
    DRUID = { "Balance", "Feral Combat", "Restoration" },
    PALADIN = { "Holy", "Protection", "Retribution" },
    PRIEST = { "Discipline", "Holy", "Shadow" },
    SHAMAN = { "Elemental", "Enhancement", "Restoration" },
}

-- Forever 1.60 has no talent tabs: its talent window is one Traits tree with every talent as a
-- node. The three classic trees are three groups of node columns (posX), split where the gap
-- between neighbouring columns is widest. nil when the game won't say.
function Probe.TraitTalents()
    local traits, classTalents = C_Traits, C_ClassTalents
    if not (traits and classTalents and classTalents.GetActiveConfigID and traits.GetConfigInfo
        and traits.GetTreeNodes and traits.GetNodeInfo) then return nil, "no Traits API" end
    local ok, configID = pcall(classTalents.GetActiveConfigID)
    configID = ok and KH.Num(configID)
    if not configID then return nil, "no active talent config" end
    local okInfo, config = pcall(traits.GetConfigInfo, configID)
    local treeID = okInfo and type(config) == "table" and type(config.treeIDs) == "table" and KH.Num(config.treeIDs[1])
    if not treeID then return nil, "no talent tree in the config" end
    local okNodes, nodes = pcall(traits.GetTreeNodes, treeID)
    if not okNodes or type(nodes) ~= "table" then return nil, "tree nodes refused" end
    local points, columns = {}, {}
    for _, nodeID in ipairs(nodes) do
        local okNode, node = pcall(traits.GetNodeInfo, configID, nodeID)
        local x = okNode and type(node) == "table" and KH.Num(node.posX)
        if x then
            if not points[x] then points[x] = 0; columns[#columns + 1] = x end
            points[x] = points[x] + (KH.Num(node.ranksPurchased) or 0)
        end
    end
    if #columns < 3 then return nil, #columns .. " talent columns" end
    table.sort(columns)
    -- the two widest gaps between columns separate the three trees
    local gaps = {}
    for i = 2, #columns do gaps[#gaps + 1] = { at = i, size = columns[i] - columns[i - 1] } end
    table.sort(gaps, function(a, b) return a.size > b.size end)
    local cut1, cut2 = math.min(gaps[1].at, gaps[2].at), math.max(gaps[1].at, gaps[2].at)
    local trees = { 0, 0, 0 }
    for i, x in ipairs(columns) do
        local tree = i < cut1 and 1 or i < cut2 and 2 or 3
        trees[tree] = trees[tree] + points[x]
    end
    return trees
end

-- points per talent tree: "Balance 0, Feral Combat 9, Restoration 0"
function Probe.Talents()
    local spec = C_SpecializationInfo
    local count = spec and spec.GetNumTalentTabs or GetNumTalentTabs
    if not count or not ((spec and spec.GetTalentTabInfo) or GetTalentTabInfo) then
        local trees, why = Probe.TraitTalents()
        if not trees then return "unknown (no talent tab API, " .. why .. ")" end
        local names = TREES[KH.Text(select(2, UnitClass("player"))) or ""] or {}
        for i, n in ipairs(trees) do trees[i] = (names[i] or ("tree " .. i)) .. " " .. n end
        return table.concat(trees, ", ")
    end
    local ok, tabs = pcall(count)
    tabs = ok and KH.Num(tabs)
    if not tabs or tabs == 0 then return "unknown (" .. (ok and "the game lists " .. tostring(tabs or "hidden") .. " trees" or "reading the trees failed") .. ")" end
    local trees, failed = {}, 0
    for i = 1, tabs do
        local name, points = TalentTab(i)
        if name == nil and points == nil then
            failed = failed + 1
        else
            trees[#trees + 1] = tostring(KH.Text(name) or ("tree " .. i)) .. " " .. tostring(KH.Num(points) or "?")
        end
    end
    return #trees > 0 and table.concat(trees, ", ") or ("unknown (" .. tabs .. " trees, " .. failed .. " failed to read)")
end

function Probe.Name(info)
    return info.name .. " " .. info.rank
end

function Probe.DispelList()
    local list = {}
    for t in pairs(KH.Spells.dispels) do list[#list + 1] = t end
    table.sort(list)
    return #list > 0 and table.concat(list, ", ") or "nothing"
end

function Probe.Snapshot(tag)
    KH.db.probe[tag] = { time = time(), lines = Probe.Collect() }
end

-- the text for the copy window: now, plus the last snapshots
function Probe.Report()
    local lines = { "== now ==" }
    for _, l in ipairs(Probe.Collect()) do lines[#lines + 1] = l end
    for _, tag in ipairs({ "combat", "calm" }) do
        local snap = KH.db.probe[tag]
        if snap then
            lines[#lines + 1] = ""
            lines[#lines + 1] = string.format("== last %s snapshot (%s) ==", tag, date and date("%Y-%m-%d %H:%M", snap.time) or snap.time)
            for _, l in ipairs(snap.lines) do lines[#lines + 1] = l end
        end
    end
    -- colour codes don't belong in a copy-paste
    local text = table.concat(lines, "\n")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return text
end

KH:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    KH:After(1.5, function()
        if InCombatLockdown() then Probe.Snapshot("combat") end
    end)
end)

KH:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    KH:After(6, function()
        if not InCombatLockdown() then Probe.Snapshot("calm") end
    end)
end)
