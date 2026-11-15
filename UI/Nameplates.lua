local _, KH = ...

local Plates = {}
KH.Plates = Plates

local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
Plates.WIDTH, Plates.HEIGHT = 60, 10
Plates.stats = { added = 0, forbidden = 0 }

local byUnit = {}
local pool = {}

local function S() return KH.db.settings end

local function Gauge(parent, width, height, fontSize)
    local w = CreateFrame("Frame", nil, parent)
    w:SetSize(width, height)
    w.gate = CreateFrame("StatusBar", nil, w)
    w.gate:SetAllPoints()
    w.gate:SetStatusBarTexture(BAR_TEXTURE)
    w.gate:SetStatusBarColor(0, 0, 0, 0)
    w.gate:SetMinMaxValues(0, 1)
    w.gate:SetValue(0)
    w.clip = CreateFrame("Frame", nil, w)
    w.clip:SetClipsChildren(true)
    w.clip:SetPoint("TOPLEFT", w, "TOPLEFT")
    w.clip:SetPoint("BOTTOMRIGHT", w.gate:GetStatusBarTexture(), "BOTTOMRIGHT")
    w.clip:SetFrameLevel(w:GetFrameLevel() + 1)

    w.bg = w.clip:CreateTexture(nil, "BACKGROUND")
    w.bg:SetColorTexture(0, 0, 0, 0.7)
    w.bar = CreateFrame("StatusBar", nil, w.clip)
    w.bar:SetStatusBarTexture(BAR_TEXTURE)
    w.bar:SetStatusBarColor(1, 0.82, 0.25, 0.9)
    w.bar:SetMinMaxValues(0, 1)
    w.bar:SetValue(0)
    w.bar:SetPoint("TOPLEFT", w, "TOPLEFT", 1, -1)
    w.bar:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -1, 1)
    w.bg:SetAllPoints(w)
    w.text = w.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.text:SetPoint("CENTER", w.bar, "CENTER", 0, 0)
    w.text:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    return w
end

local function Fill(w, unit)
    local amount = UnitGetTotalAbsorbs(unit)
    if KH.Readable(amount) and amount == nil then amount = 0 end
    w.gate:SetValue(amount)
    w.bar:SetMinMaxValues(0, KH.Spells.BiggestShield() or UnitHealthMax(unit))
    w.bar:SetValue(amount)
    if not pcall(w.text.SetFormattedText, w.text, "%d", amount) then w.text:SetText("") end
end

local function Widget(plate)
    local w = pool[plate]
    if w then return w end
    w = Gauge(plate, Plates.WIDTH, Plates.HEIGHT, 8)
    w:SetPoint("TOP", plate, "BOTTOM", 0, 4)
    w:SetFrameLevel(plate:GetFrameLevel() + 5)
    w.clip:SetFrameLevel(w:GetFrameLevel() + 1)
    pool[plate] = w
    return w
end

function Plates.Update(unit)
    local w = byUnit[unit]
    if w then Fill(w, unit) end
end

local function Remove(unit)
    local w = byUnit[unit]
    if w then w:Hide() end
    byUnit[unit] = nil
end

local function Add(unit)
    Remove(unit)
    if not (S().frames.plateShields and KH.API.absorbs and C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
        return
    end
    if KH.Bool(UnitCanAttack("player", unit)) == true then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then
        Plates.stats.forbidden = Plates.stats.forbidden + 1
        return
    end
    local w = Widget(plate)
    byUnit[unit] = w
    Plates.stats.added = Plates.stats.added + 1
    w:Show()
    Plates.Update(unit)
end

function Plates.WidgetFor(unit)
    return byUnit[unit]
end

function Plates.Count()
    local n = 0
    for _ in pairs(byUnit) do n = n + 1 end
    return n
end

function Plates.Refresh()
    for unit in pairs(byUnit) do Remove(unit) end
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if KH.Bool(UnitExists(unit)) then Add(unit) end
    end
end

KH:RegisterEvent("NAME_PLATE_UNIT_ADDED", Add)
KH:RegisterEvent("NAME_PLATE_UNIT_REMOVED", Remove)
KH:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", function(unit)
    if byUnit[unit] then Plates.Update(unit) end
end)
KH:On("SETTINGS_UPDATED", function() Plates.Refresh() end)
