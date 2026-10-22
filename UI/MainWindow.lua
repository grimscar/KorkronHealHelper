-- Kor'kron Heal Helper: the main window (Spells, Clicks and Settings tabs).
local _, KH = ...

local UI = KH.UI
local Main = {}
UI.Main = Main

local WIDTH, HEIGHT = 700, 500
local frame
local tabButtons = {}
local panels = {}
local TABS = { { key = "SPELLS", label = "Spells" }, { key = "CLICKS", label = "Clicks" }, { key = "LAYOUT", label = "Layout" },
    { key = "SETTINGS", label = "Settings" } }

local function S() return KH.db.settings end
local function Changed() KH:Fire("SETTINGS_UPDATED") end

-- spells tab: what each rank heals and costs ------------------------------------------------------

local COLUMNS = {
    { title = "Spell", width = 150, justify = "LEFT" },
    { title = "Rank", width = 40 },
    { title = "Heals", width = 60 },
    { title = "Seen", width = 70 },
    { title = "Mana", width = 50 },
    { title = "Per mana", width = 70 },
    { title = "Cast", width = 50 },
    { title = "Per sec", width = 60 },
    { title = "", width = 90, justify = "LEFT" },
}
local MAX_ROWS = 18

local function RowCells(parent, y, font)
    local cells, x = {}, 0
    for i, col in ipairs(COLUMNS) do
        local fs = UI.Text(parent, font)
        fs:SetPoint("TOPLEFT", x, y)
        fs:SetWidth(col.width)
        fs:SetJustifyH(col.justify or "RIGHT")
        cells[i] = fs
        x = x + col.width + 6
    end
    return cells
end

local function BuildSpells(panel)
    panel.intro = UI.Text(panel, "GameFontHighlightSmall", true)
    panel.intro:SetPoint("TOPLEFT", 0, 0)
    panel.intro:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    panel.intro:SetText("Lower ranks heal less, but often heal more per point of mana. |cffffd100Per mana|r is the number that saves mana. "
        .. "|cffffd100Seen|r is what your casts really healed (crits left out): after 3 casts of a rank, its Heals number comes from them "
        .. "instead of the tooltip.")

    local head = RowCells(panel, -40, "GameFontNormalSmall")
    for i, col in ipairs(COLUMNS) do head[i]:SetText(col.title) end
    panel.rows = {}
    for r = 1, MAX_ROWS do panel.rows[r] = RowCells(panel, -40 - r * 16) end

    panel.footer = UI.Text(panel, "GameFontHighlightSmall", true)
    panel.footer:SetPoint("BOTTOMLEFT", 0, 0)
    panel.footer:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
end

