-- Kor'kron Heal Helper: the healer frames.
--
-- One frame per group member (you, your party, or the raid by group). Each frame shows:
--   * health, mana, name, missing health, dead/offline;
--   * the advice: which bound heal to click right now ("HW3" over "S-L" = Shift + Left);
--   * a tint over the health bar in the colour of a debuff she can remove (curse purple,
--     poison green, disease brown, magic blue), plus the debuff icons;
--   * your own buffs and heals over time on them;
--   * faded when out of range, a border on your target.
-- Clicking casts what Bindings.lua says.
--
-- How the frames are made: 40 secure click-cast buttons are created at login. Out of combat
-- each one is given a group member ("party2", "raid14") and placed. The game's unit watch
-- shows or hides it as that person comes and goes, in combat too. Who sits where is only
-- rearranged out of combat. (Blizzard's secure group header isn't used: on Forever's beta its
-- secure snippets are unreliable, and ClickMend, VuhDo and HealBot avoid it too.)
--
-- Values the game hides in combat are never compared or calculated in Lua here: they go straight
-- into bars, texts, colours and curves (see Init.lua "hidden values").
local _, KH = ...

local Frames = {}
KH.Frames = Frames

Frames.buttons = {}
local MAX_BUTTONS = 40
local byUnit = {}
local anchor
local version = 0       -- bumps when bindings, spells or settings change; frames rebuild their advice
local options           -- Advisor.Options() for the current version

local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local AURA_SIZE = 14
local MINE_SIZE = 12    -- her own buffs: a little smaller, to fit under the advice's click text
-- power bar colours by power type: mana, rage, focus, energy
local POWER_COLORS = { [0] = { 0.25, 0.45, 1 }, [1] = { 0.9, 0.2, 0.2 }, [2] = { 1, 0.5, 0.25 }, [3] = { 1, 0.9, 0.2 } }
local TINT_ALPHA = 0.55
-- "debuffs I can remove": Classic's RAID filter (what ClickMend uses on Forever), then the
-- retail name for the same thing
local DISPEL_FILTERS = { "HARMFUL|RAID", "HARMFUL|RAID_PLAYER_DISPELLABLE" }
local DISPEL_KINDS = { "Curse", "Poison", "Disease", "Magic" }

local function S() return KH.db.settings end

-- small helpers -------------------------------------------------------------------------------

-- call a method only if this client has it; errors are swallowed (optional features)
local function Try(obj, method, ...)
    local fn = obj and obj[method]
    if not fn then return false end
    return pcall(fn, obj, ...)
end

-- show a region when a (possibly hidden) true/false is true
local function ShowIf(region, value)
    if KH.Readable(value) then
        region:SetAlpha(1)
        region:SetShown(value and true or false)
    elseif region.SetAlphaFromBoolean then
        region:Show()
        region:SetAlphaFromBoolean(value, 1, 0)
    else
        region:Hide()
    end
end

-- a step curve: alpha 1 while hurt, 0 at full health (hides "-0")
local hurtCurve
local function HurtCurve()
    if not hurtCurve and KH.API.curves then
        hurtCurve = C_CurveUtil.CreateCurve()
        hurtCurve:SetType(Enum.LuaCurveType.Step)
        hurtCurve:AddPoint(0, 1)
        hurtCurve:AddPoint(0.9999, 1)
        hurtCurve:AddPoint(1, 0)
    end
    return hurtCurve
end

-- a linear curve from health fraction to 0-100, for "85%" text while health is hidden
local percentCurve
local function PercentCurve()
    if not percentCurve and KH.API.curves then
        percentCurve = C_CurveUtil.CreateCurve()
        percentCurve:SetType(Enum.LuaCurveType.Linear)
        percentCurve:AddPoint(0, 0)
        percentCurve:AddPoint(1, 100)
    end
    return percentCurve
end

local function SetFontSize(fs, size)
    local path, _, flags = fs:GetFont()
    if path and size then fs:SetFont(path, size, flags) end
end

-- each notice once per session
local told = {}
local function TellOnce(key, fmt, ...)
    if told[key] then return end
    told[key] = true
    KH:Print(fmt, ...)
end

-- aura icons and the dispel tint (Blizzard aura containers) ----------------------------------------

local DISPEL_MAP
local function DispelColorMap()
    if not DISPEL_MAP and CreateColor then
        DISPEL_MAP = {}
        for name, c in pairs(KH.ClassData.DISPEL_COLORS) do DISPEL_MAP[name] = CreateColor(c[1], c[2], c[3], 1) end
        DISPEL_MAP.None = CreateColor(0, 0, 0, 1)
    end
    return DISPEL_MAP
end

