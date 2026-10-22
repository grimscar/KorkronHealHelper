-- Kor'kron Heal Helper: shared UI building blocks (same look as the other Kor'kron mods).
local _, KH = ...

local UI = {}
KH.UI = UI

-- pop-ups get their own frame level so overlapping windows don't show through each other
function UI.MakePopup(frame)
    frame:SetToplevel(true)
    frame:HookScript("OnShow", function(self) self:Raise() end)
end

-- a movable dialog-style window
function UI.CreateWindow(name, width, height, title)
    local frame = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("HIGH")
    frame:Hide()
    tinsert(UISpecialFrames, name)
    UI.MakePopup(frame)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", frame.TitleBg or frame, "TOP", 0, -3)
    frame.title:SetText(title or "")
    return frame
end

function UI.Button(parent, text, width, onClick, tooltip)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 100, 22)
    btn:SetText(text)
    btn:SetScript("OnClick", function(...) KH.Safe(onClick, ...) end)
    if tooltip then
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(text)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return btn
end

function UI.Text(parent, font, wrap)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(wrap and true or false) end
    return fs
end

function UI.Tip(owner, title, text)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:AddLine(title)
    if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
    GameTooltip:Show()
end

-- a checkbox with a label; get() returns the current value, set(value) stores it
function UI.Check(parent, label, tooltip, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb.label = UI.Text(cb, "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.label:SetText(label)
    cb:SetScript("OnClick", function(self) KH.Safe(set, self:GetChecked() and true or false) end)
    cb:SetScript("OnShow", function(self) self:SetChecked(get() and true or false) end)
    if tooltip then
        cb:SetScript("OnEnter", function(self) UI.Tip(self, label, tooltip) end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    cb:SetChecked(get() and true or false)
    return cb
end

-- a "-  value  +" stepper: format(value) is shown, step(delta) changes and stores it
function UI.Stepper(parent, label, tooltip, get, step, format)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(300, 24)
    f.label = UI.Text(f, "GameFontHighlight")
    f.label:SetPoint("LEFT", 0, 0)
    f.label:SetText(label)
    f.minus = UI.Button(f, "-", 24, function() step(-1); f:Refresh() end)
    f.minus:SetPoint("LEFT", 190, 0)
    f.value = UI.Text(f, "GameFontNormal")
    f.value:SetPoint("LEFT", f.minus, "RIGHT", 4, 0)
    f.value:SetWidth(52)
    f.value:SetJustifyH("CENTER")
    f.plus = UI.Button(f, "+", 24, function() step(1); f:Refresh() end)
    f.plus:SetPoint("LEFT", f.value, "RIGHT", 4, 0)
    function f:Refresh() self.value:SetText(format(get())) end
    f:SetScript("OnShow", function(self) self:Refresh() end)
    if tooltip then
        f:EnableMouse(true)
        f:SetScript("OnEnter", function(self) UI.Tip(self, label, tooltip) end)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    f:Refresh()
    return f
end

-- dropdown menu --------------------------------------------------------------------------
-- options: { label, value, selected, header } ; onPick(option) runs when one is clicked.

local menu
local MENU_ROW = 16
local MENU_PAD = 15

local MENU_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local function BuildMenu()
    menu = CreateFrame("Frame", "KorkronHealHelperDropDownMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    if menu.SetBackdrop then
        menu:SetBackdrop(MENU_BACKDROP)
    else
        local bg = menu:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("TOPLEFT", 11, -12)
        bg:SetPoint("BOTTOMRIGHT", -12, 11)
        bg:SetColorTexture(0, 0, 0, 0.9)
    end
    menu.buttons = {}
    menu:Hide()
    tinsert(UISpecialFrames, "KorkronHealHelperDropDownMenu")
end

local function MenuButton(i)
    local btn = menu.buttons[i]
    if btn then return btn end
    btn = CreateFrame("Button", nil, menu)
    btn:SetHeight(MENU_ROW)
    btn:SetPoint("TOPLEFT", MENU_PAD, -MENU_PAD - (i - 1) * MENU_ROW)
    btn:SetPoint("RIGHT", menu, "RIGHT", -MENU_PAD, 0)
    btn.hl = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.hl:SetAllPoints()
    btn.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    btn.hl:SetBlendMode("ADD")
    btn.check = btn:CreateTexture(nil, "ARTWORK")
    btn.check:SetSize(16, 16)
    btn.check:SetPoint("LEFT", 0, 0)
    btn.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.text:SetPoint("RIGHT", 0, 0)
    btn.text:SetJustifyH("LEFT")
    btn:SetScript("OnClick", function(self)
        local opt, pick = self.option, menu.onPick
        menu:Hide()
        if opt and not opt.header and pick then KH.Safe(pick, opt) end
    end)
    menu.buttons[i] = btn
    return btn
end

function UI.ShowMenu(anchor, options, onPick, width)
    if not menu then BuildMenu() end
    if menu:IsShown() and menu.anchor == anchor then
        menu:Hide()
        return
    end
    menu.anchor, menu.onPick = anchor, onPick
    for i, opt in ipairs(options) do
        local btn = MenuButton(i)
        btn.option = opt
        btn.text:ClearAllPoints()
        btn.text:SetPoint("RIGHT", 0, 0)
        if opt.header then
            btn.text:SetFontObject("GameFontNormalSmall")
            btn.text:SetPoint("LEFT", 0, 0)
            btn.text:SetText(opt.header)
            btn.check:Hide()
            btn:EnableMouse(false)
        else
            btn.text:SetFontObject("GameFontHighlightSmall")
            btn.text:SetPoint("LEFT", 18, 0)
            btn.text:SetText(opt.label)
            btn.check:SetShown(opt.selected and true or false)
            btn:EnableMouse(true)
        end
        btn:Show()
    end
    for i = #options + 1, #menu.buttons do menu.buttons[i]:Hide() end
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -MENU_PAD + 4, 4)
    menu:SetSize((width or math.max(160, anchor:GetWidth())) + MENU_PAD * 2, #options * MENU_ROW + MENU_PAD * 2)
    menu:Show()
    menu:Raise()
end

function UI.HideMenu()
    if menu then menu:Hide() end
end

-- a window with selectable text (Ctrl+A, Ctrl+C) for reports to send to the addon author
local copyBox
function UI.ShowCopyBox(title, text)
    if not copyBox then
        copyBox = UI.CreateWindow("KorkronHealHelperCopyBox", 620, 420, "")
        local scroll = CreateFrame("ScrollFrame", "KorkronHealHelperCopyBoxScroll", copyBox, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -30)
        scroll:SetPoint("BOTTOMRIGHT", -32, 12)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject("ChatFontNormal")
        edit:SetWidth(570)
        edit:SetScript("OnEscapePressed", function() copyBox:Hide() end)
        scroll:SetScrollChild(edit)
        copyBox.edit = edit
    end
    copyBox.title:SetText(title)
    copyBox.edit:SetText(text)
    copyBox:Show()
    copyBox.edit:SetFocus()
    copyBox.edit:HighlightText()
end
