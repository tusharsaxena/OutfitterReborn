#!/usr/bin/env python3
"""tools/seeds/seeds.py: re-validate Outfitter Reborn's seed ids against one wago.tools build.

WHAT THIS IS
    The defaults/ files ship game ids the addon does not own: aura, form and tracking spell ids,
    creature ids, difficulty ids, Map.db2 and UiMap ids, skill lines, battle-pet species, item ids
    and icon file ids. Each drifts one patch at a time and nothing in the repo turns red when it
    does. This tool reads every such id out of the four seed files, checks each against ONE pinned
    build of the client's own DB2 (wago.tools product `wow` for Retail, `wowf` for WoW Forever,
    Ka0s WoW Addon Standard clients-§10), and turns what it finds into FLAGS and CANDIDATES, each of
    which needs a ruling recorded as data (tools/seeds/rulings_<flavor>.json). A ruling is keyed by
    list and id, never by build, so a re-run on a later build shows only what is new.

    Flags (key `shipped:<kind>:<list>:<id>`, ruled keep or remove), over every shipped id the
    flavor's client reads:
        gone        the build's table has no row for the id
        renamed     the row's name disagrees with the comment or name beside the id
        wrong-kind  the row no longer fits the list: a spell with no aura (or no shapeshift or
                    tracking aura where the list needs one), a map of another InstanceType, a
                    difficulty of another InstanceType, a phantom that is not a weapon or armor,
                    an icon outside Interface/Icons, a pet species of another creature

    Candidates (key `<list>:<id>`, ruled accept or reject), only where a table encodes the rule:
        same-name   a player-learnable spell with a shipped spell's name and the list's aura,
                    not shipped (a rank or a variant); a creature with a shipped NPC's name
        instance    a Map row of InstanceType 3 or 4 that no zone row or brawl list holds
        difficulty  a Difficulty row of a dungeon or raid InstanceType (1, 2) no group lists
        sibling     a UiMap row under the same parent as the shipped Vashj'ir maps
        hand        HAND_CANDIDATES below, each with its reason

    The sources are the four seed files: defaults/TriggerData.lua, defaults/Zones.lua,
    defaults/Items.lua and the icon and skill-line ids in defaults/Triggers.lua. A table that is
    Retail's alone (the quest NPCs, Vashj'ir, Find Fish, the cooking pets, the Retail-only zone and
    trigger rows) is checked on the retail flavor only, as the addon never reads it on Forever.

THE STEPS
    python3 tools/seeds/seeds.py status [--flavor retail|forever]
    python3 tools/seeds/seeds.py derive --flavor F --bundle docs/seed-research/<date>-<F> --date <date> [--build V] [--replay]
    python3 tools/seeds/seeds.py check  --bundle docs/seed-research/<date>-<F>
    python3 tools/seeds/seeds.py rule   --tsv <file> --bundle docs/seed-research/<date>-<F>
    python3 tools/seeds/seeds.py report --bundle docs/seed-research/<date>-<F> --date <date>
    python3 tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-<F> --date <date>

    `derive` pins one build (the live one of the flavor's product, or --build), fetches each table
    into the git-ignored .cache/ (streamed, never read whole), writes the bundle's raw/*.csv.gz,
    SOURCES.md and candidates.json. `--replay` re-derives from the bundle's raw/ alone, offline.
    The big tables are trimmed in raw/ to the rows the derivation reads (TRIM below); SOURCES.md
    records each full download's size and sha256 so the trim can be checked against the source.
    `rule` is the only writer of the rulings file. `check` exits 1 while anything is unruled.
    `report` writes RULINGS.md. `apply` refuses while anything is unruled, writes accepted ids and
    ruled removals into the seed files where the list has a mechanical place for them (and refuses,
    naming the list, where it does not), keeps each file's line endings and layout, and is
    idempotent. The date is always an argument; nothing here reads the clock.

Python 3.8+ and its standard library only. The shape (status, derive, rule, check, report, apply;
rulings as data keyed by id) is copied from AuraMaster's tools/spell-research/retail.py; nothing is
imported across repos. Whether a shared helper should carry the build pin, the cache, the bundle and
the rulings is decided in LibKa0s#91.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import io
import json
import re
import shutil
import sys
import urllib.error
import urllib.request
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
RESEARCH = ROOT / "docs" / "seed-research"
SEED_FILES = ("defaults/TriggerData.lua", "defaults/Zones.lua", "defaults/Items.lua", "defaults/Triggers.lua")

BUILDS_URL = "https://wago.tools/api/builds"
CSV_URL = "https://wago.tools/db2/{table}/csv?build={build}"
# wago.tools answers HTTP 403 to urllib's default agent (clients-§10): say who is asking.
USER_AGENT = "ka0s-seed-validation (OutfitterReborn tools/seeds)"
CHUNK = 1 << 20
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

FLAVORS = {
    "retail": {"product": "wow", "title": "Retail"},
    "forever": {"product": "wowf", "title": "WoW Forever"},
}

# The tables each flavor reads, and why. This tuple IS the fetch list SOURCES.md records.
TABLES = (
    ("SpellName", "spell names: existence, the comment check, the same-name candidates", ("retail", "forever")),
    ("SpellEffect", "Effect / EffectAura on DifficultyID 0: the aura, shapeshift and tracking kind checks", ("retail", "forever")),
    ("SkillLineAbility", "Spell -> SkillLine: a same-name candidate must be learnable on a player line", ("retail", "forever")),
    ("SkillLine", "DisplayName_lang of the profession lines; the line names that fence pet lines out", ("retail", "forever")),
    ("Difficulty", "InstanceType of each difficulty id; the difficulty candidates", ("retail", "forever")),
    ("Map", "InstanceType 3 (battleground) / 4 (arena) of every zone row's map id; the instance candidates", ("retail", "forever")),
    ("Item", "ClassID / InventoryType: the phantom and lance kind checks", ("retail", "forever")),
    ("ItemSparse", "Display_lang: item existence and the comment check", ("retail", "forever")),
    ("ManifestInterfaceData", "FilePath of each icon file id", ("retail", "forever")),
    ("Creature", "Name_lang of the quest NPCs and the cooking pets (Retail-only lists)", ("retail",)),
    ("UiMap", "Name_lang / ParentUiMapID of the Vashj'ir uiMaps (a Retail-only list)", ("retail",)),
    ("BattlePetSpecies", "CreatureID of the cooking pets' species (a Retail-only list)", ("retail",)),
)

# Effects that put an aura on a unit (SpellEffect.Effect): APPLY_AURA, PERSISTENT_AREA_AURA,
# APPLY_AREA_AURA_PARTY, APPLY_AREA_AURA_RAID, APPLY_AREA_AURA_PET, APPLY_AREA_AURA_FRIEND,
# APPLY_AREA_AURA_ENEMY, APPLY_AREA_AURA_OWNER, APPLY_AURA_ON_PET, APPLY_AREA_AURA_SUMMONS.
AURA_EFFECTS = frozenset((6, 27, 35, 65, 119, 128, 129, 143, 174, 202))
AURA_SHAPESHIFT = 36       # SPELL_AURA_MOD_SHAPESHIFT
AURA_TRACK_RESOURCES = 45  # SPELL_AURA_TRACK_RESOURCES (Find Fish)
# SkillLine names that are not a player's: a hunter pet's own spells are not the player's aura.
PET_LINE = re.compile(r"^(Pet - |Beast Training$)")
# Difficulty.InstanceType per group: 1 party, 2 raid, 5 scenario (Delves is a scenario row).
GROUP_INSTANCE_TYPE = {"dungeonNormal": 1, "dungeonHeroic": 1, "dungeonMythic": 1, "mythicPlus": 1,
                       "raidFinder": 2, "raidNormal": 2, "raidHeroic": 2, "raidMythic": 2,
                       "raid20": 2, "raid40": 2, "delve": 5}
DIFFICULTY_CANDIDATE_TYPES = (1, 2)
ZONE_KIND_TYPE = {"bg": 3, "brawl": 3, "arena": 4}
WEAPON_OR_ARMOR = (2, 4)   # Item.ClassID: Weapon, Armor (shields and held off-hands are Armor)

# THE HAND CANDIDATES: ids the mechanical rules cannot propose, proposed where the file's own rules
# would file them. Each still needs a ruling. (flavor, list, id, why)
HAND_CANDIDATES = (
    ("forever", "FORM_SPELL_STATE", 9634,
     "Dire Bear Form replaces Bear Form at level 40 on a vanilla client (its own form, not a rank of 5487)"),
)

CANDIDATE_RULINGS = ("accept", "reject")
FLAG_RULINGS = ("keep", "remove")
FLAG_KINDS = ("gone", "renamed", "wrong-kind")
KEY = re.compile(r"^(?:shipped:(?P<kind>[a-z-]+):)?(?P<list>[A-Za-z_.]+):(?P<id>\d+)$")


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


# ---------------------------------------------------------------------------
# Writing files the repo pins CRLF (.gitattributes `* text=auto eol=crlf`)
# ---------------------------------------------------------------------------

def write_crlf(path: Path, text: str) -> None:
    """Text with CRLF terminators, as bytes, so the eol suite agrees with git (line-endings-§2)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8"))