-- one Blizzard-run aura icon (runs inside Blizzard's code: never let an error escape)
local function InitAuraButton(ab, harmful, size)
    pcall(function()
        ab:SetSize(size, size)
        ab.Icon = ab:CreateTexture(nil, "ARTWORK")
        ab.Icon:SetAllPoints(ab)
        ab.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ab:SetIcon(ab.Icon)
        if harmful then
            ab.Border = ab:CreateTexture(nil, "BACKGROUND")
            ab.Border:SetTexture("Interface\\Buttons\\WHITE8X8")
            ab.Border:SetPoint("TOPLEFT", -2, 2)
            ab.Border:SetPoint("BOTTOMRIGHT", 2, -2)
            local style = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset
            if not (style and Try(ab, "AddDispelTypeTexture", ab.Border, {
                style = style, showWhenHarmful = true, showWhenHelpful = false, showWithoutDispelType = true,
                customDispelColorMap = DispelColorMap(),
            })) then
                ab.Border:SetVertexColor(0.8, 0, 0)
            end
        end
        local cd = CreateFrame("Cooldown", nil, ab, "CooldownFrameTemplate")
        cd:SetAllPoints(ab)
        cd:SetReverse(true)
        Try(cd, "SetHideCountdownNumbers", true)
        Try(cd, "SetDrawEdge", false)
        Try(ab, "SetDurationCooldown", cd)
        ab.Stacks = ab:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        ab.Stacks:SetPoint("BOTTOMRIGHT", 2, -2)
        Try(ab, "SetApplicationCount", ab.Stacks)
        -- hovering an icon shows the debuff's tooltip; clicks still go to the frame
        Try(ab, "SetTooltipAnchorPoint", "ANCHOR_RIGHT")
        Try(ab, "SetHideTooltipInCombat", false)
        Try(ab, "SetMouseMotionEnabled", true)
        Try(ab, "SetMouseClickEnabled", false)
    end)
end

-- the tint: an invisible one-slot aura button whose only job is a coloured wash over the
-- health bar, shown by the game while a debuff of that type she can remove is on them
local function InitTintButton(button, kind, ab)
    pcall(function()
        ab:SetSize(1, 1)
        Try(ab, "EnableMouse", false)
        local icon = ab:CreateTexture(nil, "BACKGROUND")
        icon:SetSize(1, 1)
        icon:SetAlpha(0)
        Try(ab, "SetIcon", icon)
        local c = KH.ClassData.DISPEL_COLORS[kind]
        local wash = ab:CreateTexture(nil, "OVERLAY")
        wash:SetPoint("TOPLEFT", button.health, "TOPLEFT")
        wash:SetPoint("BOTTOMRIGHT", button.health, "BOTTOMRIGHT")
        wash:SetColorTexture(c[1], c[2], c[3], TINT_ALPHA)
    end)
end

local function NewContainer(button, level)
    local c = CreateFrame("AuraContainer", nil, button.content, "CustomAuraContainerTemplate")
    c:SetFrameLevel(level)
    c:SetSize(1, 1)
    return c
end

local function Grow(c, point, rightwards)
    local flow = AnchorUtil and AnchorUtil.FlowDirection
    Try(c, "SetFlowLayoutAnchorPoint", point)
    if not (flow and Try(c, "SetFlowLayoutGrowthDirection", rightwards and flow.Right or flow.Left, flow.Up)) then
        Try(c, "SetFlowLayoutGrowthDirection", rightwards and 1 or -1, 1)
    end
end

-- an icon row: the first filter the client accepts wins; nil if none. `candidates` (optional)
-- narrows it further, the game applying it in combat too; dropped if the client refuses it.
local function IconContainer(button, filters, harmful, maxCount, point, x, y, rightwards, relativeTo, candidates)
    local c = NewContainer(button, button.overlay:GetFrameLevel() + 1)
    c:SetPoint(point, relativeTo or button.content, point, x, y)
    -- debuff icons have a coloured border around them: a little more room
    local size, gap = harmful and AURA_SIZE or MINE_SIZE, harmful and 3 or 2
    local function Add(filter, cf)
        return pcall(function()
            c:AddAuraGroup("main", filter, {
                maxFrameCount = maxCount,
                layout = { elementWidth = size, elementHeight = size, elementSpacing = gap, lineSpacing = gap },
                candidateFilters = cf,
                initializeFrame = function(ab) InitAuraButton(ab, harmful, size) end,
            })
        end)
    end
    for _, filter in ipairs(filters) do
        local ok = Add(filter, candidates)
        if not ok and candidates then
            ok = Add(filter, nil)
            if ok then TellOnce("candidates", "this game build won't hide long buffs on the frames, so all of your buffs show.") end
        end
        if ok then
            Grow(c, point, rightwards)
            Try(c, "SetFlowLayoutMaximumLineSize", maxCount * (size + gap))
            Try(c, "SetEnabled", false)
            return c, filter
        end
    end
    Try(c, "Hide")
    return nil
end

-- one group per dispel type, each owning its colour; nil if the client refuses the type filter
local function TintContainer(button, filter)
    local c = NewContainer(button, button.health:GetFrameLevel() + 1)
    c:SetPoint("CENTER", button.health, "CENTER")
    local ok, err = pcall(function()
        for _, kind in ipairs(DISPEL_KINDS) do
            c:AddAuraGroup("tint" .. kind, filter, {
                maxFrameCount = 1,
                candidateFilters = { includeDispelTypes = { [kind] = true } },
                initializeFrame = function(ab) InitTintButton(button, kind, ab) end,
            })
        end
    end)
    if not ok then
        Try(c, "Hide")
        TellOnce("tint", "this game build won't colour frames by debuff type, so debuffs show as icons only. (%s)", tostring(err))
        return nil
    end
    Try(c, "SetEnabled", false)
    return c
end

-- containers can't be made in combat; they're built with the frames at login
local function BuildAuraContainers(button)
    if button.auraBuilt or not KH.API.auraContainers then return end
    if InCombatLockdown() then
        KH:OutOfCombat("auras" .. button:GetName(), function() BuildAuraContainers(button) end)
        return
    end
    button.auraBuilt = true
    local c = S().cleanse
    local filter
    -- debuff icons sit at the bottom of the health bar, so they follow the power bar's height
    button.dispelContainer, filter = IconContainer(button, DISPEL_FILTERS, true, c.maxIcons,
        "BOTTOMLEFT", 2, 2, true, button.health)
    if button.dispelContainer then
        button.tintContainer = TintContainer(button, filter)
    else
        TellOnce("icons", "this game build won't draw debuff icons on addon frames; using the simple version, which only works out of combat.")
    end
    -- her buffs and HoTs along the bottom, just left of the advice column (which stays clear for
    -- its text); long ones (Mark of the Wild, Fortitude) left out: a healer cares about what runs
    -- out in a fight. Changes need a /reload.
    local minutes = c.mineMaxMinutes or 0
    button.mineContainer = IconContainer(button, { "HELPFUL|PLAYER" }, false, 3, "BOTTOMRIGHT", -2, 1, false,
        button.health, minutes > 0 and { maxDuration = minutes * 60 } or nil)
    if button.mineContainer then
        button.mineContainer:ClearAllPoints()
        button.mineContainer:SetPoint("RIGHT", button.adviceHolder, "LEFT", -2, 0)
        button.mineContainer:SetPoint("BOTTOM", button.health, "BOTTOM", 0, 1)
    end
    Frames.UpdateAuraUnit(button)
end

function Frames.UpdateAuraUnit(button)
    local unit = button.unit
    local c = S().cleanse
    for _, info in ipairs({ { button.dispelContainer, c.enabled }, { button.tintContainer, c.enabled },
        { button.mineContainer, c.enabled and c.showMine } }) do
        local container, on = info[1], info[2]
        if container then
            if unit and on then
                Try(container, "SetUnit", unit)
                Try(container, "SetEnabled", true)
            else
                Try(container, "SetEnabled", false)
            end
        end
    end
end

-- Lua debuff check, when there are no aura containers: only works while auras are readable
local function UpdateDispelFallback(button)
    if button.dispelContainer then return end
    local icons = button.fallbackIcons
    local unit, shown, firstType = button.unit, 0, nil
    if unit and S().cleanse.enabled and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL")
            if not ok or not aura then break end
            local dtype = KH.Text(aura.dispelName)
            if dtype and KH.Spells.dispels[dtype] and shown < #icons then
                shown = shown + 1
                local icon = icons[shown]
                icon.tex:SetTexture(aura.icon)
                local col = KH.ClassData.DISPEL_COLORS[dtype]
                icon.border:SetColorTexture(col[1], col[2], col[3], 1)
                icon:Show()
                firstType = firstType or dtype
            end
        end
    end
    for i = shown + 1, #icons do icons[i]:Hide() end
    if firstType then
        local col = KH.ClassData.DISPEL_COLORS[firstType]
        button.fallbackTint:SetColorTexture(col[1], col[2], col[3], TINT_ALPHA)
        button.fallbackTint:Show()
    else
        button.fallbackTint:Hide()
    end
    button.dispelType = firstType
end

-- advice -----------------------------------------------------------------------------------------
-- The heal that fits is shown as its name and click ("HW3" over "L") and as a border around the
-- frame in that click's colour, so she can react to the colour alone.
--
-- Two ways to show it:
-- * gates (clients with UnitHealthMissing and health curves, like Forever). They need no maximum
--   health, which the game hides for party members inside dungeons. Each heal gets an invisible
--   StatusBar across the frame with the range (fits - 1, fits), fed the (hidden) missing health,
--   so its fill is either empty or full. The heal's label and border sit in a clipping frame
--   running from the next bigger heal's fill edge to its own fill edge: visible only while this
--   heal fits and the next one doesn't. Her HoTs on them raise every gate by the healing they
--   will still do (changing a plain bar's range is fine in combat).
--   The emergency gate is the other way round: its fill is full while they're safe. The normal
--   heals are clipped to its fill, the fast heal to the part its fill leaves empty. Safe means
--   health above the danger line (damage per second times the slow heal's cast, Tracker.lua), so
--   it's fed the (hidden) health; while damage is hidden, a step curve of health percent instead.
--   A second, shield gate starts at the end of the emergency gate's fill and is fed their
--   (hidden) shield: the normal heals run to the end of its fill, the fast heal sits in a clip
--   inside the fast-heal clip that starts there, so it shows only while neither is full.
-- * Lua (older clients): bands of health fraction, chosen while health is readable (text only).

local BORDER = 2

local function OptionColor(option)
    local click = KH.Bindings.Click(option.key)
    return click and click.color or { 0.4, 1, 0.5 }
end

-- name + click text at the top right; with `area`, also a border around it
local function Label(parent, holder, area)
    local label = {}
    label.spell = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label.spell:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    label.spell:SetJustifyH("RIGHT")
    label.click = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label.click:SetPoint("TOPRIGHT", label.spell, "BOTTOMRIGHT", 0, -1)
    label.click:SetJustifyH("RIGHT")
    if area then
        label.edges = {}
        for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, BORDER }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, BORDER },
            { "TOPLEFT", "BOTTOMLEFT", BORDER, nil }, { "TOPRIGHT", "BOTTOMRIGHT", BORDER, nil } }) do
            local edge = parent:CreateTexture(nil, "OVERLAY")
            edge:SetPoint(side[1], area, side[1])
            edge:SetPoint(side[2], area, side[2])
            if side[3] then edge:SetWidth(side[3]) else edge:SetHeight(side[4]) end
            label.edges[i] = edge
        end
    end
    return label
