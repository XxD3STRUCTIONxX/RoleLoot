-- A fake WoW client, just enough of it for RoleLoot, and test scenarios:
-- a level 30 Human Retribution paladin looting, questing and browsing the BiS list.
unpack = unpack or table.unpack
math.atan2 = math.atan2 or math.atan
tinsert = table.insert

local fails, passes = {}, 0
local function check(ok, what)
    if ok then passes = passes + 1 else fails[#fails + 1] = what end
end

---------------------------------------------------------------- widgets

local Widget = {}
Widget.__index = Widget
local function New(kind, name, parent)
    local w = setmetatable({ kind = kind, parent = parent, children = {}, scripts = {}, hooks = {},
                             shown = true, width = 36, height = 36, level = 1 }, Widget)
    if parent then table.insert(parent.children, w) end
    if name then _G[name] = w; w.name = name end
    return w
end
for _, m in ipairs({ "SetPoint", "ClearAllPoints", "SetFrameStrata", "SetMovable", "EnableMouse",
    "RegisterForDrag", "RegisterForClicks", "StartMoving", "StopMovingOrSizing", "SetHighlightTexture",
    "SetTexCoord", "SetColorTexture", "SetAllPoints", "SetBlendMode", "SetVertexColor", "SetTextColor",
    "SetJustifyH", "SetWordWrap", "SetScrollChild", "SetClampedToScreen", "SetAutoFocus", "ClearFocus", "HighlightText", "SetFocus" }) do
    Widget[m] = function(self, ...) self[m .. "Args"] = { ... } end
end
function Widget:SetSize(w, h) self.width, self.height = w, h end
function Widget:SetWidth(w) self.width = w end
function Widget:SetHeight(h) self.height = h end
function Widget:GetWidth() return self.width end
function Widget:GetHeight() return self.height end
function Widget:GetRight() return 600 end
function Widget:GetTop() return 700 end
function Widget:SetText(t) self.text = t end
function Widget:GetText() return self.text end
function Widget:SetTexture(t) self.texture = t end
function Widget:SetScript(k, f) self.scripts[k] = f end
function Widget:GetScript(k) return self.scripts[k] end
function Widget:HookScript(k, f) self.hooks[k] = self.hooks[k] or {}; table.insert(self.hooks[k], f) end
function Widget:Show() self.shown = true end
function Widget:Hide() self.shown = false end
function Widget:SetShown(s) self.shown = s and true or false end
function Widget:IsShown() return self.shown end
function Widget:IsVisible() return self.shown end
function Widget:LockHighlight() self.locked = true end
function Widget:UnlockHighlight() self.locked = false end
function Widget:SetFrameLevel(l) self.level = l end
function Widget:GetFrameLevel() return self.level end
function Widget:SetChecked(c) self.checked = c end
function Widget:GetChecked() return self.checked end
function Widget:GetName() return self.name end
function Widget:GetParent() return self.parent end
function Widget:GetID() return self.id or 0 end
function Widget:GetFontString() return self.fontString end
function Widget:RegisterEvent(e) self.events = self.events or {}; self.events[e] = true end
function Widget:CreateTexture() local t = New("Texture", nil, self); self.textures = self.textures or {}; table.insert(self.textures, t) return t end
function Widget:CreateFontString() return New("FontString", nil, self) end
function Widget:CreateAnimationGroup() return New("AnimationGroup", nil, self) end
function Widget:CreateAnimation() return New("Animation", nil, self) end
function Widget:Play() self.playing = true end
function Widget:Stop() self.playing = false end
for _, m in ipairs({ "SetLooping", "SetFromAlpha", "SetToAlpha", "SetDuration", "SetAlpha" }) do
    Widget[m] = Widget[m] or function(self, ...) self[m .. "Args"] = { ... } end
end
function Widget:GetCenter() return 500, 500 end
function Widget:GetEffectiveScale() return 1 end

local frames = {}
function CreateFrame(kind, name, parent, template)
    local f = New(kind, name, parent)
    f.template = template
    if template == "UIPanelButtonTemplate" then f.fontString = New("FontString", nil, f) end
    table.insert(frames, f)
    return f
end
UIParent = New("Frame", "UIParent")
Minimap = New("Frame", "Minimap")
Minimap:SetSize(140, 140)
UISpecialFrames = {}

local function Click(b, button) b.scripts.OnClick(b, button or "LeftButton") end
-- The button with `text` among `parent`'s children.
local function ButtonOf(parent, text)
    for _, c in ipairs(parent.children) do
        if c.kind == "Button" and c.text == text then return c end
    end
end

---------------------------------------------------------------- game state and API

local ITEMS = {} -- id -> { name, equipLoc, classID, subclassID, minLevel, stats }
local function Item(id, name, equipLoc, classID, subclassID, minLevel, stats, lines)
    ITEMS[id] = { name = name, equipLoc = equipLoc, classID = classID, subclassID = subclassID,
                  minLevel = minLevel, stats = stats, lines = lines or {} }
end
local function Link(id) return id and ("|cff1eff00|Hitem:" .. id .. "::::::::|h[" .. ITEMS[id].name .. "]|h|r") end
local function IdOf(x) return type(x) == "number" and x or tonumber(tostring(x):match("item:(%d+)")) end

FORGOTTEN = {} -- items the game has dropped from its cache
ASKED = {} -- items GetItemInfo was called for
C_Item = {
    GetItemStats = function(link) local i = ITEMS[IdOf(link)] return i and i.stats end,
    GetItemInfoInstant = function(x)
        local id = IdOf(x); local i = ITEMS[id]
        if i then return id, "", "", i.equipLoc, "icon" .. id, i.classID, i.subclassID end
    end,
    GetItemInfo = function(x)
        local id = IdOf(x); local i = ITEMS[id]
        ASKED[id] = true
        if i and not FORGOTTEN[id] then return i.name, Link(id), 2, i.ilvl or 30, i.minLevel end
    end,
}
C_TooltipInfo = { GetHyperlink = function(link)
    local lines = { { leftText = ITEMS[IdOf(link)].name } }
    for _, l in ipairs(ITEMS[IdOf(link)].lines) do lines[#lines + 1] = { leftText = l } end
    return { lines = lines }
end }
local T = { level = 30, kind = "none", equipped = {}, bags = {}, loot = {}, rolls = {}, quest = {}, time = 0 }
function UnitClass() return "Paladin", "PALADIN" end
function UnitRace() return "Human", "Human" end
function UnitFactionGroup() return "Alliance" end
function UnitLevel() return T.level end
function IsInInstance() return T.kind ~= "none", T.kind end
function GetInventoryItemLink(_, slot) return Link(T.equipped[slot]) end
function GetLootSlotLink(slot) return Link(T.loot[slot]) end
function GetNumLootItems() return #T.loot end
function GetLootSourceInfo() return T.lootSource end
function UnitGUID() return T.target and T.target.guid end
function UnitName() return T.target and T.target.name end
function UnitClassification() return T.target and T.target.class end
function GetInstanceInfo() return "Blackrock Depths" end
function GetRealZoneText() return "Searing Gorge" end
function GetLootRollItemLink(id) return Link(T.rolls[id]) end
function GetQuestItemLink(_, i) return Link(T.quest[i]) end
C_Container = { GetContainerItemLink = function(_, slot) return Link(T.bags[slot]) end }
function GetTime() return T.time end
function GetBuildInfo() return "1.16.0", "60001" end
C_AddOns = { GetAddOnMetadata = function(_, key) return key == "Version" and "test" or nil end }
function GetCursorPosition() return 0, 0 end
function IsShiftKeyDown() return false end
function ChatEdit_InsertLink() end
function GetTexCoordsForRole(role) return role == "TANK" and 0 or 0.25, 0.25, 0, 0.25 end
SlashCmdList = {}
local printed = {}
print = function(...) table.insert(printed, table.concat({ ... }, " ")) end

local timers = {}
C_Timer = {
    After = function(d, f) table.insert(timers, { at = T.time + d, f = f }) end,
    NewTicker = function(d, f)
        local ticker = {}
        function ticker:Cancel() self.cancelled = true end
        local function Tick() if not ticker.cancelled then f(ticker) C_Timer.After(d, Tick) end end
        C_Timer.After(d, Tick)
        return ticker
    end,
}
local function RunTimers()
    for _ = 1, 100000 do
        if not timers[1] then return end
        table.sort(timers, function(a, b) return a.at < b.at end)
        local t = table.remove(timers, 1)
        T.time = math.max(T.time, t.at)
        t.f()
    end
    error("timers never stop")
end

function hooksecurefunc(a, b, c)
    local t, name, f = a, b, c
    if type(a) == "string" then t, name, f = _G, a, b end
    local orig = t[name]
    t[name] = function(...) orig(...) f(...) end
end

-- Tooltips: SetHyperlink runs the OnTooltipSetItem hooks; AddLine is recorded.
local function Tooltip(name)
    local tip = New("GameTooltip", name)
    function tip:SetOwner() self.lines = {} end
    function tip:AddLine(s) table.insert(self.lines, s) end
    function tip:SetHyperlink(link)
        self.lines, self.link = {}, link
        for _, f in ipairs(self.hooks.OnTooltipSetItem or {}) do f(self) end
    end
    function tip:GetItem() return "name", self.link end
    function tip:SetBackdropBorderColor(r, g, b) self.border = { r, g, b } end
    New("FontString", name .. "TextRight1")
    return tip
end
GameTooltip, ItemRefTooltip = Tooltip("GameTooltip"), Tooltip("ItemRefTooltip")

-- Loot window, roll popup, quest rewards and the combined bag (modern UI).
LootFrame = New("Frame", "LootFrame")
LootFrame.shown = false
local lootRows = {}
for i = 1, 3 do
    local row = New("Frame", nil, LootFrame)
    row.Item = New("Button", nil, row)
    function row:GetSlotIndex() return i end
    lootRows[i] = row
end
LootFrame.ScrollBox = { ForEachFrame = function(_, f) for _, r in ipairs(lootRows) do f(r) end end }

GroupLootFrame1 = New("Frame", "GroupLootFrame1")
GroupLootFrame1.IconFrame = New("Button", nil, GroupLootFrame1)
GroupLootFrame1.rollID = 7

QuestInfoFrame = { rewardsFrame = New("Frame", "QuestInfoRewardsFrame") }
QuestInfoFrame.rewardsFrame.RewardButtons = {}
for i = 1, 3 do
    local tile = New("Button", nil, QuestInfoFrame.rewardsFrame)
    tile.type, tile.objectType, tile.id = "choice", "item", i
    tile.Icon = New("Texture", nil, tile)
    QuestInfoFrame.rewardsFrame.RewardButtons[i] = tile
end
function QuestInfo_Display() end

ContainerFrameCombinedBags = New("Frame", "ContainerFrameCombinedBags")
local bagButtons = {}
for i = 1, 3 do
    local b = New("Button", nil, ContainerFrameCombinedBags)
    b.id = i
    function b:GetBagID() return 0 end
    bagButtons[i] = b
end
function ContainerFrameCombinedBags:UpdateItems() end
function ContainerFrameCombinedBags:EnumerateValidItems() return ipairs(bagButtons) end

local function Fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events and f.events[event] then f.scripts.OnEvent(f, event, ...) end
    end
end

---------------------------------------------------------------- items

local S = function(t)
    local s = {}
    for k, v in pairs(t) do s[k == "ARMOR" and "RESISTANCE0_NAME" or k == "DPS" and "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
        or ("ITEM_MOD_" .. k .. "_SHORT")] = v end
    return s
end
Item(1001, "Healer Robe", "INVTYPE_ROBE", 4, 3, 25, S { INTELLECT = 10, SPELL_HEALING_DONE = 20, ARMOR = 150 })
Item(1002, "Strong Mail Chest", "INVTYPE_CHEST", 4, 3, 28, S { STRENGTH = 12, STAMINA = 8, ARMOR = 200 })
Item(1003, "Worn Mail Chest", "INVTYPE_CHEST", 4, 3, 20, S { STRENGTH = 4, STAMINA = 4, ARMOR = 150 })
Item(1004, "Plate Helm", "INVTYPE_HEAD", 4, 4, 40, S { STRENGTH = 10, STAMINA = 10, ARMOR = 300 })
Item(1005, "Leather Gloves", "INVTYPE_HAND", 4, 2, 25, S { STRENGTH = 6, ARMOR = 50 })
Item(1006, "Short Sword", "INVTYPE_WEAPON", 2, 7, 25, S { STRENGTH = 5, DPS = 10 })
Item(1007, "Greatsword", "INVTYPE_2HWEAPON", 2, 8, 28, S { STRENGTH = 10, DPS = 20 })
Item(1008, "Staff", "INVTYPE_2HWEAPON", 2, 10, 25, S { STRENGTH = 10, DPS = 20 })
Item(1009, "Future Greatsword", "INVTYPE_2HWEAPON", 2, 8, 35, S { STRENGTH = 20, DPS = 30 })
Item(1010, "Worn Greataxe", "INVTYPE_2HWEAPON", 2, 1, 20, S { STRENGTH = 5, DPS = 15 })
Item(1011, "Strength Ring", "INVTYPE_FINGER", 4, 0, 25, S { STRENGTH = 8 })
Item(1012, "Healing Ring", "INVTYPE_FINGER", 4, 0, 25, S { SPELL_HEALING_DONE = 15, INTELLECT = 5 })
Item(1013, "Defender Legs", "INVTYPE_LEGS", 4, 3, 25, S { DEFENSE_SKILL_RATING = 10, STAMINA = 10, ARMOR = 200 })
-- Your mana regen and spell power wrist (the screenshot case) against 3 more armor.
Item(1014, "Oilrag", "INVTYPE_WRIST", 4, 1, 28, S { MANA_REGENERATION = 3, SPELL_POWER = 9, ARMOR = 22 })
Item(1015, "Chain Bracers", "INVTYPE_WRIST", 4, 3, 25, S { ARMOR = 25 })
-- The same greatsword with an on-hit effect.
Item(1016, "Proc Greatsword", "INVTYPE_2HWEAPON", 2, 8, 28, S { STRENGTH = 10, DPS = 20 },
     { "Chance on hit: Blasts the enemy for 50 Fire damage." })
-- Not in the item list: learned from loot.
Item(1017, "New Bael'Gar Belt", "INVTYPE_WAIST", 4, 3, 25, S { STRENGTH = 9 })
Item(1018, "Learned Last Time Boots", "INVTYPE_FEET", 4, 3, 25, S { STRENGTH = 7 })
Item(1019, "Wolf Green Cloak", "INVTYPE_CLOAK", 4, 1, 25, S { STRENGTH = 3 })
Item(1020, "Rare Mob Shoulders", "INVTYPE_SHOULDER", 4, 3, 25, S { STRENGTH = 5 })
-- A level 60 quest reward without a required level (most are like that).
Item(1021, "Quest Epic Helm", "INVTYPE_HEAD", 4, 3, 0, S { STRENGTH = 30 })
ITEMS[1021].ilvl = 65
Item(1022, "Level 55 Boots", "INVTYPE_FEET", 4, 4, 55, S { STRENGTH = 30 })
T.equipped = { [5] = 1003, [16] = 1010, [9] = 1014 }

---------------------------------------------------------------- load the addon

local ns = {}
load(DATA_SRC, "@Data.lua")("RoleLoot", ns)
local count = 0
for _ in pairs(ns.SOURCES) do count = count + 1 end
check(count > 2000, "Data.lua has " .. count .. " items")
load(ADDON_SRC, "@RoleLoot.lua")("RoleLoot", ns)
-- The BiS list's sources: the fake items, from a level 30 dungeon (and one Horde quest).
ns.SOURCES = {}
for id in pairs(ITEMS) do if id < 1017 then ns.SOURCES[id] = { "Boss " .. id, "Test Dungeon", 25 } end end
ns.SOURCES[1022] = { "Boss 1022", "Late Dungeon", 55 }
ns.SOURCES[1011][4] = "Horde"

---------------------------------------------------------------- scenarios

-- First login, a 0.8 save with the Healer role and no spec: settings open.
RoleLootDB = { role = "healer" }
RoleLootLearned = { [1018] = { "Some Boss", "Some Dungeon", 0 } }
Fire("PLAYER_LOGIN")
local settings = RoleLootFrame
check(settings and settings.shown, "settings open on first login")
check(RoleLootDB.role == "melee2h" and RoleLootDB.dungeonRole == "healer", "old Healer role: a style, healer in dungeons")
check(ns.SOURCES[1018] and ns.SOURCES[1018][1] == "Some Boss", "items learned before are listed")
local function Labels(buttons)
    local labels = {}
    for _, b in ipairs(buttons) do labels[#labels + 1] = b.text end
    return table.concat(labels, ",")
end
check(Labels(settings.dungeonButtons) == "DPS,Tank,Healer", "dungeon labels: " .. Labels(settings.dungeonButtons))
check(Labels(settings.roleButtons) == "2H melee,1H melee,Bow,Any ranged,Caster", "styles: " .. Labels(settings.roleButtons))
for _, b in ipairs(settings.roleButtons) do
    check(b.width >= 100 and b.SetPointArgs[2] + b.width <= settings.width - 10, b.text .. " button fits in the window")
end
check(settings.dungeonButtons[2].textures and settings.dungeonButtons[2].textures[1].texture
    == "Interface\\LFGFrame\\UI-LFG-ICON-ROLES", "Tank button has the role icon")
check(settings.roleButtons[1].textures[1].texture == "Interface\\Icons\\INV_Axe_04", "2H melee button has an icon")

Click(settings.specButtons[3]) -- Retribution
check(RoleLootDB.spec == 3 and RoleLootDB.role == "melee2h" and RoleLootDB.dungeonRole == nil,
    "Retribution picks 2H melee, DPS in dungeons")
check(settings.dungeonButtons[1].locked, "DPS highlighted")

local function Tip(id)
    GameTooltip:SetHyperlink(Link(id))
    return GameTooltip.lines[1] or ""
end
local function Expect(id, verdict, reason)
    local line = Tip(id)
    check(line:find(verdict, 1, true) and line:find(reason, 1, true), ITEMS[id].name .. ": " .. line)
end
Expect(1001, "PASS", "Healer gear, you play Melee")
Expect(1002, "NEED", "Upgrade +")
Expect(1003, "GREED", "Not an upgrade")
Expect(1004, "PASS", "can't wear this armor")
check(GameTooltip.border[1] == 1 and GameTooltip.border[2] == 0.25 and Tip(1004):find("Pass-Up", 1, true),
    "PASS tooltip: red border and the cross icon")
check(GameTooltipTextRight1.shown and GameTooltipTextRight1.text:find("PASS", 1, true), "PASS header beside the item name")
for _, f in ipairs(GameTooltip.hooks.OnTooltipCleared) do f(GameTooltip) end
check(GameTooltip.border[2] == 1 and not GameTooltip.roleLootOutline.shown, "cleared tooltip: border back to normal")
Tip(1004)
check(GameTooltip.roleLootOutline.shown and GameTooltip.roleLootOutline.sides[1].SetColorTextureArgs[2] == 0.25,
    "PASS tooltip: thick red outline")
Expect(1005, "GREED", "Not your best armor type")
Expect(1006, "GREED", "You fight with a two-hander")
Click(settings.roleButtons[2]) -- 1H melee
check(not Tip(1006):find("You fight", 1, true), "1H melee takes one-handers")
Expect(1007, "GREED", "You fight one-handed")
Click(settings.roleButtons[1]) -- back to 2H melee
Expect(1007, "NEED", "racial weapon")
Expect(1008, "PASS", "can't use this weapon")
Expect(1011, "NEED", "slot empty")
Expect(1012, "PASS", "Healer gear")
Expect(1013, "PASS", "Tank gear")
Expect(1015, "GREED", "Not an upgrade") -- (was "Upgrade +13%")
T.equipped[16] = 1007
Expect(1016, "NEED", "Upgrade +")
T.equipped[16] = 1010

-- Dungeon roles: Tank in a dungeon, not outside.
Click(settings.dungeonButtons[2])
check(RoleLootDB.dungeonRole == "tank", "Tank dungeon role saved")
Expect(1013, "PASS", "Tank gear")
T.kind = "party"
Expect(1013, "NEED", "(Retribution, Tank)")
Expect(1001, "PASS", "you play Tank")
-- Healer in dungeons, the fighting style outside.
Click(settings.dungeonButtons[3]) -- Healer
T.kind = "raid"
Expect(1001, "NEED", "(Retribution, Healer)")
T.kind = "none"
Expect(1001, "PASS", "you play Melee")
Click(settings.roleButtons[5]) -- Caster
Expect(1002, "(Retribution, Caster)", "")
Click(settings.roleButtons[1])
Click(settings.dungeonButtons[1]) -- DPS
check(RoleLootDB.dungeonRole == nil, "DPS clears the dungeon role")

-- Minimap tooltip and clicks.
RoleLootMinimapButton.scripts.OnEnter()
local tip = table.concat(GameTooltip.lines, "|")
check(tip:find("2H melee", 1, true) and tip:find("In dungeons: DPS", 1, true), "minimap tooltip: " .. tip)
Click(RoleLootMinimapButton, "RightButton")
check(not settings.shown, "right-click toggles settings")

-- Loot window.
T.loot = { 1001, 1002, 1005 }
LootFrame.shown = true
Fire("LOOT_OPENED")
RunTimers()
local function MarkOf(b) return b.RoleLootMark and b.RoleLootMark.shown and b.RoleLootMark.label.text end
check(MarkOf(lootRows[1].Item) == "PASS", "loot: healer robe PASS")
check(MarkOf(lootRows[2].Item) == "NEED", "loot: chest NEED")
check(MarkOf(lootRows[3].Item) == "GREED", "loot: gloves GREED")
local need, greed = lootRows[2].Item.RoleLootMark, lootRows[3].Item.RoleLootMark
check(need.pulse.playing and need.icon.texture:find("Dice", 1, true), "NEED pulses, with the dice")
check(not greed.pulse.playing and greed.icon.texture:find("Coin", 1, true), "GREED is still, with the coin")
LootFrame.shown = false
check(not ns.SOURCES[1001][1]:find("Bael", 1, true), "known items keep their source")

-- Learning: a boss in a dungeon, a normal wolf and a rare mob in the world.
T.kind, T.loot, T.lootSource = "party", { 1017, 1001 }, "Creature-1"
T.target = { guid = "Creature-1", name = "Bael'Gar", class = "elite" }
Fire("LOOT_OPENED")
check(RoleLootLearned[1017] and RoleLootLearned[1017][1] == "Bael'Gar" and RoleLootLearned[1017][2] == "Blackrock Depths"
    and RoleLootLearned[1017][3] == 25,
    "learned the boss drop")
check(ns.SOURCES[1001][1] == "Boss 1001", "listed items are not relearned")
T.kind, T.loot, T.lootSource = "none", { 1019 }, "Creature-2"
T.target = { guid = "Creature-2", name = "Wolf", class = "normal" }
Fire("LOOT_OPENED")
check(not RoleLootLearned[1019], "a normal mob's drop is not learned")
T.loot, T.lootSource = { 1020 }, "Creature-3"
T.target = { guid = "Creature-3", name = "Rare Ogre", class = "rare" }
Fire("LOOT_OPENED")
check(RoleLootLearned[1020] and RoleLootLearned[1020][2] == "Searing Gorge", "a rare mob's drop is learned")
T.target, T.lootSource = nil, nil
RunTimers()

-- Roll popup and chat.
T.rolls[7] = 1007
Fire("START_LOOT_ROLL", 7)
RunTimers()
check(MarkOf(GroupLootFrame1.IconFrame) == "NEED", "roll popup: greatsword NEED")
check(printed[#printed]:find("NEED", 1, true), "roll printed in chat")

-- Quest rewards: only the best NEED gets a mark.
T.quest = { 1001, 1011, 1002 }
QuestInfo_Display()
local tiles = QuestInfoFrame.rewardsFrame.RewardButtons
check(MarkOf(tiles[3]) == "NEED" and not MarkOf(tiles[1]) and not MarkOf(tiles[2]), "quest: best reward marked only")

-- Bags: NEED only.
T.bags = { 1001, 1002, 1005 }
ContainerFrameCombinedBags:UpdateItems()
check(not MarkOf(bagButtons[1]) and MarkOf(bagButtons[2]) == "NEED" and not MarkOf(bagButtons[3]), "bags: NEED only")

-- BiS list.
SlashCmdList.ROLELOOT("bis")
RunTimers()
local bis = RoleLootBisFrame
local function Listed()
    local ids = {}
    for _, row in ipairs(bis.rows) do
        if row.shown and row.link then ids[#ids + 1] = IdOf(row.link) end
    end
    return ids
end
local function Has(id) for _, v in ipairs(Listed()) do if v == id then return true end end end
check(bis.shown and #Listed() > 0, "BiS list shows items")
check(Has(1002) and Has(1007) and Has(1003), "BiS: chest, greatsword and worn chest listed")
check(not Has(1001) and not Has(1008) and not Has(1013), "BiS: no off-role or unusable items")
check(not Has(1011), "BiS: no Horde-only item")
check(not Has(1004) and not Has(1009), "BiS: nothing above level 33 at 3 ahead")
for _ = 1, 7 do Click(ButtonOf(bis, "+")) end
check(bis.ahead.text == 10, "levels ahead 10")
check(Has(1004) and Has(1009), "BiS: level 35 and 40 items at 10 ahead")
check(Listed()[1] == 1004, "BiS: head first")
check(not ASKED[1022], "BiS: level 55 items are not requested at level 30")
local before = #timers
Fire("GET_ITEM_INFO_RECEIVED", 99999)
check(#timers == before, "other items arriving don't rebuild the list")
check(not Has(1021), "BiS: a level 60 quest reward is not level 0")
FORGOTTEN[1002] = true
RoleLootBisFrame.ahead.text = nil
Click(ButtonOf(bis, "-")) Click(ButtonOf(bis, "+"))
check(Has(1002), "BiS: items the game forgets stay listed")
FORGOTTEN[1002] = nil
bis.upgrades.checked = true
Click(bis.upgrades)
check(not Has(1003), "upgrades only hides the worn chest")
Click(ButtonOf(bis, "Next upgrades"))
local main = {}
for _, id in ipairs(Listed()) do if ITEMS[id].classID == 2 then main[#main + 1] = id end end
check(#main == 3 and main[1] == 1016 and main[2] == 1007 and main[3] == 1009,
    "next upgrades: lowest level first, then best: " .. table.concat(main, ","))
Click(ButtonOf(bis, "Settings"))
check(settings.shown, "BiS Settings button opens settings")
check(settings.SetPointArgs[2] == UIParent and settings.SetPointArgs[4] == 604,
    "settings open beside the BiS list (a screen position: never anchored to it)")
-- Double-clicking: windows reopening beside each other never anchor to each other.
Click(ButtonOf(bis, "Settings")) Click(ButtonOf(bis, "Settings"))
SlashCmdList.ROLELOOT("bis") SlashCmdList.ROLELOOT("bis")
check(bis.SetPointArgs[2] ~= settings and settings.SetPointArgs[2] ~= bis, "no window anchored to another")

-- Search window.
Click(ButtonOf(bis, "Search"))
local search = RoleLootSearchFrame
check(search and search.shown and search.SetPointArgs[2] ~= nil, "search opens beside the others")
local function Found()
    local ids = {}
    for _, row in ipairs(search.rows) do
        if row.shown and row.link then ids[#ids + 1] = IdOf(row.link) end
    end
    return ids
end
local function In(id) for _, v in ipairs(Found()) do if v == id then return true end end end
check(search.class.text == "Class: Paladin" and search.role.text == "Role: Melee", "search starts as you")
check(In(1002) and In(1007) and In(1009) and not In(1001) and not In(1008), "search: usable melee gear 25-35")
check(not In(1004), "search: level 40 helm outside 25-35")
search.box.text = "GREATSWORD"
search.box.scripts.OnTextChanged(search.box)
check(#Found() == 3 and In(1007) and In(1009) and In(1016), "search by name: the three greatswords")
search.box.text = ""
search.box.scripts.OnTextChanged(search.box)
Click(search.sort) -- Strength
check(search.sort.text == "Sort: Strength" and Found()[1] == 1009, "sort by Strength: the 20 Strength sword first")
Click(search.sort, "RightButton")
check(search.sort.text == "Sort: Score", "right-click goes back")
search.all.checked = true
Click(search.all)
RunTimers() -- (the newly requested items arrive)
check(In(1001) and In(1008), "all items: healer robe and staff too")
search.all.checked = false
Click(search.all)
for _ = 1, 5 do Click(search.class) end
check(search.class.text == "Class: Mage" and not In(1002) and not In(1007), "a mage can't wear mail or swing greatswords")

-- Bug / feedback window: the issues link and your setup, read-only.
SlashCmdList.ROLELOOT("bug")
local bug = RoleLootBugFrame
check(bug and bug.shown, "/rl bug opens the bug window")
check(bug.link.text == "https://github.com/XxD3STRUCTIONxX/RoleLoot/issues/new/choose", "bug window has the issues link")
check(bug.setup.text:find("RoleLoot test, client 1.16.0", 1, true) and bug.setup.text:find("Human Paladin level 30", 1, true)
    and bug.setup.text:find("Retribution", 1, true), "setup line: " .. bug.setup.text)
bug.link.text = "typed over"
bug.link.scripts.OnTextChanged(bug.link, true)
check(bug.link.text == "https://github.com/XxD3STRUCTIONxX/RoleLoot/issues/new/choose", "the link can't be typed over")
check(ButtonOf(settings, "Bug / feedback"), "settings has a Bug / feedback button")

if #fails > 0 then error(#fails .. " failed:\n  " .. table.concat(fails, "\n  "), 0) end
print = _G.io and io.write or print
io.write(passes .. " checks passed\n")
