-- Kor'kron Heal Helper: heal size and mana efficiency on spell tooltips (spellbook, action bars).
local _, KH = ...

local Tooltip = {}
KH.Tooltip = Tooltip

-- the extra tooltip lines for a spell ID: { { text, r, g, b }, ... }
function Tooltip.Lines(spellID)
    local info = KH.Spells.byID[spellID]
    if not info or not info.amount then return nil end
    local lines = {}
    local source = info.source == "seen" and string.format(" (your last %d casts)", info.seen.n) or ""
    lines[#lines + 1] = { string.format("Heals about %d%s", KH.Round(info.amount), source), 0.4, 1, 0.4 }
    if info.hpm then
        lines[#lines + 1] = { string.format("%.2f healing per mana, %d per second", info.hpm, KH.Round(info.hps or 0)), 0.4, 1, 0.4 }
    end
    local entry = KH.Spells.heals[info.name]
    if entry and info.best then
        lines[#lines + 1] = { "Your most mana-efficient " .. info.name, 1, 0.82, 0 }
    elseif entry then
        for _, other in pairs(entry.ranks) do
            if other.best then
                lines[#lines + 1] = { string.format("Rank %d heals more per mana (%.2f)", other.rank, other.hpm), 0.7, 0.7, 0.7 }
            end
        end
    end
    return lines
end

local function OnSpellTooltip(tooltip, data)
    if not (KH.db and KH.db.settings.tooltips) then return end
    local id = data and KH.Num(data.id)
    local lines = id and Tooltip.Lines(id)
    if not lines then return end
    tooltip:AddLine(" ")
    for _, l in ipairs(lines) do tooltip:AddLine(l[1], l[2], l[3], l[4]) end
end

function Tooltip:Init()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
            KH.Safe(OnSpellTooltip, tooltip, data)
        end)
    end
end