end

local function SetLabel(label, option)
    local c = OptionColor(option)
    label.color = c
    label.spell:SetText(KH.Spells.Short(option.info))
    label.spell:SetTextColor(c[1], c[2], c[3], 1)
    label.click:SetText(option.short)
    for _, edge in ipairs(label.edges or {}) do edge:SetColorTexture(c[1], c[2], c[3], 0.9) end
end

-- invisible bar across the whole frame; only its fill's edge matters
local function GateBar(button)
    local bar = CreateFrame("StatusBar", nil, button.adviceHolder)
    bar:SetAllPoints(button.content)
    bar:SetStatusBarTexture(BAR_TEXTURE)
    bar:SetStatusBarColor(0, 0, 0, 0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

local function ClipFrame(parent)
    local clip = CreateFrame("Frame", nil, parent)
    clip:SetClipsChildren(true)
    return clip
end

local function Gate(button, i)
    local gate = button.gates[i]
    if gate then return gate end
    gate = { bar = GateBar(button), clip = ClipFrame(button.normalClip) }
    gate.label = Label(gate.clip, button.adviceHolder, button.content)
    button.gates[i] = gate
    return gate
end

local emergencyCurve, emergencyCurveVersion

local function BuildGates(button)
    if button.gateVersion == version then return end
    button.gateVersion = version
    local holder, area = button.adviceHolder, button.content
    if not button.emergencyGate then
        local e = { bar = GateBar(button), shield = GateBar(button), clip = ClipFrame(holder) }
        local fill = e.bar:GetStatusBarTexture()
        -- the shield gate starts where the health gate's fill ends: its fill's end is at the
        -- frame's right edge (or further) when either is full, at the left edge when both are empty
        e.shield:ClearAllPoints()
        e.shield:SetPoint("TOPLEFT", fill, "TOPRIGHT")
        e.shield:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
        e.shield:SetWidth(area:GetWidth())
        area:HookScript("OnSizeChanged", function(_, width) e.shield:SetWidth(width) end)
        local shieldFill = e.shield:GetStatusBarTexture()
        -- fill full = safe: normal heals inside either fill, the fast heal after both
        e.clip:SetPoint("TOPLEFT", fill, "TOPRIGHT")
        e.clip:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT")
        e.inner = ClipFrame(e.clip)
        e.inner:SetPoint("TOPLEFT", shieldFill, "TOPRIGHT")
        e.inner:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT")
        e.label = Label(e.inner, holder, area)
        button.emergencyGate = e
        button.normalClip = ClipFrame(holder)
        button.normalClip:SetPoint("TOPLEFT", area, "TOPLEFT")
        button.normalClip:SetPoint("BOTTOMRIGHT", shieldFill, "BOTTOMRIGHT")
    end

    local thresholds = KH.Advisor.Thresholds(options, S().advisor)
    button.gateHot = nil    -- UpdateGates sets the ranges
    for i, rung in ipairs(thresholds) do
        local gate = Gate(button, i)
        gate.option = rung.option
        gate.threshold = rung.threshold
        gate.clip:ClearAllPoints()
        if i < #thresholds then
            gate.clip:SetPoint("TOPLEFT", Gate(button, i + 1).bar:GetStatusBarTexture(), "TOPRIGHT")
        else
            gate.clip:SetPoint("TOPLEFT", area, "TOPLEFT")
        end
        gate.clip:SetPoint("BOTTOMRIGHT", gate.bar:GetStatusBarTexture(), "BOTTOMRIGHT")
        SetLabel(gate.label, rung.option)
        gate.clip:Show()
    end
    button.gateCount = #thresholds
    for i = #thresholds + 1, #button.gates do button.gates[i].clip:Hide() end

    local e = button.emergencyGate
    local a = S().advisor
    e.on = options.emergency ~= nil and (a.emergencyByTime or (a.emergency or 0) > 0)
    e.clip:SetShown(e.on)
    if e.on then SetLabel(e.label, options.emergency) end
    if emergencyCurveVersion ~= version then
        emergencyCurveVersion = version
        -- 1 (safe) from the emergency line up, 0 below it
        emergencyCurve = (a.emergency or 0) > 0 and KH.Advisor.Curve({ lo = a.emergency, hi = 2 }) or nil
    end
end

-- the emergency gate: full (safe) or empty (fast heal). A shield on them buys time: the damage
-- has to get through it first. Readable, it simply lowers the line; hidden, the shield gate is
-- full when the shield alone covers the line (safe when either health or shield does).
local function UpdateEmergency(button, unit, settings)
    local e = button.emergencyGate
    e.shield:SetMinMaxValues(0, 1)
    e.shield:SetValue(0)
    if e.on and KH.Advisor.ByTime(settings) then
        local line = KH.Advisor.DangerLine(options, KH.Tracker.DamagePerSecond(unit), settings)
        if line > 0 and settings.countShields and KH.API.absorbs then
            local absorbs = UnitGetTotalAbsorbs(unit)
            if KH.Readable(absorbs) then
                line = line - (KH.Num(absorbs) or 0)
            else
                e.shield:SetMinMaxValues(line - 1, line)
                e.shield:SetValue(absorbs)
            end
        end
        if line > 0 then
            e.bar:SetMinMaxValues(line - 1, line)
            e.bar:SetValue(UnitHealth(unit))
            return
        end
    elseif e.on and emergencyCurve then
        e.bar:SetMinMaxValues(0, 1)
        e.bar:SetValue(UnitHealthPercent(unit, settings.predicted, emergencyCurve))
        return
    end
    e.bar:SetMinMaxValues(0, 1)
    e.bar:SetValue(1)
end

local function UpdateGates(button, unit, settings)
    BuildGates(button)
    -- her HoTs on them: every heal needs that much more missing health to fit
    local hot = settings.countHots and KH.Round(KH.Tracker.HotRemaining(unit)) or 0
    if hot ~= button.gateHot then
        button.gateHot = hot
        for i = 1, button.gateCount do
            local gate = button.gates[i]
            gate.bar:SetMinMaxValues(gate.threshold + hot - 1, gate.threshold + hot)
        end
    end
    -- missing health, minus heals already on the way when that setting is on
    local missing = UnitHealthMissing(unit, settings.predicted)
    for i = 1, button.gateCount do button.gates[i].bar:SetValue(missing) end
    UpdateEmergency(button, unit, settings)
end

local function AdviceSlot(button, i)
    local slot = button.advice[i]
    if slot then return slot end
    slot = Label(button.adviceHolder, button.adviceHolder)
    button.advice[i] = slot
    return slot
end

-- the Lua path's bands, rebuilt when the max health, bindings or settings changed
local function EnsurePlan(button, maxHealth)
    if button.planVersion == version and button.planMax == maxHealth then return end
    button.planVersion, button.planMax = version, maxHealth
    button.plan = maxHealth and KH.Advisor.Plan(options, maxHealth, S().advisor) or {}
    for i, band in ipairs(button.plan) do
        SetLabel(AdviceSlot(button, i), band.option)
    end
end

-- the health fraction Lua may use, or nil when health is hidden (her HoTs count as healed)
local function ReadableFraction(unit, settings)
    local hp, max = KH.Num(UnitHealth(unit)), KH.Num(UnitHealthMax(unit))
    if not hp or not max or max <= 0 then return nil end
    if settings.predicted and UnitGetIncomingHeals then
        hp = hp + (KH.Num(UnitGetIncomingHeals(unit)) or 0)
    end
    if settings.countHots then hp = hp + KH.Tracker.HotRemaining(unit) end
    return math.min(1, hp / max)
end

-- (the Lua path keeps the emergency health % line; the danger line needs the gates)
local function UpdatePlan(button, unit, settings)
    EnsurePlan(button, button.maxHealth)
    local fraction = ReadableFraction(unit, settings)
    local chosen = fraction and KH.Advisor.Choose(button.plan, fraction)
    for i, slot in ipairs(button.advice) do
        local band = button.plan[i]
        local alpha = (band and band == chosen) and 1 or 0
        local color = slot.color or { 0.4, 1, 0.5 }
        slot.spell:SetTextColor(color[1], color[2], color[3], alpha)
        slot.click:SetTextColor(1, 1, 1, alpha)
    end
end

function Frames.AdviceMode()
    return (KH.API.healthMissing and KH.API.curves) and "gates" or "lua"
end

function Frames.UpdateAdvice(button)
    local unit = button.unit
    local settings = S().advisor
    if not unit or not settings.enabled or not options or #options.normal == 0 and not options.emergency then
        button.adviceHolder:Hide()
        return
    end
    button.adviceHolder:Show()
    if Frames.AdviceMode() == "gates" then
        UpdateGates(button, unit, settings)
    else
        UpdatePlan(button, unit, settings)
    end

    -- no advice on the dead
    local dead = UnitIsDeadOrGhost(unit)
    if KH.Bool(dead) ~= nil then
        button.adviceHolder:SetAlpha(dead and 0 or 1)
    elseif button.adviceHolder.SetAlphaFromBoolean then
        button.adviceHolder:SetAlphaFromBoolean(dead, 0, 1)
    end
end

-- updates ------------------------------------------------------------------------------------------

function Frames.UpdateHealth(button)
    local unit = button.unit
    if not unit then return end
    local max, hp = UnitHealthMax(unit), UnitHealth(unit)
    button.health:SetMinMaxValues(0, max)
    button.health:SetValue(hp)
    -- remember the maximum while it's readable: the advice needs it in combat
    local readableMax = KH.Num(max)
    if readableMax and readableMax > 0 then button.maxHealth = readableMax end

    Frames.UpdateHealthText(button, max, hp)
    ShowIf(button.dead, UnitIsDeadOrGhost(unit))
    Frames.UpdateShield(button)
    Frames.UpdateIncoming(button)
end

-- the number under the name, per Layout setting: missing ("-160"), percent ("77%"), current
-- ("540"), both ("540 (77%)") or none. Hidden numbers go straight to the game to format.
function Frames.UpdateHealthText(button, max, hp)
    local unit, fs, mode = button.unit, button.missing, S().frames.healthText
    local readableMax, readableHp = KH.Num(max), KH.Num(hp)
    if mode == "none" then
        fs:SetText("")
    elseif readableMax and readableHp and readableMax > 0 then
        local missing = readableMax - readableHp
        local pct = KH.Round(readableHp / readableMax * 100)
        if mode == "percent" then
            fs:SetText(pct .. "%")
        elseif mode == "current" then
            fs:SetText(KH.Short(readableHp))
        elseif mode == "both" then
            fs:SetText(KH.Short(readableHp) .. " (" .. pct .. "%)")
        else
            fs:SetText(missing > 0 and ("-" .. KH.Short(missing)) or "")
        end
        if mode == "missing" then fs:SetTextColor(1, 0.45, 0.45, 1) else fs:SetTextColor(1, 1, 1, 1) end
    elseif mode == "missing" then
        if not (UnitHealthMissing and pcall(fs.SetFormattedText, fs, "-%d", UnitHealthMissing(unit))) then
            fs:SetText("")
        end
        local alpha = HurtCurve() and UnitHealthPercent(unit, false, HurtCurve()) or 1
        fs:SetTextColor(1, 0.45, 0.45, alpha)
    else
        -- (no comparisons here: these values may be hidden)
        local curve = PercentCurve()
        local pct = curve and UnitHealthPercent(unit, false, curve)
        local ok
        if mode == "percent" and curve then
            ok = pcall(fs.SetFormattedText, fs, "%.0f%%", pct)
        elseif mode == "both" and curve then
            ok = pcall(fs.SetFormattedText, fs, "%d (%.0f%%)", hp, pct)
        else
            ok = pcall(fs.SetFormattedText, fs, "%d", hp)
        end
        if not ok then fs:SetText("") end
        fs:SetTextColor(1, 1, 1, 1)
    end
end

-- pixels the shield bar takes from the top of every frame (0 when it's off)
function Frames.ShieldSpace()
    local f = S().frames
    if not (f.showShields and KH.API.absorbs and f.shieldHeight > 0) then return 0 end
    return f.shieldHeight + 1
end

-- the gold shield bar (the game's own total of damage shields on them, hidden or not)
function Frames.UpdateShield(button)
    local unit = button.unit
    if not unit then return end
    local show = Frames.ShieldSpace() > 0
    button.shield:SetShown(show)
    if not show then return end
    button.shield:SetHeight(S().frames.shieldHeight)
    local amount = UnitGetTotalAbsorbs(unit)
    if KH.Readable(amount) and amount == nil then amount = 0 end
    button.shield:SetMinMaxValues(0, KH.Spells.BiggestShield() or UnitHealthMax(unit))
    button.shield:SetValue(amount)
end

-- the incoming-heal bar, then the advice (which counts incoming heals too)
function Frames.UpdateIncoming(button)
    local unit = button.unit
    if not unit then return end
    local show = S().frames.showIncoming and UnitGetIncomingHeals ~= nil
    button.incomingClip:SetShown(show)
    if show then
        local amount = UnitGetIncomingHeals(unit)
        if KH.Readable(amount) and amount == nil then amount = 0 end
        button.incoming:SetMinMaxValues(0, UnitHealthMax(unit))
        button.incoming:SetValue(amount)
    end
    Frames.UpdateAdvice(button)
end

-- the power bar (mana, rage, energy) and its text; the health bar fills the space when it's off
function Frames.UpdatePower(button)
    local unit = button.unit
    if not unit then return end
    local f = S().frames
    local ptype = KH.Num(UnitPowerType(unit))
    local show = f.showPower ~= "none" and f.powerHeight > 0 and (f.showPower == "all" or not ptype or ptype == 0)
    button.mana:SetShown(show)
    button.health:SetPoint("TOPLEFT", 1, -1 - Frames.ShieldSpace())
    button.health:SetPoint("BOTTOMRIGHT", -1, show and (f.powerHeight + 1) or 1)
    if show then
        button.mana:SetHeight(f.powerHeight)
        local c = POWER_COLORS[ptype or 0] or POWER_COLORS[0]
        button.mana:SetStatusBarColor(c[1], c[2], c[3])
        button.mana:SetMinMaxValues(0, UnitPowerMax(unit))
        button.mana:SetValue(UnitPower(unit))
    end
    Frames.UpdatePowerText(button, show)
end

function Frames.UpdatePowerText(button, shown)
    local unit, fs, mode = button.unit, button.powerText, S().frames.powerText
    if mode == "none" or not shown then
        fs:SetText("")
        return
    end
    local power, max = UnitPower(unit), UnitPowerMax(unit)
    local readablePower, readableMax = KH.Num(power), KH.Num(max)
    if readablePower and readableMax then
        local pct = readableMax > 0 and KH.Round(readablePower / readableMax * 100) or 0
        if mode == "percent" then
            fs:SetText(pct .. "%")
        elseif mode == "both" then
            fs:SetText(KH.Short(readablePower) .. " (" .. pct .. "%)")
        else
            fs:SetText(KH.Short(readablePower))
        end
        return
    end
    -- hidden: the game formats the current amount (no percent for hidden power)
    if not pcall(fs.SetFormattedText, fs, "%d", power) then fs:SetText("") end
end

-- sizes and fonts that follow the Layout settings (plain frames: fine in combat)
function Frames.LayoutElements(button)
    local f = S().frames
    button.name:SetWidth(math.max(20, f.width - 52))
    SetFontSize(button.name, f.nameSize)
    SetFontSize(button.missing, f.textSize)
    SetFontSize(button.powerText, f.textSize)
end

function Frames.UpdateName(button)
    local unit = button.unit
    if not unit then return end
    -- first name only (Forever's UnitName also returns the surname); may be hidden, so no string work
    button.name:SetText((UnitName(unit)))
    local classTag = KH.Text(select(2, UnitClass(unit)))
    local r, g, b = 0.2, 0.8, 0.3
    if classTag and S().frames.classColors then r, g, b = KH.ClassColor(classTag) end
    button.health:SetStatusBarColor(r, g, b)
    local online = UnitIsConnected(unit)
    if KH.Bool(online) ~= nil then
        button.offline:SetShown(not online)
    else
        button.offline:Hide()
    end
end

function Frames.UpdateTarget(button)
    local unit = button.unit
    if not unit then return end
    ShowIf(button.targetBorder, UnitIsUnit(unit, "target"))
end

function Frames.UpdateRange(button)
    local unit = button.unit
    if not unit then return end
    local content, faded = button.content, S().frames.rangeAlpha
    if KH.Bool(UnitIsUnit(unit, "player")) then
        content:SetAlpha(1)
        return
    end
    local inRange, checked = UnitInRange(unit)
    if KH.Readable(inRange) and KH.Readable(checked) then
        -- not checked = the range check doesn't apply (not grouped with them)
        content:SetAlpha((inRange or not checked) and 1 or faded)
    elseif content.SetAlphaFromBoolean then
        content:SetAlphaFromBoolean(inRange, 1, faded)
    end
end

function Frames.UpdateAll(button)
    if not button.unit then return end
    Frames.UpdateName(button)
    Frames.UpdateHealth(button)
    Frames.UpdatePower(button)
    Frames.UpdateTarget(button)
    Frames.UpdateRange(button)
    UpdateDispelFallback(button)
end

-- building a frame ---------------------------------------------------------------------------------

local function Remap()
    wipe(byUnit)
    for _, b in ipairs(Frames.buttons) do
        if b.unit and b:IsShown() then byUnit[b.unit] = b end
    end
end

local function OnUnitChanged(button, unit)
    if unit == button.unit then return end
    button.unit = unit
    button.maxHealth = nil
    Remap()
    Frames.UpdateAuraUnit(button)
    if unit then Frames.UpdateAll(button) end
end

local function Setup(button)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.65)

    -- everything visual lives on "content", so range fading is one alpha on a plain frame
    local content = CreateFrame("Frame", nil, button)
    content:SetAllPoints()
    button.content = content

    local health = CreateFrame("StatusBar", nil, content)
    health:SetStatusBarTexture(BAR_TEXTURE)
    health:SetPoint("TOPLEFT", 1, -1)
    health:SetPoint("BOTTOMRIGHT", -1, 1)   -- moved up by UpdatePower when the power bar shows
    health:SetMinMaxValues(0, 1)
    health:SetValue(1)
    button.health = health

    -- heals on the way (hers while casting, and other healers'): a faint bar that starts where
    -- the health ends, as wide as the health bar so both use the same scale, cut at the edge
    local incomingClip = CreateFrame("Frame", nil, content)
    incomingClip:SetAllPoints(health)
    incomingClip:SetClipsChildren(true)
    incomingClip:SetFrameLevel(health:GetFrameLevel() + 1)
    -- heals on the way (hers while casting, and other healers'): a faint bar that starts where
    -- the health ends, as wide as the health bar so both use the same scale, cut at the edge
    local incomingClip = CreateFrame("Frame", nil, content)
    incomingClip:SetAllPoints(health)
    incomingClip:SetClipsChildren(true)
    incomingClip:SetFrameLevel(health:GetFrameLevel() + 1)
    local incoming = CreateFrame("StatusBar", nil, incomingClip)
    incoming:SetStatusBarTexture(BAR_TEXTURE)
    incoming:SetStatusBarColor(0.4, 1, 0.5, 0.45)
    incoming:SetPoint("TOPLEFT", health:GetStatusBarTexture(), "TOPRIGHT")
    incoming:SetPoint("BOTTOMLEFT", health:GetStatusBarTexture(), "BOTTOMRIGHT")
    incoming:SetMinMaxValues(0, 1)
    incoming:SetValue(0)
    health:HookScript("OnSizeChanged", function(_, width) incoming:SetWidth(width) end)
    button.incomingClip = incomingClip
    button.incoming = incoming

    -- shields (Power Word: Shield): a gold bar across the top of the frame, the way the power bar
    -- runs along the bottom. Its space is kept whether or not there's a shield (UpdatePower moves
    -- the health bar under it), so nothing moves when a shield comes or goes and it covers
    -- nothing. Full = her biggest shield (else their max health).
    local shield = CreateFrame("StatusBar", nil, content)
    shield:SetStatusBarTexture(BAR_TEXTURE)
    shield:SetStatusBarColor(1, 0.82, 0.25, 1)
    shield:SetPoint("TOPLEFT", 1, -1)
    shield:SetPoint("TOPRIGHT", -1, -1)
    shield:SetHeight(5)
    shield:SetMinMaxValues(0, 1)
    shield:SetValue(0)
    button.shield = shield

    local mana = CreateFrame("StatusBar", nil, content)
    mana:SetStatusBarTexture(BAR_TEXTURE)
    mana:SetStatusBarColor(0.25, 0.45, 1)
    mana:SetPoint("BOTTOMLEFT", 1, 1)
    mana:SetPoint("BOTTOMRIGHT", -1, 1)
    mana:SetHeight(4)
    button.mana = mana

    -- text sits above the bars and the tint
    local overlay = CreateFrame("Frame", nil, content)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(health:GetFrameLevel() + 3)
    button.overlay = overlay

    button.name = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.name:SetPoint("TOPLEFT", health, "TOPLEFT", 3, -2)
    button.name:SetWidth(64)
    button.name:SetJustifyH("LEFT")
    if button.name.SetWordWrap then button.name:SetWordWrap(false) end

    button.missing = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.missing:SetPoint("TOPLEFT", button.name, "BOTTOMLEFT", 0, -2)
    button.missing:SetJustifyH("LEFT")

    button.powerText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.powerText:SetPoint("TOPLEFT", button.missing, "BOTTOMLEFT", 0, -1)
    button.powerText:SetJustifyH("LEFT")
    button.powerText:SetTextColor(0.6, 0.75, 1)

    button.dead = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.dead:SetPoint("CENTER", 0, 0)
    button.dead:SetText("|cffaaaaaaDEAD|r")
    button.dead:Hide()

    button.offline = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.offline:SetPoint("CENTER", 0, 0)
    button.offline:SetText("|cff888888Offline|r")
    button.offline:Hide()

    button.targetBorder = overlay:CreateTexture(nil, "OVERLAY")
    button.targetBorder:SetPoint("TOPLEFT", -1, 1)
    button.targetBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    button.targetBorder:SetColorTexture(1, 1, 1, 0.25)
    button.targetBorder:Hide()

    -- the Lua fallback's tint and icons (only used without aura containers)
    button.fallbackTint = overlay:CreateTexture(nil, "BACKGROUND")
    button.fallbackTint:SetPoint("TOPLEFT", health, "TOPLEFT")
    button.fallbackTint:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT")
    button.fallbackTint:Hide()
    button.fallbackIcons = {}
    for i = 1, 3 do
        local icon = CreateFrame("Frame", nil, overlay)
        icon:SetSize(AURA_SIZE, AURA_SIZE)
        icon:SetPoint("BOTTOMLEFT", health, "BOTTOMLEFT", 2 + (i - 1) * (AURA_SIZE + 3), 2)
        icon.border = icon:CreateTexture(nil, "BACKGROUND")
        icon.border:SetPoint("TOPLEFT", -2, 2)
        icon.border:SetPoint("BOTTOMRIGHT", 2, -2)
        icon.tex = icon:CreateTexture(nil, "ARTWORK")
        icon.tex:SetAllPoints()
        icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:Hide()
        button.fallbackIcons[i] = icon
    end

    -- the advice ("HW3" / "S-L") on the right
    local holder = CreateFrame("Frame", nil, overlay)
    holder:SetPoint("TOPRIGHT", health, "TOPRIGHT", -2, -2)
    holder:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", -2, 2)
    holder:SetWidth(44)
    button.adviceHolder = holder
    button.advice = {}
    button.plan = {}
    button.gates = {}
    button.gateCount = 0

    button:HookScript("OnAttributeChanged", function(self, name, value)
        if name == "unit" then KH.Safe(OnUnitChanged, self, value) end
    end)
    button:HookScript("OnShow", function(self) KH.Safe(function() Remap(); Frames.UpdateAll(self) end) end)
    button:HookScript("OnHide", function() KH.Safe(Remap) end)
    -- the HoT tracker needs to know who she clicked (the game may hide the cast's target name)
    button:HookScript("PreClick", function(self) KH.Safe(KH.Tracker.Clicked, self.unit) end)
    button:HookScript("OnEnter", function(self) KH.Safe(Frames.ShowTooltip, self) end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)

    BuildAuraContainers(button)
end

local function CreateButton(i)
    local b = CreateFrame("Button", "KorkronHealHelperUnit" .. i, anchor, "SecureUnitButtonTemplate, SecureActionButtonTemplate")
    -- both edges: the secure click code picks the one matching the game's "cast on key down" setting
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:Hide()
    Setup(b)
    return b
end

-- hover: who it is and what each click does
function Frames.ShowTooltip(button)
    if not button.unit then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetUnit(button.unit)
    GameTooltip:AddLine(" ")
    for _, b in ipairs(KH.Bindings.Resolved()) do
        GameTooltip:AddDoubleLine(b.label, KH.Bindings.Describe(b.binding), 1, 0.82, 0, 1, 1, 1)
    end
    GameTooltip:Show()
end

-- who goes in which frame ------------------------------------------------------------------------------

-- { { unit, group }, ... } in display order: raid by group, else you and your party
function Frames.GroupUnits()
    local list = {}
    if IsInRaid() then
        for i = 1, MAX_BUTTONS do
            local _, _, subgroup = GetRaidRosterInfo(i)
            subgroup = KH.Num(subgroup)
            if subgroup then list[#list + 1] = { unit = "raid" .. i, group = subgroup, index = i } end
        end
        table.sort(list, function(a, b)
            if a.group ~= b.group then return a.group < b.group end
            return a.index < b.index
        end)
    elseif IsInGroup() then
        list[1] = { unit = "player", group = 1 }
        for i = 1, 4 do
            if UnitExists("party" .. i) then list[#list + 1] = { unit = "party" .. i, group = 1 } end
        end
    elseif S().frames.showSolo or Frames.editing then
        list[1] = { unit = "player", group = 1 }
    end
    -- edit mode: fill up to a party of five with copies of you, to see the layout
    if Frames.editing and not IsInRaid() then
        for i = #list + 1, 5 do list[i] = { unit = "player", group = 1 } end
    end
    return list
end

-- give every frame its person and place (protected work: out of combat only)
local function Assign()
    if not anchor then return end
    local f = S().frames
    local list = f.enabled and Frames.GroupUnits() or {}
    local col, row, lastGroup = 0, 0, nil
    local cols, rows = 0, 0
    for i, b in ipairs(Frames.buttons) do
        local entry = list[i]
        if entry then
            if entry.group ~= lastGroup then col, row, lastGroup = col + 1, 0, entry.group end
            row = row + 1
            -- each group is a column (or a row), its members going down (or across)
            local x, y = col, row
            if f.groupsAs == "rows" then x, y = row, col end
            cols, rows = math.max(cols, x), math.max(rows, y)
            b:SetSize(f.width, f.height)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", anchor, "TOPLEFT", (x - 1) * (f.width + f.spacingX), -(y - 1) * (f.height + f.spacingY))
            Frames.LayoutElements(b)
            b:SetAttribute("unit", entry.unit)
            KH.Bindings.ApplyTo(b)
            RegisterUnitWatch(b)
        else
            UnregisterUnitWatch(b)
            b:SetAttribute("unit", nil)
            b:Hide()
        end
    end
    Frames.cols, Frames.rows = math.max(cols, 1), math.max(rows, 1)
    Remap()
    KH:Fire("FRAMES_LAID_OUT")
end

function Frames.Reassign()
    KH:OutOfCombat("assign", Assign)
end

local function ApplyLayout()
    if not anchor then return end
    local f = S().frames
    anchor:ClearAllPoints()
    anchor:SetPoint(f.point, UIParent, f.point, f.x, f.y)
    anchor:SetScale(f.scale)
    anchor.handle:SetShown(not f.locked and f.enabled)
    Assign()
end

function Frames.Anchor()
    return anchor
end

function Frames.ApplyLayout()
    KH:OutOfCombat("layout", ApplyLayout)
end

-- edit mode shows preview frames; the frames are protected, so out of combat only
function Frames.SetEditing(on)
    Frames.editing = on and true or false
    KH:OutOfCombat("layout", ApplyLayout)
end

local function SavePosition()
    local f = S().frames
    local point, _, _, x, y = anchor:GetPoint(1)
    f.point, f.x, f.y = point or "TOPLEFT", KH.Round(x or 0), KH.Round(y or 0)
end

local function Build()
    anchor = CreateFrame("Frame", "KorkronHealHelperAnchor", UIParent)
    anchor:SetSize(10, 10)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)

    -- drag handle, shown while the frames are unlocked
    local handle = CreateFrame("Button", nil, anchor)
    handle:SetSize(112, 16)
    handle:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
    handle.bg = handle:CreateTexture(nil, "BACKGROUND")
    handle.bg:SetAllPoints()
    handle.bg:SetColorTexture(0.77, 0.12, 0.23, 0.8)
    handle.text = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    handle.text:SetPoint("CENTER")
    handle.text:SetText("Kor'kron Heal - drag")
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if not InCombatLockdown() then anchor:StartMoving() end
    end)
    handle:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        KH.Safe(SavePosition)
    end)
    Frames.SavePosition = SavePosition
    handle:SetScript("OnEnter", function(self)
        KH.UI.Tip(self, "Kor'kron Heal Helper", "Drag to move the healer frames. Lock them in /khh (Settings) or with /khh lock.")
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    anchor.handle = handle

    for i = 1, MAX_BUTTONS do Frames.buttons[i] = CreateButton(i) end
    ApplyLayout()
end

function Frames:Init()
    if anchor then return end
    if InCombatLockdown() then
        KH:OutOfCombat("buildFrames", function() Frames:Init() end)
        return
    end
    Build()
    Frames.Refresh()
end

-- bindings, spells or settings changed: rebuild the advice and re-apply clicks/layout
function Frames.Refresh()
    version = version + 1
    options = KH.Advisor.Options()
    for _, b in ipairs(Frames.buttons) do
        if b.unit then
            Frames.UpdateAuraUnit(b)
            Frames.UpdateAll(b)
        end
    end
    KH:OutOfCombat("layout", ApplyLayout)
end

function Frames.SetLocked(locked)
    S().frames.locked = locked
    if anchor then anchor.handle:SetShown(not locked and S().frames.enabled) end
end

function Frames.ResetPosition()
    local d = KH.DB.Defaults().frames
    local f = S().frames
    f.point, f.x, f.y = d.point, d.x, d.y
    KH:OutOfCombat("layout", ApplyLayout)
end

-- the frame showing a unit, if any
function Frames.ButtonFor(unit)
    return byUnit[unit]
end

KH:On("BINDINGS_UPDATED", function() if anchor then Frames.Refresh() end end)
KH:On("SETTINGS_UPDATED", function() if anchor then Frames.Refresh() end end)

-- events ------------------------------------------------------------------------------------------------

local function ForUnit(fn)
    return function(unit)
        local b = unit and byUnit[unit]
        if b then fn(b) end
    end
end

KH:RegisterEvent("UNIT_HEALTH", ForUnit(Frames.UpdateHealth))
KH:RegisterEvent("UNIT_MAXHEALTH", ForUnit(Frames.UpdateHealth))
KH:RegisterEvent("UNIT_HEAL_PREDICTION", ForUnit(Frames.UpdateIncoming))
-- a shield put on, hit or gone: the bar, then the advice (a shield buys time)
KH:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", ForUnit(function(b)
    Frames.UpdateShield(b)
    Frames.UpdateAdvice(b)
end))
KH:RegisterEvent("UNIT_POWER_UPDATE", ForUnit(Frames.UpdatePower))
KH:RegisterEvent("UNIT_MAXPOWER", ForUnit(Frames.UpdatePower))
KH:RegisterEvent("UNIT_DISPLAYPOWER", ForUnit(Frames.UpdatePower))
KH:RegisterEvent("UNIT_NAME_UPDATE", ForUnit(Frames.UpdateName))
KH:RegisterEvent("UNIT_CONNECTION", ForUnit(Frames.UpdateAll))
KH:RegisterEvent("UNIT_FLAGS", ForUnit(Frames.UpdateHealth))
KH:RegisterEvent("UNIT_AURA", ForUnit(UpdateDispelFallback))
KH:RegisterEvent("PLAYER_TARGET_CHANGED", function()
    for _, b in pairs(byUnit) do Frames.UpdateTarget(b) end
end)
KH:RegisterEvent("GROUP_ROSTER_UPDATE", function()
    KH:Debounce("roster", 0.2, function()
        Frames.Reassign()
        for _, b in pairs(byUnit) do Frames.UpdateAll(b) end
    end)
end)
KH:RegisterEvent("PLAYER_ENTERING_WORLD", function() Frames.Reassign() end)
-- after a fight: maximum health is readable again, refresh everything
KH:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    for _, b in pairs(byUnit) do Frames.UpdateAll(b) end
end)

-- a HoT she just cast: the advice changes at once
KH:On("TRACKER_UPDATED", function()
    for _, b in pairs(byUnit) do Frames.UpdateAdvice(b) end
end)

-- range is polled: there is no event for it. The advice too while HoTs tick down or damage
-- comes in (the danger line moves without a health event).
local ticker = CreateFrame("Frame")
local elapsed, adviceElapsed, wasBusy = 0, 0, false
ticker:SetScript("OnUpdate", function(_, dt)
    elapsed, adviceElapsed = elapsed + dt, adviceElapsed + dt
    if elapsed < 0.25 then return end
    elapsed = 0
    for _, b in pairs(byUnit) do KH.Safe(Frames.UpdateRange, b) end
    if adviceElapsed < 0.5 then return end
    adviceElapsed = 0
    -- once more after the last HoT or hit runs out
    local busy = KH.Tracker.Busy()
    if busy or wasBusy then
        for _, b in pairs(byUnit) do KH.Safe(Frames.UpdateAdvice, b) end
    end
    wasBusy = busy
end)