def write_json(path: Path, doc) -> None:
    write_crlf(path, json.dumps(doc, indent=1, sort_keys=True, ensure_ascii=False) + "\n")


# ---------------------------------------------------------------------------
# The seed files
# ---------------------------------------------------------------------------

class Seed:
    """One shipped id: the list it is in, its kind, the name beside it, the clients that read it."""

    __slots__ = ("list", "kind", "id", "name", "clients", "extra", "file")

    def __init__(self, lst, kind, sid, name, clients, file, **extra):
        self.list, self.kind, self.id, self.name = lst, kind, int(sid), (name or "").strip()
        self.clients, self.file, self.extra = tuple(clients), file, extra

    def __repr__(self):
        return "Seed(%s %s %d %r %s)" % (self.list, self.kind, self.id, self.name, self.clients)


BOTH = ("retail", "forever")
RETAIL = ("retail",)


def block(text: str, opener: str) -> str:
    """The body of the brace block that starts at the first `opener` (a literal), braces balanced."""
    start = text.find(opener)
    if start < 0:
        raise SystemExit("seed parse: %r not found" % opener)
    i = text.index("{", start)
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[i + 1:j]
    raise SystemExit("seed parse: %r has no closing brace" % opener)


ENTRY = re.compile(r"\[(\d+)\]\s*=\s*([^,\n]+?)\s*,?[ \t]*(?:--[ \t]*(.*))?$", re.M)
ARRAY_ENTRY = re.compile(r"^\s*(\d+)\s*,[ \t]*(?:--[ \t]*(.*))?$", re.M)


def keyed(body: str):
    """`[id] = value, -- comment` lines: [(id, value, comment)]."""
    return [(int(m.group(1)), m.group(2).strip(), (m.group(3) or "").strip()) for m in ENTRY.finditer(body)]


def parse_trigger_data(text: str, file: str) -> list:
    out = []
    for sid, _v, _c in keyed(block(text, "D.AURA_ICON_STATE = {")):
        out.append(Seed("AURA_ICON_STATE", "icon", sid, "", BOTH, file))
    for sid, value, comment in keyed(block(text, "D.AURA_SPELL_STATE = {")):
        out.append(Seed("AURA_SPELL_STATE", "spell", sid, comment, BOTH, file, aura="any", value=value))
    m = re.search(r"D\.AURA_SPELL_STATE\[NS\.PerClient\(\{\s*retail\s*=\s*(\d+),\s*forever\s*=\s*(\d+)\s*\}\)\]"
                  r"\s*=\s*(\"\w+\")\s*--\s*(.*)", text)
    if not m:
        raise SystemExit("seed parse: the per-client Shadowmeld line is gone from %s" % file)
    out.append(Seed("AURA_SPELL_STATE", "spell", m.group(1), m.group(4), RETAIL, file, aura="any",
                    value=m.group(3), perClient=True))
    out.append(Seed("AURA_SPELL_STATE", "spell", m.group(2), m.group(4), ("forever",), file, aura="any",
                    value=m.group(3), perClient=True))
    for sid, value, comment in keyed(block(text, "D.FORM_SPELL_STATE = {")):
        out.append(Seed("FORM_SPELL_STATE", "spell", sid, comment, BOTH, file, aura="shapeshift", value=value))
    for m in re.finditer(r"D\.FORM_SPELL_STATE\[(\d+)\]\s*=\s*NS\.PerClient\(\{\s*(\w+)\s*=\s*(\"\w+\")\s*\}\)"
                         r"\s*--\s*(.*)", text):
        out.append(Seed("FORM_SPELL_STATE", "spell", m.group(1), m.group(4), (m.group(2),), file,
                        aura="shapeshift", value=m.group(3), perClient=True))
    region = text[text.index("local ARGENT_EITHER"):text.index("setmetatable(D.ARGENT_MOUNTS")]
    for sid, _v, comment in keyed(region):
        out.append(Seed("ARGENT_MOUNTS", "creature", sid, comment, RETAIL, file))
    vig = re.search(r"Vigilance on Wings: (.+?), every variant.*\n(D\.VIGILANCE_NPCS = \{[^}]*\})", text)
    if not vig:
        raise SystemExit("seed parse: VIGILANCE_NPCS (and its header) not found in %s" % file)
    for sid, _v, _c in keyed(vig.group(2).replace(",", ",\n")):
        out.append(Seed("VIGILANCE_NPCS", "creature", sid, vig.group(1), RETAIL, file, inline=True))
    for sid, _v, comment in keyed(block(text, "D.LEVIATHAN_NPCS = {")):
        out.append(Seed("LEVIATHAN_NPCS", "creature", sid, comment, RETAIL, file))
    for flavor, opener in (("retail", "local RETAIL_DIFFICULTY_GROUPS = {"),
                           ("forever", "local FOREVER_DIFFICULTY_GROUPS = {")):
        for m in re.finditer(r"^\s*(\w+)\s*=\s*\{([^}]*)\}", block(text, opener), re.M):
            for sid in re.findall(r"\d+", m.group(2)):
                if int(sid) == 0:
                    continue  # 0 is "outside an instance", not a Difficulty row
                out.append(Seed("DIFFICULTY_GROUPS." + m.group(1), "difficulty", sid, "", (flavor,), file,
                                group=m.group(1), opener=opener))
    for m in ARRAY_ENTRY.finditer(block(text, "D.VASHJIR_MAP_IDS = {")):
        out.append(Seed("VASHJIR_MAP_IDS", "uimap", m.group(1), m.group(2), RETAIL, file))
    for m in re.finditer(r"^\s*(\w+)\s*=\s*(\d+),", block(text, "D.SKILL_LINES = {"), re.M):
        out.append(Seed("SKILL_LINES", "skillline", m.group(2), m.group(1).title(), BOTH, file))
    fish = re.search(r"D\.FIND_FISH = \{ spell = (\d+), texture = (\d+) \}", text)
    if not fish:
        raise SystemExit("seed parse: D.FIND_FISH not found in %s" % file)
    out.append(Seed("FIND_FISH", "spell", fish.group(1), "Find Fish", RETAIL, file, aura="track"))
    out.append(Seed("FIND_FISH", "icon", fish.group(2), "", RETAIL, file))
    creatures = dict((n.strip(), int(c)) for n, c in
                     re.findall(r"([A-Z][\w' ]*?) (?:is )?creature (\d+)", text[text.index("COOKING trigger's pets"):]))
    for m in re.finditer(r"species = (\d+) \},\s*--\s*(.*)", block(text, "D.COOKING_PETS = {")):
        name = m.group(2).strip()
        out.append(Seed("COOKING_PETS", "battlepet", m.group(1), name, RETAIL, file, creature=creatures.get(name)))
    return out


