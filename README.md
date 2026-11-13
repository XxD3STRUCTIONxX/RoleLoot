# RoleLoot

A WoW: Forever addon that tells you **Need / Greed / Pass** for gear, based on your class, talent spec, **role** and race, and lists the best dungeon, raid and quest items for you.

Built so a Retribution paladin stops being told to Need healer gear.

## Features

- **Setup window** (`/rl`, or right-click the minimap button): pick your talent spec and fighting style (2H melee, 1H melee, Bow, Any ranged, Caster), off-meta included. The style decides which weapons you NEED (a 2H fighter greeds one-handers and shields). Race and class come from your character.
- **Dungeon role**: Tank, DPS or Healer (with role icons), used inside dungeons and raids, for example a Retribution paladin who tanks dungeons. DPS means your fighting style.
- **Highlights**: a colored NEED / GREED / PASS border on the loot window and roll popups, NEED on the best quest reward (or, with no upgrade, SELL on the choice that sells best at a vendor, or AH when Auctionator or TradeSkillMaster prices say the auction house pays more), and NEED on upgrades sitting in your bags.
- **Tooltips**: every piece of gear gets a Need / Greed / Pass line, compared with what you wear. Mana regen and spell power count for paladins and shamans, and "Chance on hit" effects count for physical roles. A few points of armor is not an upgrade.
- **Loot rolls**: the same verdict is printed in chat when a roll starts. RoleLoot never rolls for you.
- **BiS list** (`/rl bis`, or left-click the minimap button): the best items per slot from 7000 boss drops, dungeon and raid trash drops and quest rewards, with item icons. Tick "On the AH" to list only items with an Auctionator or TradeSkillMaster price (shown instead of the source); click one while the auction house is open to search for it.
  - **Levels ahead**: show items you can use up to 0 to 20 levels above you.
  - **Best for me** or **Next upgrades** (upgrades only, lowest level first).
- **Item search** (`/rl search`, or Search in the BiS list): every item in the list for any class, race and role, by name, slot and level range, sorted by score or by one stat (Strength, Spell power, Mana regen, Defense, Weapon DPS and more). Left-click a filter button for the next choice, right-click for the previous. "All items" turns off the class and role filter.
- Windows open next to each other instead of on top.
- **Learns from your loot**: gear missing from the list (newer item versions, rare mob drops) is added when you loot it in a dungeon or raid, or from a rare or boss mob in the world. Shared by all your characters.
- **Minimap button**: drag it around the minimap's edge.

## Bugs and feedback

[Open an issue](https://github.com/XxD3STRUCTIONxX/RoleLoot/issues/new/choose) and pick **Bug report** or **Feedback or idea**. In game, `/rl bug` (or **Bug / feedback** in the settings) shows this link and your setup to copy into the report.

## Install

Copy the `RoleLoot` folder to `World of Warcraft\_forever_\Interface\AddOns\` and restart the game.

## Tests

The addon runs against a fake WoW client in a Lua interpreter (fengari):

```
cd tests && npm install && node run.js
```

## Updating the item list

`RoleLoot/Data.lua` is generated from [wow-classic-items](https://github.com/Nakroma/wow-classic-items) (MIT):

```
npm install wow-classic-items@2.0.1
node make_data.js node_modules/wow-classic-items > RoleLoot/Data.lua
```

`RoleLoot/ForeverData.lua` adds WoW: Forever items that list misses (quest rewards, dungeon and world drops):

```
python make_forever.py wow_forever_complete.db <everloot folder> > RoleLoot/ForeverData.lua
```

## License and credits

All Rights Reserved (see `RoleLoot/LICENSE`), except the item data below, which stays under its own terms.

- Data.lua's item sources: [wow-classic-items](https://github.com/Nakroma/wow-classic-items) by Nakroma, MIT License.
- ForeverData.lua's quest rewards and dungeon drops: [Forever Mastery](https://forevermastery.com), used with permission.
- ForeverData.lua's drops and quest rewards seen by players: Data from [Everloot](https://everloot.app), [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), used with permission.
