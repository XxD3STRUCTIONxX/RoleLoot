-- RoleLoot: Need / Greed / Pass advice on item tooltips and loot rolls,
-- for your class, spec, role and race, and a list of the best dungeon, raid
-- and quest items. /rl opens the setup window, /rl bis the list.
local _, ns = ...

---------------------------------------------------------------- data

-- Specs per class, in talent-tab order, with the fighting style each one
-- levels with and its role in dungeons (nil: damage).
local SPECS = {
    WARRIOR = { { "Arms", "melee2h" }, { "Fury", "melee1h" }, { "Protection", "melee1h", "tank" } },
    PALADIN = { { "Holy", "melee2h", "healer" }, { "Protection", "melee1h", "tank" }, { "Retribution", "melee2h" } },
    HUNTER  = { { "Beast Mastery", "ranged" }, { "Marksmanship", "ranged" }, { "Survival", "ranged" } },
    ROGUE   = { { "Assassination", "melee1h" }, { "Combat", "melee1h" }, { "Subtlety", "melee1h" } },
    PRIEST  = { { "Discipline", "caster", "healer" }, { "Holy", "caster", "healer" }, { "Shadow", "caster" } },
    SHAMAN  = { { "Elemental", "caster" }, { "Enhancement", "melee2h" }, { "Restoration", "caster", "healer" } },
    MAGE    = { { "Arcane", "caster" }, { "Fire", "caster" }, { "Frost", "caster" } },
    WARLOCK = { { "Affliction", "caster" }, { "Demonology", "caster" }, { "Destruction", "caster" } },
    DRUID   = { { "Balance", "caster" }, { "Feral", "melee2h" }, { "Restoration", "caster", "healer" } },
}
-- Roles gear is scored for (BASE below). Your fighting style is one of the
-- damage ones; the dungeon role can make it tank or healer.
local ROLES = { "melee", "ranged", "tank", "caster", "healer" }
local ROLE_LABEL = { melee = "Melee", ranged = "Ranged", tank = "Tank", caster = "Caster", healer = "Healer", dps = "DPS" }
-- Fighting styles: how you deal damage, questing and in dungeons as DPS.
local STYLES = { "melee2h", "melee1h", "rangedbow", "ranged", "caster" }
local STYLE_LABEL = { melee2h = "2H melee", melee1h = "1H melee", rangedbow = "Bow", ranged = "Any ranged", caster = "Caster" }
local STYLE_ROLE = { melee2h = "melee", melee1h = "melee", rangedbow = "ranged", ranged = "ranged", caster = "caster" }
local DUNGEON_ROLES = { "dps", "tank", "healer" } -- (dps: saved as nil, your style)

-- A role's or style's icon: texture and tex coords. Tank, DPS and Healer use
-- the game's group-finder role icons when it has them.
local LFG_ROLE = { tank = "TANK", healer = "HEALER", dps = "DAMAGER" }
local ROLE_ICON = { melee2h = "INV_Axe_04", melee1h = "Ability_DualWield", rangedbow = "INV_Weapon_Bow_07",
                    ranged = "INV_Weapon_Rifle_01", caster = "Spell_Fire_FireBolt02",
                    tank = "INV_Shield_06", healer = "Spell_Holy_HolyBolt", dps = "INV_Sword_04" }
local function RoleIcon(role)
    if LFG_ROLE[role] and GetTexCoordsForRole then
        return "Interface\\LFGFrame\\UI-LFG-ICON-ROLES", { GetTexCoordsForRole(LFG_ROLE[role]) }
    end
    return "Interface\\Icons\\" .. ROLE_ICON[role], { 0.08, 0.92, 0.08, 0.92 }
end

-- Stat weights per role, in points per 1 of the stat. Rough leveling values:
-- a weight of 1 or more marks a stat the role is built on (see Fit).
-- Keys are GetItemStats' without "ITEM_MOD_" and "_SHORT"; ARMOR and DPS are special.
local BASE = {
    -- PROC: per "Chance on hit:" effect (see ItemStats), worth about 6 Strength.
    melee = { STRENGTH = 2, AGILITY = 1.5, ATTACK_POWER = 1, HIT_RATING = 1.5, CRIT_RATING = 1.2,
              HASTE_RATING = 0.8, STAMINA = 0.3, ARMOR = 0.01, DPS = 8, PROC = 12 },
    ranged = { AGILITY = 2, RANGED_ATTACK_POWER = 1, ATTACK_POWER = 1, HIT_RATING = 1.5, CRIT_RATING = 1.2,
               INTELLECT = 0.3, STAMINA = 0.3, ARMOR = 0.01, DPS = 8, PROC = 8 },
    tank = { STAMINA = 1.5, DEFENSE_SKILL_RATING = 1.5, DODGE_RATING = 1.2, PARRY_RATING = 1.1,
             BLOCK_RATING = 0.8, BLOCK_VALUE = 0.3, STRENGTH = 1, AGILITY = 1, ATTACK_POWER = 0.4,
             HIT_RATING = 0.8, ARMOR = 0.05, DPS = 3, PROC = 8 },
    caster = { SPELL_POWER = 1, SPELL_DAMAGE_DONE = 1, INTELLECT = 1, SPIRIT = 0.3, HIT_RATING = 1.2,
               CRIT_RATING = 1, MANA_REGENERATION = 1, POWER_REGEN0 = 1, STAMINA = 0.3,
               ARCANE_DAMAGE_DONE = 0.7, FIRE_DAMAGE_DONE = 0.7, FROST_DAMAGE_DONE = 0.7,
               HOLY_DAMAGE_DONE = 0.7, NATURE_DAMAGE_DONE = 0.7, SHADOW_DAMAGE_DONE = 0.7 },
    healer = { SPELL_POWER = 1, SPELL_HEALING_DONE = 1, INTELLECT = 1, SPIRIT = 0.7,
               MANA_REGENERATION = 2, POWER_REGEN0 = 2, CRIT_RATING = 0.8, STAMINA = 0.2 },
}
-- Class changes to a role's weights.
local CLASS_TWEAKS = {
    ROGUE = { melee = { AGILITY = 2, STRENGTH = 1 } },
    DRUID = { melee = { AGILITY = 2, FERAL_ATTACK_POWER = 1 }, tank = { FERAL_ATTACK_POWER = 0.4 } },
    HUNTER = { melee = { AGILITY = 2, STRENGTH = 0.5 } },
    -- Paladins and shamans fight with mana and spells too: some worth, below 1
    -- so it never makes an item theirs (a Ret paladin still passes healer gear).
    PALADIN = { melee = { INTELLECT = 0.4, SPELL_POWER = 0.4, SPELL_DAMAGE_DONE = 0.4, HOLY_DAMAGE_DONE = 0.3,
                          MANA_REGENERATION = 0.6, POWER_REGEN0 = 0.6 },
                tank = { INTELLECT = 0.3, SPELL_POWER = 0.4, SPELL_DAMAGE_DONE = 0.4, HOLY_DAMAGE_DONE = 0.3,
                         MANA_REGENERATION = 0.5, POWER_REGEN0 = 0.5 } },
    SHAMAN = { melee = { INTELLECT = 0.3, SPELL_POWER = 0.3, SPELL_DAMAGE_DONE = 0.3, NATURE_DAMAGE_DONE = 0.2,
                         MANA_REGENERATION = 0.5, POWER_REGEN0 = 0.5 } },
}
local DPS_KEY = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
-- Stats every role likes a little; never a sign that an item belongs to another role.
local SHARED = { ITEM_MOD_STAMINA_SHORT = true, RESISTANCE0_NAME = true, [DPS_KEY] = true }