def zone_rows(text: str) -> list:
    """`[(row id, row text, trailing comment)]` of Z.rows, each row's braces balanced."""
    body, out, i = block(text, "Z.rows = {"), [], 0
    while True:
        start = body.find('{ id = "', i)
        if start < 0:
            return out
        depth, j = 0, start
        while True:
            depth += {"{": 1, "}": -1}.get(body[j], 0)
            if depth == 0:
                break
            j += 1
        tail = body[j + 1:].split("\n", 1)[0]
        comment = tail.split("--", 1)[1].strip() if "--" in tail else ""
        rid = re.match(r'\{ id = "(\w+)"', body[start:]).group(1)
        out.append((rid, body[start:j + 1], comment))
        i = j + 1


def zone_row_clients(text: str) -> dict:
    """{zone row id: clients}, for the zone triggers' icons."""
    return {rid: (RETAIL if "clients = RETAIL" in row else BOTH) for rid, row, _c in zone_rows(text)}


def parse_zones(text: str, file: str) -> list:
    out = []
    for rid, row, comment in zone_rows(text):
        kind = re.search(r'kind = "(\w+)"', row).group(1)
        ids = re.search(r"mapIDs = \{([^}]*)\}", row)
        if not ids:
            continue  # a generic row matches by instance type and holds no id
        clients = RETAIL if "clients = RETAIL" in row else BOTH
        for sid in re.findall(r"\d+", ids.group(1)):
            out.append(Seed("Zones." + rid, "map", sid, comment, clients, file, zoneKind=kind, row=rid))
    brawl = re.search(r"Z\.ALL_BRAWL_MAP_IDS = \{([^}]*)\}", text)
    if not brawl:
        raise SystemExit("seed parse: Z.ALL_BRAWL_MAP_IDS not found in %s" % file)
    for sid in re.findall(r"\d+", brawl.group(1)):
        out.append(Seed("Zones.BRAWL", "map", sid, "", RETAIL, file, zoneKind="brawl", row="BRAWL"))
    return out


def parse_items(text: str, file: str) -> list:
    out = []
    lances = re.search(r"local ARGENT_LANCE, ALLIANCE_LANCE, HORDE_LANCE = (\d+), (\d+), (\d+)", text)
    if not lances:
        raise SystemExit("seed parse: the lance constants are gone from %s" % file)
    const = {"ARGENT_LANCE": int(lances.group(1)), "ALLIANCE_LANCE": int(lances.group(2)),
             "HORDE_LANCE": int(lances.group(3))}
    body = block(text, "ID.ALIASES = {")
    for m in re.finditer(r"^\s*\[(\w+)\]\s*=\s*\w+,[ \t]*--[ \t]*(.*?) ->", body, re.M):
        key = m.group(1)
        sid = int(key) if key.isdigit() else const[key]
        out.append(Seed("ITEM.ALIASES", "item", sid, m.group(2), BOTH, file, weapon=not key.isdigit(),
                        constant=not key.isdigit()))
    for lst, opener in (("ITEM.IGNORED_UNUSED", "ID.IGNORED_UNUSED = {"), ("ITEM.PHANTOM_IDS", "ID.PHANTOM_IDS = {"),
                        ("ITEM.CORRECTIONS", "ID.CORRECTIONS = {")):
        for m in re.finditer(r"^\s*\[(\d+)\]\s*=\s*.*?--[ \t]*(.*)$", block(text, opener), re.M):
            out.append(Seed(lst, "item", m.group(1), m.group(2), BOTH, file, weapon=lst == "ITEM.PHANTOM_IDS",
                            opener=opener))
    return out


def parse_triggers(text: str, file: str, zone_clients: dict) -> list:
    out = []
    rows = block(text, "C.rows = {")
    chunks = re.split(r"\n(?=    \{ id = \"|    druidForm\()", rows)
    for chunk in chunks:
        m = re.match(r"\s*\{ id = \"(\w+)\"", chunk)
        if m:
            rid = m.group(1)
            head = chunk.split("params", 1)[0]
            clients = RETAIL if re.search(r"^\s*\{ id = [^\n]*clients = RETAIL", chunk) else BOTH
            icon = re.search(r"icon = (\d+)", head)
            if icon:
                out.append(Seed("ICONS.Triggers", "icon", icon.group(1), rid, clients, file))
            for sl in re.findall(r"skillLine = (\d+)", chunk):
                out.append(Seed("SKILL_LINES.Triggers", "skillline", sl, "", clients, file, row=rid))
            continue
        m = re.match(r"\s*druidForm\(\"(\w+)\".*?\"FORM_\w+\", (\d+)(, RETAIL)?\)", chunk, re.S)
        if m:
            out.append(Seed("ICONS.Triggers", "icon", m.group(2), m.group(1), RETAIL if m.group(3) else BOTH, file))
    for zid, icon in re.findall(r"(\w+) = (\d+)", block(text, "C.ZONE_ICONS = {")):
        out.append(Seed("ICONS.ZONE_ICONS", "icon", icon, zid, zone_clients.get(zid, BOTH), file))
    return out


def read_seeds(root: Path = ROOT) -> list:
    texts = {f: (root / f).read_bytes().decode("utf-8").replace("\r\n", "\n") for f in SEED_FILES}
    seeds = parse_trigger_data(texts["defaults/TriggerData.lua"], "defaults/TriggerData.lua")
    seeds += parse_zones(texts["defaults/Zones.lua"], "defaults/Zones.lua")
    seeds += parse_items(texts["defaults/Items.lua"], "defaults/Items.lua")
    seeds += parse_triggers(texts["defaults/Triggers.lua"], "defaults/Triggers.lua",
                            zone_row_clients(texts["defaults/Zones.lua"]))
    check_parse(seeds)
    return seeds


# A thin parse reads as a clean diff, so the parse has a floor per list (layout: fail loudly).
PARSE_FLOOR = {"AURA_ICON_STATE": 2, "AURA_SPELL_STATE": 5, "FORM_SPELL_STATE": 6, "ARGENT_MOUNTS": 16,
               "VIGILANCE_NPCS": 4, "LEVIATHAN_NPCS": 3, "VASHJIR_MAP_IDS": 3, "SKILL_LINES": 5,
               "FIND_FISH": 2, "COOKING_PETS": 2, "Zones.BRAWL": 4, "ITEM.ALIASES": 7,
               "ITEM.IGNORED_UNUSED": 12, "ITEM.PHANTOM_IDS": 18, "ITEM.CORRECTIONS": 3,
               "ICONS.Triggers": 20, "ICONS.ZONE_ICONS": 6, "SKILL_LINES.Triggers": 3}


def check_parse(seeds: list) -> None:
    counts = defaultdict(int)
    for s in seeds:
        counts[s.list] += 1
    zones = sum(n for k, n in counts.items() if k.startswith("Zones.") and k != "Zones.BRAWL")
    short = ["%s %d < %d" % (k, counts[k], n) for k, n in PARSE_FLOOR.items() if counts[k] < n]
    if zones < 40:
        short.append("zone map ids %d < 40" % zones)
    if sum(1 for s in seeds if s.kind == "difficulty") < 15:
        short.append("difficulty ids < 15")
    if short:
        raise SystemExit("seed parse came up thin (%s): fix the parser before ruling anything." % "; ".join(short))


