-- Kor'kron Heal Helper: edit mode (/khh edit).
--
-- A box over the healer frames: drag its edges or corners to resize every frame, drag the middle
-- to move them. Without a group, five preview frames (copies of you) show the layout. The frames
-- are protected, so edit mode is out of combat only and closes itself when a fight starts.
-- Everything else (bar sizes, text, spacing) is on the Layout tab.
local _, KH = ...

local UI = KH.UI
local Edit = {}
UI.Edit = Edit

local MIN_W, MAX_W, MIN_H, MAX_H = 50, 300, 20, 120
local HANDLE = 10
-- where each handle sits and which way it resizes: sx -1 = left edge, 1 = right; sy 1 = top, -1 = bottom
local HANDLES = {
    { "TOPLEFT", -1, 1 }, { "TOP", 0, 1 }, { "TOPRIGHT", 1, 1 }, { "RIGHT", 1, 0 },
    { "BOTTOMRIGHT", 1, -1 }, { "BOTTOM", 0, -1 }, { "BOTTOMLEFT", -1, -1 }, { "LEFT", -1, 0 },
}

local box, drag

local function F() return KH.db.settings.frames end

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- cursor in the frames' own (scaled) units
local function Cursor()
    local x, y = GetCursorPosition()
    local scale = KH.Frames.Anchor():GetEffectiveScale()
    return x / scale, y / scale
end

-- store the position as an offset from the screen's top left, so resizing from the left or top
-- edge can move the frames by exactly what they grew
local function ToTopLeft()
    local anchor, f = KH.Frames.Anchor(), F()
    local left, top = anchor:GetLeft(), anchor:GetTop()
    local screenTop = UIParent:GetTop()
    if not (left and top and screenTop) then return end
    local ratio = UIParent:GetEffectiveScale() / anchor:GetEffectiveScale()
    f.point, f.x, f.y = "TOPLEFT", KH.Round(left), KH.Round(top - screenTop * ratio)
end

-- the box covers every frame shown
function Edit.Fit()
    if not box then return end
    local f = F()
    local cols, rows = KH.Frames.cols or 1, KH.Frames.rows or 1
    box:SetSize(cols * f.width + (cols - 1) * f.spacingX + 8, rows * f.height + (rows - 1) * f.spacingY + 8)
end

function Edit.BeginDrag(handle)
    if InCombatLockdown() then return end
    ToTopLeft()
    local f = F()
    local x, y = Cursor()
    drag = { handle = handle, x = x, y = y, width = f.width, height = f.height, left = f.x, top = f.y,
        cols = KH.Frames.cols or 1, rows = KH.Frames.rows or 1 }
end

function Edit.EndDrag()
    if not drag then return end
    drag = nil
    KH:Fire("SETTINGS_UPDATED")
end

-- while dragging: the box edge follows the cursor, shared out over the columns or rows
function Edit.UpdateDrag()
    if not drag then return end
    if InCombatLockdown() then
        drag = nil
        return
    end
    local f, h = F(), drag.handle
    local x, y = Cursor()
    local dx, dy = x - drag.x, y - drag.y
    local width, height = f.width, f.height
    if h.sx ~= 0 then
        width = KH.Round(Clamp(drag.width + h.sx * dx / drag.cols, MIN_W, MAX_W))
        if h.sx < 0 then f.x = drag.left - (width - drag.width) * drag.cols end
    end
    if h.sy ~= 0 then
        height = KH.Round(Clamp(drag.height + h.sy * dy / drag.rows, MIN_H, MAX_H))
        if h.sy > 0 then f.y = drag.top + (height - drag.height) * drag.rows end
    end
    if width ~= f.width or height ~= f.height then
        f.width, f.height = width, height
        KH.Frames.ApplyLayout()
        Edit.Fit()
    end
end

local function Build()
    local anchor = KH.Frames.Anchor()
    box = CreateFrame("Frame", "KorkronHealHelperEditBox", anchor)
    box:SetPoint("TOPLEFT", anchor, "TOPLEFT", -4, 4)
    box:SetFrameStrata("HIGH")
    -- catches the mouse, so clicking the preview frames doesn't cast
    box:EnableMouse(true)
    box.bg = box:CreateTexture(nil, "BACKGROUND")
    box.bg:SetAllPoints()
    box.bg:SetColorTexture(0.2, 0.6, 1, 0.18)
    box.title = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    box.title:SetPoint("BOTTOM", box, "TOP", 0, 22)
    box.title:SetText("Edit mode: drag the edges or corners to resize, the middle to move")

    -- move: drag the middle
    box:SetScript("OnMouseDown", function(_, mouse)
        if mouse == "LeftButton" and not InCombatLockdown() then anchor:StartMoving() end
    end)
    box:SetScript("OnMouseUp", function()
        anchor:StopMovingOrSizing()
        KH.Safe(KH.Frames.SavePosition)
    end)

    for _, spec in ipairs(HANDLES) do
        local h = CreateFrame("Frame", nil, box)
        h.sx, h.sy = spec[2], spec[3]
        h:SetSize(spec[2] == 0 and 24 or HANDLE, spec[3] == 0 and 24 or HANDLE)
        h:SetPoint("CENTER", box, spec[1])
        h:EnableMouse(true)
        h.tex = h:CreateTexture(nil, "OVERLAY")
        h.tex:SetAllPoints()
        h.tex:SetColorTexture(1, 0.82, 0, 0.9)
        h:SetScript("OnMouseDown", function(self) KH.Safe(Edit.BeginDrag, self) end)
        h:SetScript("OnMouseUp", function() KH.Safe(Edit.EndDrag) end)
    end
    box:SetScript("OnUpdate", function() if drag then KH.Safe(Edit.UpdateDrag) end end)

    local done = UI.Button(box, "Done", 70, function() Edit.Stop() end)
    done:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 0, 2)
    local opts = UI.Button(box, "Layout options", 110, function() UI.Main:Show("LAYOUT") end,
        "Bar sizes, text, spacing and how groups are arranged.")
    opts:SetPoint("LEFT", done, "RIGHT", 4, 0)
end

function Edit.IsActive()
    return box ~= nil and box:IsShown()
end

function Edit.Start()
    if InCombatLockdown() then
        KH:Print("edit mode works out of combat only.")
        return
    end
    if not KH.Frames.Anchor() then return end
    if not box then Build() end
    KH.Frames.SetEditing(true)
    box:Show()
    Edit.Fit()
end

function Edit.Stop()
    drag = nil
    if box then box:Hide() end
    if KH.Frames.editing then
        KH.Frames.SetEditing(false)
        KH:Print("layout saved.")
    end
end

function Edit.Toggle()
    if Edit.IsActive() then Edit.Stop() else Edit.Start() end
end

KH:On("FRAMES_LAID_OUT", function() Edit.Fit() end)
KH:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    if Edit.IsActive() then
        Edit.Stop()
        KH:Print("edit mode closed: a fight started.")
    end
end)
