-- Kor'kron Heal Helper: minimap button (drag to move around the minimap edge).
local _, KH = ...

local UI = KH.UI
local MinimapButton = {}
UI.MinimapButton = MinimapButton

local ICON = "Interface\\Icons\\Spell_Nature_MagicImmunity"
local button

local function UpdatePosition()
    local angle = math.rad(KH.db.settings.minimap.angle or 200)
    local radius = (Minimap:GetWidth() / 2) + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    KH.db.settings.minimap.angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
    UpdatePosition()
end

local function Build()
    button = CreateFrame("Button", "KorkronHealHelperMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            UI.Main:Show("CLICKS")
        else
            UI.Main:Toggle()
        end
    end)
    button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(KH.TITLE)
        GameTooltip:AddLine("Left-click: open", 0, 1, 0)
        GameTooltip:AddLine("Right-click: click-casting", 0, 1, 0)
        GameTooltip:AddLine("Drag: move button", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function MinimapButton:Update()
    if KH.db.settings.minimap.hide then
        if button then button:Hide() end
        return
    end
    if not button then Build() end
    UpdatePosition()
    button:Show()
end