def for_flavor(seeds: list, flavor: str) -> list:
    return [s for s in seeds if flavor in s.clients]


# ---------------------------------------------------------------------------
# The build's tables
# ---------------------------------------------------------------------------

def http_get(url: str, accept: str = "*/*"):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": accept})
    try:
        return urllib.request.urlopen(req, timeout=300)
    except urllib.error.HTTPError as err:
        raise SystemExit("HTTP %s fetching %s: %s" % (err.code, url, err.reason))
    except urllib.error.URLError as err:
        raise SystemExit("Could not reach %s: %s" % (url, err.reason))


def live_build(product: str) -> dict:
    """The newest build of `product` from the builds API (JSON keyed by product, newest first)."""
    data = json.load(http_get(BUILDS_URL, "application/json"))
    builds = data.get(product) or []
    if not builds:
        raise SystemExit("The builds API lists no %r builds; pass --build." % product)
    return builds[0]


def fetch(table: str, build: str, cache: Path) -> Path:
    """One table's CSV in the cache, streamed to disk through a .part file."""
    cache.mkdir(parents=True, exist_ok=True)
    dest = cache / ("%s-%s.csv" % (table, build))
    if dest.exists():
        return dest
    tmp = dest.with_suffix(".csv.part")
    url = CSV_URL.format(table=table, build=build)
    log("  %-22s fetching %s" % (table, url))
    with http_get(url, "text/csv") as response, tmp.open("wb") as handle:
        shutil.copyfileobj(response, handle, CHUNK)
    tmp.replace(dest)
    return dest


def open_csv(path: Path):
    if path.suffix == ".gz":
        return io.TextIOWrapper(gzip.open(path, "rb"), encoding="utf-8", newline="")
    return path.open("r", encoding="utf-8", newline="")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(CHUNK), b""):
            h.update(chunk)
    return h.hexdigest()


def load_rows(path: Path, keep) -> tuple:
    """`(header, [row dict])` of the rows `keep(row)` admits, streamed one row at a time."""
    with open_csv(path) as handle:
        reader = csv.DictReader(handle)
        rows = [row for row in reader if keep(row)]
        return reader.fieldnames, rows


def write_raw(path: Path, header, rows) -> None:
    """A deterministic .csv.gz (mtime 0): the same rows give the same bytes."""
    path.parent.mkdir(parents=True, exist_ok=True)
    buf = io.StringIO(newline="")
    writer = csv.DictWriter(buf, fieldnames=header, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    with path.open("wb") as raw, gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0, compresslevel=9) as gz:
        gz.write(buf.getvalue().encode("utf-8"))


def norm(name: str) -> str:
    return re.sub(r"\s+", " ", (name or "").replace("’", "'")).strip().casefold()


def tables_for(flavor: str) -> list:
    return [(t, why) for t, why, flavors in TABLES if flavor in flavors]


class DB:
    """The rows of one build the derivation reads, from the cache (full) or a bundle's raw/ (trimmed).

    Creature.db2 is a SUBSET: the client carries the creatures it draws itself (companions, mounts,
    some NPCs; 23,167 rows of ids up to 276,385 on Retail 12.1.5.70783), and most NPCs come from the
    server. So a quest NPC the table lacks is UNCHECKABLE, never `gone` (shipped_flags).

    TRIM: SpellName keeps the shipped spell ids and every row sharing a shipped spell's name (the
    name beside it in the file, or the shipped id's own name on the build);
    SpellEffect and SkillLineAbility keep the rows of those spells; Creature keeps the shipped NPC
    ids and every row sharing a shipped NPC's name; Item, ItemSparse and ManifestInterfaceData keep
    the shipped ids. The other tables are kept whole. Every filter is idempotent, so a replay of the
    trimmed raw/ admits the same rows the first run read."""

    def __init__(self, seeds: list, flavor: str, source):
        self.flavor, self.kept, self.headers = flavor, {}, {}
        self.full = {}
        spells = {s.id for s in seeds if s.kind == "spell"} | {h[2] for h in HAND_CANDIDATES if h[0] == flavor}
        spell_names = {norm(s.name) for s in seeds if s.kind == "spell" and s.name}
        npcs = {s.id for s in seeds if s.kind == "creature"} | {s.extra.get("creature") for s in seeds
                                                                 if s.kind == "battlepet"}
        pets = {s.id for s in seeds if s.kind == "battlepet"}
        npc_names = {norm(s.name) for s in seeds if s.kind in ("creature", "battlepet") and s.name}
        items = {s.id for s in seeds if s.kind == "item"}
        icons = {s.id for s in seeds if s.kind == "icon"}

        def by_id(ids):
            return lambda row: int(row["ID"]) in ids

        # Two passes: the shipped ids' own names join the comments', so a qualified comment
        # (`rogue Stealth`) still admits every row named `Stealth`.
        _h, own = load_rows(source("SpellName"), lambda r: int(r["ID"]) in spells)
        spell_names |= {norm(r["Name_lang"]) for r in own}
        sn = self._load("SpellName", source, lambda r: int(r["ID"]) in spells or norm(r["Name_lang"]) in spell_names)
        self.spell_names = {int(r["ID"]): r["Name_lang"] for r in sn}
        universe = set(self.spell_names)
        self.effects = defaultdict(list)
        for r in self._load("SpellEffect", source, lambda r: int(r["SpellID"]) in universe):
            if int(r["DifficultyID"] or 0) == 0:
                self.effects[int(r["SpellID"])].append((int(r["Effect"]), int(r["EffectAura"])))
        self.skill_lines = {int(r["ID"]): r for r in self._load("SkillLine", source, lambda r: True)}
        self.learned = defaultdict(set)
        for r in self._load("SkillLineAbility", source, lambda r: int(r["Spell"]) in universe):
            self.learned[int(r["Spell"])].add(int(r["SkillLine"]))
        self.difficulty = {int(r["ID"]): r for r in self._load("Difficulty", source, lambda r: True)}
        self.maps = {int(r["ID"]): r for r in self._load("Map", source, lambda r: True)}
        self.items = {int(r["ID"]): r for r in self._load("Item", source, by_id(items))}
        self.item_names = {int(r["ID"]): r["Display_lang"] for r in self._load("ItemSparse", source, by_id(items))}
        self.files = {int(r["ID"]): (r["FilePath"] + r["FileName"]).replace("\\", "/")
                      for r in self._load("ManifestInterfaceData", source, by_id(icons))}
        self.creatures, self.uimaps, self.species = {}, {}, {}
        if flavor == "retail":
            self.creatures = {int(r["ID"]): r["Name_lang"] for r in self._load(
                "Creature", source, lambda r: int(r["ID"]) in npcs or norm(r["Name_lang"]) in npc_names)}
            self.uimaps = {int(r["ID"]): r for r in self._load("UiMap", source, lambda r: True)}
            self.species = {int(r["ID"]): r for r in self._load("BattlePetSpecies", source, by_id(pets))}

    def _load(self, table: str, source, keep):
        path = source(table)
        header, rows = load_rows(path, keep)
        self.kept[table], self.headers[table] = rows, header
        return rows

    def auras(self, spell: int) -> set:
        return {aura for effect, aura in self.effects.get(spell, ()) if effect in AURA_EFFECTS}

    def applies_aura(self, spell: int) -> bool:
        return any(effect in AURA_EFFECTS for effect, _a in self.effects.get(spell, ()))

    def player_learnable(self, spell: int) -> bool:
        for line in self.learned.get(spell, ()):
            row = self.skill_lines.get(line)
            if row is not None and not PET_LINE.match(row["DisplayName_lang"]):
                return True
        return False


