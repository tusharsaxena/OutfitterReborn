#!/usr/bin/env python3
"""tools/seeds/test_seeds.py: the seed tool's offline tests (no network: tiny fixture CSVs).

Run with `python3 -m pytest -q tools/seeds` or `python3 -m unittest discover tools/seeds`.
"""

from __future__ import annotations

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import seeds  # noqa: E402

FIXTURES = HERE / "fixtures"


def fixture_source(table):
    return FIXTURES / ("%s.csv" % table)


def S(lst, kind, sid, name="", clients=seeds.BOTH, **extra):
    return seeds.Seed(lst, kind, sid, name, clients, "defaults/Fixture.lua", **extra)


FIXTURE_SEEDS = [
    S("AURA_SPELL_STATE", "spell", 2645, "Ghost Wolf", aura="any"),
    S("AURA_SPELL_STATE", "spell", 5215, "Prowl", aura="any"),
    S("FORM_SPELL_STATE", "spell", 1784, "rogue Stealth", aura="shapeshift"),
    S("FORM_SPELL_STATE", "spell", 783, "Travel Form", aura="shapeshift"),
    S("FIND_FISH", "spell", 43308, "Find Fish", seeds.RETAIL, aura="track"),
    S("DIFFICULTY_GROUPS.dungeonNormal", "difficulty", 1, group="dungeonNormal"),
    S("DIFFICULTY_GROUPS.raidNormal", "difficulty", 9, group="raidNormal"),
    S("DIFFICULTY_GROUPS.delve", "difficulty", 208, group="delve"),
    S("DIFFICULTY_GROUPS.dungeonHeroic", "difficulty", 14, group="dungeonHeroic"),
    S("Zones.BG_AV", "map", 30, zoneKind="bg"),
    S("Zones.BG_X", "map", 572, zoneKind="bg"),
    S("Zones.BG_GONE", "map", 4444, zoneKind="bg"),
    S("ITEM.IGNORED_UNUSED", "item", 2901, "Mining Pick"),
    S("ITEM.PHANTOM_IDS", "item", 133948, "Monk, Fists of the Heavens", weapon=True),
    S("ITEM.PHANTOM_IDS", "item", 128293, "DK, Blades of the Fallen Prince", weapon=True),
    S("ICONS.Triggers", "icon", 132261, "RIDING"),
    S("ICONS.Triggers", "icon", 999, "BROKEN"),
    S("LEVIATHAN_NPCS", "creature", 33060, "Salvaged Siege Engine", seeds.RETAIL),
    S("LEVIATHAN_NPCS", "creature", 33062, "Salvaged Chopper", seeds.RETAIL),
    S("VASHJIR_MAP_IDS", "uimap", 201, "Kelp'thar Forest", seeds.RETAIL),
    S("VASHJIR_MAP_IDS", "uimap", 204, "Abyssal Depths", seeds.RETAIL),
    S("SKILL_LINES", "skillline", 182, "Herbalism"),
    S("SKILL_LINES", "skillline", 633, "Lockpicking"),
    S("COOKING_PETS", "battlepet", 297, "Lil' Ragnaros", seeds.RETAIL, creature=51600),
]


def derived(flavor="retail"):
    mine = seeds.for_flavor(FIXTURE_SEEDS, flavor)
    db = seeds.DB(mine, flavor, fixture_source)
    return db, seeds.derive(db, mine, flavor)


def keys(rows):
    return {r["key"] for r in rows}


