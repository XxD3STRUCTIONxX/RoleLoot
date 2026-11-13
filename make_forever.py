# Builds RoleLoot/ForeverData.lua: WoW: Forever gear that Data.lua doesn't list.
#  - Forever Mastery (forevermastery.com, used with permission): quest rewards and dungeon drops,
#    from the wow_forever_complete.db file.
#  - Everloot (everloot.app, CC BY-SA 4.0, used with permission): player-observed drop rates,
#    quest rewards and loot, from files downloaded off its public API into one folder:
#    drops*.json (/api/rollups/drops), npc*.json, quest*.json, loot*.json (/api/corpus/public),
#    zones.json ({uiMapId: name}) and instance-map-names.json (its addon/data file).
# Usage: python make_forever.py <wow_forever_complete.db> [everloot folder] > RoleLoot/ForeverData.lua
import collections
import glob
import json
import os
import re
import sqlite3
import sys

db, data_lua = sys.argv[1], "RoleLoot/Data.lua"
everloot = sys.argv[2] if len(sys.argv) > 2 else None
have = {int(m) for m in re.findall(r"^\s*\[(\d+)\]", open(data_lua, encoding="utf8").read(), re.M)}
c = sqlite3.connect(db)
NOT_GEAR = ('', 'Non-equippable', 'Non-equipable', 'Shirt', 'Tabard', 'Bag', 'Ammo', 'Ammo Pouch', 'Quiver')
GEAR = "i.slot IS NOT NULL AND i.slot NOT IN (" + ", ".join(f"'{s}'" for s in NOT_GEAR) + ")"
info = {r[0]: r[1:] for r in c.execute("SELECT item_id, slot, req_level, item_level FROM items")}
# Everloot's instance names where RoleLoot (Data.lua) spells them differently.
ALIAS = {"Deadmines": "The Deadmines", "Stormwind Stockade": "The Stockade",
         "Sunken Temple": "The Temple of Atal'Hakkar", "Ahn'Qiraj Temple": "Ahn'Qiraj"}


def lua(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def level(req, ilvl):  # (as make_data.js: quest rewards mostly have no required level)
    return req or max(0, min(60, (ilvl or 5) - 5))


def item_level(iid, fallback):
    """Required level from the database; an item it doesn't know gets the mob's or quest's level."""
    if iid in info:
        return level(info[iid][1], info[iid][2])
    return max(0, min(60, fallback or 0))


def wanted(iid):  # gear we don't list; items the database doesn't know are kept (the addon checks the slot in game)
    return iid not in have and iid not in rows and (iid not in info or (info[iid][0] or '') not in NOT_GEAR)


rows = {}
for iid, quest, extra, req, ilvl in c.execute(f"""SELECT i.item_id, r.entity_name, r.extra_info, i.req_level, i.item_level
        FROM items i JOIN item_relations r USING (item_id) WHERE {GEAR} AND r.relation_type = 'quest_reward'
        ORDER BY i.item_id, r.entity_name"""):
    if iid in have or iid in rows:
        continue
    side = next((f for f in ("Alliance", "Horde") if f in (extra or "")), None)
    rows[iid] = [lua("Quest"), lua(quest), level(req, ilvl)] + ([lua(side)] if side else [])
# Dungeon drops: the pages name the dungeon; their boss headings aren't reliable, so "Trash Drops".
for iid, zone, req, ilvl in c.execute(f"""SELECT DISTINCT i.item_id, s.zone_name, i.req_level, i.item_level
        FROM item_sources s JOIN items i USING (item_id) WHERE {GEAR} AND s.source_origin = 'forevermastery'
        ORDER BY i.item_id"""):
    if iid in have or iid in rows:
        continue
    rows[iid] = [lua("Trash Drops"), lua(zone), level(req, ilvl)]

skipped = collections.Counter()
if everloot:
    def pages(prefix, field):
        for f in sorted(glob.glob(os.path.join(everloot, prefix + "[0-9]*.json"))):
            yield from json.load(open(f, encoding="utf8"))[field]

    zones = {int(k): v for k, v in json.load(open(os.path.join(everloot, "zones.json"))).items() if v}
    instances = set()
    for i in json.load(open(os.path.join(everloot, "instance-map-names.json"), encoding="utf8"))["instances"]:
        zones.setdefault(i["id"], ALIAS.get(i["name"], i["name"]))
        instances.add(zones[i["id"]])
    # Each mob's most reported name, level and map; the map where its loot was opened wins (dungeons).
    names, levels, maps = (collections.defaultdict(collections.Counter) for _ in range(3))
    for r in pages("npc", "records"):
        if all(ord(ch) < 0x250 for ch in r["name"]):  # English names only (some players run other clients)
            names[r["npcId"]][r["name"]] += 1
        levels[r["npcId"]][r.get("level") or 0] += 1
        maps[r["npcId"]][r["mapId"]] += 1
    for r in pages("loot", "records"):
        if r.get("sourceNpcId") and r.get("mapId"):
            maps[r["sourceNpcId"]][r["mapId"]] += 100
    # Quest rewards players saw, most reported title per quest.
    for r in sorted(pages("quest", "records"), key=lambda r: r["questId"]):
        for iid in r.get("rewardItemIds") or []:
            if wanted(iid):
                side = r.get("faction") if r.get("faction") in ("Alliance", "Horde") else None
                rows[iid] = [lua("Quest"), lua(r["title"]), item_level(iid, r.get("level"))] + ([lua(side)] if side else [])
    # Drops (3+ players agree on each rate): the source that dropped the item most often.
    best = {}
    for r in pages("drops", "rates"):
        if r["itemId"] not in best or r["drops"] > best[r["itemId"]]["drops"]:
            best[r["itemId"]] = r
    for iid, r in sorted(best.items()):
        if not wanted(iid):
            continue
        npc = r.get("sourceNpcId")
        name = r.get("sourceName") or (names[npc].most_common(1)[0][0] if npc and names[npc] else None)
        zone = next((zones[m] for m, _ in maps[npc].most_common() if m in zones), None) if npc else None
        if zone in instances and not r.get("sourceName"):  # sightings aren't recorded inside instances
            name = name or "Trash Drops"
        if not npc:  # a chest or other object: they stand in the open world
            name, zone = name or "Treasure Chest", zone or "World chests"
        if not (name and zone):  # mostly random world drops off dungeon mobs (no names, no map inside)
            name, zone = "Random Drops", "Any zone"
            skipped["listed as Random Drops (mob without a name or zone)"] += 1
        lvl = levels[npc].most_common(1)[0][0] if npc and levels[npc] else 0
        rows[iid] = [lua(name), lua(zone), item_level(iid, lvl)]

assert rows, "nothing new"
out = ["-- Generated by make_forever.py: items Data.lua doesn't list. Do not edit by hand.",
       "-- Sources: Forever Mastery (forevermastery.com), used with permission; and",
       "-- Data from Everloot (https://everloot.app), CC BY-SA 4.0, used with permission.",
       "local _, ns = ...", "local S = ns.SOURCES"]
out += [f"S[{iid}] = S[{iid}] or {{ {', '.join(map(str, e))} }}" for iid, e in sorted(rows.items())]
sys.stdout.reconfigure(encoding="utf8", newline="\n")
sys.stdout.write("\n".join(out) + "\n")
print(f"{len(rows)} items; skipped: {dict(skipped)}", file=sys.stderr)