# ---------------------------------------------------------------------------
# Flags and candidates
# ---------------------------------------------------------------------------

def name_matches(shipped: str, actual: str) -> bool:
    """The comment names the row: equal, or the row's name after a qualifier (`rogue Stealth`,
    `Monk, Fists of the Heavens`)."""
    a, b = norm(shipped), norm(actual)
    return a == b or a.endswith(" " + b) or a.endswith(", " + b)


def lookup(db: DB, s: Seed):
    """`(name or None when gone, wrong-kind reason or None, notes)` of one shipped id."""
    if s.kind == "spell":
        name = db.spell_names.get(s.id)
        if name is None:
            return None, None, []
        aura, auras = s.extra.get("aura"), db.auras(s.id)
        notes = ["auras: %s" % (", ".join(str(a) for a in sorted(auras)) or "none")]
        if aura == "any" and not db.applies_aura(s.id):
            return name, "applies no aura", notes
        if aura == "shapeshift" and AURA_SHAPESHIFT not in auras:
            return name, "no shapeshift aura (36)", notes
        if aura == "track" and AURA_TRACK_RESOURCES not in auras:
            return name, "no resource-tracking aura (45)", notes
        return name, None, notes
    if s.kind == "creature":
        return db.creatures.get(s.id), None, []
    if s.kind == "difficulty":
        row = db.difficulty.get(s.id)
        if row is None:
            return None, None, []
        want, got = GROUP_INSTANCE_TYPE[s.extra["group"]], int(row["InstanceType"])
        notes = ["%s, InstanceType %d" % (row["Name_lang"], got)]
        return row["Name_lang"], (None if got == want else "InstanceType %d, the group needs %d" % (got, want)), notes
    if s.kind == "map":
        row = db.maps.get(s.id)
        if row is None:
            return None, None, []
        want, got = ZONE_KIND_TYPE[s.extra["zoneKind"]], int(row["InstanceType"])
        notes = ["%s, InstanceType %d" % (row["MapName_lang"], got)]
        return row["MapName_lang"], (None if got == want else "InstanceType %d, a %s row needs %d"
                                     % (got, s.extra["zoneKind"], want)), notes
    if s.kind == "uimap":
        row = db.uimaps.get(s.id)
        return (row["Name_lang"] if row else None), None, []
    if s.kind == "skillline":
        row = db.skill_lines.get(s.id)
        return (row["DisplayName_lang"] if row else None), None, []
    if s.kind == "battlepet":
        row = db.species.get(s.id)
        if row is None:
            return None, None, []
        creature = int(row["CreatureID"])
        name = db.creatures.get(creature, "")
        bad = None
        if s.extra.get("creature") and creature != s.extra["creature"]:
            bad = "species summons creature %d, the header says %d" % (creature, s.extra["creature"])
        return name, bad, ["creature %d" % creature]
    if s.kind == "item":
        name = db.item_names.get(s.id)
        if name is None:
            return None, None, []
        row = db.items.get(s.id) or {}
        cls = int(row.get("ClassID") or -1)
        notes = ["ClassID %s, SubclassID %s, InventoryType %s" % (row.get("ClassID"), row.get("SubclassID"),
                                                                   row.get("InventoryType"))]
        if s.extra.get("weapon") and cls not in WEAPON_OR_ARMOR:
            return name, "ClassID %d is neither a weapon nor armor" % cls, notes
        return name, None, notes
    if s.kind == "icon":
        path = db.files.get(s.id)
        if path is None:
            return None, None, []
        bad = None if path.lower().startswith("interface/icons/") else "not under Interface/Icons"
        return path, bad, []
    raise SystemExit("unknown seed kind %r" % s.kind)


def shipped_flags(db: DB, seeds: list, uncheckable: list) -> list:
    out, seen = [], set()
    for s in seeds:
        name, bad, notes = lookup(db, s)
        kinds = []
        if name is None and s.kind == "creature":
            uncheckable.append({"list": s.list, "id": s.id, "comment": s.name,
                                "why": "Creature.db2 carries a subset; the server supplies this NPC"})
            continue
        if name is None:
            kinds.append(("gone", ""))
        else:
            if s.name and s.kind not in ("map", "icon", "difficulty") and not name_matches(s.name, name):
                kinds.append(("renamed", ""))
            if bad:
                kinds.append(("wrong-kind", bad))
        for kind, why in kinds:
            key = "shipped:%s:%s:%d" % (kind, s.list, s.id)
            if key in seen:
                continue
            seen.add(key)
            out.append({"key": key, "kind": kind, "list": s.list, "id": s.id, "file": s.file,
                        "comment": s.name, "name": name or "", "why": why, "notes": notes})
    return out


def candidate(lst, sid, name, source, notes, target=None) -> dict:
    return {"key": "%s:%d" % (lst, sid), "list": lst, "id": sid, "name": name, "source": source,
            "notes": notes, "target": target}


def spell_candidates(db: DB, seeds: list) -> list:
    out = []
    for lst, aura in (("AURA_SPELL_STATE", "any"), ("FORM_SPELL_STATE", "shapeshift")):
        shipped = {s.id for s in seeds if s.list == lst}
        names = {norm(s.name): s for s in seeds if s.list == lst}
        by_name = {norm(db.spell_names[s.id]): s for s in seeds if s.list == lst and s.id in db.spell_names}
        names.update(by_name)
        for sid, name in sorted(db.spell_names.items()):
            twin = names.get(norm(name))
            if twin is None or sid in shipped or not db.player_learnable(sid):
                continue
            auras = db.auras(sid)
            fits = db.applies_aura(sid) if aura == "any" else AURA_SHAPESHIFT in auras
            if not fits:
                continue
            lines = sorted(db.skill_lines[ln]["DisplayName_lang"] for ln in db.learned[sid] if ln in db.skill_lines)
            out.append(candidate(lst, sid, name, "same-name",
                                 ["twin of %d" % twin.id, "lines: " + ", ".join(lines),
                                  "auras: " + ", ".join(str(a) for a in sorted(auras))]))
    return out


def creature_candidates(db: DB, seeds: list) -> list:
    out = []
    for lst in ("ARGENT_MOUNTS", "VIGILANCE_NPCS", "LEVIATHAN_NPCS"):
        mine = [s for s in seeds if s.list == lst]
        if not mine:
            continue
        shipped = {s.id for s in mine}
        names = {norm(db.creatures.get(s.id) or s.name) for s in mine}
        for cid, name in sorted(db.creatures.items()):
            if cid not in shipped and norm(name) in names:
                out.append(candidate(lst, cid, name, "same-name", [],
                                     target=None if lst == "ARGENT_MOUNTS" else lst))
    return out


def map_candidates(db: DB, seeds: list) -> list:
    held = {s.id for s in seeds if s.kind == "map"}
    out = []
    for mid, row in sorted(db.maps.items()):
        itype = int(row["InstanceType"] or 0)
        if itype in (3, 4) and mid not in held:
            out.append(candidate("Zones.NEW", mid, row["MapName_lang"], "instance",
                                 ["InstanceType %d (%s)" % (itype, "battleground" if itype == 3 else "arena"),
                                  "ExpansionID %s" % row.get("ExpansionID")]))
    return out


def difficulty_candidates(db: DB, seeds: list) -> list:
    held = {s.id for s in seeds if s.kind == "difficulty"}
    out = []
    for did, row in sorted(db.difficulty.items()):
        itype = int(row["InstanceType"] or 0)
        if itype in DIFFICULTY_CANDIDATE_TYPES and did not in held:
            out.append(candidate("DIFFICULTY_GROUPS.NONE", did, row["Name_lang"], "difficulty",
                                 ["InstanceType %d" % itype, "MaxPlayers %s" % row.get("MaxPlayers")]))
    return out


