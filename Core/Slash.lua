-- Kor'kron Heal Helper: /khh commands.
local _, KH = ...

local HELP = {
    "/khh - open the window (spells, clicks, settings)",
    "/khh clicks - set up click-casting",
    "/khh measured clear - forget the heal sizes learned from your casts",
    "/khh lock | unlock - lock or move the healer frames",
    "/khh edit - edit mode: drag the frames' edges and corners to resize them",
    "/khh layout - bar sizes, text, spacing",
    "/khh frames - show or hide the healer frames",
    "/khh reset - put the frames back in their starting spot",
    "/khh selfcast on | off - the game's Auto Self Cast (off = out-of-range heals don't land on you)",
    "/khh probe - report what the game hides from addons right now (copy it for the addon author)",
    "/khh errors - show problems the addon ran into; /khh errors clear",
    "/khh minimap - show or hide the minimap button",
    "/khh debug - extra chat output for testing",
}

local function Run(input)
    local cmd, rest = string.match(strtrim(input or ""), "^(%S*)%s*(.-)$")
    cmd = string.lower(cmd or "")
    local UI, settings = KH.UI, KH.db.settings

    if cmd == "" or cmd == "show" then
        UI.Main:Toggle()
    elseif cmd == "help" or cmd == "?" then
        for _, line in ipairs(HELP) do KH:Print(line) end
    elseif cmd == "spells" then
        UI.Main:Show("SPELLS")
    elseif cmd == "clicks" or cmd == "bind" or cmd == "bindings" then
        UI.Main:Show("CLICKS")
    elseif cmd == "measured" then
        if rest == "clear" then
            KH.Measure.Clear()
            KH:Print("Learned heal sizes forgotten.")
        else
            KH:Print("Heal sizes are learned from your casts (see the Spells tab). /khh measured clear forgets them.")
        end
    elseif cmd == "edit" then
        UI.Edit.Toggle()
    elseif cmd == "layout" then
        UI.Main:Show("LAYOUT")
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        UI.Main:Show("SETTINGS")
    elseif cmd == "lock" or cmd == "unlock" then
        KH.Frames.SetLocked(cmd == "lock")
        KH:Print("Healer frames %s.", cmd == "lock" and "locked" or "unlocked: drag the red bar to move them")
    elseif cmd == "frames" then
        settings.frames.enabled = not settings.frames.enabled
        KH:Fire("SETTINGS_UPDATED")
        KH:Print("Healer frames %s%s.", settings.frames.enabled and "on" or "off",
            InCombatLockdown() and " (after this fight)" or "")
    elseif cmd == "reset" then
        KH.Frames.ResetPosition()
        KH:Print("Healer frames moved back to their starting spot.")
    elseif cmd == "probe" then
        KH.Probe.Snapshot(InCombatLockdown() and "combat" or "calm")
        UI.ShowCopyBox("Game check report (Ctrl+C to copy)", KH.Probe.Report())
    elseif cmd == "selfcast" then
        if rest == "on" or rest == "off" then KH.SetAutoSelfCast(rest == "on") end
        KH:Print("Auto Self Cast is %s.", KH.AutoSelfCast() and "on: out-of-range heals land on you"
            or "off: a heal on someone out of range does nothing")
    elseif cmd == "minimap" then
        settings.minimap.hide = not settings.minimap.hide
        UI.MinimapButton:Update()
    elseif cmd == "debug" then
        settings.debug = not settings.debug
        KH:Print("Debug %s.", settings.debug and "on" or "off")
    elseif cmd == "errors" then
        if rest == "clear" then
            wipe(KH.errors)
            KH:Print("Errors cleared.")
        elseif #KH.errors == 0 then
            KH:Print("No errors this session.")
        else
            local lines = {}
            for i, e in ipairs(KH.errors) do
                lines[#lines + 1] = string.format("%d. (x%d) %s", i, e.count, e.message)
            end
            UI.ShowCopyBox("Errors this session (Ctrl+C to copy)", table.concat(lines, "\n\n"))
        end
    elseif cmd == "version" then
        KH:Print("Version %s.", KH.version)
    else
        KH:Print("Unknown command. Type /khh help.")
    end
end

SLASH_KORKRONHEALHELPER1 = "/khh"
SLASH_KORKRONHEALHELPER2 = "/kheal"
SlashCmdList.KORKRONHEALHELPER = function(input) KH.Safe(Run, input) end
KH.RunSlash = Run

function KorkronHealHelper_OnAddonCompartmentClick()
    KH.UI.Main:Toggle()
end
