-- Kor'kron Heal Helper: startup.
local ADDON_NAME, KH = ...

KH:RegisterEvent("ADDON_LOADED", function(name)
    if name ~= ADDON_NAME then return end
    KH.DB:Init()
    KH.Tooltip:Init()
end)

KH:RegisterEvent("PLAYER_LOGIN", function()
    KH.Spells.Scan()
    KH.Bindings.Get()
    KH.Frames:Init()
    KH.UI.MinimapButton:Update()
    KH:After(8, function()
        if KH.char.relaidOut then
            KH.char.relaidOut = nil
            KH:Print("your clicks were set to the new layout: Left = most efficient rank, Shift + Left = biggest, "
                .. "Ctrl + Left = rank 1, Right = fast heal. The frame's border colour shows which click fits. See /khh clicks.")
        end
        if KH.db.settings.selfCastWarning and KH.AutoSelfCast() then
            KH:Print("the game's |cffffd100Auto Self Cast|r is on: a heal clicked on someone out of range lands on you instead. "
                .. "Type |cffffd100/khh selfcast off|r to turn it off (or untick it in /khh Settings).")
        end
    end)
end)

-- spell data (tooltip numbers) can arrive a little after login
KH:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    KH:After(2, KH.Spells.Scan)
end)