def uimap_candidates(db: DB, seeds: list) -> list:
    mine = [s for s in seeds if s.list == "VASHJIR_MAP_IDS"]
    parents = {db.uimaps[s.id]["ParentUiMapID"] for s in mine if s.id in db.uimaps}
    shipped = {s.id for s in mine}
    out = []
    if len(parents) == 1:
        parent = parents.pop()
        for uid, row in sorted(db.uimaps.items()):
            if row["ParentUiMapID"] == parent and uid not in shipped:
                out.append(candidate("VASHJIR_MAP_IDS", uid, row["Name_lang"], "sibling",
                                     ["parent uiMap %s" % parent, "Type %s" % row["Type"]], target="VASHJIR_MAP_IDS"))
    return out


def hand_candidates(db: DB, flavor: str, missing: list) -> list:
    out = []
    for fl, lst, sid, why in HAND_CANDIDATES:
        if fl != flavor:
            continue
        if sid not in db.spell_names:
            missing.append({"list": lst, "id": sid, "why": why})
            continue
        out.append(candidate(lst, sid, db.spell_names[sid], "hand",
                             ["hand: " + why, "auras: " + ", ".join(str(a) for a in sorted(db.auras(sid)))]))
    return out


def derive(db: DB, seeds: list, flavor: str) -> dict:
    missing: list = []
    uncheckable: list = []
    cands = spell_candidates(db, seeds) + map_candidates(db, seeds) + difficulty_candidates(db, seeds)
    if flavor == "retail":
        cands += creature_candidates(db, seeds) + uimap_candidates(db, seeds)
    cands += hand_candidates(db, flavor, missing)
    seen, unique = set(), []
    for c in cands:
        if c["key"] not in seen:
            seen.add(c["key"])
            unique.append(c)
    return {"candidates": sorted(unique, key=lambda c: (c["list"], c["id"])),
            "flags": shipped_flags(db, seeds, uncheckable), "handMissing": missing,
            "uncheckable": uncheckable,
            "shipped": len({(s.list, s.id) for s in seeds}),
            "shippedByKind": dict(sorted(_count(seeds).items()))}


def _count(seeds):
    out = defaultdict(set)
    for s in seeds:
        out[s.kind].add((s.list, s.id))
    return {k: len(v) for k, v in out.items()}


# ---------------------------------------------------------------------------
# Bundles
# ---------------------------------------------------------------------------

def bundles(flavor: str, root: Path = RESEARCH) -> list:
    return sorted(p for p in root.glob("*-" + flavor) if (p / "candidates.json").exists())


def status_line(live: str, found: list) -> str:
    """`CURRENT <build> (<bundle>)` or `NEW <build> ...`: the first word is what the command reads."""
    if not found:
        return "NEW %s (no bundle yet)" % live
    last = found[-1]
    built = json.loads(last.joinpath("candidates.json").read_text(encoding="utf-8"))["build"]
    if built == live:
        return "CURRENT %s (%s)" % (live, last.name)
    return "NEW %s (last ruled %s, %s)" % (live, built, last.name)


def load_doc(bundle: Path) -> dict:
    path = bundle / "candidates.json"
    if not path.exists():
        raise SystemExit("%s has no candidates.json: run derive first." % bundle)
    return json.loads(path.read_text(encoding="utf-8"))


def rulings_path(flavor: str) -> Path:
    return HERE / ("rulings_%s.json" % flavor)