local function GameKey(k)
    if k == "ARMOR" then return "RESISTANCE0_NAME" end
    if k == "DPS" then return DPS_KEY end
    return "ITEM_MOD_" .. k .. "_SHORT"
end

local weightCache = {}
local function Weights(role, class)
    local key = role .. ":" .. class
    if not weightCache[key] then
        local w = {}
        for k, v in pairs(BASE[role]) do w[GameKey(k)] = v end
        for k, v in pairs(CLASS_TWEAKS[class] and CLASS_TWEAKS[class][role] or {}) do w[GameKey(k)] = v end
        weightCache[key] = w
    end
    return weightCache[key]
end

-- Armor (item class 4) subclasses: 1 cloth, 2 leather, 3 mail, 4 plate, 6 shield,
-- 7 libram, 8 idol, 9 totem. Best armor per class: { before level 40, from 40 }.
local BEST_ARMOR = {
    WARRIOR = { 3, 4 }, PALADIN = { 3, 4 }, HUNTER = { 2, 3 }, SHAMAN = { 2, 3 },
    ROGUE = { 2, 2 }, DRUID = { 2, 2 }, PRIEST = { 1, 1 }, MAGE = { 1, 1 }, WARLOCK = { 1, 1 },
}
local OTHER_ARMOR = { -- shields and relics
    WARRIOR = { [6] = true }, PALADIN = { [6] = true, [7] = true }, SHAMAN = { [6] = true, [9] = true },
    DRUID = { [8] = true },
}
-- Weapon (item class 2) subclasses each class can learn: 0 1H axe, 1 2H axe, 2 bow,
-- 3 gun, 4 1H mace, 5 2H mace, 6 polearm, 7 1H sword, 8 2H sword, 10 staff,
-- 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
local function Set(...)
    local t = {}
    for _, v in ipairs({ ... }) do t[v] = true end
    return t
end
local WEAPONS = {
    WARRIOR = Set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
    PALADIN = Set(0, 1, 4, 5, 6, 7, 8),
    HUNTER  = Set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18),
    ROGUE   = Set(2, 3, 4, 7, 13, 15, 16, 18),
    PRIEST  = Set(4, 10, 15, 19),
    SHAMAN  = Set(0, 1, 4, 5, 10, 13, 15),
    MAGE    = Set(7, 10, 15, 19),
    WARLOCK = Set(7, 10, 15, 19),
    DRUID   = Set(4, 5, 10, 13, 15),
}
local TWO_HAND_SUBCLASS = Set(1, 5, 6, 8, 10)
-- Racial weapon skill bonuses (race file -> weapon subclasses).
local RACIAL_WEAPONS = { Human = Set(4, 5, 7, 8), Orc = Set(0, 1), Dwarf = Set(3), Troll = Set(2, 16) }
local RACIAL_BONUS = 1.05

-- Equip location -> the slots it competes with.
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_SHIELD = { 17 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
    INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
local RANGED_LOC = Set("INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN")

---------------------------------------------------------------- scoring

-- How much `role` (of class `class`) gets from `stats` (GetItemStats) on an
-- item worn at `equipLoc`; `wand` when it is a wand.
local function Score(stats, equipLoc, wand, role, class)
    local w, score = Weights(role, class), 0
    for k, v in pairs(stats) do
        local wk = w[k] or 0
        if k == DPS_KEY then
            if wand then
                wk = (role == "caster" or role == "healer") and 2 or 0
            elseif (RANGED_LOC[equipLoc] or false) ~= (role == "ranged") then
                wk = wk * 0.1 -- a melee's ranged weapon, a hunter's melee weapon
            end
        end
        score = score + v * wk
    end
    return score
end

-- Score, and the other role the item is made for when it has none of your
-- role's main stats but another role's (a healing mace for a Retribution paladin).
local function Fit(stats, equipLoc, wand, role, class)
    local function Core(r)
        local w = Weights(r, class)
        for k in pairs(stats) do
            if not SHARED[k] and (w[k] or 0) >= 1 then return true end
        end
    end
    local score = Score(stats, equipLoc, wand, role, class)
    if Core(role) then return score end
    local off, best = nil, 0
    for _, r in ipairs(ROLES) do
        local s = r ~= role and Core(r) and Score(stats, equipLoc, wand, r, class) or 0
        if s > best then off, best = r, s end
    end
    return score, off
end

local GetItemStats = (C_Item and C_Item.GetItemStats) or GetItemStats
local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

-- An item's tooltip lines (text): the game's tooltip data, else a hidden tooltip.
local scanner
local function TooltipLines(link)
    local lines = {}
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local data = C_TooltipInfo.GetHyperlink(link)
        for _, line in ipairs(data and data.lines or {}) do lines[#lines + 1] = line.leftText end
        return lines
    end
    scanner = scanner or CreateFrame("GameTooltip", "RoleLootScanTip", nil, "GameTooltipTemplate")
    scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanner:ClearLines()
    scanner:SetHyperlink(link)
    for i = 1, scanner:NumLines() do
        local text = _G["RoleLootScanTipTextLeft" .. i]
        lines[#lines + 1] = text and text:GetText()
    end
    return lines
end

-- GetItemStats plus ITEM_MOD_PROC_SHORT: its "Chance on hit:" effects, which
-- the game's stats leave out (a weapon's fire blast, a stun).
-- shortcut: every proc is worth the same, whatever it does; weigh them per item if that misleads.
local statCache = {}
local function GetStats(link)
    if statCache[link] then return statCache[link] end
    local stats = GetItemStats(link)
    if not stats then return end -- (not loaded yet: ask again later)
    local copy, procs = {}, 0
    for k, v in pairs(stats) do copy[k] = v end
    for _, text in ipairs(TooltipLines(link)) do
        if text and text:find("^Chance on hit:") then procs = procs + 1 end
    end
    copy.ITEM_MOD_PROC_SHORT = procs > 0 and procs or nil
    statCache[link] = copy
    return copy
end

local function LinkScore(link, role, class)
    local stats = link and GetStats(link)
    if not stats then return 0 end
    local _, _, _, equipLoc, _, classID, subclassID = GetInstant(link)
    return Score(stats, equipLoc, classID == 2 and subclassID == 19, role, class)
end

---------------------------------------------------------------- verdict

local db -- RoleLootDB: { spec = index, role = a fighting style, dungeonRole = "tank"/"healer" (nil: damage), ... }
local player = {}

local function SpecName()
    return db.spec and SPECS[player.class][db.spec][1] or "?"
end

-- The role gear is judged for: your fighting style's (melee, ranged or
-- caster), or tank or healer inside a dungeon or raid when that is your
-- dungeon role (a Ret paladin who tanks them).
local function ActiveRole()
    local _, kind = IsInInstance()
    return (kind == "party" or kind == "raid") and db.dungeonRole or STYLE_ROLE[db.role]
end

-- Whether `class` can wear an item at `level` (and why not), and whether it is
-- a lower armor type than the class's best then (a Ret paladin's leather).
local function CanUse(class, equipLoc, classID, subclassID, level)
    local bestArmor = BEST_ARMOR[class][level >= 40 and 2 or 1]
    local isArmor = classID == 4 and equipLoc ~= "INVTYPE_CLOAK" and subclassID ~= 0
    if classID == 2 and not WEAPONS[class][subclassID] then return false, "Your class can't use this weapon" end
    if isArmor and subclassID >= 6 then
        if not (OTHER_ARMOR[class] and OTHER_ARMOR[class][subclassID]) then return false, "Your class can't use this" end
    elseif isArmor and subclassID > bestArmor then
        return false, "Your class can't wear this armor"
    end
    return true, nil, isArmor and subclassID <= 4 and subclassID < bestArmor
