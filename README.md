# RoleLoot

A WoW: Forever addon that tells you **Need / Greed / Pass** for gear, based on your class, talent spec, **role** and race, and lists the best dungeon, raid and quest items for you.

Built so a Retribution paladin stops being told to Need healer gear.

## Features

- **Setup window** (`/rl`, or right-click the minimap button): pick your talent spec and your fighting styles from a dropdown (2H melee, 1H melee, Bow, Any ranged, Caster; tick as many as you use), off-meta included. The styles decide which weapons you NEED (a 2H-only fighter greeds one-handers and shields; tick both 2H and 1H to take either). With styles of different roles (melee and caster), gear gets the best verdict among them. Race and class come from your character.
- **Dungeon role**: Tank, DPS or Healer (with role icons), used inside dungeons and raids, for example a Retribution paladin who tanks dungeons. DPS means your fighting style.
- **Role outside dungeons**: Tank, DPS or Healer while questing. Usually the same as your dungeon role; pick a different one only if you really want gear judged differently out in the world.
- **Highlights**: a colored NEED / GREED / PASS border on the loot window and roll popups, NEED on the best quest reward (or, with no upgrade, SELL on the choice that sells best at a vendor, or AH when Auctionator or TradeSkillMaster prices say the auction house pays more), and NEED on upgrades sitting in your bags.
- **Tooltips**: every piece of gear gets a Need / Greed / Pass line, compared with what you wear. Mana regen and spell power count for paladins and shamans, and "Chance on hit" effects count for physical roles. A few points of armor is not an upgrade. A weapon whose skill you haven't learned counts 30% less and says where to train it; gear above your level says when you can wear it, and quest rewards prefer what you can wear now.
- **Loot rolls**: the same verdict is printed in chat when a roll starts. RoleLoot never rolls for you.
- **BiS list** (`/rl bis`, or left-click the minimap button): the best items per slot from 7000 boss drops, dungeon and raid trash drops and quest rewards, with item icons. Tick "On the AH" to list only items with an Auctionator or TradeSkillMaster price (shown instead of the source); click one while the auction house is open to search for it.
  - **Levels ahead**: show items you can use up to 0 to 20 levels above you.
  - **Best for me** or **Next upgrades** (upgrades only, lowest level first).
- **Item search** (`/rl search`, or Search in the BiS list): every item in the list for any class, race and role, by name, slot and level range, sorted by score or by one stat (Strength, Spell power, Mana regen, Defense, Weapon DPS and more). Left-click a filter button for the next choice, right-click for the previous. "All items" turns off the class and role filter.
- **Dungeon tracker**: opens when you enter a dungeon or raid and shows the run's time, XP and XP an hour, and the possible drops with their verdicts: every boss's at first, then only those of the boss you target. Leaving (a corpse run) keeps the run going; entering another dungeon or **New run** starts a new one, and the finished run is printed in chat. Escape leaves it open (close it with its X); `/rl run` reopens it. In the settings: turn it off, **Move** it (drag it; the spot is kept) or **Reset position**.
- **Sell unneeded gear**: a button beside the vendor window sells the gear in your bags that is GREED or PASS in every role you play (dungeons, outside, each fighting style), after a confirmation that lists it. Only green and blue gear (never profession tools, fishing poles, epics or items the AH pays more for), and 12 at most, so all of them fit on the vendor's Buyback tab.
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
