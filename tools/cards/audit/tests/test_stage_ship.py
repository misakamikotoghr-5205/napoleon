"""stage_ship.py strips drafts, skips excluded paths, follows dependencies, and is deterministic."""
import json
import os
import shutil
import tempfile
import unittest

import common


class StageShipTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="k15-stage-")
        # The fixture is named godot.project so Godot import of this repo does not
        # warn about a nested project.godot (that WARNING fails the card runner).
        self.src = os.path.join(self.tmp, "src")
        shutil.copytree(os.path.join(common.FIX, "stage_src"), self.src)
        alt = os.path.join(self.src, "godot.project")
        if os.path.isfile(alt):
            os.replace(alt, os.path.join(self.src, "project.godot"))

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def stage(self, name):
        dst = os.path.join(self.tmp, name)
        proc = common.run([common.PY, os.path.join(common.AUDIT, "stage_ship.py"), dst, "--src=" + self.src])
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertRegex(proc.stdout.strip().splitlines()[-1], r"^STAGED \d+ files, \d+ bytes$")
        return dst

    def rels(self, dst):
        found = []
        for dirpath, _dirs, files in os.walk(dst):
            for name in files:
                found.append(os.path.relpath(os.path.join(dirpath, name), dst).replace(os.sep, "/"))
        return sorted(found)

    def test_dependency_exclusion_and_strip(self):
        dst = self.stage("a")
        rels = self.rels(dst)
        for required in (
            "scenes/cards/CardGame.tscn",
            "scripts/ship/root.gd",
            "scripts/ship/child.gd",
            "scripts/ship/other.gd",
            "scripts/ship/bus.gd",
            "scripts/ship/root.gd.import",
            "data/payload.json",
            "data/cards/era/1938/a.json",
            "data/cards/text/era/1938/a.text.json",
            "data/town/item_templates.json",
            "data/cast.json",
            "fonts/Tiny.ttf",
            "project.godot",
            "export_presets.cfg",
            "scripts/cards/core/validate_main.gd",
            "scripts/ship/validate_helper.gd",
        ):
            self.assertIn(required, rels)
        for banned in (
            "data/cards/_examples/skip.json",
            "data/cards/branch/skip.json",
            "data/cards/rules/wording.json",
            "data/cards/theme/palette.dev.json",
            "art/_placeholder/x.png",
            "scripts/town/no.gd",
            "scenes/Main.tscn",
            "data/town/other.json",
            "data/codebook.json",
        ):
            self.assertNotIn(banned, rels)
        with open(os.path.join(dst, "data", "cards", "era", "1938", "a.json"), encoding="utf-8") as fh:
            card = json.load(fh)
        self.assertEqual(list(card.keys()), ["_meta", "cards"])
        self.assertNotIn("brief", card["_meta"])
        self.assertNotIn("brief", card["cards"][0])
        self.assertNotIn("_provenance", card["cards"][0])
        self.assertEqual(card["cards"][0]["art"], "portrait.a")
        with open(os.path.join(dst, "data", "cards", "text", "era", "1938", "a.text.json"), encoding="utf-8") as fh:
            text = json.load(fh)
        self.assertEqual(text["p.a"]["_provenance"], "human:A:2026-01-15")
        self.assertNotIn("brief", text["p.a"])
        with open(os.path.join(dst, "data", "payload.json"), encoding="utf-8") as fh:
            payload = json.load(fh)
        self.assertEqual(payload, {"keep": 1})
        with open(os.path.join(dst, "data", "cards", "era", "1938", "a.json"), encoding="utf-8") as fh:
            raw = fh.read()
        self.assertNotIn("META-BRIEF", raw)
        self.assertNotIn("CARD-BRIEF", raw)
        self.assertIn("\n  \"_meta\": {\n", raw)
        staged = card["cards"][0]["stage"]
        self.assertEqual(staged, {
            "cast": [{"who": "brother", "at": "door"}],
            "props": [{"art": "prop.trunk", "at": "door_side"}],
            "intro": [{"who": "", "ref": "body"}],
            "after": {"listen": [{"who": "me", "ref": "lines.me"}]},
        })
        self.assertEqual(brief_paths(card), [])
        for token in ("STAGE-BRIEF", "CAST-BRIEF", "PROP-BRIEF", "INTRO-BRIEF", "AFTER-BRIEF"):
            self.assertNotIn(token, raw)

    def test_two_runs_match(self):
        first = self.stage("one")
        second = self.stage("two")
        left = self.rels(first)
        right = self.rels(second)
        self.assertEqual(left, right)
        for rel in left:
            with open(os.path.join(first, rel), "rb") as fh:
                a = fh.read()
            with open(os.path.join(second, rel), "rb") as fh:
                b = fh.read()
            self.assertEqual(a, b, rel)

    def test_escaped_triple_quote_stays_in_the_string(self):
        # Same counterexample as the audit guard: a backslash before """ inside
        # a triple-quoted string is not a closer. scan_gd used to honor
        # backslashes only outside triple quotes, so the fake return leaked
        # into code and the real closer swallowed AudioStreamGenerator.
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "k15stage", os.path.join(common.AUDIT, "stage_ship.py"))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)

        src = (
            "extends Node\n"
            "func f():\n"
            "    var _note = \"\"\"\n"
            "\\\"\"\"\n"
            "if CardShip.is_ship():\n"
            "    return\n"
            "\"\"\"\n"
            "    var _generator := AudioStreamGenerator.new()\n"
            "    var _legacy := \"res://audio/music/open.ogg\"\n"
        )
        self.assertEqual(src.splitlines()[3], '\\"""')
        paths, code = mod.scan_gd(src)
        self.assertNotIn("is_ship", code)
        self.assertNotIn("return", code)
        self.assertIn("AudioStreamGenerator", code)
        self.assertIn("audio/music/open.ogg", paths)

        odd = (
            "extends Node\n"
            "func f():\n"
            "    var _note = \"\"\"\n"
            "\\\\\\\"\"\"\n"
            "if CardShip.is_ship():\n"
            "    return\n"
            "\"\"\"\n"
            "    var _generator := AudioStreamGenerator.new()\n"
            "    var _legacy := \"res://audio/music/odd.ogg\"\n"
        )
        self.assertEqual(odd.splitlines()[3], '\\\\\\"""')
        paths, code = mod.scan_gd(odd)
        self.assertNotIn("is_ship", code)
        self.assertIn("AudioStreamGenerator", code)
        self.assertIn("audio/music/odd.ogg", paths)

        even = (
            "extends Node\n"
            "func f():\n"
            "    var _note = \"\"\"\n"
            "\\\\\"\"\"\n"
            "    var _generator := AudioStreamGenerator.new()\n"
            "    var _legacy := \"res://audio/music/even.ogg\"\n"
        )
        self.assertEqual(even.splitlines()[3], '\\\\"""')
        paths, code = mod.scan_gd(even)
        self.assertIn("AudioStreamGenerator", code)
        self.assertIn("audio/music/even.ogg", paths)

    def test_variants_ai_disclosure_vs_no_disclosure(self):
        # Populate src with AI art, AI audio, AI text, and manifests containing both human & ai paths.
        os.makedirs(os.path.join(self.src, "art", "ai", "cards", "portrait"), exist_ok=True)
        with open(os.path.join(self.src, "art", "ai", "cards", "portrait", "linsao.png"), "wb") as fh:
            fh.write(b"ai-png")
        os.makedirs(os.path.join(self.src, "audio", "ai", "music"), exist_ok=True)
        with open(os.path.join(self.src, "audio", "ai", "music", "day.ogg"), "wb") as fh:
            fh.write(b"ai-ogg")
        os.makedirs(os.path.join(self.src, "audio", "ai", "sfx"), exist_ok=True)
        with open(os.path.join(self.src, "audio", "ai", "sfx", "click.ogg"), "wb") as fh:
            fh.write(b"ai-sfx-ogg")
        with open(os.path.join(self.src, "audio", "ai", "sfx", "manifest.json"), "w", encoding="utf-8") as fh:
            json.dump({
                "cues": {
                    "click": {
                        "human": "audio/cards/sfx/click.ogg",
                        "ai": "audio/ai/sfx/click.ogg",
                        "_provenance": "ai:google-flow:lyria:2026-10-18:sfx.click.v1",
                    }
                }
            }, fh)
        os.makedirs(os.path.join(self.src, "data", "cards", "text_ai", "era", "1938"), exist_ok=True)
        with open(os.path.join(self.src, "data", "cards", "text_ai", "era", "1938", "a.text.json"), "w", encoding="utf-8") as fh:
            json.dump({
                "_meta": {"_provenance": "ai:google:gemini-2.5-pro:2026-10-18:212-1", "brief": "DROP-ME"},
                "p.a": {"title": "林嫂", "brief": "DROP-ENTRY-BRIEF"},
            }, fh)
        os.makedirs(os.path.join(self.src, "data", "cards", "art"), exist_ok=True)
        with open(os.path.join(self.src, "data", "cards", "art", "manifest.json"), "w", encoding="utf-8") as fh:
            json.dump({
                "missing": "",
                "art": {
                    "portrait.linsao": {
                        "base": [48, 64],
                        "human": "art/cards/portrait/linsao.png",
                        "ai": "art/ai/cards/portrait/linsao.png",
                        "_provenance": "ai:google-imagen:2026-10-18:portrait.linsao.v1",
                    }
                },
            }, fh)
        os.makedirs(os.path.join(self.src, "data", "cards", "audio"), exist_ok=True)
        with open(os.path.join(self.src, "data", "cards", "audio", "music.json"), "w", encoding="utf-8") as fh:
            json.dump({
                "cues": {
                    "day": {
                        "human": "audio/cards/music/day.ogg",
                        "ai": "audio/ai/music/day.ogg",
                        "_provenance": "ai:google-lyria:2026-10-18:cue.day.v1",
                    }
                }
            }, fh)

        # 1. Default / ai-disclosure variant keeps AI files and string _provenance.
        dst_ai = os.path.join(self.tmp, "stage_ai")
        proc_ai = common.run([
            common.PY, os.path.join(common.AUDIT, "stage_ship.py"),
            dst_ai, "--src=" + self.src, "--variant=ai-disclosure",
        ])
        self.assertEqual(proc_ai.returncode, 0, proc_ai.stdout + proc_ai.stderr)
        rels_ai = self.rels(dst_ai)
        self.assertIn("art/ai/cards/portrait/linsao.png", rels_ai)
        self.assertIn("audio/ai/music/day.ogg", rels_ai)
        self.assertIn("audio/ai/sfx/click.ogg", rels_ai)
        self.assertIn("audio/ai/sfx/manifest.json", rels_ai)
        self.assertIn("data/cards/text_ai/era/1938/a.text.json", rels_ai)
        with open(os.path.join(dst_ai, "data", "cards", "text_ai", "era", "1938", "a.text.json"), encoding="utf-8") as fh:
            staged_text_ai = json.load(fh)
        self.assertEqual(staged_text_ai["_meta"]["_provenance"], "ai:google:gemini-2.5-pro:2026-10-18:212-1")
        self.assertNotIn("brief", staged_text_ai["_meta"])
        self.assertNotIn("brief", staged_text_ai["p.a"])
        with open(os.path.join(dst_ai, "data", "cards", "art", "manifest.json"), encoding="utf-8") as fh:
            staged_art_ai = json.load(fh)
        self.assertEqual(staged_art_ai["art"]["portrait.linsao"]["ai"], "art/ai/cards/portrait/linsao.png")
        self.assertEqual(staged_art_ai["art"]["portrait.linsao"]["_provenance"], "ai:google-imagen:2026-10-18:portrait.linsao.v1")
        with open(os.path.join(dst_ai, "audio", "ai", "sfx", "manifest.json"), encoding="utf-8") as fh:
            staged_sfx_ai = json.load(fh)
        self.assertEqual(staged_sfx_ai["cues"]["click"]["ai"], "audio/ai/sfx/click.ogg")
        self.assertEqual(staged_sfx_ai["cues"]["click"]["_provenance"], "ai:google-flow:lyria:2026-10-18:sfx.click.v1")

        # 2. no-disclosure variant excludes AI files and strips ai keys & provenance from manifests.
        dst_human = os.path.join(self.tmp, "stage_human")
        proc_human = common.run([
            common.PY, os.path.join(common.AUDIT, "stage_ship.py"),
            dst_human, "--src=" + self.src, "--variant=no-disclosure",
        ])
        self.assertEqual(proc_human.returncode, 0, proc_human.stdout + proc_human.stderr)
        rels_human = self.rels(dst_human)
        self.assertNotIn("art/ai/cards/portrait/linsao.png", rels_human)
        self.assertNotIn("audio/ai/music/day.ogg", rels_human)
        self.assertNotIn("audio/ai/sfx/click.ogg", rels_human)
        self.assertNotIn("audio/ai/sfx/manifest.json", rels_human)
        self.assertIn("data/cards/audio/sfx.json", rels_human)
        self.assertNotIn("data/cards/text_ai/era/1938/a.text.json", rels_human)
        with open(os.path.join(dst_human, "data", "cards", "art", "manifest.json"), encoding="utf-8") as fh:
            staged_art_human = json.load(fh)
        self.assertNotIn("ai", staged_art_human["art"]["portrait.linsao"])
        self.assertNotIn("_provenance", staged_art_human["art"]["portrait.linsao"])
        with open(os.path.join(dst_human, "data", "cards", "audio", "music.json"), encoding="utf-8") as fh:
            staged_audio_human = json.load(fh)
        self.assertNotIn("ai", staged_audio_human["cues"]["day"])
        self.assertNotIn("_provenance", staged_audio_human["cues"]["day"])
        with open(os.path.join(dst_human, "data", "cards", "audio", "sfx.json"), encoding="utf-8") as fh:
            staged_sfx_human = json.load(fh)
        self.assertEqual(staged_sfx_human["cues"]["click"]["human"], "audio/cards/sfx/click.ogg")
        self.assertNotIn("ai", staged_sfx_human["cues"]["click"])
        self.assertNotIn("_provenance", staged_sfx_human["cues"]["click"])

        # 3. package_steam.sh --stage-only works for both variants.
        pkg_script = os.path.join(common.ROOT, "tools", "package_steam.sh")
        pkg_ai_dir = os.path.join(self.tmp, "pkg_ai")
        pkg_human_dir = os.path.join(self.tmp, "pkg_human")
        res_pkg_ai = common.run(["bash", pkg_script, "--stage-only", "--variant=ai-disclosure", "--src=" + self.src, "--staging=" + pkg_ai_dir])
        self.assertEqual(res_pkg_ai.returncode, 0, res_pkg_ai.stdout + res_pkg_ai.stderr)
        self.assertIn("art/ai/cards/portrait/linsao.png", self.rels(pkg_ai_dir))
        res_pkg_human = common.run(["bash", pkg_script, "--stage-only", "--no-ai", "--src=" + self.src, "--staging=" + pkg_human_dir])
        self.assertEqual(res_pkg_human.returncode, 0, res_pkg_human.stdout + res_pkg_human.stderr)
        self.assertNotIn("art/ai/cards/portrait/linsao.png", self.rels(pkg_human_dir))

        # 4. Verify staged project.godot rewrites run/main_scene to CardGame.tscn and repo project.godot has run/main_scene.ship.
        for staged_dir in (dst_ai, dst_human, pkg_ai_dir, pkg_human_dir):
            with open(os.path.join(staged_dir, "project.godot"), encoding="utf-8") as fh:
                proj = fh.read()
            self.assertIn('run/main_scene="res://scenes/cards/CardGame.tscn"', proj)
            self.assertIn('run/main_scene.ship="res://scenes/cards/CardGame.tscn"', proj)
            self.assertNotIn('run/main_scene="res://scenes/Main.tscn"', proj)
        with open(os.path.join(common.ROOT, "project.godot"), encoding="utf-8") as fh:
            repo_proj = fh.read()
        self.assertIn('run/main_scene.ship="res://scenes/cards/CardGame.tscn"', repo_proj)


    def write_json(self, rel, data):
        path = os.path.join(self.src, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=2)

    def test_story_packs_follow_the_variant(self):
        human_prov = "human:A:2026-10-22"
        ai_prov = "ai:claude:opus-5.5:2026-10-22:packs-test"
        packs = {
            "story_h": {"source": "human", "_provenance": human_prov},
            "story_ai": {"source": "ai", "_provenance": ai_prov, "order": 10},
            "off": {"source": "human", "_provenance": human_prov, "enabled": False},
            "_dev": {"source": "ai", "_provenance": ai_prov},
            "nosource": {"_provenance": human_prov},
        }
        for pack_id, extra in packs.items():
            manifest = {"id": pack_id, "name": "剧情 " + pack_id, "version": "1", "compat": "cards-text/1",
                        "_doc": "DROP-DOC", "brief": "DROP-BRIEF"}
            manifest.update(extra)
            self.write_json("packs/%s/pack.json" % pack_id, manifest)
            self.write_json("packs/%s/text/era/1938/a.text.json" % pack_id, {
                "_meta": {"_provenance": extra["_provenance"]},
                "p.a": {"body": "Pack body " + pack_id, "brief": "DROP-ENTRY-BRIEF"},
            })
        self.write_json("packs/mismatch/pack.json", {"id": "other", "source": "human", "_provenance": human_prov})
        os.makedirs(os.path.join(self.src, "packs", "broken"), exist_ok=True)
        with open(os.path.join(self.src, "packs", "broken", "pack.json"), "w", encoding="utf-8") as fh:
            fh.write("{not json")
        with open(os.path.join(self.src, "packs", "story_h", "README.md"), "w", encoding="utf-8") as fh:
            fh.write("notes\n")
        with open(os.path.join(self.src, "packs", "story_h", "text", "notes.txt"), "w", encoding="utf-8") as fh:
            fh.write("notes\n")
        with open(os.path.join(self.src, "packs", "loose.pck"), "wb") as fh:
            fh.write(b"GDPC")

        dst_ai = os.path.join(self.tmp, "packs_ai")
        proc = common.run([common.PY, os.path.join(common.AUDIT, "stage_ship.py"), dst_ai, "--src=" + self.src,
                           "--variant=ai-disclosure"])
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        staged = [r for r in self.rels(dst_ai) if r.startswith("packs/")]
        self.assertEqual(staged, [
            "packs/story_ai/pack.json",
            "packs/story_ai/text/era/1938/a.text.json",
            "packs/story_h/pack.json",
            "packs/story_h/text/era/1938/a.text.json",
        ])
        with open(os.path.join(dst_ai, "packs", "story_ai", "pack.json"), encoding="utf-8") as fh:
            manifest = json.load(fh)
        self.assertEqual(manifest["_provenance"], ai_prov)
        self.assertNotIn("_doc", manifest)
        self.assertNotIn("brief", manifest)
        self.assertEqual(manifest["name"], "剧情 story_ai")
        with open(os.path.join(dst_ai, "packs", "story_h", "text", "era", "1938", "a.text.json"), encoding="utf-8") as fh:
            text = json.load(fh)
        self.assertEqual(text["_meta"]["_provenance"], human_prov)
        self.assertEqual(text["p.a"], {"body": "Pack body story_h"})

        dst_human = os.path.join(self.tmp, "packs_human")
        proc = common.run([common.PY, os.path.join(common.AUDIT, "stage_ship.py"), dst_human, "--src=" + self.src,
                           "--no-ai"])
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        staged = [r for r in self.rels(dst_human) if r.startswith("packs/")]
        self.assertEqual(staged, ["packs/story_h/pack.json", "packs/story_h/text/era/1938/a.text.json"])


def brief_paths(value, path=""):
    found = []
    if isinstance(value, dict):
        for key, child in value.items():
            here = "%s.%s" % (path, key) if path else key
            if key == "brief":
                found.append(here)
            found.extend(brief_paths(child, here))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            found.extend(brief_paths(child, "%s[%d]" % (path, index)))
    return found


if __name__ == "__main__":
    unittest.main()
