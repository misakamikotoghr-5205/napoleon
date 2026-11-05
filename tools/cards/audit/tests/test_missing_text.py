"""missing_text.py lists fields and mechanism notes, and never copies brief text."""
import json
import os
import shutil
import tempfile
import unittest

import common

LEAKS = [
    "THIS_BRIEF_MUST_NOT_LEAK_PERSON",
    "THIS_BRIEF_MUST_NOT_LEAK_CHOICE",
    "THIS_BRIEF_MUST_NOT_LEAK_CARD",
    "THIS_BRIEF_MUST_NOT_LEAK_DONE",
    "THIS_BRIEF_MUST_NOT_LEAK_ERA",
    "THIS_BRIEF_MUST_NOT_LEAK_GUIDE",
    "THIS_BRIEF_MUST_NOT_LEAK_RULE",
    "THIS_BRIEF_MUST_NOT_LEAK_UI",
    "THIS_BRIEF_MUST_NOT_LEAK_HELP",
    "THIS_BRIEF_MUST_NOT_LEAK_OBS",
    "THIS_BRIEF_MUST_NOT_LEAK_CODE",
    "THIS_BRIEF_MUST_NOT_LEAK_STAGE",
    "THIS_BRIEF_MUST_NOT_LEAK_LABEL",
    "THIS_BRIEF_MUST_NOT_LEAK_NAME",
    "THIS_BRIEF_MUST_NOT_LEAK_CAST",
    "THIS_BRIEF_MUST_NOT_LEAK_CASTBRIEF",
    "THIS_BRIEF_MUST_NOT_LEAK_STAGECHOICE",
    "THIS_BRIEF_MUST_NOT_LEAK_STAGECARD",
    "THIS_BRIEF_MUST_NOT_LEAK_STAGEBLOCK",
    "THIS_BRIEF_MUST_NOT_LEAK_CASTSLOT",
    "THIS_BRIEF_MUST_NOT_LEAK_PROP",
    "THIS_BRIEF_MUST_NOT_LEAK_BEATBODY",
    "THIS_BRIEF_MUST_NOT_LEAK_BEATGREET",
    "THIS_BRIEF_MUST_NOT_LEAK_BEATME",
    "THIS_BRIEF_MUST_NOT_LEAK_BEATHIDE",
    "THIS_BRIEF_MUST_NOT_LEAK_BEATCHOICE",
    "THIS_BRIEF_MUST_NOT_LEAK_EMPTYEXPIRE",
    "THIS_BRIEF_MUST_NOT_LEAK_GRUDGE",
    "THIS_BRIEF_MUST_NOT_LEAK_FATE",
    "THIS_BRIEF_MUST_NOT_LEAK_STREET",
    "THIS_BRIEF_MUST_NOT_LEAK_BIGFATE",
    "THIS_BRIEF_MUST_NOT_LEAK_LIFE",
    "THIS_BRIEF_MUST_NOT_LEAK_PRISON",
    "THIS_BRIEF_MUST_NOT_LEAK_EXTRA",
    "THIS_BRIEF_MUST_NOT_LEAK_EXTRA2",
    "THIS_BRIEF_MUST_NOT_LEAK_G02",
    "THIS_BRIEF_MUST_NOT_LEAK_G02B",
    "THIS_BRIEF_MUST_NOT_LEAK_G01",
]