def load_rulings(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def all_keys(doc: dict) -> list:
    return [c["key"] for c in doc["candidates"]] + [f["key"] for f in doc["flags"]]


def unruled(doc: dict, rulings: dict) -> list:
    return [k for k in all_keys(doc) if k not in rulings]


def set_ruling(rulings: dict, key: str, ruling: str, reason: str) -> None:
    m = KEY.match(key)
    if not m:
        raise SystemExit("%r is not <list>:<id> or shipped:<kind>:<list>:<id>." % key)
    kind = m.group("kind")
    if kind and kind not in FLAG_KINDS:
        raise SystemExit("%r: unknown flag kind %r." % (key, kind))
    allowed = FLAG_RULINGS if kind else CANDIDATE_RULINGS
    if ruling not in allowed:
        raise SystemExit("the ruling for %s must be %s; got %r." % (key, " or ".join(allowed), ruling))
    reason = (reason or "").strip()
    if not reason or "\n" in reason:
        raise SystemExit("the reason for %s must be one non-empty line." % key)
    rulings[key] = {"ruling": ruling, "reason": reason}


def read_tsv(path: Path) -> list:
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 3:
            raise SystemExit("%s: a ruling line is key<TAB>ruling<TAB>reason; got %r" % (path, line))
        out.append(tuple(p.strip() for p in parts))
    return out


def sources_md(flavor: str, build: dict, date: str, info: list, replay: bool) -> str:
    fl = FLAVORS[flavor]
    lines = ["# Sources: %s seed re-validation, %s" % (fl["title"], date), "",
             "Written by `tools/seeds/seeds.py derive`. Do not edit by hand.", "",
             "- Product: wago.tools `%s` (%s)" % (fl["product"], fl["title"]),
             "- Build: `%s`%s" % (build["version"], (" (created %s)" % build["created_at"]) if build.get("created_at") else ""),
             "- Run date: %s%s" % (date, " (replayed from this bundle's raw/)" if replay else ""),
             "- Builds API: %s" % BUILDS_URL, "",
             "`raw/` holds each table this run read as `.csv.gz`. The big tables are trimmed to the rows",
             "the derivation reads (the TRIM note in `tools/seeds/seeds.py`, class `DB`); a replay admits",
             "the same rows. The full download's size and sha256 are recorded here so the trim can be",
             "checked against the source.", "",
             "| Table | Why | URL | Full size | Full sha256 | Rows in raw/ |", "| --- | --- | --- | --- | --- | --- |"]
    for row in info:
        lines.append("| %s | %s | %s | %s | %s | %d |" % (row["table"], row["why"], row["url"], row["size"],
                                                        row["sha256"], row["rows"]))
    return "\n".join(lines) + "\n"


def cmd_status(args) -> int:
    for flavor in ([args.flavor] if args.flavor else list(FLAVORS)):
        live = live_build(FLAVORS[flavor]["product"])["version"]
        print("%s: %s" % (flavor, status_line(live, bundles(flavor, args.root))))
    return 0


def cmd_derive(args) -> int:
    flavor, bundle = args.flavor, args.bundle
    seeds = for_flavor(read_seeds(args.root_repo), flavor)
    raw = bundle / "raw"
    if args.replay:
        previous = load_doc(bundle)
        build = {"version": previous["build"], "created_at": previous.get("buildCreated", "")}
        if args.build and args.build != build["version"]:
            raise SystemExit("--replay %s is build %s, not %s." % (bundle, build["version"], args.build))

        def source(table):
            path = raw / ("%s.csv.gz" % table)
            if not path.exists():
                raise SystemExit("--replay: %s has no raw/%s.csv.gz." % (bundle, table))
            return path
    else:
        build = {"version": args.build, "created_at": ""} if args.build else live_build(FLAVORS[flavor]["product"])

        def source(table):
            return fetch(table, build["version"], args.cache_dir)
    log("%s: build %s, %d shipped ids" % (flavor, build["version"], len(seeds)))
    db = DB(seeds, flavor, source)
    result = derive(db, seeds, flavor)
    info = []
    old_sources = {}
    if args.replay:
        old_sources = {r["table"]: r for r in load_doc(bundle).get("sources", [])}
    for table, why in tables_for(flavor):
        rows = db.kept[table]
        if args.replay:
            entry = dict(old_sources.get(table) or {"size": "?", "sha256": "?"})
        else:
            full = source(table)
            entry = {"size": full.stat().st_size, "sha256": sha256(full)}
            write_raw(raw / ("%s.csv.gz" % table), db.headers[table], rows)
        entry.update({"table": table, "why": why, "rows": len(rows),
                      "url": CSV_URL.format(table=table, build=build["version"])})
        info.append(entry)
    doc = {"flavor": flavor, "product": FLAVORS[flavor]["product"], "build": build["version"],
           "buildCreated": build.get("created_at", ""), "date": args.date,
           "tool": "tools/seeds/seeds.py derive", "sources": info}
    doc.update(result)
    write_json(bundle / "candidates.json", doc)
    if not args.replay:
        write_crlf(bundle / "SOURCES.md", sources_md(flavor, build, args.date, info, False))
    rulings = load_rulings(args.rulings or rulings_path(flavor))
    log("%d shipped ids, %d candidates, %d flags, %d unruled"
        % (doc["shipped"], len(doc["candidates"]), len(doc["flags"]), len(unruled(doc, rulings))))
    return 0


def cmd_rule(args) -> int:
    doc = load_doc(args.bundle)
    path = args.rulings or rulings_path(doc["flavor"])
    todo = [(k, args.ruling, args.reason) for k in (args.key or ())] + (read_tsv(args.tsv) if args.tsv else [])
    if not todo:
        raise SystemExit("rule needs --key (with --ruling and --reason) or --tsv.")
    known = set(all_keys(doc))
    rulings = load_rulings(path)
    for key, ruling, reason in todo:
        if key not in known:
            raise SystemExit("%s is not a candidate or flag in %s/candidates.json." % (key, args.bundle))
        set_ruling(rulings, key, ruling, reason)
    write_crlf(path, json.dumps(rulings, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    log("Recorded %d ruling(s) in %s" % (len(todo), path))
    return 0


def cmd_check(args) -> int:
    doc = load_doc(args.bundle)
    todo = unruled(doc, load_rulings(args.rulings or rulings_path(doc["flavor"])))
    if not todo:
        print("OK: every candidate and flag in %s is ruled." % args.bundle.name)
        return 0
    rows = {c["key"]: c for c in doc["candidates"]}
    rows.update({f["key"]: f for f in doc["flags"]})
    print("%d unruled:" % len(todo))
    for key in todo:
        row = rows[key]
        print("  %s  %s [%s] %s" % (key, row["name"], row.get("source") or row.get("kind"),
                                    "; ".join(row.get("notes") or ()) or row.get("why", "")))
    return 1


# ---------------------------------------------------------------------------
# Apply: the mechanical edits, layout and line endings kept
# ---------------------------------------------------------------------------

# Where an accepted candidate goes: list -> (file, opener, entry shape). `line` lists hold one
# `[id] = true, -- name` per line; `inline` lists are one `{ ... }` on the opener's line.
TARGETS = {
    "VIGILANCE_NPCS": ("defaults/TriggerData.lua", "D.VIGILANCE_NPCS = {", "inline-set"),
    "LEVIATHAN_NPCS": ("defaults/TriggerData.lua", "D.LEVIATHAN_NPCS = {", "line-set"),
    "VASHJIR_MAP_IDS": ("defaults/TriggerData.lua", "D.VASHJIR_MAP_IDS = {", "line-array"),
}
# Where a ruled removal comes out: list -> (file, opener). Lists not here (the per-client lines,
# the shared spell tables, the zone rows) need a hand edit, and apply says so.
REMOVABLE = {
    "VIGILANCE_NPCS": ("defaults/TriggerData.lua", "D.VIGILANCE_NPCS = {"),
    "LEVIATHAN_NPCS": ("defaults/TriggerData.lua", "D.LEVIATHAN_NPCS = {"),
    "VASHJIR_MAP_IDS": ("defaults/TriggerData.lua", "D.VASHJIR_MAP_IDS = {"),
    "ITEM.IGNORED_UNUSED": ("defaults/Items.lua", "ID.IGNORED_UNUSED = {"),
    "ITEM.PHANTOM_IDS": ("defaults/Items.lua", "ID.PHANTOM_IDS = {"),
}


class LuaFile:
    """A seed file as lines plus its terminator, so an edit keeps CRLF or LF as it found it."""

    def __init__(self, path: Path):
        self.path = path
        raw = path.read_bytes().decode("utf-8")
        self.eol = "\r\n" if "\r\n" in raw else "\n"
        self.lines = raw.split(self.eol)
        self.changed = False

    def span(self, opener: str) -> tuple:
        """`(first, last)` line indexes of the block `opener` starts (last holds its `}`)."""
        for i, line in enumerate(self.lines):
            if opener in line:
                depth = 0
                for j in range(i, len(self.lines)):
                    text = self.lines[j].split("--", 1)[0]
                    depth += text.count("{") - text.count("}")
                    if depth <= 0:
                        return i, j
                break
        raise SystemExit("apply: %s has no block %r" % (self.path, opener))

    def has(self, opener: str, sid: int) -> bool:
        first, last = self.span(opener)
        code = [line.split("--", 1)[0] for line in self.lines[first:last + 1]]
        body = "\n".join(code).split("{", 1)[1]
        return re.search(r"(?<![\w.])\[?%d\]?(?![\w.])" % sid, body) is not None

    def insert(self, opener: str, shape: str, sid: int, name: str) -> bool:
        if self.has(opener, sid):
            return False
        first, last = self.span(opener)
        if shape == "inline-set":
            self.lines[first] = self._inline(self.lines[first], lambda items: items + ["[%d] = true" % sid])
        else:
            entries = [k for k in range(first + 1, last) if re.match(r"^\s*(\[\d+\]|\d+)", self.lines[k])]
            where = (entries[-1] + 1) if entries else last
            indent = re.match(r"^(\s*)", self.lines[where - 1] if entries else self.lines[first]).group(1)
            if not entries:
                indent += "    "
            body = "[%d] = true," % sid if shape == "line-set" else "%d," % sid
            self.lines.insert(where, "%s%s -- %s" % (indent, body, name))
        self.changed = True
        return True

    def remove(self, opener: str, sid: int) -> bool:
        if not self.has(opener, sid):
            return False
        first, last = self.span(opener)
        pat = re.compile(r"^\s*(\[%d\]\s*=|%d\s*,)" % (sid, sid))
        for k in range(first + 1, last):
            if pat.match(self.lines[k]):
                del self.lines[k]
                self.changed = True
                return True
        line = self.lines[first]
        new = self._inline(line, lambda items: [t for t in items if not re.match(r"^\[%d\]\s*=" % sid, t)])
        if new == line:
            raise SystemExit("apply: cannot place %d in %s's %r by machine; edit it by hand." % (sid, self.path, opener))
        self.lines[first] = new
        self.changed = True
        return True

    @staticmethod
    def _inline(line: str, edit) -> str:
        """A one-line `{ a, b }` list with `edit(items)` applied, its spacing kept."""
        m = re.match(r"^(.*?\{\s*)(.*?)(\s*\}[^}]*)$", line)
        if not m:
            raise SystemExit("apply: %r is not a one-line list" % line)
        items = [t.strip() for t in m.group(2).split(",") if t.strip()]
        return m.group(1) + ", ".join(edit(items)) + m.group(3)

    def save(self) -> None:
        if self.changed:
            self.path.write_bytes(self.eol.join(self.lines).encode("utf-8"))


def plan(doc: dict, rulings: dict) -> tuple:
    todo = unruled(doc, rulings)
    if todo:
        raise SystemExit("apply refused: %d key(s) unruled (seeds.py check lists them)." % len(todo))
    inserts = [c for c in doc["candidates"] if rulings[c["key"]]["ruling"] == "accept"]
    removals = [f for f in doc["flags"] if rulings[f["key"]]["ruling"] == "remove"]
    for c in inserts:
        if c.get("target") not in TARGETS:
            raise SystemExit("apply refused: %s is accepted, but %s has no mechanical place for a new id "
                             "(a new zone row, a difficulty group, a per-client key): edit it by hand, then "
                             "re-derive." % (c["key"], c["list"]))
    for f in removals:
        if f["list"] not in REMOVABLE:
            raise SystemExit("apply refused: %s is ruled remove, but %s is a per-client or shared list: "
                             "edit it by hand, then re-derive." % (f["key"], f["list"]))
    return inserts, removals


def apply_bundle(doc: dict, rulings: dict, root: Path) -> list:
    inserts, removals = plan(doc, rulings)
    files, changes = {}, []

    def lua(rel):
        if rel not in files:
            files[rel] = LuaFile(root / rel)
        return files[rel]
    for c in inserts:
        rel, opener, shape = TARGETS[c["target"]]
        if lua(rel).insert(opener, shape, c["id"], c["name"]):
            changes.append("%s: +%d %s" % (c["list"], c["id"], c["name"]))
    for f in removals:
        rel, opener = REMOVABLE[f["list"]]
        if lua(rel).remove(opener, f["id"]):
            changes.append("%s: -%d %s" % (f["list"], f["id"], f["name"] or f["comment"]))
    for f in files.values():
        f.save()
    return changes


def cmd_apply(args) -> int:
    doc = load_doc(args.bundle)
    changes = apply_bundle(doc, load_rulings(args.rulings or rulings_path(doc["flavor"])), args.root_repo)
    for line in changes:
        log("  " + line)
    log("%d change(s)" % len(changes))
    return 0


# ---------------------------------------------------------------------------
# RULINGS.md
# ---------------------------------------------------------------------------

def _cell(text) -> str:
    return str(text or "").replace("|", "\\|")


def rulings_md(doc: dict, rulings: dict, date: str) -> str:
    tally = defaultdict(int)
    for key in all_keys(doc):
        tally[rulings.get(key, {}).get("ruling", "unruled")] += 1
    review = sum(1 for k in all_keys(doc) if "needs owner review" in rulings.get(k, {}).get("reason", ""))
    lines = ["# Rulings: %s seed re-validation, %s (build %s)" % (FLAVORS[doc["flavor"]]["title"], doc["date"], doc["build"]),
             "", "Generated by `tools/seeds/seeds.py report` on %s from this bundle's `candidates.json` and "
             "`tools/seeds/rulings_%s.json`. Do not edit by hand." % (date, doc["flavor"]), "",
             "%d shipped ids checked; %d candidates, %d flags: %s; %d marked needs owner review."
             % (doc["shipped"], len(doc["candidates"]), len(doc["flags"]),
                ", ".join("%d %s" % (n, r) for r, n in sorted(tally.items())), review), ""]
    todo = unruled(doc, rulings)
    if todo:
        lines += ["## Unruled: %d" % len(todo), ""] + ["- `%s`" % k for k in todo] + [""]
    lines += ["## Candidates: %d" % len(doc["candidates"]), ""]
    if doc["candidates"]:
        lines += ["| List | Id | Name | Source | Notes | Ruling | Reason |", "| --- | --- | --- | --- | --- | --- | --- |"]
        for c in doc["candidates"]:
            r = rulings.get(c["key"], {})
            lines.append("| %s | `%d` | %s | %s | %s | %s | %s |" % (
                c["list"], c["id"], _cell(c["name"]), c["source"], _cell("; ".join(c["notes"])),
                r.get("ruling", "**unruled**"), _cell(r.get("reason", ""))))
    else:
        lines.append("None.")
    lines += ["", "## Shipped-id flags: %d" % len(doc["flags"]), ""]
    if doc["flags"]:
        lines += ["| Kind | List | Id | File comment | Build name | Why | Ruling | Reason |",
                  "| --- | --- | --- | --- | --- | --- | --- | --- |"]
        for f in doc["flags"]:
            r = rulings.get(f["key"], {})
            lines.append("| %s | %s | `%d` | %s | %s | %s | %s | %s |" % (
                f["kind"], f["list"], f["id"], _cell(f["comment"]), _cell(f["name"]), _cell(f["why"]),
                r.get("ruling", "**unruled**"), _cell(r.get("reason", ""))))
    else:
        lines.append("None.")
    if doc.get("uncheckable"):
        lines += ["", "## Not checkable against this build: %d" % len(doc["uncheckable"]), "",
                  "Ids the client's table cannot vouch for either way; no flag, no ruling.", "",
                  "| List | Id | File comment | Why |", "| --- | --- | --- | --- |"]
        lines += ["| %s | `%d` | %s | %s |" % (u["list"], u["id"], _cell(u["comment"]), _cell(u["why"]))
                  for u in doc["uncheckable"]]
    if doc.get("handMissing"):
        lines += ["", "## Hand candidates the build lacks", ""] + [
            "- `%s:%d`: %s" % (m["list"], m["id"], m["why"]) for m in doc["handMissing"]]
    return "\n".join(lines) + "\n"


def cmd_report(args) -> int:
    doc = load_doc(args.bundle)
    write_crlf(args.bundle / "RULINGS.md", rulings_md(doc, load_rulings(args.rulings or rulings_path(doc["flavor"])),
                                                       args.date))
    log("Wrote %s" % (args.bundle / "RULINGS.md"))
    return 0


def _date(value: str) -> str:
    if not DATE_RE.match(value):
        raise argparse.ArgumentTypeError("a date is YYYY-MM-DD; got %r" % value)
    return value


def parse_args(argv):
    p = argparse.ArgumentParser(description="Re-validate Outfitter Reborn's seed ids against a wago.tools build.",
                                epilog="The contract is docs/validate-seeds.md.")
    p.add_argument("--rulings", type=Path, default=None, help="the rulings file (default rulings_<flavor>.json)")
    p.add_argument("--cache-dir", type=Path, default=HERE / ".cache")
    p.add_argument("--root-repo", type=Path, default=ROOT, help=argparse.SUPPRESS)
    sub = p.add_subparsers(dest="command", required=True)
    st = sub.add_parser("status", help="is there a live build newer than the newest bundle?")
    st.add_argument("--flavor", choices=sorted(FLAVORS))
    st.add_argument("--root", type=Path, default=RESEARCH)
    d = sub.add_parser("derive", help="flags and candidates into the bundle's candidates.json")
    d.add_argument("--flavor", choices=sorted(FLAVORS), required=True)
    d.add_argument("--bundle", type=Path, required=True)
    d.add_argument("--date", type=_date, required=True)
    d.add_argument("--build", help="pin this build instead of the live one")
    d.add_argument("--replay", action="store_true", help="read only the bundle's raw/, no network")
    r = sub.add_parser("rule", help="record rulings (the only writer of the rulings file)")
    r.add_argument("--bundle", type=Path, required=True)
    r.add_argument("--key", action="append")
    r.add_argument("--ruling")
    r.add_argument("--reason")
    r.add_argument("--tsv", type=Path)
    for name, helptext in (("check", "exit 1 while anything is unruled"), ("report", "write RULINGS.md"),
                           ("apply", "write accepted ids and ruled removals into the seed files")):
        c = sub.add_parser(name, help=helptext)
        c.add_argument("--bundle", type=Path, required=True)
        if name != "check":
            c.add_argument("--date", type=_date, required=True)
    return p.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    return {"status": cmd_status, "derive": cmd_derive, "rule": cmd_rule, "check": cmd_check,
            "report": cmd_report, "apply": cmd_apply}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