class TestParse(unittest.TestCase):
    def test_the_real_seed_files_parse_past_every_floor(self):
        got = seeds.read_seeds()
        by = {(s.list, s.id): s for s in got}
        self.assertEqual(by[("AURA_SPELL_STATE", 58984)].clients, ("retail",))
        self.assertEqual(by[("AURA_SPELL_STATE", 20580)].clients, ("forever",))
        self.assertEqual(by[("FORM_SPELL_STATE", 33891)].clients, ("retail",))
        self.assertEqual(by[("Zones.BG_EOTS", 566)].clients, ("retail",))
        self.assertEqual(by[("Zones.BG_AV", 30)].clients, seeds.BOTH)
        self.assertEqual(by[("ICONS.Triggers", 136041)].clients, ("retail",))
        self.assertEqual(by[("COOKING_PETS", 1204)].extra["creature"], 70082)
        self.assertEqual(by[("ITEM.ALIASES", 46106)].name, "Argent Lance")
        self.assertEqual(sum(1 for s in got if s.list == "VIGILANCE_NPCS"), 4)

    def test_a_thin_parse_is_refused(self):
        # red under: check_parse returning without its floor
        thin = [s for s in seeds.read_seeds() if s.list != "ITEM.PHANTOM_IDS"]
        with self.assertRaises(SystemExit) as err:
            seeds.check_parse(thin)
        self.assertIn("ITEM.PHANTOM_IDS", str(err.exception))

    def test_a_crlf_file_parses_as_lf(self):
        text = "D.VASHJIR_MAP_IDS = {\r\n    201, -- Kelp'thar Forest\r\n}\r\n".replace("\r\n", "\n")
        rows = list(seeds.ARRAY_ENTRY.finditer(seeds.block(text, "D.VASHJIR_MAP_IDS = {")))
        self.assertEqual([(m.group(1), m.group(2)) for m in rows], [("201", "Kelp'thar Forest")])


class TestNames(unittest.TestCase):
    def test_a_qualifier_before_the_name_matches(self):
        self.assertTrue(seeds.name_matches("rogue Stealth", "Stealth"))
        self.assertTrue(seeds.name_matches("Monk, Fists of the Heavens", "Fists of the Heavens"))
        self.assertTrue(seeds.name_matches("Lil’ Ragnaros", "Lil' Ragnaros"))
        self.assertFalse(seeds.name_matches("Scroll of Protection V", "Scroll of Strength V"))


class TestDerive(unittest.TestCase):
    def setUp(self):
        self.db, self.doc = derived()
        self.flags, self.cands = keys(self.doc["flags"]), keys(self.doc["candidates"])

    def test_flags_gone_renamed_and_wrong_kind(self):
        self.assertIn("shipped:gone:Zones.BG_GONE:4444", self.flags)
        self.assertIn("shipped:gone:SKILL_LINES:633", self.flags)
        self.assertIn("shipped:wrong-kind:Zones.BG_X:572", self.flags)          # an arena on a bg row
        self.assertIn("shipped:wrong-kind:FORM_SPELL_STATE:783", self.flags)    # aura 36 only on a difficulty row
        self.assertIn("shipped:wrong-kind:ITEM.PHANTOM_IDS:128293", self.flags) # ClassID 15
        self.assertIn("shipped:wrong-kind:ICONS.Triggers:999", self.flags)
        self.assertIn("shipped:wrong-kind:DIFFICULTY_GROUPS.dungeonHeroic:14", self.flags)
        self.assertNotIn("shipped:wrong-kind:DIFFICULTY_GROUPS.delve:208", self.flags)
        self.assertNotIn("shipped:renamed:FORM_SPELL_STATE:1784", self.flags)
        self.assertNotIn("shipped:renamed:ITEM.PHANTOM_IDS:133948", self.flags)
        self.assertNotIn("shipped:wrong-kind:ICONS.Triggers:132261", self.flags)

    def test_a_creature_the_client_table_lacks_is_uncheckable_not_gone(self):
        self.assertNotIn("shipped:gone:LEVIATHAN_NPCS:33062", self.flags)
        self.assertEqual([u["id"] for u in self.doc["uncheckable"]], [33062])

    def test_candidates_where_a_table_encodes_the_rule(self):
        self.assertIn("AURA_SPELL_STATE:6783", self.cands)     # a Prowl rank on a druid line
        self.assertIn("FORM_SPELL_STATE:1785", self.cands)     # a Stealth rank with aura 36
        self.assertIn("Zones.NEW:2799", self.cands)            # an InstanceType 3 map no row holds
        self.assertNotIn("Zones.NEW:600", self.cands)          # a dungeon is no zone candidate
        self.assertIn("DIFFICULTY_GROUPS.NONE:24", self.cands)
        self.assertNotIn("DIFFICULTY_GROUPS.NONE:208", self.cands)
        self.assertIn("LEVIATHAN_NPCS:33061", self.cands)
        self.assertIn("VASHJIR_MAP_IDS:205", self.cands)
        self.assertNotIn("VASHJIR_MAP_IDS:203", self.cands)    # the parent is not a sibling

    def test_a_pet_line_spell_is_never_a_candidate(self):
        # MUTATION-CHECKED 2026-11-15: with the PET_LINE guard in DB.player_learnable removed, this
        # case went red (AURA_SPELL_STATE:24450, the hunter cat's Prowl, was proposed), then the guard
        # was restored.
        self.assertNotIn("AURA_SPELL_STATE:24450", self.cands)

    def test_the_forever_flavor_reads_no_retail_only_list(self):
        _db, doc = derived("forever")
        lists = {f["list"] for f in doc["flags"]} | {c["list"] for c in doc["candidates"]}
        self.assertFalse(lists & {"LEVIATHAN_NPCS", "VASHJIR_MAP_IDS", "COOKING_PETS", "FIND_FISH"})