local function RefreshSpells(panel)
    local ranks = KH.Spells.AllHealRanks()
    for r = 1, MAX_ROWS do
        local cells, info = panel.rows[r], ranks[r]
        for _, fs in ipairs(cells) do fs:SetText("") end
        if info then
            local color = info.best and "|cff60ff60" or ""
            cells[1]:SetText(info.name)
            cells[2]:SetText(tostring(info.rank))
            cells[3]:SetText(info.amount and tostring(KH.Round(info.amount)) or "?")
            local seen = info.seen
            cells[4]:SetText(seen and string.format("%d-%d |cff808080x%d|r", seen.min, seen.max, seen.n) or "|cff808080-|r")
            cells[5]:SetText(info.cost and tostring(info.cost) or "?")
            cells[6]:SetText(info.hpm and (color .. string.format("%.2f", info.hpm)) or "?")
            cells[7]:SetText(info.castTime and string.format("%.1fs", info.castTime) or "?")
            cells[8]:SetText(info.hps and tostring(KH.Round(info.hps)) or "?")
            cells[9]:SetText(info.best and "|cff60ff60most efficient|r" or "")
        end
    end
    if #ranks == 0 then
        panel.rows[1][1]:SetText("|cff808080No heals found for your class yet.|r")
    end
    local cleanses = {}
    for name in pairs(KH.Spells.cleanses) do cleanses[#cleanses + 1] = name end
    table.sort(cleanses)
    panel.footer:SetText(string.format("+Healing from gear: |cffffffff%d|r (already in Heals; changing it starts Seen over).   You can remove: |cffffffff%s|r%s",
        KH.Spells.bonus, KH.Probe.DispelList(), #cleanses > 0 and (" (" .. table.concat(cleanses, ", ") .. ")") or ""))
end

-- clicks tab: what each click on a frame does ----------------------------------------------------------

local function BindingMenu(anchorButton, key)
    local options = {}
    local current = KH.Bindings.Get()[key]
    local function Add(label, value)
        local sel = current and value and current.spell == value.spell and current.rank == value.rank and current.action == value.action
        options[#options + 1] = { label = label, value = value, selected = sel }
    end
    local names = {}
    for name in pairs(KH.Spells.heals) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local heal = KH.Spells.heals[name]
        options[#options + 1] = { header = name }
        Add("Most mana-efficient (follows your real heals)", { spell = name, rank = "best" })
        Add("Highest rank (follows your level)", { spell = name, rank = "max" })
        if heal.maxRank > 1 then Add("Highest -1", { spell = name, rank = "max-1" }) end
        if heal.maxRank > 2 then Add("Highest -2", { spell = name, rank = "max-2" }) end
        for rank = 1, heal.maxRank do
            local info = heal.ranks[rank]
            if info then
                Add(string.format("Rank %d  |cff808080(%s heal, %s mana)|r", rank, info.amount and KH.Round(info.amount) or "?", info.cost or "?"),
                    { spell = name, rank = rank })
            end
        end
    end
    local cleanses = {}
    for name in pairs(KH.Spells.cleanses) do cleanses[#cleanses + 1] = name end
    table.sort(cleanses)
    if #cleanses > 0 then
        options[#options + 1] = { header = "Cleanses" }
        for _, name in ipairs(cleanses) do Add(name, { spell = name }) end
    end
    local others = {}
    for name in pairs(KH.Spells.others) do others[#others + 1] = name end
    table.sort(others)
    if #others > 0 then
        options[#options + 1] = { header = "Other spells" }
        for _, name in ipairs(others) do Add(name, { spell = name }) end
    end
    options[#options + 1] = { header = "Other" }
    Add("Target them", { action = "target" })
    Add("Open their menu", { action = "menu" })
    options[#options + 1] = { label = "|cff808080Nothing|r", value = false }
    UI.ShowMenu(anchorButton, options, function(opt)
        KH.Bindings.Set(key, opt.value or nil)
        Main:Refresh()
    end, 260)
end

local function BuildClicks(panel)
    panel.intro = UI.Text(panel, "GameFontHighlightSmall", true)
    panel.intro:SetPoint("TOPLEFT", 0, 0)
    panel.intro:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    panel.intro:SetText("Clicking a healer frame casts on that person. Put a few ranks of your main heal on different clicks: "
        .. "the frame's border turns the colour of the click that fits how much health they're missing (no border: don't heal yet). "
        .. "|cffffd100Most efficient|r follows your real heals. Changes made in combat take effect when the fight ends.")
    panel.rows = {}
    for i, click in ipairs(KH.Bindings.CLICKS) do
        local y = -56 - (i - 1) * 24
        local swatch = panel:CreateTexture(nil, "ARTWORK")
        swatch:SetSize(10, 10)
        swatch:SetPoint("TOPLEFT", 0, y - 5)
        swatch:SetColorTexture(click.color[1], click.color[2], click.color[3])
        local label = UI.Text(panel, "GameFontNormal")
        label:SetPoint("TOPLEFT", 16, y - 4)
        label:SetWidth(120)
        label:SetText(click.label)
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(330, 20)
        btn:SetPoint("TOPLEFT", 140, y)
        btn:SetScript("OnClick", function(self) KH.Safe(BindingMenu, self, click.key) end)
        local short = UI.Text(panel)
        short:SetPoint("LEFT", btn, "RIGHT", 8, 0)
        short:SetText("|cff808080shown as|r " .. click.short)
        panel.rows[i] = { key = click.key, button = btn }
    end
    local reset = UI.Button(panel, "Reset to defaults", 140, function()
        KH.Bindings.Reset()
        Main:Refresh()
    end, "Go back to the suggested clicks for your class.")
    reset:SetPoint("BOTTOMLEFT", 0, 0)
end

local function RefreshClicks(panel)
    local saved = KH.Bindings.Get()
    for _, row in ipairs(panel.rows) do
        row.button:SetText(KH.Bindings.Describe(saved[row.key]))
    end
end

-- settings tab ------------------------------------------------------------------------------------------

local function BuildSettings(panel)
    local col1, col2 = 0, 320
    local y1, y2 = 0, 0
    local function Check(col, label, tip, get, set)
        local cb = UI.Check(panel, label, tip, get, function(v) set(v); Changed() end)
        if col == 1 then cb:SetPoint("TOPLEFT", col1, y1); y1 = y1 - 26 else cb:SetPoint("TOPLEFT", col2, y2); y2 = y2 - 26 end
        return cb
    end
    local f, a, c = function() return S().frames end, function() return S().advisor end, function() return S().cleanse end

    Check(1, "Show healer frames", nil, function() return f().enabled end, function(v) f().enabled = v end)
    Check(1, "Lock frames in place", "Hide the red drag bar above the frames.", function() return f().locked end, function(v) KH.Frames.SetLocked(v) end)
    Check(1, "Show my frame when solo", "Handy for testing clicks and advice on yourself.", function() return f().showSolo end, function(v) f().showSolo = v end)
    Check(1, "Class coloured health", nil, function() return f().classColors end, function(v) f().classColors = v end)
    Check(1, "Show incoming heals", "A faint green bar after the health: how much the heals being cast on them will bring back, yours and other healers'.",
        function() return f().showIncoming end, function(v) f().showIncoming = v end)
    Check(1, "Spell tooltips: heal and mana per rank", nil, function() return S().tooltips end, function(v) S().tooltips = v end)
    Check(1, "Game: Auto Self Cast", "The game's own option. When on, a heal clicked on someone out of range lands on you instead. Healers usually turn it off.",
        function() return KH.AutoSelfCast() end, function(v) KH.SetAutoSelfCast(v) end)
    Check(1, "Minimap button", nil, function() return not S().minimap.hide end, function(v)
        S().minimap.hide = not v
        UI.MinimapButton:Update()
    end)

    Check(2, "Suggest which heal to click", "Shows the heal that fits each person's missing health, e.g. HW3 over S-L = Shift + Left click.",
        function() return a().enabled end, function(v) a().enabled = v end)
    Check(2, "Count heals already on the way", "Don't suggest a heal when someone else's heal is about to land.",
        function() return a().predicted end, function(v) a().predicted = v end)
    Check(2, "Show debuffs I can remove", "Curses, poisons, diseases or magic your spells can remove, coloured by type.",
        function() return c().enabled end, function(v) c().enabled = v end)
    Check(2, "Show my buffs and heals over time", nil, function() return c().showMine end, function(v) c().showMine = v end)
    Check(2, "Click a dead player to resurrect", "Any heal click on a dead frame casts your resurrection (Ancestral Spirit) instead. Needs Cast by: macro.",
        function() return S().smartRes end, function(v) S().smartRes = v end)

    local steppers = {
        { "Allowed overheal", "A heal can overheal by this much and still be suggested. Higher = bigger heals sooner.",
            function() return a().overheal end, function(d) a().overheal = math.max(0, math.min(0.5, a().overheal + d * 0.05)) end,
            function(v) return KH.Round(v * 100) .. "%" end },
        { "Emergency below", "Below this health, suggest your fast heal (Lesser Healing Wave) instead. 0% turns it off.",
            function() return a().emergency end, function(d) a().emergency = math.max(0, math.min(0.8, a().emergency + d * 0.05)) end,
            function(v) return KH.Round(v * 100) .. "%" end },
    }
    local y = math.min(y1, y2) - 10
    for _, s in ipairs(steppers) do
        local stepper = UI.Stepper(panel, s[1], s[2], s[3], function(d) s[4](d); Changed() end, s[5])
        stepper:SetPoint("TOPLEFT", 0, y)
        y = y - 28
    end

    local reset = UI.Button(panel, "Reset position", 120, function() KH.Frames.ResetPosition() end)
    reset:SetPoint("BOTTOMLEFT", 0, 0)
    local probe = UI.Button(panel, "Game check report", 140, function() KH.RunSlash("probe") end,
        "What the game currently hides from addons. Copy it and send it to the addon author.")
    probe:SetPoint("LEFT", reset, "RIGHT", 8, 0)
    local castBy = UI.Button(panel, "", 160, function()
        local order = { macro = "name", name = "id", id = "macro" }
        S().castBy = order[S().castBy] or "macro"
        Changed()
        Main:Refresh()
    end, "How clicks cast. Macro (best) casts on the person and cancels if it can't land. "
        .. "Try the others only if clicking a frame doesn't cast the right rank. Changes in combat apply after the fight.")
    castBy:SetPoint("LEFT", probe, "RIGHT", 8, 0)
    panel.castBy = castBy
end

local function RefreshSettings(panel)
    local labels = { macro = "macro", name = "name + rank", id = "spell ID" }
    panel.castBy:SetText("Cast by: " .. (labels[S().castBy] or S().castBy))
end

-- layout tab: sizes, bars, text ----------------------------------------------------------------------------

-- a button that steps through choices: "Health text: Percent"
local function Cycle(panel, label, tooltip, choices, get, set)
    local btn
    btn = UI.Button(panel, "", 260, function()
        local current = get()
        for i, c in ipairs(choices) do
            if c[1] == current then
                set(choices[i % #choices + 1][1])
                break
            end
        end
        Changed()
        btn:Refresh()
    end, tooltip)
    function btn:Refresh()
        local text = get()
        for _, c in ipairs(choices) do if c[1] == get() then text = c[2] end end
        self:SetText(label .. ": " .. text)
    end
    btn:SetScript("OnShow", function(self) self:Refresh() end)
    btn:Refresh()
    return btn
end

local LAYOUT_DEFAULTS = { "width", "height", "scale", "spacingX", "spacingY", "groupsAs", "powerHeight", "showPower",
    "healthText", "powerText", "nameSize", "textSize" }

local function BuildLayout(panel)
    local f = function() return S().frames end
    panel.intro = UI.Text(panel, "GameFontHighlightSmall", true)
    panel.intro:SetPoint("TOPLEFT", 0, 0)
    panel.intro:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    panel.intro:SetText("How the healer frames look. For quick resizing, use |cffffd100Edit mode|r (or |cffffd100/khh edit|r): "
        .. "drag the edges and corners of the frames with the mouse. Changes made in combat apply when the fight ends.")

    local function Num(key, step, lo, hi, fmt)
        return function() return f()[key] end, function(d) f()[key] = math.max(lo, math.min(hi, f()[key] + d * step)) end, fmt or tostring
    end
    local steppers = {
        { "Frame width", nil, Num("width", 4, 50, 300) },
        { "Frame height", nil, Num("height", 2, 20, 120) },
        { "Scale", "Makes everything bigger or smaller, text included.", Num("scale", 0.05, 0.5, 2,
            function(v) return string.format("%.2f", v) end) },
        { "Gap between frames (across)", nil, Num("spacingX", 1, 0, 30) },
        { "Gap between frames (down)", nil, Num("spacingY", 1, 0, 30) },
        { "Power bar height", "The mana, rage or energy bar under the health. 0 hides it.", Num("powerHeight", 1, 0, 30) },
        { "Name text size", nil, Num("nameSize", 1, 6, 24) },
        { "Number text size", "The health and power numbers.", Num("textSize", 1, 6, 24) },
    }
    local y = -40
    for _, s in ipairs(steppers) do
        local get, step, fmt = s[3], s[4], s[5]
        local stepper = UI.Stepper(panel, s[1], s[2], get, function(d) step(d); Changed() end, fmt)
        stepper:SetPoint("TOPLEFT", 0, y)
        y = y - 28
    end

    local cycles = {
        Cycle(panel, "Health text", "The number under each name.",
            { { "missing", "Missing (-160)" }, { "percent", "Percent (77%)" }, { "current", "Current (540)" },
              { "both", "Current + percent" }, { "none", "None" } },
            function() return f().healthText end, function(v) f().healthText = v end),
        Cycle(panel, "Power bar", "Mana, rage and energy bars, or only mana (the one healers watch).",
            { { "all", "Everyone" }, { "mana", "Mana users only" }, { "none", "Off" } },
            function() return f().showPower end, function(v) f().showPower = v end),
        Cycle(panel, "Power text", "Mana, rage or energy as a number, under the health number.",
            { { "none", "None" }, { "current", "Current" }, { "percent", "Percent" }, { "both", "Current + percent" } },
            function() return f().powerText end, function(v) f().powerText = v end),
        Cycle(panel, "Groups", "In a raid each group gets its own column (members going down) or row (members going across).",
            { { "columns", "Columns" }, { "rows", "Rows" } },
            function() return f().groupsAs end, function(v) f().groupsAs = v end),
    }
    local cy = -40
    for _, c in ipairs(cycles) do
        c:SetPoint("TOPLEFT", 340, cy)
        cy = cy - 28
    end
    panel.cycles = cycles

    local editBtn = UI.Button(panel, "Edit mode (drag to resize)", 200, function() UI.Edit.Toggle() end,
        "Shows a box over the frames: drag its edges or corners to resize, the middle to move. Out of combat only.")
    editBtn:SetPoint("TOPLEFT", 340, cy - 12)
    local resetLayout = UI.Button(panel, "Reset layout", 120, function()
        local d = KH.DB.Defaults().frames
        for _, key in ipairs(LAYOUT_DEFAULTS) do f()[key] = d[key] end
        Changed()
        Main:Refresh()
    end, "Sizes, bars and text back to how they started (the position stays).")
    resetLayout:SetPoint("BOTTOMLEFT", 0, 0)
    local resetPos = UI.Button(panel, "Reset position", 120, function() KH.Frames.ResetPosition() end)
    resetPos:SetPoint("LEFT", resetLayout, "RIGHT", 8, 0)
end

local function RefreshLayout(panel)
    for _, c in ipairs(panel.cycles) do c:Refresh() end
end

-- window ------------------------------------------------------------------------------------------------

local BUILDERS = { SPELLS = BuildSpells, CLICKS = BuildClicks, LAYOUT = BuildLayout, SETTINGS = BuildSettings }
local REFRESHERS = { SPELLS = RefreshSpells, CLICKS = RefreshClicks, LAYOUT = RefreshLayout, SETTINGS = RefreshSettings }

local function Build()
    frame = UI.CreateWindow("KorkronHealHelperMain", WIDTH, HEIGHT, KH.TITLE .. " |cff808080" .. KH.version .. "|r")
    for i, tab in ipairs(TABS) do
        local btn = UI.Button(frame, tab.label, 100, function() Main:Show(tab.key) end)
        btn:SetPoint("TOPLEFT", 14 + (i - 1) * 104, -30)
        tabButtons[tab.key] = btn
        local panel = CreateFrame("Frame", nil, frame)
        panel:SetPoint("TOPLEFT", 16, -62)
        panel:SetPoint("BOTTOMRIGHT", -16, 14)
        panel:Hide()
        BUILDERS[tab.key](panel)
        panels[tab.key] = panel
    end
end

function Main:Refresh()
    if not frame or not frame:IsShown() then return end
    local key = S().tab
    if REFRESHERS[key] then REFRESHERS[key](panels[key]) end
end

function Main:Show(tab)
    if not frame then Build() end
    tab = tab or S().tab
    if not panels[tab] then tab = "SPELLS" end
    S().tab = tab
    for key, panel in pairs(panels) do
        panel:SetShown(key == tab)
        if tabButtons[key].SetEnabled then tabButtons[key]:SetEnabled(key ~= tab) end
    end
    frame:Show()
    Main:Refresh()
end

function Main:Toggle()
    if frame and frame:IsShown() then frame:Hide() else Main:Show() end
end

KH:On("SPELLS_UPDATED", function() Main:Refresh() end)
KH:On("BINDINGS_UPDATED", function() Main:Refresh() end)