end

-- Better than what you wear, by enough to matter: 1% and 1 point (half a
-- Strength), so 3 more armor alone is no upgrade. Any use for an empty slot is.
local function IsUpgrade(score, worn)
    return worn <= 0 and score > 0 or (score > worn * 1.01 and score - worn >= 1)
end

-- "NEED" / "GREED" / "PASS" and why, for item `link`; nil when it isn't gear
-- or the game hasn't loaded its stats yet. When the item suits your spec and
-- role, also its score and that of what you wear in its slot. `atLevel`: the
-- level you'd wear it at (the BiS list's items ahead of you), for armor types.
local function Verdict(link, atLevel)
    if not (db and db.role and link) then return end
    local _, _, _, equipLoc, _, classID, subclassID = GetInstant(link)
    if not SLOTS[equipLoc] then return end
    local stats = GetStats(link)
    if not stats then return end
    local class, role = player.class, ActiveRole()
    local usable, why, lowArmor = CanUse(class, equipLoc, classID, subclassID, math.max(UnitLevel("player"), atLevel or 0))
    if not usable then return "PASS", why end

    local score, off = Fit(stats, equipLoc, classID == 2 and subclassID == 19, role, class)
    if off then return "PASS", ROLE_LABEL[off] .. " gear, you play " .. ROLE_LABEL[role] end
    -- Weapons that don't fit your style (as damage dealer; tanks and healers take any).
    local melee = classID == 2 and not RANGED_LOC[equipLoc] and subclassID ~= 19
    if role == "melee" and db.role == "melee2h"
        and (equipLoc == "INVTYPE_SHIELD" or (melee and not TWO_HAND_SUBCLASS[subclassID])) then
        return "GREED", "You fight with a two-hander"
    end
    if role == "melee" and db.role == "melee1h" and melee and TWO_HAND_SUBCLASS[subclassID] then
        return "GREED", "You fight one-handed"
    end
    if role == "ranged" and db.role == "rangedbow" and classID == 2 and RANGED_LOC[equipLoc] and subclassID ~= 2 then
        return "GREED", "You use a bow"
    end
    if score <= 0 then return "GREED", "Nothing useful for " .. ROLE_LABEL[role] end

    local racial = classID == 2 and RACIAL_WEAPONS[player.race] and RACIAL_WEAPONS[player.race][subclassID]
    if racial then score = score * RACIAL_BONUS end

    -- Compare with what you wear there: the weaker ring/trinket, both hands for a two-hander.
    local worn
    for _, slot in ipairs(SLOTS[equipLoc]) do
        local s = LinkScore(GetInventoryItemLink("player", slot), role, class)
        worn = worn and math.min(worn, s) or s
    end
    if equipLoc == "INVTYPE_2HWEAPON" then worn = worn + LinkScore(GetInventoryItemLink("player", 17), role, class) end
    -- (scored still, so the BiS list can show it as a lower-armor upgrade)
    if lowArmor then return "GREED", "Not your best armor type", score, worn end
    if IsUpgrade(score, worn) then
        local gain = worn > 0 and string.format("Upgrade +%d%%", math.floor((score / worn - 1) * 100)) or "Upgrade (slot empty)"
        return "NEED", gain .. (racial and ", racial weapon" or ""), score, worn
    end
    return "GREED", "Not an upgrade", score, worn
end

local COLOR = { NEED = "|cff20ff20", GREED = "|cffffd200", PASS = "|cffff4040" }
local function VerdictText(link)
    local verdict, reason = Verdict(link)
    if verdict then
        return COLOR[verdict] .. verdict .. "|r |cffaaaaaa" .. reason .. " (" .. SpecName() .. ", "
            .. ROLE_LABEL[ActiveRole()] .. ")|r", verdict
    end
end

---------------------------------------------------------------- settings window

local frame
local BuildList, OpenBis, BuildSearch, RefreshMarks -- (the BiS and search windows and highlights, below)
local function Refresh()
    if frame then
        for i, b in ipairs(frame.specButtons) do
            if db.spec == i then b:LockHighlight() else b:UnlockHighlight() end
        end
        for _, b in ipairs(frame.roleButtons) do
            if db.role == b.role then b:LockHighlight() else b:UnlockHighlight() end
        end
        for _, b in ipairs(frame.dungeonButtons) do
            if db.dungeonRole == b.role then b:LockHighlight() else b:UnlockHighlight() end
        end
    end
    BuildList()
    BuildSearch()
    RefreshMarks()
end

-- A button at x, y of `parent`; `onClick` gets the mouse button; `role`: a role icon before its text.
local function Button(parent, text, width, x, y, onClick, role)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(_, mouse) onClick(mouse) Refresh() end)
    if role then
        local texture, coords = RoleIcon(role)
        local icon = b:CreateTexture(nil, "OVERLAY")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", 6, 0)
        icon:SetTexture(texture)
        icon:SetTexCoord(unpack(coords))
        local label = b:GetFontString()
        if label then
            label:ClearAllPoints()
            label:SetPoint("LEFT", icon, "RIGHT", 3, 0)
            label:SetPoint("RIGHT", -6, 0) -- (cut off, never past the button)
        end
    end
    return b
end

local windows = {} -- every RoleLoot window, for Toggle