class TestBundle(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_raw_is_deterministic_and_a_replay_admits_the_same_rows(self):
        mine = seeds.for_flavor(FIXTURE_SEEDS, "retail")
        db = seeds.DB(mine, "retail", fixture_source)
        for run in ("a", "b"):
            for table, rows in db.kept.items():
                seeds.write_raw(self.tmp / run / ("%s.csv.gz" % table), db.headers[table], rows)
        for table in db.kept:
            name = "%s.csv.gz" % table
            self.assertEqual((self.tmp / "a" / name).read_bytes(), (self.tmp / "b" / name).read_bytes(), table)
        again = seeds.DB(mine, "retail", lambda t: self.tmp / "a" / ("%s.csv.gz" % t))
        self.assertEqual(seeds.derive(again, mine, "retail"), seeds.derive(db, mine, "retail"))

    def test_status_reads_the_newest_bundle(self):
        self.assertTrue(seeds.status_line("1.2.3", []).startswith("NEW 1.2.3"))
        for name, build in (("2026-01-01-retail", "1.2.2"), ("2026-02-01-retail", "1.2.3")):
            (self.tmp / name).mkdir()
            (self.tmp / name / "candidates.json").write_text(json.dumps({"build": build}))
        found = seeds.bundles("retail", self.tmp)
        self.assertEqual(seeds.status_line("1.2.3", found), "CURRENT 1.2.3 (2026-02-01-retail)")
        self.assertTrue(seeds.status_line("1.2.4", found).startswith("NEW 1.2.4 (last ruled 1.2.3"))

    def test_crlf_writer(self):
        seeds.write_crlf(self.tmp / "x.md", "a\nb\r\nc\n")
        self.assertEqual((self.tmp / "x.md").read_bytes(), b"a\r\nb\r\nc\r\n")


class TestRulings(unittest.TestCase):
    def test_set_ruling_validates_key_ruling_and_reason(self):
        r = {}
        seeds.set_ruling(r, "Zones.NEW:2799", "reject", "a brawl")
        seeds.set_ruling(r, "shipped:gone:SKILL_LINES:633", "keep", "fallback covers it")
        for key, ruling, reason in (("nope", "accept", "x"), ("Zones.NEW:1", "keep", "x"),
                                    ("shipped:gone:X:1", "accept", "x"), ("shipped:odd:X:1", "keep", "x"),
                                    ("Zones.NEW:1", "accept", ""), ("Zones.NEW:1", "accept", "a\nb")):
            with self.assertRaises(SystemExit):
                seeds.set_ruling(r, key, ruling, reason)
        self.assertEqual(sorted(r), ["Zones.NEW:2799", "shipped:gone:SKILL_LINES:633"])

    def test_apply_refuses_while_anything_is_unruled(self):
        _db, doc = derived()
        with self.assertRaises(SystemExit) as err:
            seeds.plan(doc, {})
        self.assertIn("unruled", str(err.exception))

    def test_apply_refuses_an_accept_with_no_mechanical_place(self):
        _db, doc = derived()
        rulings = {k: {"ruling": "reject", "reason": "x"} for k in keys(doc["candidates"])}
        rulings.update({k: {"ruling": "keep", "reason": "x"} for k in keys(doc["flags"])})
        rulings["Zones.NEW:2799"] = {"ruling": "accept", "reason": "x"}
        with self.assertRaises(SystemExit) as err:
            seeds.plan(doc, rulings)
        self.assertIn("by hand", str(err.exception))


LUA = ("local _, NS = ...\r\n"
       "D.VIGILANCE_NPCS = { [39710] = true, [40719] = true }\r\n"
       "D.LEVIATHAN_NPCS = {\r\n"
       "    -- confirmed 2026-11-03\r\n"
       "    [33060] = true, -- Salvaged Siege Engine\r\n"
       "    [33062] = true, -- Salvaged Chopper\r\n"
       "}\r\n"
       "D.VASHJIR_MAP_IDS = {\r\n"
       "    201, -- Kelp'thar Forest\r\n"
       "    204, -- Abyssal Depths\r\n"
       "}\r\n")


class TestApply(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        (self.root / "defaults").mkdir()
        self.path = self.root / "defaults" / "TriggerData.lua"
        self.path.write_bytes(LUA.encode())
        cands = [seeds.candidate("LEVIATHAN_NPCS", 33061, "Salvaged Siege Engine", "same-name", [], "LEVIATHAN_NPCS"),
                 seeds.candidate("VIGILANCE_NPCS", 40720, "Aviana's Guardian", "same-name", [], "VIGILANCE_NPCS"),
                 seeds.candidate("VASHJIR_MAP_IDS", 205, "Shimmering Expanse", "sibling", [], "VASHJIR_MAP_IDS")]
        flags = [{"key": "shipped:gone:LEVIATHAN_NPCS:33062", "kind": "gone", "list": "LEVIATHAN_NPCS",
                  "id": 33062, "name": "", "comment": "Salvaged Chopper"},
                 {"key": "shipped:gone:VIGILANCE_NPCS:39710", "kind": "gone", "list": "VIGILANCE_NPCS",
                  "id": 39710, "name": "", "comment": ""}]
        self.doc = {"candidates": cands, "flags": flags}
        self.rulings = {c["key"]: {"ruling": "accept", "reason": "x"} for c in cands}
        self.rulings.update({f["key"]: {"ruling": "remove", "reason": "x"} for f in flags})

    def tearDown(self):
        shutil.rmtree(self.root)

    def test_apply_edits_in_place_keeps_crlf_and_is_idempotent(self):
        changes = seeds.apply_bundle(self.doc, self.rulings, self.root)
        self.assertEqual(len(changes), 5)
        data = self.path.read_bytes()
        self.assertEqual(data.count(b"\r\n"), data.count(b"\n"), "every line still ends CRLF")
        text = data.decode()
        self.assertIn("D.VIGILANCE_NPCS = { [40719] = true, [40720] = true }\r\n", text)
        self.assertIn("    [33060] = true, -- Salvaged Siege Engine\r\n    [33061] = true, -- Salvaged Siege Engine\r\n}", text)
        self.assertNotIn("33062", text)
        self.assertIn("    204, -- Abyssal Depths\r\n    205, -- Shimmering Expanse\r\n}", text)
        self.assertEqual(seeds.apply_bundle(self.doc, self.rulings, self.root), [])
        self.assertEqual(self.path.read_bytes(), data)

    def test_a_number_in_a_comment_is_not_an_entry(self):
        lua = seeds.LuaFile(self.path)
        self.assertFalse(lua.has("D.LEVIATHAN_NPCS = {", 2026))
        self.assertTrue(lua.has("D.VASHJIR_MAP_IDS = {", 204))


if __name__ == "__main__":
    unittest.main()
