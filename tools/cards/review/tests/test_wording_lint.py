# K13 措辞检查：只对夹具断言。不扫仓库真数据（别人的牌不能让各线 CI 变红）。
import io
import json
import os
import re
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import wording_lint

FIX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")
CJK_RE = re.compile(r"[\u3000-\u9fff\uf900-\ufaff\uff00-\uffef]")
RULES = [
    "puppet_prefix",
    "year_1945",
    "year_1949",
    "war_length",
    "fifties_no_punish",
    "no_violence_detail",
    "brief_no_dialogue",
    "guide_no_hidden",
    "no_percent",
]


def findings(rel, scope="all"):
    path = os.path.join(FIX, rel)
    return wording_lint.lint_paths([path], scope=scope)


def rules_of(rows, card_id=None):
    out = set()
    for f in rows:
        if card_id is None or f.card_id == card_id:
            out.add(f.rule_id)
    return out


class WordingLintTests(unittest.TestCase):
    def test_rule_ids_and_cjk_only_under_underscore(self):
        data = wording_lint.load_rules()
        ids = [r["id"] for r in data["rules"]]
        self.assertEqual(ids, RULES)
        for rule in data["rules"]:
            self.assertIn(rule["level"], ("must", "should", "hint"))
            self.assertTrue(rule["scope"])
            self.assertTrue(rule["kind"])
            self.assertTrue(rule.get("_doc"))
        bad = []

        def walk(node, underscore):
            if isinstance(node, dict):
                for k, v in node.items():
                    key = str(k)
                    if CJK_RE.search(key):
                        bad.append("key " + key)
                    if key == "brief" or key.startswith("_"):
                        continue
                    walk(v, False)
            elif isinstance(node, list):
                for item in node:
                    walk(item, underscore)
            elif isinstance(node, str) and not underscore and CJK_RE.search(node):
                bad.append(node)

        walk(data, False)
        self.assertEqual(bad, [])

    def test_each_bad_fixture_is_only_its_rule(self):
        cases = {
            "puppet_prefix": "puppet_bad.json",
            "year_1945": "year_1945_bad.json",
            "year_1949": "year_1949_bad.json",
            "war_length": "war_length_bad.json",
            "fifties_no_punish": "fifties_bad.json",
            "no_violence_detail": "violence_bad.json",
            "brief_no_dialogue": "dialogue_bad.json",
        }
        for rule, rel in cases.items():
            rows = findings(rel)
            self.assertIn(rule, rules_of(rows), rel)
            self.assertTrue(all(f.level == "must" for f in rows), rel)
            self.assertEqual(rules_of(rows), {rule}, "%s also hit %s" % (rel, rules_of(rows)))

    def test_good_fixtures_are_clean(self):
        for rel in (
            "puppet_good.json",
            "year_1945_good.json",
            "year_1949_good.json",
            "war_length_good.json",
            "fifties_good.json",
            "violence_good.json",
            "dialogue_good.json",
        ):
            self.assertEqual(findings(rel), [], rel)

    def test_puppet_choice_field_and_prefix_forms(self):
        rows = findings("puppet_bad.json")
        choice = [f for f in rows if f.card_id == "ev.1938.choice"]
        self.assertEqual(len(choice), 1)
        self.assertEqual(choice[0].field, "choices.pay.brief")
        self.assertIn("维持会", choice[0].message)
        # the card's own brief already has 伪维持会 and must not be flagged
        self.assertTrue(all(f.field != "brief" for f in choice))

    def test_fifties_structural_and_words_are_separate_fields(self):
        rows = findings("fifties_bad.json")
        struct = [f for f in rows if f.card_id == "ft.1951.bad"]
        self.assertEqual([f.field for f in struct], ["weight"])
        omen = [f for f in rows if f.card_id == "ev.1953.omen"]
        self.assertEqual([f.field for f in omen], ["weight"])
        meet = [f for f in rows if f.card_id == "ev.1952.meet"]
        self.assertEqual([f.field for f in meet], ["brief"])
        self.assertIn("斗争会", meet[0].message)

    def test_guide_steps_and_rule_pages(self):
        steps = findings("guide/steps.json")
        bad = [f for f in steps if f.card_id == "gd.bad.hidden"]
        self.assertTrue(any(f.rule_id == "guide_no_hidden" and f.level == "must" for f in bad))
        self.assertIn("概率", bad[0].message)
        self.assertIn("本心", bad[0].message)
        self.assertEqual([f for f in steps if f.card_id == "gd.ok.clean"], [])
        pages = findings("guide/rule_pages.json")
        self.assertEqual(rules_of(pages, "rule.bad.hidden"), {"guide_no_hidden"})
        self.assertEqual([f for f in pages if f.card_id == "rule.ok.clean"], [])

    def test_guide_text_percent_and_plain_text_percent(self):
        rows = findings("text/guide/steps.text.json")
        bad = [f for f in rows if f.card_id == "gd.bad.percent"]
        self.assertEqual(rules_of(rows, "gd.bad.percent"), {"no_percent", "guide_no_hidden"})
        self.assertTrue(all(f.field == "bubble" for f in bad))
        self.assertEqual([f for f in rows if f.card_id == "gd.ok.clean"], [])
        news = findings("text/news.text.json")
        self.assertEqual(rules_of(news, "nt.1938.price"), {"no_percent"})
        self.assertEqual([f for f in news if f.card_id == "nt.1938.ok"], [])
        # percent in a non-guide body is not a guide leak
        self.assertNotIn("guide_no_hidden", rules_of(news))

    def test_stage_briefs_quote_puppet_and_clean_beat(self):
        path = os.path.join(FIX, "stage_brief.json")
        with open(path, encoding="utf-8") as handle:
            card = json.load(handle)["cards"][0]
        fields = [field for field, _text in wording_lint._stage_briefs(card["stage"])]
        self.assertEqual(fields, [
            "stage.brief",
            "stage.cast[0].brief",
            "stage.cast[1].brief",
            "stage.props[0].brief",
            "stage.intro[0].brief",
            "stage.intro[1].brief",
            "stage.after.fail[0].brief",
            "stage.after.success[0].brief",
        ])
        quote = "把门打开，把良民证拿出来给我看看"
        self.assertGreater(len(quote), 12)
        rows = findings("stage_brief.json")
        self.assertEqual(
            [(f.card_id, f.field, f.rule_id, f.level) for f in rows],
            [
                ("ev.1938.police_check", "stage.cast[0].brief", "puppet_prefix", "must"),
                ("ev.1938.police_check", "stage.intro[0].brief", "brief_no_dialogue", "must"),
            ],
        )
        self.assertIn("维持会", rows[0].message)
        buf = io.StringIO()
        with redirect_stdout(buf):
            code = wording_lint.main([path])
        self.assertEqual(code, 0)
        lines = [ln for ln in buf.getvalue().splitlines() if ln.startswith("LINT MUST")]
        self.assertEqual(len(lines), 2)
        self.assertIn(":ev.1938.police_check:stage.cast[0].brief puppet_prefix ", lines[0])
        self.assertIn(":ev.1938.police_check:stage.intro[0].brief brief_no_dialogue ", lines[1])
        self.assertTrue(lines[1].startswith("LINT MUST "))
        self.assertNotIn("stage.intro[1].brief", buf.getvalue())
        self.assertNotIn("stage.cast[1].brief", buf.getvalue())
        self.assertNotIn("stage.props[0].brief", buf.getvalue())
        self.assertNotIn("stage.after.", buf.getvalue())
        self.assertTrue(buf.getvalue().strip().endswith("LINT DONE 2 must, 0 should, 0 hint"))
        self.assertEqual(findings("stage_brief.json", "text"), [])
        brief_rows = findings("stage_brief.json", "brief")
        self.assertEqual(rules_of(brief_rows), {"puppet_prefix", "brief_no_dialogue"})

    def test_post1949_docs(self):
        bad = findings("post1949/punish.md")
        self.assertEqual(rules_of(bad), {"fifties_no_punish"})
        self.assertEqual(findings("post1949/policy.md"), [])

    def test_scope_filter_matches_k15_text_call(self):
        self.assertEqual(findings("guide/steps.json", "text"), [])
        text_rows = findings("text/guide/steps.text.json", "text")
        self.assertIn("no_percent", rules_of(text_rows, "gd.bad.percent"))
        self.assertIn("guide_no_hidden", rules_of(text_rows, "gd.bad.percent"))
        self.assertEqual(findings("text/guide/steps.text.json", "brief"), [])
        self.assertEqual(findings("fifties_bad.json", "text"), [])
        brief_rows = findings("fifties_bad.json", "brief")
        self.assertEqual(rules_of(brief_rows), {"fifties_no_punish"})

    def test_cli_format_exit_and_json(self):
        bad = os.path.join(FIX, "year_1945_bad.json")
        good = os.path.join(FIX, "year_1945_good.json")
        buf = io.StringIO()
        with redirect_stdout(buf):
            code = wording_lint.main([bad])
        self.assertEqual(code, 0)
        text = buf.getvalue().strip().splitlines()
        self.assertTrue(text[-1].startswith("LINT DONE "))
        self.assertRegex(text[-1], r"^LINT DONE \d+ must, \d+ should, \d+ hint$")
        self.assertTrue(text[0].startswith("LINT MUST "))
        self.assertRegex(text[0], r"^LINT MUST \S+:\S+:\S+ \S+ .+$")
        buf = io.StringIO()
        with redirect_stdout(buf):
            code = wording_lint.main(["--fail-on=must", "--scope=all", bad])
        self.assertEqual(code, 1)
        buf = io.StringIO()
        with redirect_stdout(buf):
            code = wording_lint.main(["--fail-on=must", good])
        self.assertEqual(code, 0)
        self.assertTrue(buf.getvalue().strip().endswith("LINT DONE 0 must, 0 should, 0 hint"))
        # K15: wording_lint.py <path> --scope=text --fail-on=must
        guide_text = os.path.join(FIX, "text/guide/steps.text.json")
        buf = io.StringIO()
        with redirect_stdout(buf):
            code = wording_lint.main([guide_text, "--scope=text", "--fail-on=must"])
        self.assertEqual(code, 1)
        self.assertIn("no_percent", buf.getvalue())
        with tempfile.TemporaryDirectory() as tmp:
            outp = os.path.join(tmp, "out.json")
            buf = io.StringIO()
            with redirect_stdout(buf):
                code = wording_lint.main([bad, good, "--json=" + outp, "--fail-on=should"])
            self.assertEqual(code, 1)
            with open(outp, encoding="utf-8") as handle:
                payload = json.load(handle)
        self.assertGreaterEqual(payload["must"], 1)
        self.assertEqual(payload["should"], 0)
        self.assertEqual(payload["hint"], 0)
        files = [item["file"] for item in payload["items"]]
        self.assertEqual(files, sorted(files))

    def test_two_files_sorted_and_stable(self):
        a = os.path.join(FIX, "war_length_bad.json")
        b = os.path.join(FIX, "violence_bad.json")
        buf1 = io.StringIO()
        buf2 = io.StringIO()
        with redirect_stdout(buf1):
            wording_lint.main([b, a])
        with redirect_stdout(buf2):
            wording_lint.main([a, b])
        self.assertEqual(buf1.getvalue(), buf2.getvalue())
        lines = [ln for ln in buf1.getvalue().splitlines() if ln.startswith("LINT MUST")]
        self.assertEqual(lines, sorted(lines))

    def test_levels_format(self):
        line = wording_lint.format_line(wording_lint.Finding(
            "should", "a.json", "id.x", "brief", "some_rule", "note"
        ))
        self.assertEqual(line, "LINT SHOULD a.json:id.x:brief some_rule note")


if __name__ == "__main__":
    unittest.main()