-- A movable window with a title and close button; Escape closes it.
local function NewWindow(name, title, width, height)
    local ok, f = pcall(CreateFrame, "Frame", name, UIParent, "BasicFrameTemplateWithInset")
    if not ok then -- (a client without that template: a plain dark box)
        f = CreateFrame("Frame", name, UIParent)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.85)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT")
    end
    f:SetSize(width, height)
    f:Hide() -- (Toggle shows it)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, name)
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOP", 0, -6)
    text:SetText(title)
    windows[#windows + 1] = f
    return f
end

-- Shows or hides window `f`; shown, it opens beside another open RoleLoot
-- window instead of on top of it (settings next to the BiS list).
local function Toggle(f)
    if f:IsShown() then f:Hide() return end
    local other
    for _, w in ipairs(windows) do
        if w ~= f and w:IsShown() then other = w end
    end
    f:ClearAllPoints()
    -- (a screen position, not anchored to `other`: two windows anchored to
    -- each other is an error the game refuses)
    if other and other:GetRight() then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", other:GetRight() + 4, other:GetTop())
    else
        f:SetPoint("CENTER")
    end
    f:Show()
end

-- Bug / feedback: addons can't open a browser, so this window shows the
-- GitHub link and your setup as text to copy (Ctrl+C) into the report.
local ISSUES_URL = "https://github.com/XxD3STRUCTIONxX/RoleLoot/issues/new/choose"
local bug
local function SetupText()
    local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version = meta and meta("RoleLoot", "Version") or "?"
    local client, build = GetBuildInfo()
    return string.format("RoleLoot %s, client %s (%s), %s %s level %d, %s, role %s, dungeons %s",
        version, client or "?", build or "?", player.raceName, player.className, UnitLevel("player"), SpecName(),
        STYLE_LABEL[db.role] or "none", ROLE_LABEL[db.dungeonRole or "dps"])
end

-- A read-only text box at y in `f`, holding `text`, selected when clicked.
local function CopyBox(f, y, text)
    local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    box:SetSize(f:GetWidth() - 40, 20)
    box:SetPoint("TOPLEFT", 22, y)
    box:SetAutoFocus(false)
    box.value = text
    box:SetText(text)
    box:SetScript("OnTextChanged", function(b, typed) if typed then b:SetText(b.value) b:HighlightText() end end)
    box:SetScript("OnEditFocusGained", function(b) b:HighlightText() end)
    box:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
    return box
end

local function OpenBug()
    if bug then
        bug.setup.value = SetupText()
        bug.setup:SetText(bug.setup.value)
        Toggle(bug)
        return
    end
    local f = NewWindow("RoleLootBugFrame", "RoleLoot bug / feedback", 480, 190)
    bug = f
    Toggle(f)
    local function Label(y, text)
        local l = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        l:SetPoint("TOPLEFT", 16, y)
        l:SetWidth(f:GetWidth() - 32)
        l:SetJustifyH("LEFT")
        l:SetText(text)
    end
    Label(-32, "1. Click the link, press Ctrl+C, and open it in your browser:")
    f.link = CopyBox(f, -48, ISSUES_URL)
    Label(-82, "2. Pick Bug report or Feedback, and paste your setup (copy it the same way):")
    f.setup = CopyBox(f, -98, SetupText())
    Label(-132, "Screenshots help a lot: the tooltip or window that looks wrong, with what you expected.")
    f.link:SetFocus()
end

local function OpenSettings()
    if frame then Toggle(frame) Refresh() return end
    local f = NewWindow("RoleLootFrame", "RoleLoot", 544, 270) -- (5 style buttons, 100 wide)
    Toggle(f)
    frame = f
    local who = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    who:SetPoint("TOPLEFT", 14, -34)
    who:SetText(player.raceName .. " " .. player.className .. " (race and class from your character)")

    local spec = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spec:SetPoint("TOPLEFT", 14, -60)
    spec:SetText("Talent spec:")
    f.specButtons = {}
    for i, s in ipairs(SPECS[player.class]) do
        f.specButtons[i] = Button(f, s[1], 100, 14 + (i - 1) * 104, -76, function()
            db.spec, db.role, db.dungeonRole = i, s[2], s[3] -- (the spec's own style and dungeon role)
        end)
    end

    local role = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    role:SetPoint("TOPLEFT", 14, -110)
    role:SetText("Fighting style (questing, and dungeons as DPS; off-meta welcome):")
    f.roleButtons = {}
    for i, r in ipairs(STYLES) do
        local b = Button(f, STYLE_LABEL[r], 100, 14 + (i - 1) * 104, -126, function() db.role = r end, r)
        b.role = r
        f.roleButtons[i] = b
    end

    local dungeon = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dungeon:SetPoint("TOPLEFT", 14, -160)
    dungeon:SetText("Role in dungeons and raids:")
    f.dungeonButtons = {}
    for i, r in ipairs(DUNGEON_ROLES) do
        local saved = r ~= "dps" and r or nil
        local b = Button(f, ROLE_LABEL[r], 100, 14 + (i - 1) * 104, -176, function() db.dungeonRole = saved end, r)
        b.role = saved
        f.dungeonButtons[i] = b
    end

    Button(f, "BiS list", 110, 420, -208, function() OpenBis() end)
    Button(f, "Bug / feedback", 110, 420, -236, function() OpenBug() end)
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 14, -214)
    hint:SetWidth(270)
    hint:SetJustifyH("LEFT")
    hint:SetText("Hover gear or roll on loot to see Need / Greed / Pass. /rl search: every item.")
    Refresh()
end

---------------------------------------------------------------- BiS window

-- Slot groups, in the window's order: label, then the equip locations in it.
local GROUPS = {
    { "Head", "INVTYPE_HEAD" }, { "Neck", "INVTYPE_NECK" }, { "Shoulders", "INVTYPE_SHOULDER" },
    { "Back", "INVTYPE_CLOAK" }, { "Chest", "INVTYPE_CHEST", "INVTYPE_ROBE" }, { "Wrists", "INVTYPE_WRIST" },
    { "Hands", "INVTYPE_HAND" }, { "Waist", "INVTYPE_WAIST" }, { "Legs", "INVTYPE_LEGS" },
    { "Feet", "INVTYPE_FEET" }, { "Rings", "INVTYPE_FINGER" }, { "Trinkets", "INVTYPE_TRINKET" },
    { "Main hand", "INVTYPE_2HWEAPON", "INVTYPE_WEAPON", "INVTYPE_WEAPONMAINHAND" },
    { "Off hand", "INVTYPE_SHIELD", "INVTYPE_WEAPONOFFHAND", "INVTYPE_HOLDABLE" },
    { "Ranged / relic", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN", "INVTYPE_RELIC" },
}
local GROUP_OF = {}
for i, group in ipairs(GROUPS) do
    for j = 2, #group do GROUP_OF[group[j]] = i end
end
local PER_GROUP = 3 -- items shown per slot group
local MAX_AHEAD = 20
local ROW_HEIGHT = 20
local SORTS = { { "best", "Best for me" }, { "next", "Next upgrades" } }
local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local bis -- the window
local OpenSearch -- (below)

-- Rebuilds the open list at most twice a second (items arrive in bursts).
local pending
local function BuildSoon()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        BuildList()
        BuildSearch()
        RefreshMarks()
    end)
end

-- Asks the server for the listed gear a window shows: from `minLevel` to
-- `maxLevel` (by its source's level) and wearable by `class` (nil: any).
-- Never everything: the game keeps only so many items and drops others,
-- even the ones you wear, so asking for all 7000 made tooltips flicker
-- ("Retrieving item information") while the drops were asked for again.
-- Cached items cost nothing; the rest go REQUESTS_PER_TICK every 0.1 s,
-- nearest your level first. GET_ITEM_INFO_RECEIVED then refills the lists.
-- Items the server never answers for would show as loading forever: the
-- status stops saying so a while after the last request (loadUntil).
local queue, queued, asked, loadUntil, ticker = {}, {}, {}, 0, nil
local REQUESTS_PER_TICK = 30
local function RequestItems(minLevel, maxLevel, class)
    local level, new = UnitLevel("player"), {}
    for id, src in pairs(ns.SOURCES) do
        -- (level 0: unknown, as for learned items from before 0.8.1; always asked)
        if not queued[id] and (src[3] == 0 or (src[3] >= minLevel and src[3] <= maxLevel)) then
            local _, _, _, equipLoc, _, classID, subclassID = GetInstant(id)
            if GROUP_OF[equipLoc] and (not class or CanUse(class, equipLoc, classID, subclassID, 60)) then
                queued[id] = true
                new[#new + 1] = id
            end
        end
    end
    if not new[1] then return end
    table.sort(new, function(x, y)
        local dx, dy = math.abs(ns.SOURCES[x][3] - level), math.abs(ns.SOURCES[y][3] - level)
        if dx ~= dy then return dx < dy end
        return x < y
    end)
    for _, id in ipairs(new) do queue[#queue + 1] = id end
    local wait = #queue / (REQUESTS_PER_TICK * 10) + 10 -- (when nothing is cached)
    loadUntil = math.max(loadUntil, GetTime() + wait)
    C_Timer.After(wait, function() BuildList() BuildSearch() end)
    if ticker then return end
    local i = 0
    ticker = C_Timer.NewTicker(0.1, function(t)
        local sent = 0
        while sent < REQUESTS_PER_TICK do
            i = i + 1
            local id = queue[i]
            if not id then
                queue, ticker = {}, nil
                return t:Cancel()
            end
            asked[id] = true
            if GetInfo(id) then
                BuildSoon() -- (cached: no GET_ITEM_INFO_RECEIVED comes for it)
            else
                sent = sent + 1
            end
        end
    end)
end
-- The BiS list's items: wearable, from 10 levels below you to db.ahead above.
local function RequestBis()
    local level = UnitLevel("player")
    RequestItems(level - 10, level + db.ahead, player.class)
end

-- Item `id`'s name, link and the level you can use it at, once the game has
-- it. Kept here: the game can forget items again, which made the list flicker.
-- Quest rewards mostly have no required level (the quest has one): their
-- item level, less 5, stands in for it.
local infoCache = {}
local function ItemInfo(id, src)
    local c = infoCache[id]
    if not c and asked[id] then
        local name, link, _, itemLevel, minLevel = GetInfo(id)
        if link then
            local level = math.max(minLevel or 0, src[3])
            if level == 0 and itemLevel then level = math.max(0, math.min(60, itemLevel - 5)) end
            c = { name = name, link = link, level = level }
            infoCache[id] = c
        end
    end
    if c then return c.name, c.link, c.level end
end

-- Per slot group, the listed items for your spec and role up to db.ahead
-- levels above you: by score ("best"), or only upgrades, lowest level first
-- ("next"). Also how many items the game hasn't loaded yet.
local function Pick()
    local maxLevel = UnitLevel("player") + db.ahead
    local groups, loading = {}, 0
    for id, src in pairs(ns.SOURCES) do
        local _, _, _, equipLoc, icon = GetInstant(id)
        local g = GROUP_OF[equipLoc]
        local _, link, level = ItemInfo(id, src)
        if g and not link then
            if asked[id] then loading = loading + 1 end
        elseif g and (not src[4] or src[4] == player.faction) and level <= maxLevel then
            local verdict, reason, score, worn = Verdict(link, level)
            local upgrade = score and IsUpgrade(score, worn)
            if score and (upgrade or (db.sort == "best" and not db.upgradesOnly)) then
                groups[g] = groups[g] or {}
                tinsert(groups[g], { link = link, icon = icon, score = score, worn = worn, upgrade = upgrade,
                                     lowArmor = verdict == "GREED" and reason == "Not your best armor type",
                                     minLevel = level, src = src })
            end
        end
    end
    for _, list in pairs(groups) do
        table.sort(list, function(a, b)
            if db.sort == "next" and a.minLevel ~= b.minLevel then return a.minLevel < b.minLevel end
            if a.score ~= b.score then return a.score > b.score end
            return a.link < b.link
        end)
    end
    return groups, loading
end

-- Row `i` of window `win`'s list: a heading, or an item (hover: its tooltip,
-- shift-click: link it in chat).
local function Row(win, i)
    if win.rows[i] then return win.rows[i] end
    local row = CreateFrame("Button", nil, win.content)
    row:SetSize(bis.content:GetWidth(), ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 4, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 24, 0)
    row.name:SetWidth(210)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.info = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.info:SetPoint("RIGHT", -4, 0)
    row.info:SetWidth(row:GetWidth() - 240)
    row.info:SetJustifyH("RIGHT")
    row.info:SetWordWrap(false)
    row:SetScript("OnEnter", function()
        if not row.link then return end
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(row.link)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function()
        if row.link and IsShiftKeyDown() then ChatEdit_InsertLink(row.link) end
    end)
    win.rows[i] = row
    return row
end

-- Fills row `n` of `win`; EndRows hides the rows after the last one.
local function Put(win, n, text, link, info, icon)
    local row = Row(win, n)
    row.link = link
    row.name:SetText(text)
    row.info:SetText(info or "")
    row.icon:SetTexture(icon)
    row.icon:SetShown(icon ~= nil)
    row:Show()
end
local function EndRows(win, n)
    for i = n + 1, #win.rows do win.rows[i]:Hide() end
    win.content:SetHeight(math.max(n * ROW_HEIGHT, 1))
end

-- A scrolling list from y to the bottom of window `f` (f.rows, f.content).
local function List(f, y)
    f.rows = {}
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, y)
    scroll:SetPoint("BOTTOMRIGHT", -32, 12)
    f.content = CreateFrame("Frame", nil, scroll)
    f.content:SetSize(f:GetWidth() - 50, 1)
    scroll:SetScrollChild(f.content)
end

BuildList = function()
    if not (bis and bis:IsShown()) then return end
    bis.ahead:SetText(db.ahead)
    for _, b in ipairs(bis.sortButtons) do
        if db.sort == b.sort then b:LockHighlight() else b:UnlockHighlight() end
    end
    bis.upgrades:SetChecked(db.upgradesOnly)
    bis.upgrades:SetShown(db.sort == "best") -- ("next" lists upgrades only anyway)

    local n, groups, loading = 0, {}, 0
    if db.role then
        RequestBis()
        groups, loading = Pick()
    end
    local level = UnitLevel("player")
    for g, group in ipairs(GROUPS) do
        local list = groups[g] or {}
        if list[1] then n = n + 1 Put(bis, n, "|cffffd200" .. group[1] .. "|r") end
        for k = 1, math.min(PER_GROUP, #list) do
            local e = list[k]
            local lv = e.minLevel > level and ("|cffff6060Lv " .. e.minLevel .. "|r") or ("Lv " .. e.minLevel)
            local gain = "|cff888888no upgrade|r"
            if e.upgrade then
                gain = "|cff20ff20" .. (e.worn > 0 and string.format("+%d%%", math.floor((e.score / e.worn - 1) * 100))
                    or "empty slot") .. "|r"
            end
            if e.lowArmor then gain = gain .. " |cffffd200lower armor|r" end
            n = n + 1
            Put(bis, n, e.link, e.link, lv .. "   " .. gain .. "   |cffaaaaaa" .. e.src[1] .. ", " .. e.src[2] .. "|r", e.icon)
        end
    end
    EndRows(bis, n)

    if not db.role then
        bis.status:SetText("Pick your spec and role first (Settings).")
    elseif loading > 0 and GetTime() < loadUntil then
        bis.status:SetText("Loading " .. loading .. " items from the server...")
    elseif n == 0 then
        bis.status:SetText("Nothing found up to " .. db.ahead .. " levels above you.")
    else
        bis.status:SetText("")
    end
end

OpenBis = function()
    if bis then Toggle(bis) BuildList() return end
    local f = NewWindow("RoleLootBisFrame", "RoleLoot BiS list", 560, 470)
    Toggle(f)
    bis = f

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 14, -36)
    label:SetText("Levels ahead:")
    local function Ahead(delta)
        db.ahead = math.max(0, math.min(MAX_AHEAD, db.ahead + delta))
    end
    Button(f, "-", 24, 108, -31, function() Ahead(-1) end)
    f.ahead = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.ahead:SetPoint("TOPLEFT", 136, -36)
    f.ahead:SetWidth(22)
    Button(f, "+", 24, 160, -31, function() Ahead(1) end)

    f.sortButtons = {}
    for i, s in ipairs(SORTS) do
        local b = Button(f, s[2], 100, 200 + (i - 1) * 104, -31, function() db.sort = s[1] end)
        b.sort = s[1]
        f.sortButtons[i] = b
    end
    Button(f, "Settings", 80, 466, -31, function() OpenSettings() end)
    Button(f, "Search", 80, 466, -56, function() OpenSearch() end)

    f.upgrades = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.upgrades:SetSize(22, 22)
    f.upgrades:SetPoint("TOPLEFT", 10, -58)
    f.upgrades:SetScript("OnClick", function(b) db.upgradesOnly = b:GetChecked() and true or false BuildList() end)
    local upgradesLabel = f.upgrades:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    upgradesLabel:SetPoint("LEFT", f.upgrades, "RIGHT", 2, 0)
    upgradesLabel:SetText("Upgrades only")

    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.status:SetPoint("TOPRIGHT", -100, -64)
    List(f, -84)

    BuildList()
end

---------------------------------------------------------------- search window

-- Every listed item for any class, race and role, filtered by name, slot and
-- level, sorted by score or by one stat. "All items" drops the class and role filter.
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local RACES = { "Human", "Dwarf", "NightElf", "Gnome", "Orc", "Scourge", "Tauren", "Troll" }
local RACE_LABEL = { NightElf = "Night Elf", Scourge = "Undead" }
local ALLIANCE = Set("Human", "Dwarf", "NightElf", "Gnome")
-- Sort keys: a label, then the stats (BASE's names) summed; "Score" has none.
local STATS = { { "Score" }, { "Strength", "STRENGTH" }, { "Agility", "AGILITY" }, { "Stamina", "STAMINA" },
    { "Intellect", "INTELLECT" }, { "Spirit", "SPIRIT" }, { "Attack power", "ATTACK_POWER" },
    { "Spell power", "SPELL_POWER", "SPELL_DAMAGE_DONE" }, { "Healing", "SPELL_HEALING_DONE" },
    { "Mana regen", "MANA_REGENERATION", "POWER_REGEN0" }, { "Crit", "CRIT_RATING" }, { "Hit", "HIT_RATING" },
    { "Defense", "DEFENSE_SKILL_RATING" }, { "Armor", "ARMOR" }, { "Weapon DPS", "DPS" }, { "On-hit effects", "PROC" } }
local MAX_RESULTS = 100

local search -- the window; search.q: its filters

local function ClassLabel(c) return c:sub(1, 1) .. c:sub(2):lower() end
-- The entry of `list` after `cur` (right-click: before).
local function Cycle(list, cur, mouse)
    local i = 1
    for k, v in ipairs(list) do if v == cur then i = k end end
    return list[(i - 1 + (mouse == "RightButton" and -1 or 1)) % #list + 1]
end

BuildSearch = function()
    if not (search and search:IsShown()) then return end
    local q = search.q
    search.class:SetText("Class: " .. ClassLabel(q.class))
    search.race:SetText("Race: " .. (RACE_LABEL[q.race] or q.race))
    search.role:SetText("Role: " .. ROLE_LABEL[q.role])
    search.slot:SetText("Slot: " .. (q.slot == 0 and "Any" or GROUPS[q.slot][1]))
    search.sort:SetText("Sort: " .. STATS[q.stat][1])
    search.min:SetText(q.min)
    search.max:SetText(q.max)
    search.all:SetChecked(q.all)

    RequestItems(q.min - 10, q.max, not q.all and q.class or nil)
    local results, loading, text = {}, 0, q.text:lower()
    local faction, sortBy = ALLIANCE[q.race] and "Alliance" or "Horde", STATS[q.stat]
    for id, src in pairs(ns.SOURCES) do
        local _, _, _, equipLoc, icon, classID, subclassID = GetInstant(id)
        local g = GROUP_OF[equipLoc]
        if g and (q.slot == 0 or q.slot == g) then
            local name, link, level = ItemInfo(id, src)
            local stats = link and GetStats(link)
            if not stats then
                if asked[id] then loading = loading + 1 end
            elseif level >= q.min and level <= q.max and (q.all or not src[4] or src[4] == faction)
                and (text == "" or name:lower():find(text, 1, true)) then
                local score, off = Fit(stats, equipLoc, classID == 2 and subclassID == 19, q.role, q.class)
                if q.all or (CanUse(q.class, equipLoc, classID, subclassID, level) and not off) then
                    if classID == 2 and RACIAL_WEAPONS[q.race] and RACIAL_WEAPONS[q.race][subclassID] then
                        score = score * RACIAL_BONUS
                    end
                    local value = score
                    if sortBy[2] then
                        value = 0
                        for j = 2, #sortBy do value = value + (stats[GameKey(sortBy[j])] or 0) end
                    end
                    if value > 0 then
                        tinsert(results, { link = link, icon = icon, value = value, level = level, src = src })
                    end
                end
            end
        end
    end
    table.sort(results, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        if a.level ~= b.level then return a.level < b.level end
        return a.link < b.link
    end)
    local n = math.min(MAX_RESULTS, #results)
    for k = 1, n do
        local e = results[k]
        local value = sortBy[2] and string.format("%g %s", e.value, sortBy[1]) or string.format("score %d", math.floor(e.value))
        Put(search, k, e.link, e.link, "Lv " .. e.level .. "   |cff20ff20" .. value .. "|r   |cffaaaaaa"
            .. e.src[1] .. ", " .. e.src[2] .. "|r", e.icon)
    end
    EndRows(search, n)
    search.status:SetText((loading > 0 and GetTime() < loadUntil and ("Loading " .. loading .. " items...  ") or "")
        .. #results .. " found" .. (#results > n and (", best " .. n .. " shown") or ""))
end

OpenSearch = function()
    if search then Toggle(search) BuildSearch() return end
    local f = NewWindow("RoleLootSearchFrame", "RoleLoot item search", 600, 500)
    search = f
    local level = UnitLevel("player")
    f.q = { text = "", class = player.class, race = player.race, role = ActiveRole() or "melee", slot = 0, stat = 1,
            min = math.max(1, level - 5), max = math.min(60, level + 5), all = false }
    local q = f.q
    Toggle(f)

    local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    box:SetSize(140, 20)
    box:SetPoint("TOPLEFT", 20, -32)
    box:SetAutoFocus(false)
    box:SetScript("OnTextChanged", function(b) q.text = b:GetText() or "" BuildSearch() end)
    box:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
    f.box = box

    -- Left-click: next, right-click: previous.
    f.class = Button(f, "", 130, 170, -31, function(m) q.class = Cycle(CLASSES, q.class, m) end)
    f.race = Button(f, "", 130, 304, -31, function(m) q.race = Cycle(RACES, q.race, m) end)
    f.role = Button(f, "", 130, 438, -31, function(m) q.role = Cycle(ROLES, q.role, m) end)
    f.slot = Button(f, "", 130, 14, -58, function(m)
        q.slot = (q.slot + (m == "RightButton" and -1 or 1)) % (#GROUPS + 1)
    end)
    f.sort = Button(f, "", 150, 148, -58, function(m)
        q.stat = (q.stat - 1 + (m == "RightButton" and -1 or 1)) % #STATS + 1
    end)

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", 306, -63)
    label:SetText("Level")
    local function Level(key, delta)
        q[key] = math.max(1, math.min(60, q[key] + delta))
        q.min, q.max = math.min(q.min, q.max), math.max(q.min, q.max)
    end
    Button(f, "-", 22, 338, -58, function() Level("min", -1) end)
    f.min = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.min:SetPoint("TOPLEFT", 362, -63)
    Button(f, "+", 22, 384, -58, function() Level("min", 1) end)
    Button(f, "-", 22, 416, -58, function() Level("max", -1) end)
    f.max = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.max:SetPoint("TOPLEFT", 440, -63)
    Button(f, "+", 22, 462, -58, function() Level("max", 1) end)

    f.all = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.all:SetSize(22, 22)
    f.all:SetPoint("TOPLEFT", 494, -58)
    f.all:SetScript("OnClick", function(b) q.all = b:GetChecked() and true or false BuildSearch() end)
    local allLabel = f.all:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    allLabel:SetPoint("LEFT", f.all, "RIGHT", 2, 0)
    allLabel:SetText("All items")

    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.status:SetPoint("TOPLEFT", 16, -88)
    List(f, -104)
    BuildSearch()
end


-- Gear the item list lacks (newer item versions, rare mobs) is learned from
-- your loot windows into RoleLootLearned (all characters): { mob, place, 0 }.
-- In a dungeon or raid anything counts (a chest's loot: "Trash Drops"); in the
-- world only rare and boss mobs, so a wolf's random green isn't listed.
local WORLD_SOURCES = { rare = true, rareelite = true, worldboss = true }
local function Learn()
    local inside = IsInInstance()
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local id = link and tonumber(link:match("item:(%d+)"))
        local _, _, _, equipLoc = GetInstant(id or 0)
        local _, _, quality, itemLevel, minLevel = GetInfo(link or 0)
        if id and not ns.SOURCES[id] and GROUP_OF[equipLoc] and (quality or 0) >= 2 then
            local guid = GetLootSourceInfo and GetLootSourceInfo(slot)
            local mob = guid and guid == UnitGUID("target") and UnitName("target")
            if inside or (mob and WORLD_SOURCES[UnitClassification("target")]) then
                local level = (minLevel or 0) > 0 and minLevel or math.max(0, math.min(60, (itemLevel or 5) - 5))
                local src = { mob or "Trash Drops", (inside and GetInstanceInfo() or GetRealZoneText()) or "?", level }
                RoleLootLearned[id], ns.SOURCES[id], asked[id] = src, src, true
                BuildSoon()
            end
        end
    end
end

---------------------------------------------------------------- highlights

-- A glowing border, label and roll icon on item buttons: the loot window,
-- roll popups, quest rewards and your bags. NEED also pulses.
local MARK_COLOR = { NEED = { 0.1, 1, 0.1 }, GREED = { 1, 0.82, 0 }, PASS = { 1, 0.25, 0.25 } }
-- The loot roll buttons' own icons: dice, coin, cross.
local MARK_ICON = { NEED = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", GREED = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
                    PASS = "Interface\\Buttons\\UI-GroupLoot-Pass-Up" }
local ALL = { NEED = true, GREED = true, PASS = true }
local NEED_ONLY = { NEED = true } -- (bags: only what you should put on)

-- Shows `verdict` on `button` (nil: hides it), around `icon` (default: the button).
local function MarkAs(button, verdict, icon)
    local mark = button.RoleLootMark
    if not verdict then
        if mark then mark:Hide() end
        return
    end
    if not mark then
        icon = icon or button
        mark = CreateFrame("Frame", nil, button)
        mark:SetAllPoints(icon)
        mark:SetFrameLevel(button:GetFrameLevel() + 5)
        mark.border = mark:CreateTexture(nil, "OVERLAY")
        mark.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        mark.border:SetBlendMode("ADD")
        mark.border:SetPoint("CENTER")
        mark.border:SetSize(icon:GetWidth() * 1.8, icon:GetHeight() * 1.8)
        -- A wider, softer second border: the glow.
        mark.glow = mark:CreateTexture(nil, "ARTWORK")
        mark.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        mark.glow:SetBlendMode("ADD")
        mark.glow:SetAlpha(0.6)
        mark.glow:SetPoint("CENTER")
        mark.glow:SetSize(icon:GetWidth() * 2.3, icon:GetHeight() * 2.3)
        mark.icon = mark:CreateTexture(nil, "OVERLAY")
        mark.icon:SetSize(16, 16)
        mark.icon:SetPoint("CENTER", mark, "TOPRIGHT", -2, -2)
        mark.label = mark:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        mark.label:SetPoint("TOPLEFT", 1, -1)
        mark.pulse = mark.glow:CreateAnimationGroup()
        mark.pulse:SetLooping("BOUNCE")
        local fade = mark.pulse:CreateAnimation("Alpha")
        fade:SetFromAlpha(0.9)
        fade:SetToAlpha(0.2)
        fade:SetDuration(0.7)
        button.RoleLootMark = mark
    end
    local c = MARK_COLOR[verdict]
    mark.border:SetVertexColor(c[1], c[2], c[3])
    mark.glow:SetVertexColor(c[1], c[2], c[3])
    mark.icon:SetTexture(MARK_ICON[verdict])
    mark.label:SetTextColor(c[1], c[2], c[3])
    mark.label:SetText(verdict)
    if verdict == "NEED" then mark.pulse:Play() else mark.pulse:Stop() end
    mark:Show()
end

-- Marks `button` with item `link`'s verdict when it is one of `show`.
local function Mark(button, link, show, icon)
    local verdict = link and Verdict(link)
    MarkAs(button, show[verdict or ""] and verdict or nil, icon)
end

-- Loot window: the scrolling one of the modern UI, else LootButton1-4.
local function PaintLoot()
    if not (LootFrame and LootFrame:IsShown()) then return end
    if LootFrame.ScrollBox and LootFrame.ScrollBox.ForEachFrame then
        LootFrame.ScrollBox:ForEachFrame(function(row)
            local data = row.GetElementData and row:GetElementData()
            local slot = (row.GetSlotIndex and row:GetSlotIndex()) or (type(data) == "table" and data.slotIndex)
            Mark(row.Item or row, slot and GetLootSlotLink(slot), ALL)
        end)
    else
        for i = 1, LOOTFRAME_NUMBUTTONS or 4 do
            local b = _G["LootButton" .. i]
            if b then Mark(b, b:IsShown() and b.slot and GetLootSlotLink(b.slot), ALL) end
        end
    end
end

-- Group loot roll popups.
local function PaintRolls()
    for i = 1, NUM_GROUP_LOOT_FRAMES or 4 do
        local f = _G["GroupLootFrame" .. i]
        if f then Mark(f.IconFrame or f, f:IsShown() and f.rollID and GetLootRollItemLink(f.rollID), ALL) end
    end
end

-- Quest rewards (the quest giver's window, the quest log, the map's quest
-- details): the biggest upgrade among them gets NEED, the rest nothing.
local questFrame, questLog
local function PaintQuest()
    if not (questFrame and questFrame:IsVisible()) then return end
    local tiles = questFrame.RewardButtons
    if not tiles then -- (older UI: named tiles)
        tiles = {}
        local name = questFrame:GetName()
        for i = 1, 10 do tiles[i] = name and _G[name .. "QuestInfoItem" .. i] or nil end
    end
    local GetLink = questLog and GetQuestLogItemLink or GetQuestItemLink
    local best, bestScore
    for _, tile in pairs(tiles) do
        MarkAs(tile, nil)
        if tile:IsShown() and (tile.objectType == nil or tile.objectType == "item")
            and (tile.type == "choice" or tile.type == "reward") then
            local verdict, _, score = Verdict(GetLink(tile.type, tile:GetID()))
            if verdict == "NEED" and (not bestScore or score > bestScore) then best, bestScore = tile, score end
        end
    end
    if best then MarkAs(best, "NEED", best.Icon or best.icon) end
end

-- Bags: the combined bag and the separate ones (modern UI), else the old ContainerFrame_Update.
local GetBagLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
local function PaintBag(frame)
    if not (frame and frame:IsShown()) then return end
    local function One(btn)
        local bag = btn.GetBagID and btn:GetBagID() or btn:GetParent():GetID()
        Mark(btn, bag and GetBagLink(bag, btn:GetID()), NEED_ONLY)
    end
    if frame.EnumerateValidItems then
        for _, btn in frame:EnumerateValidItems() do One(btn) end
    elseif frame.Items then
        for _, btn in ipairs(frame.Items) do One(btn) end
    else
        for i = 1, frame.size or 0 do
            local btn = _G[frame:GetName() .. "Item" .. i]
            if btn then One(btn) end
        end
    end
end

local function BagFrames()
    local list = { ContainerFrameCombinedBags }
    for i = 1, NUM_CONTAINER_FRAMES or 13 do list[#list + 1] = _G["ContainerFrame" .. i] end
    return list
end

RefreshMarks = function()
    if not db then return end
    PaintLoot()
    PaintRolls()
    PaintQuest()
    for _, f in pairs(BagFrames()) do PaintBag(f) end
end

-- Hooks the game's windows (at login: the game's own UI has loaded by then).
local function HookMarks()
    local hookedBags = false
    for _, f in pairs(BagFrames()) do
        if f.UpdateItems then
            hooksecurefunc(f, "UpdateItems", PaintBag)
            hookedBags = true
        end
    end
    if not hookedBags and ContainerFrame_Update then hooksecurefunc("ContainerFrame_Update", PaintBag) end
    if LootFrame_Update then hooksecurefunc("LootFrame_Update", PaintLoot) end -- (old UI's pages)
    if QuestInfo_Display then
        hooksecurefunc("QuestInfo_Display", function(_, _, _, _, mapView)
            questFrame = (QuestInfoFrame and QuestInfoFrame.rewardsFrame)
                or (mapView and MapQuestInfoRewardsFrame or QuestInfoRewardsFrame)
            questLog = QuestInfoFrame and QuestInfoFrame.questLog and true or false
            PaintQuest()
        end)
    end
end

SLASH_ROLELOOT1, SLASH_ROLELOOT2 = "/rl", "/roleloot"
SlashCmdList.ROLELOOT = function(msg)
    msg = msg and msg:lower() or ""
    if msg:match("bis") then OpenBis() elseif msg:match("search") then OpenSearch()
    elseif msg:match("bug") or msg:match("feedback") then OpenBug() else OpenSettings() end
end
RoleLoot_OnAddonCompartmentClick = function() OpenBis() end -- (the .toc's addon-list button)

---------------------------------------------------------------- minimap button

local ICON = "Interface\\Icons\\INV_Misc_Bag_08"

-- A round button on the minimap's edge: click opens the settings, drag moves it around.
local function MinimapButton()
    local b = CreateFrame("Button", "RoleLootMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- (crops the icon's square border)
    icon:SetPoint("TOPLEFT", 7, -6)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    local function Place()
        local a = math.rad(db.minimapAngle or 200)
        local r = Minimap:GetWidth() / 2 + 5
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
    end
    b:SetScript("OnDragStart", function()
        b:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            db.minimapAngle = math.deg(math.atan2(y / scale - my, x / scale - mx))
            Place()
        end)
    end)
    b:SetScript("OnDragStop", function() b:SetScript("OnUpdate", nil) end)
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then OpenSettings() else OpenBis() end
    end)
    b:SetScript("OnEnter", function()
        GameTooltip:SetOwner(b, "ANCHOR_LEFT")
        GameTooltip:AddLine("RoleLoot")
        GameTooltip:AddLine(SpecName() .. ", " .. (STYLE_LABEL[db.role] or "no style picked"), 1, 1, 1)
        GameTooltip:AddLine("In dungeons: " .. ROLE_LABEL[db.dungeonRole or "dps"], 1, 1, 1)
        GameTooltip:AddLine("Left-click: BiS list   Right-click: settings   Drag: move", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Place()
end

---------------------------------------------------------------- tooltips and loot rolls

-- Colors `tip`'s border by the verdict (`c`; nil: back to the game's).
local function TintTooltip(tip, c)
    local r, g, b = 1, 1, 1
    if c then r, g, b = c[1], c[2], c[3] elseif TOOLTIP_DEFAULT_COLOR then
        r, g, b = TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b
    end
    if tip.NineSlice and tip.NineSlice.SetBorderColor then tip.NineSlice:SetBorderColor(r, g, b)
    elseif tip.SetBackdropBorderColor then tip:SetBackdropBorderColor(r, g, b) end
    tip.roleLootTint = c
end

local function OnTooltip(tip)
    if tip ~= GameTooltip and tip ~= ItemRefTooltip then return end
    local link
    if TooltipUtil and TooltipUtil.GetDisplayedItem then link = select(2, TooltipUtil.GetDisplayedItem(tip)) end
    if not link and tip.GetItem then link = select(2, tip:GetItem()) end
    local text, verdict = VerdictText(link)
    if text then
        tip:AddLine("|T" .. MARK_ICON[verdict] .. ":16|t RoleLoot: " .. text)
        TintTooltip(tip, MARK_COLOR[verdict])
        tip:Show() -- (fits the new line)
    end
end
for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
    if tip then tip:HookScript("OnTooltipCleared", function(t) TintTooltip(t) end) end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltip)
else
    for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do tip:HookScript("OnTooltipSetItem", OnTooltip) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("START_LOOT_ROLL")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("LOOT_OPENED")
events:RegisterEvent("PLAYER_ENTERING_WORLD") -- (in or out of a dungeon: the dungeon role)
events:SetScript("OnEvent", function(_, event, rollID)
    if event == "PLAYER_LOGIN" then
        RoleLootDB = RoleLootDB or {}
        db = RoleLootDB
        db.ahead = db.ahead or 3
        db.sort = db.sort or "best"
        player.className, player.class = UnitClass("player")
        -- Before 0.9 the role was melee/ranged/tank/caster/healer, the dungeon role any role or "dps".
        if db.role and not STYLE_LABEL[db.role] then
            local spec = db.spec and SPECS[player.class][db.spec]
            if db.role == "tank" or db.role == "healer" then db.dungeonRole = db.dungeonRole or db.role end
            db.role = (db.role == "ranged" or db.role == "caster") and db.role or (spec and spec[2]) or "melee2h"
        end
        if db.dungeonRole ~= "tank" and db.dungeonRole ~= "healer" then db.dungeonRole = nil end
        player.raceName, player.race = UnitRace("player")
        player.faction = UnitFactionGroup("player")
        RoleLootLearned = RoleLootLearned or {}
        for id, src in pairs(RoleLootLearned) do ns.SOURCES[id] = ns.SOURCES[id] or src end
        MinimapButton()
        HookMarks()
        C_Timer.After(5, RequestBis) -- (so the BiS list is ready when opened)
        if not db.spec then
            print("|cff20ff20RoleLoot|r: pick your spec and role (/rl).")
            OpenSettings()
        end
    elseif event == "LOOT_OPENED" then
        Learn()
        C_Timer.After(0, PaintLoot) -- (after the game fills the window)
    elseif event == "START_LOOT_ROLL" then
        C_Timer.After(0, PaintRolls)
        local link = GetLootRollItemLink(rollID)
        local text = VerdictText(link)
        if text then print("|cff20ff20RoleLoot|r " .. link .. ": " .. text) end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if asked[rollID] then BuildSoon() end -- (rollID: the item; others are the game's own)
    elseif db then
        BuildSoon() -- (new gear, level or zone: verdicts change)
    end
end)

---------------------------------------------------------------- self-check

do -- the case this addon exists for: healer gear is a Pass for a Retribution paladin
    local healerChest = { ITEM_MOD_INTELLECT_SHORT = 10, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 20,
                          ITEM_MOD_STAMINA_SHORT = 5, RESISTANCE0_NAME = 300 }
    local plateChest = { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_STAMINA_SHORT = 5, RESISTANCE0_NAME = 300 }
    local _, off = Fit(healerChest, "INVTYPE_CHEST", false, "melee", "PALADIN")
    local _, none = Fit(plateChest, "INVTYPE_CHEST", false, "melee", "PALADIN")
    local _, staOnly = Fit({ ITEM_MOD_STAMINA_SHORT = 8 }, "INVTYPE_FINGER", false, "melee", "PALADIN")
    local _, mageInt = Fit({ ITEM_MOD_INTELLECT_SHORT = 8, ITEM_MOD_STAMINA_SHORT = 4 }, "INVTYPE_HEAD", false,
        "caster", "MAGE")
    assert(off == "healer" and none == nil and staOnly == nil and mageInt == nil, "RoleLoot self-check failed")
end