class MissingTextTests(unittest.TestCase):
    def test_fixture_list_is_complete_and_has_no_brief(self):
        tmp = tempfile.mkdtemp(prefix="k15-missing-")
        try:
            out = os.path.join(tmp, "missing_text")
            proc = common.run([
                common.PY, os.path.join(common.AUDIT, "missing_text.py"),
                "--src=" + os.path.join(common.FIX, "missing_src"),
                "--out=" + out,
            ])
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            self.assertRegex(proc.stdout.strip(), r"^MISSING TEXT \d+ entries, A=\d+ B=\d+$")
            with open(out + ".json", encoding="utf-8") as fh:
                payload = json.load(fh)
            with open(out + ".md", encoding="utf-8") as fh:
                md = fh.read()
            blob = json.dumps(payload, ensure_ascii=False) + md
            for leak in LEAKS:
                self.assertNotIn(leak, blob)
            by_id = {}
            for row in payload["entries"]:
                by_id.setdefault(row["id"], row)
            self.assertNotIn("p.done.1938", by_id)
            self.assertNotIn("p.otherera", by_id)
            guide = by_id["gd.d1.deal"]
            self.assertEqual(guide["fields"], ["say", "bubble"])
            self.assertEqual(guide["notes"]["teaches"], ["deal"])
            self.assertEqual(guide["notes"]["teacher"], "brother")
            rule = by_id["rule.day"]
            self.assertEqual(rule["fields"], ["title", "body"])
            person = by_id["p.demo.1938"]
            for field in ("title", "body", "lines.greet", "lines.accept", "lines.leave", "lines.refused", "choices.listen"):
                self.assertIn(field, person["fields"])
            self.assertEqual(person["notes"]["choice_ids"], ["listen"])
            self.assertEqual(person["notes"]["slot_ids"], ["paper"])
            self.assertEqual(person["notes"]["person"], "linsao")
            self.assertEqual(by_id["w0.title.new"]["w0_stub"], True)
            self.assertIn("w0.title.new", md)
            self.assertIn("正式界面换掉后可删", md)
            self.assertEqual(by_id["c10.help.move"]["owner"], "B")
            self.assertEqual(by_id["c16.settings.guide_hints"]["fields"], ["t"])
            self.assertEqual(by_id["obs.spot.mark"]["fields"], ["t"])
            self.assertEqual(by_id["cb.word.0417"]["fields"], ["word"])
            self.assertEqual(by_id["stage.1938"]["fields"], ["intro.p1", "intro.p2"])
            self.assertEqual(by_id["stage.1938"]["notes"]["intro_paras"], 2)
            self.assertIn("name", by_id["item.rice.jing"]["fields"])
            self.assertEqual(by_id["brother"]["type"], "person_name")
            self.assertEqual(by_id["suanming"]["fields"], ["name"])
            self.assertGreater(payload["counts"]["A"], 0)
            self.assertGreater(payload["counts"]["B"], 0)
            for cid in (
                "ev.stage.1938", "p.grudge.1938", "fa.cold.1938",
                "st.rain.1938", "bf.box.1938", "lf.winter.1938",
            ):
                self.assertIn("outcomes.ignored", by_id[cid]["fields"], cid)
                self.assertEqual(by_id[cid]["fields"].count("outcomes.ignored"), 1, cid)
            self.assertNotIn("outcomes.ignored", by_id["ev.empty.1938"]["fields"])
            self.assertNotIn("outcomes.ignored", by_id["pr.cell"]["fields"])
            self.assertEqual(by_id["p.grudge.1938"]["fields"], [
                "title", "body", "lines.greet", "outcomes.ignored",
            ])
            staged = by_id["ev.stage.1938"]
            self.assertEqual(staged["fields"], [
                "title", "body", "choices.hide", "outcomes.ignored",
                "lines.greet", "lines.me_ask", "outcomes.hide",
            ])
            self.assertEqual(staged["fields"].count("body"), 1)
            self.assertEqual(staged["fields"].count("choices.hide"), 1)
            self.assertEqual(staged["notes"]["beats"], [
                {"ref": "body", "who": "旁白", "place": "intro"},
                {"ref": "lines.greet", "who": "ex_patrol", "place": "intro"},
                {"ref": "lines.me_ask", "who": "沈如花", "place": "intro"},
                {"ref": "outcomes.hide", "who": "旁白", "place": "after.hide"},
                {"ref": "choices.hide", "who": "ex_patrol", "place": "after.success"},
            ])
            self.assertIn("旁白", md)
            self.assertIn("沈如花", md)
            for key in ("w0.stage.enter", "w0.stage.at_door", "w0.stage.leave"):
                row = by_id[key]
                self.assertEqual(row["owner"], "A", key)
                self.assertEqual(row["w0_stub"], False, key)
                self.assertEqual(row["type"], "ui_key", key)
                self.assertEqual(row["fields"], ["t"], key)
                self.assertEqual(row["text_file"], "data/cards/text/ui/W0.text.json", key)
                self.assertEqual(row["notes"]["params"], ["name"], key)
            stub = md.split("## W0 桩用的键，正式界面换掉后可删", 1)[1]
            section_a = md.split("## A ·", 1)[1].split("## B ·", 1)[0]
            section_b = md.split("## B ·", 1)[1].split("## W0 桩用的键", 1)[0]
            for key in ("w0.stage.enter", "w0.stage.at_door", "w0.stage.leave"):
                self.assertIn("`%s`" % key, section_a)
                self.assertNotIn(key, stub)
            self.assertIn("`w0.title.new`", stub)
            for key in ("g02.end.leave", "g02.end.ignore", "g01.end.wait"):
                row = by_id[key]
                self.assertEqual(row["owner"], "B", key)
                self.assertEqual(row["w0_stub"], False, key)
                self.assertEqual(row["type"], "ui_key", key)
                self.assertEqual(row["fields"], ["t"], key)
                self.assertIn("`%s`" % key, section_b)
                self.assertNotIn(key, stub)
            for pid in ("ex_patrol", "ex_vendor"):
                row = by_id[pid]
                self.assertEqual(row["type"], "person_name", pid)
                self.assertEqual(row["owner"], "A", pid)
                self.assertEqual(row["fields"], ["name"], pid)
                self.assertEqual(row["text_file"], "data/cards/text/persons.text.json", pid)
                self.assertIn("extras.json", row["file"])
                self.assertIn("`%s`" % pid, section_a)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_launch_items_rows_use_template(self):
        tmp = tempfile.mkdtemp(prefix="k15-launch-")
        try:
            src = os.path.join(tmp, "src")
            shutil.copytree(os.path.join(common.FIX, "missing_src"), src)
            items_dir = os.path.join(src, "data", "cards", "items")
            os.makedirs(items_dir)
            with open(os.path.join(items_dir, "launch_items.json"), "w", encoding="utf-8") as fh:
                json.dump({
                    "_meta": {"owner": "K11", "schema": 1, "brief": "THIS_BRIEF_MUST_NOT_LEAK_LAUNCH"},
                    "items": [
                        {"template": "rice.jing", "eras": ["1938"], "weight": 5, "brief": "THIS_BRIEF_MUST_NOT_LEAK_LAUNCH"},
                        {"template": "silver.yuan_a", "eras": ["1938"], "weight": 0, "brief": "THIS_BRIEF_MUST_NOT_LEAK_LAUNCH"},
                    ],
                }, fh)
            out = os.path.join(tmp, "missing_text")
            proc = common.run([
                common.PY, os.path.join(common.AUDIT, "missing_text.py"),
                "--src=" + src, "--out=" + out,
            ])
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            with open(out + ".json", encoding="utf-8") as fh:
                payload = json.load(fh)
            by_id = {row["id"]: row for row in payload["entries"]}
            self.assertIn("name", by_id["item.rice.jing"]["fields"])
            self.assertEqual(by_id["item.silver.yuan_a"]["fields"], ["name"])
            self.assertTrue(by_id["item.silver.yuan_a"]["file"].endswith("launch_items.json"))
            self.assertNotIn("THIS_BRIEF_MUST_NOT_LEAK_LAUNCH", json.dumps(payload, ensure_ascii=False))
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
