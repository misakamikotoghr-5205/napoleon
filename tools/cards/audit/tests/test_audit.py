"""Good-pack and one-bad-fixture-per-rule tests for audit.py."""
import os
import shutil
import subprocess
import tempfile
import unittest

import common


def setUpModule():
    dest = os.path.join(common.ROOT, "docs", "cards", "audit", "legacy_hashes.json")
    if not os.path.isfile(dest):
        subprocess.check_call([common.PY, os.path.join(common.AUDIT, "audit.py"), "--build-legacy-hashes"],
                              cwd=common.ROOT)


class AuditPackTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="k15-audit-")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def stage(self, name, overlay=None, legacy_candle=False):
        dst = os.path.join(self.tmp, name)
        overlay_path = os.path.join(common.FIX, "bad", overlay) if overlay else None
        common.build_stage(dst, overlay=overlay_path, legacy_candle=legacy_candle)
        return dst

    def run_audit(self, dst, pck=None):
        report = os.path.join(self.tmp, "report.md")
        proc = common.audit_cmd(dst, report, pck=pck)
        return proc, proc.stdout + proc.stderr, report

    def test_good_pack_items_1_and_3_through_9(self):
        dst = self.stage("good")
        with open(os.path.join(dst, "art", "cards", "portrait.png"), "rb") as fh:
            portrait = fh.read()
        pck = os.path.join(self.tmp, "good.pck")
        common.write_pck(pck, [("art/cards/portrait.png", portrait), ("data/cards/theme/palette.json", b"{}")])
        proc, out, report = self.run_audit(dst, pck=pck)
        self.assertEqual(proc.returncode, 0, out)
        self.assertTrue(out.strip().endswith("AUDIT OK"), out)
        self.assertNotIn("AUDIT FAIL:", out)
        with open(report, encoding="utf-8") as fh:
            text = fh.read()
        self.assertTrue(text.strip().endswith("AUDIT OK"))
        self.assertRegex(text, r"## 5\. .*\n\nOK\n")
        self.assertTrue(os.path.isfile(os.path.join(dst, "scripts", "cards", "ui", "plain.gd")))

    def test_pck_roundtrip_keeps_bytes(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("k15audit", os.path.join(common.AUDIT, "audit.py"))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        pck = os.path.join(self.tmp, "round.pck")
        blob = b"hello-bytes"
        common.write_pck(pck, [("docs/leak.txt", blob)])
        files = mod.read_pck(pck)
        self.assertEqual(files[0]["path"], "docs/leak.txt")
        self.assertEqual(files[0]["blob"], blob)

    def test_bad_brief(self):
        dst = self.stage("brief", "brief")
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(any("brief" in line for line in common.item_lines(out, 1)))

    def test_bad_placeholder_path(self):
        dst = self.stage("ph")
        path = os.path.join(dst, "art", "_placeholder", "x.png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as fh:
            fh.write(b"placeholder")
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(any("_placeholder" in line for line in common.item_lines(out, 1)))

    def test_bad_provenance(self):
        dst = self.stage("prov", "provenance")
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(any("not human" in line for line in common.item_lines(out, 2)))

    def test_missing_say_relays_validator(self):
        dst = self.stage("say", "missing_say")
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        lines = common.item_lines(out, 2)
        self.assertTrue(any("DATA ERROR:" in line and "say" in line for line in lines), out)

    def _item2_data_errors(self, out, report):
        lines = common.item_lines(out, 2)
        data = [line for line in lines if "DATA ERROR:" in line]
        with open(report, encoding="utf-8") as fh:
            text = fh.read()
        self.assertIn("## 2.", text)
        self.assertIn("\nFAIL\n", text)
        return lines, data, text

    def test_v27_missing_outcomes_ignored(self):
        dst = self.stage("ignored", "ignored")
        proc, out, report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        _lines, data, text = self._item2_data_errors(out, report)
        self.assertTrue(any("V27" in line and "outcomes.ignored" in line and "ev.ignored.miss" in line for line in data), out)
        self.assertFalse(any("ev.silent" in line for line in data), out)
        self.assertIn("outcomes.ignored", text)
        self.assertIn("V27", text)

    def test_v37_unwritten_ignore(self):
        dst = self.stage("v37", "v37")
        proc, out, report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        _lines, data, text = self._item2_data_errors(out, report)
        self.assertTrue(any("V37" in line and "ev.v37.miss" in line for line in data), out)
        for quiet in ("bf.wheel", "ev.pass", "ev.checked", "ev.blank"):
            self.assertFalse(any(quiet in line for line in data), quiet)
        self.assertIn("V37", text)

    def test_v27_stage_ref_unwritten(self):
        dst = self.stage("stage", "stage_ref")
        proc, out, report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        lines, data, text = self._item2_data_errors(out, report)
        self.assertTrue(lines, out)
        self.assertTrue(any(
            "DATA ERROR:" in line and "V27" in line and "lines.unwritten" in line and "ev.stage.miss" in line
            for line in data), out)
        self.assertFalse(any("field 'body'" in line for line in data), out)
        self.assertIn("lines.unwritten", text)
        self.assertIn("V27", text)

    def test_bad_legacy_art(self):
        dst = self.stage("legacy", "legacy_art")
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(any("legacy: true" in line for line in common.item_lines(out, 3)))

    def test_image_not_in_provenance(self):
        dst = self.stage("nocsv")
        extra = os.path.join(dst, "art", "cards", "unknown.png")
        shutil.copy(os.path.join(dst, "art", "cards", "portrait.png"), extra)
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(any("unknown.png" in line and "ASSET_PROVENANCE" in line for line in common.item_lines(out, 4)))

    def test_legacy_hash(self):
        dst = self.stage("hash", legacy_candle=True)
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(any("legacy blacklist" in line for line in common.item_lines(out, 4)), out)

    def test_cjk_in_string_not_comment(self):
        dst = self.stage("cjk", "cjk_gd")
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        lines = common.item_lines(out, 5)
        self.assertTrue(any("cjk.gd" in line and "string literal" in line for line in lines), out)
        self.assertFalse(any("plain.gd" in line for line in lines), out)

    def test_color_literal(self):
        dst = self.stage("color", "color_gd")
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(any("color.gd" in line and "Color" in line for line in common.item_lines(out, 5)), out)

    def test_palette_parse_exception_is_card_theme_only(self):
        # Contract §11.4 item 5: card_theme.gd may call Color.html to read palette.json; nothing else is exempt.
        dst = self.stage("theme")
        ui = os.path.join(dst, "scripts", "cards", "ui")
        theme = os.path.join(ui, "common", "card_theme.gd")
        os.makedirs(os.path.dirname(theme), exist_ok=True)
        shutil.copy(os.path.join(common.ROOT, "scripts", "cards", "ui", "common", "card_theme.gd"), theme)
        proc, out, _report = self.run_audit(dst)
        self.assertEqual(proc.returncode, 0, out)
        self.assertFalse(any("card_theme.gd" in line for line in common.item_lines(out, 5)), out)
        with open(theme, "a", encoding="utf-8", newline="\n") as fh:
            fh.write("\n\nstatic func _bad() -> Color:\n\tvar c := Color8(1, 2, 3)\n\treturn Color.MAGENTA\n")
        with open(os.path.join(ui, "parse.gd"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write('extends RefCounted\nfunc f() -> Color:\n\treturn Color.html("#123456")\n')
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        lines = common.item_lines(out, 5)
        self.assertTrue(any("card_theme.gd" in line and "Color.MAGENTA" in line for line in lines), out)
        self.assertTrue(any("card_theme.gd" in line and "Color8" in line for line in lines), out)
        self.assertTrue(any("parse.gd:3" in line and "Color.html" in line for line in lines), out)
        self.assertFalse(any("card_theme.gd" in line and "Color.html" in line for line in lines), out)

    def test_unguarded_audio(self):
        dst = self.stage("audio", "audio_gd")
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(any("audio.gd" in line and "AudioStreamGenerator" in line for line in common.item_lines(out, 5)), out)

    def test_ship_else_is_guarded_other_else_is_not(self):
        good = self.stage("else-good")
        proc, out, _report = self.run_audit(good)
        self.assertEqual(proc.returncode, 0, out)
        self.assertFalse(any("else_guard.gd" in line for line in common.item_lines(out, 5)), out)
        bad = self.stage("else-bad", "audio_else")
        proc, out, _report = self.run_audit(bad)
        self.assertNotEqual(proc.returncode, 0)
        lines = common.item_lines(out, 5)
        self.assertTrue(any("audio_else.gd" in line and "AudioStreamGenerator" in line for line in lines), out)
        self.assertTrue(any("audio_else.gd" in line and "legacy music" in line for line in lines), out)
        self.assertFalse(any("else_guard.gd" in line for line in lines), out)

    def test_string_and_comment_do_not_forge_a_guard(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("k15audit", os.path.join(common.AUDIT, "audit.py"))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        good = os.path.join(common.FIX, "good", "scripts", "cards", "ui", "else_guard.gd")
        with open(good, encoding="utf-8") as fh:
            self.assertEqual(mod.audio_hits(fh.read()), [])
        fake = os.path.join(common.FIX, "bad", "audio_fake_guard", "scripts", "cards", "ui", "audio_fake_guard.gd")
        with open(fake, encoding="utf-8") as fh:
            hits = mod.audio_hits(fh.read())
        self.assertTrue(any(msg == "AudioStreamGenerator" for _n, msg in hits), hits)
        self.assertTrue(any("legacy music" in msg and "open.ogg" in msg for _n, msg in hits), hits)
        self.assertTrue(any("legacy music" in msg and "returned.ogg" in msg for _n, msg in hits), hits)
        dst = self.stage("fake-guard", "audio_fake_guard")
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        lines = common.item_lines(out, 5)
        self.assertTrue(any("audio_fake_guard.gd" in line and "AudioStreamGenerator" in line for line in lines), out)
        self.assertTrue(any("audio_fake_guard.gd" in line and "legacy music" in line for line in lines), out)
        self.assertFalse(any("else_guard.gd" in line for line in lines), out)

    def test_review_180_multiline_string_is_not_a_guard(self):
        # GPT review on #180 (comment 6187700231). Column-0 if/else and a fake
        # early return live inside a multiline string. Walking those source
        # lines must not treat the later audio as guarded.
        import importlib.util
        spec = importlib.util.spec_from_file_location("k15audit", os.path.join(common.AUDIT, "audit.py"))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        src = (
            "extends Node\n"
            "func f():\n"
            "    var note = \"\"\"\n"
            "if CardShip.is_ship():\n"
            "    pass\n"
            "else:\n"
            "    \"\"\"\n"
            "    var generator := AudioStreamGenerator.new()\n"
            "    var legacy := \"res://audio/music/open.ogg\"\n"
        )
        lines = src.splitlines()
        func_at = lines.index("func f():")
        func_lines = lines[func_at:]
        gen = next(i for i, line in enumerate(func_lines) if "AudioStreamGenerator" in line)
        leg = next(i for i, line in enumerate(func_lines) if "open.ogg" in line)
        self.assertFalse(mod.line_is_guarded(func_lines, gen), func_lines)
        self.assertFalse(mod.line_is_guarded(func_lines, leg), func_lines)
        hits = mod.audio_hits(src)
        self.assertIn((gen + func_at + 1, "AudioStreamGenerator"), hits)
        self.assertTrue(any(n == leg + func_at + 1 and "open.ogg" in msg for n, msg in hits), hits)

        early = (
            "extends Node\n"
            "func f():\n"
            "    var note = \"\"\"\n"
            "if CardShip.is_ship():\n"
            "    return\n"
            "\"\"\"\n"
            "    var generator := AudioStreamGenerator.new()\n"
            "    var legacy := \"res://audio/music/returned.ogg\"\n"
        )
        elines = early.splitlines()
        efunc = elines.index("func f():")
        ebody = elines[efunc:]
        egen = next(i for i, line in enumerate(ebody) if "AudioStreamGenerator" in line)
        eleg = next(i for i, line in enumerate(ebody) if "returned.ogg" in line)
        self.assertFalse(mod.line_is_guarded(ebody, egen), ebody)
        self.assertFalse(mod.line_is_guarded(ebody, eleg), ebody)
        ehits = mod.audio_hits(early)
        self.assertIn((egen + efunc + 1, "AudioStreamGenerator"), ehits)
        self.assertTrue(any(n == eleg + efunc + 1 and "returned.ogg" in msg for n, msg in ehits), ehits)

        good = os.path.join(common.FIX, "good", "scripts", "cards", "ui", "else_guard.gd")
        with open(good, encoding="utf-8") as fh:
            good_src = fh.read()
        self.assertEqual(mod.audio_hits(good_src), [])
        glines = good_src.splitlines()
        # Real ship-else, including the body after it, stays guarded.
        start = glines.index("func legacy_in_else():")
        end = glines.index("func legacy_else_same_line():")
        body = glines[start:end]
        hit = next(i for i, line in enumerate(body) if "AudioStreamGenerator" in line)
        self.assertTrue(mod.line_is_guarded(body, hit), body)

    def test_review_180_escaped_triple_quote_is_not_a_guard(self):
        # GPT review on #180 (comment 6188831818, restated in 6189952610).
        # Inside a triple-quoted string, a backslash escapes the next character,
        # so \""" is not a closer. The scanner used to honor backslashes only
        # outside triple quotes: the fake early-return became code, and the
        # real closer opened a new string that hid AudioStreamGenerator.
        import importlib.util
        spec = importlib.util.spec_from_file_location("k15audit", os.path.join(common.AUDIT, "audit.py"))
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
        lines = src.splitlines()
        func_at = lines.index("func f():")
        func_lines = lines[func_at:]
        gen = next(i for i, line in enumerate(func_lines) if "AudioStreamGenerator" in line)
        leg = next(i for i, line in enumerate(func_lines) if "open.ogg" in line)
        _strings, mask, reliable = mod.gd_strings_and_mask(src)
        self.assertTrue(reliable, mask)
        self.assertNotIn("is_ship", mask)
        self.assertNotIn("return", mask)
        self.assertIn("AudioStreamGenerator", mask)
        self.assertFalse(mod.line_is_guarded(func_lines, gen), mask)
        self.assertFalse(mod.line_is_guarded(func_lines, leg), mask)
        hits = mod.audio_hits(src)
        self.assertIn((gen + func_at + 1, "AudioStreamGenerator"), hits)
        self.assertTrue(any(n == leg + func_at + 1 and "open.ogg" in msg for n, msg in hits), hits)

        # Odd run of backslashes (three): the first quote is escaped, so """ does not close.
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
        olines = odd.splitlines()
        ofunc = olines.index("func f():")
        obody = olines[ofunc:]
        ogen = next(i for i, line in enumerate(obody) if "AudioStreamGenerator" in line)
        oleg = next(i for i, line in enumerate(obody) if "odd.ogg" in line)
        _strings, omask, reliable = mod.gd_strings_and_mask(odd)
        self.assertTrue(reliable, omask)
        self.assertNotIn("is_ship", omask)
        self.assertIn("AudioStreamGenerator", omask)
        self.assertFalse(mod.line_is_guarded(obody, ogen), omask)
        self.assertFalse(mod.line_is_guarded(obody, oleg), omask)
        ohits = mod.audio_hits(odd)
        self.assertIn((ogen + ofunc + 1, "AudioStreamGenerator"), ohits)
        self.assertTrue(any(n == oleg + ofunc + 1 and "odd.ogg" in msg for n, msg in ohits), ohits)

        # Even run (two): """ really closes. Audio after it is real and unguarded.
        even = (
            "extends Node\n"
            "func f():\n"
            "    var _note = \"\"\"\n"
            "\\\\\"\"\"\n"
            "    var _generator := AudioStreamGenerator.new()\n"
            "    var _legacy := \"res://audio/music/even.ogg\"\n"
        )
        self.assertEqual(even.splitlines()[3], '\\\\"""')
        elines = even.splitlines()
        efunc = elines.index("func f():")
        ebody = elines[efunc:]
        egen = next(i for i, line in enumerate(ebody) if "AudioStreamGenerator" in line)
        eleg = next(i for i, line in enumerate(ebody) if "even.ogg" in line)
        _strings, emask, reliable = mod.gd_strings_and_mask(even)
        self.assertTrue(reliable, emask)
        self.assertIn("AudioStreamGenerator", emask)
        self.assertFalse(mod.line_is_guarded(ebody, egen), emask)
        self.assertFalse(mod.line_is_guarded(ebody, eleg), emask)
        ehits = mod.audio_hits(even)
        self.assertIn((egen + efunc + 1, "AudioStreamGenerator"), ehits)
        self.assertTrue(any(n == eleg + efunc + 1 and "even.ogg" in msg for n, msg in ehits), ehits)

        # An unclosed literal must not blank the tail into a clean mask, and a
        # fake early-return inside that tail must not count as a guard.
        unclosed = (
            "extends Node\n"
            "func f():\n"
            "    var _note = \"\"\"\n"
            "if CardShip.is_ship():\n"
            "    return\n"
            "    var _generator := AudioStreamGenerator.new()\n"
            "    var _legacy := \"res://audio/music/open.ogg\"\n"
        )
        _strings, umask, reliable = mod.gd_strings_and_mask(unclosed)
        self.assertFalse(reliable)
        self.assertIn("AudioStreamGenerator", umask)
        ulines = unclosed.splitlines()
        ufunc = ulines.index("func f():")
        ubody = ulines[ufunc:]
        ugen = next(i for i, line in enumerate(ubody) if "AudioStreamGenerator" in line)
        self.assertFalse(mod.line_is_guarded(ubody, ugen), umask)
        uhits = mod.audio_hits(unclosed)
        self.assertTrue(any(msg == "AudioStreamGenerator" for _n, msg in uhits), uhits)
        self.assertTrue(any("open.ogg" in msg for _n, msg in uhits), uhits)

        fixture = os.path.join(
            common.FIX, "bad", "audio_escape_guard", "scripts", "cards", "ui", "audio_escape_guard.gd")
        with open(fixture, encoding="utf-8") as fh:
            fixture_src = fh.read()
        self.assertIn('\\"""', fixture_src)
        fhits = mod.audio_hits(fixture_src)
        self.assertTrue(any(msg == "AudioStreamGenerator" for _n, msg in fhits), fhits)
        self.assertTrue(any("open.ogg" in msg for _n, msg in fhits), fhits)
        dst = self.stage("escape-guard", "audio_escape_guard")
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        fail_lines = common.item_lines(out, 5)
        self.assertTrue(any("audio_escape_guard.gd" in line and "AudioStreamGenerator" in line for line in fail_lines), out)
        self.assertTrue(any("audio_escape_guard.gd" in line and "legacy music" in line for line in fail_lines), out)
        self.assertFalse(any("else_guard.gd" in line for line in fail_lines), out)

    def test_verdict_word_only_in_observation(self):
        dst = self.stage("verdict", "verdict")
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        lines = common.item_lines(out, 6)
        self.assertTrue(any("赝品" in line and "obs" in line for line in lines), out)
        self.assertFalse(any("people.text" in line and "赝品" in line for line in lines), out)

    def test_percent_in_guide_bubble(self):
        dst = self.stage("pct", "percent")
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(any("%" in line and "gd.pct" in line for line in common.item_lines(out, 6)), out)

    def test_missing_glyph(self):
        dst = self.stage("glyph", "glyph")
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(any("丂" in line for line in common.item_lines(out, 7)), out)

    def test_palette_missing(self):
        dst = self.stage("pal")
        os.remove(os.path.join(dst, "data", "cards", "theme", "palette.json"))
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(any("palette.json" in line for line in common.item_lines(out, 8)))

    def test_pck_contains_docs(self):
        dst = self.stage("pck")
        pck = os.path.join(self.tmp, "bad.pck")
        common.write_pck(pck, [("docs/leak.txt", b"nope")])
        proc, out, _report = self.run_audit(dst, pck=pck)
        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(any("docs/leak.txt" in line for line in common.item_lines(out, 9)), out)

    def test_wording_lint_missing_fails_closed(self):
        dst = self.stage("lint")
        report = os.path.join(self.tmp, "report.md")
        proc = common.audit_cmd(dst, report, lint=os.path.join(self.tmp, "no-such-lint.py"))
        out = proc.stdout + proc.stderr
        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(any("wording_lint" in line for line in common.item_lines(out, 6)), out)

    def test_ai_disclosure_counts_provenance_and_human_override(self):
        import json
        dst = self.stage("ai-good")
        # Add AI art (one standalone AI art, one overridden by existing art/cards/portrait.png)
        os.makedirs(os.path.join(dst, "art", "ai", "cards"), exist_ok=True)
        shutil.copy(
            os.path.join(dst, "art", "cards", "portrait.png"),
            os.path.join(dst, "art", "ai", "cards", "portrait.png"),
        )
        shutil.copy(
            os.path.join(dst, "art", "cards", "portrait.png"),
            os.path.join(dst, "art", "ai", "cards", "ai_only.png"),
        )
        manifest_path = os.path.join(dst, "data", "cards", "art", "manifest.json")
        with open(manifest_path, encoding="utf-8") as fh:
            manifest = json.load(fh)
        manifest["art"]["portrait.demo"]["ai"] = "art/ai/cards/portrait.png"
        manifest["art"]["portrait.demo"]["_provenance"] = "ai:google-imagen:2026-10-18:portrait.demo.v1"
        manifest["art"]["portrait.ai_only"] = {
            "base": [48, 64],
            "human": "",
            "ai": "art/ai/cards/ai_only.png",
            "_provenance": "ai:google-imagen:2026-10-18:portrait.ai_only.v1",
        }
        with open(manifest_path, "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, ensure_ascii=False, indent=2)

        # Reference portrait.ai_only in card data
        people_path = os.path.join(dst, "data", "cards", "era", "1938", "people.json")
        with open(people_path, encoding="utf-8") as fh:
            people = json.load(fh)
        people["cards"][0]["bg"] = "portrait.ai_only"
        with open(people_path, "w", encoding="utf-8") as fh:
            json.dump(people, fh, ensure_ascii=False, indent=2)

        # Add AI audio with provenance
        os.makedirs(os.path.join(dst, "audio", "ai", "music"), exist_ok=True)
        with open(os.path.join(dst, "audio", "ai", "music", "day.ogg"), "wb") as fh:
            fh.write(b"OggS-ai-audio-bytes")
        os.makedirs(os.path.join(dst, "data", "cards", "audio"), exist_ok=True)
        with open(os.path.join(dst, "data", "cards", "audio", "music.json"), "w", encoding="utf-8") as fh:
            json.dump({
                "_meta": {"owner": "C16", "schema": 1},
                "cues": {
                    "day": {
                        "human": "",
                        "ai": "audio/ai/music/day.ogg",
                        "_provenance": "ai:google-lyria:2026-10-18:cue.day.v1",
                    }
                },
            }, fh, ensure_ascii=False, indent=2)

        # Add AI text with 5-part provenance
        os.makedirs(os.path.join(dst, "data", "cards", "text_ai", "era", "1938"), exist_ok=True)
        with open(os.path.join(dst, "data", "cards", "text_ai", "era", "1938", "ai_extra.text.json"), "w", encoding="utf-8") as fh:
            json.dump({
                "_meta": {"_provenance": "ai:google:gemini-2.5-pro:2026-10-18:212-1"},
                "p.demo.1938": {"title": "Title"},
                "ui.ai_only": {"t": "Body"},
            }, fh, ensure_ascii=False, indent=2)

        report = os.path.join(self.tmp, "report_ai.md")
        proc = common.audit_cmd(dst, report, variant="ai-disclosure")
        out = proc.stdout + proc.stderr
        self.assertEqual(proc.returncode, 0, out)
        self.assertTrue(out.strip().endswith("AUDIT OK"), out)

        with open(report, encoding="utf-8") as fh:
            text = fh.read()
        self.assertIn("- variant: ai-disclosure", text)
        self.assertIn("AI 生成、需声明 (5 项)", text)
        self.assertIn("分类统计: total=5, art=2, audio=1, text=2", text)
        self.assertIn("已被人工资产覆盖: art=1, audio=0, text=1", text)
        self.assertIn("ai:google-imagen: 2 (AI 生成、需声明)", text)
        self.assertIn("ai:google-lyria: 1 (AI 生成、需声明)", text)
        self.assertIn("ai:google:gemini-2.5-pro: 2 (AI 生成、需声明)", text)

        # In no-disclosure mode, the exact same directory must fail on items 1, 2, 3, and 4!
        report_no_ai = os.path.join(self.tmp, "report_no_ai.md")
        proc_no_ai = common.audit_cmd(dst, report_no_ai, variant="no-disclosure")
        out_no_ai = proc_no_ai.stdout + proc_no_ai.stderr
        self.assertNotEqual(proc_no_ai.returncode, 0, out_no_ai)
        self.assertTrue(any("art/ai/cards/ai_only.png must not be shipped" in ln for ln in common.item_lines(out_no_ai, 1)), out_no_ai)
        self.assertTrue(any("text_ai" in ln for ln in common.item_lines(out_no_ai, 2)), out_no_ai)
        self.assertTrue(any("portrait.ai_only" in ln for ln in common.item_lines(out_no_ai, 3)), out_no_ai)
        self.assertTrue(any("no-disclosure mode" in ln for ln in common.item_lines(out_no_ai, 4)), out_no_ai)

    def add_pack(self, dst, pack_id, source, text, **extra):
        import json
        prov = "human:A:2026-10-22" if source == "human" else "ai:claude:opus-5.5:2026-10-22:packs-test"
        manifest = {"id": pack_id, "name": "剧情插件 " + pack_id, "version": "1", "source": source,
                    "_provenance": prov, "compat": "cards-text/1"}
        manifest.update(extra)
        base = os.path.join(dst, "packs", pack_id)
        os.makedirs(os.path.join(base, "text", "era", "1938"), exist_ok=True)
        with open(os.path.join(base, "pack.json"), "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, ensure_ascii=False, indent=2)
        with open(os.path.join(base, "text", "era", "1938", "people.text.json"), "w", encoding="utf-8") as fh:
            json.dump(dict({"_meta": {"_provenance": prov}}, **text), fh, ensure_ascii=False, indent=2)
        return base

    def test_story_packs_counted_per_variant(self):
        dst = self.stage("packs-good")
        # human pack stacked above the AI pack hides the AI title; greet stays active AI text
        self.add_pack(dst, "story_h", "human", {"p.demo.1938": {"title": "Pack title", "body": "Pack body"}}, order=20)
        self.add_pack(dst, "story_ai", "ai", {"p.demo.1938": {"title": "AI title", "lines": {"greet": "AI greet"}}},
                      order=10)
        report = os.path.join(self.tmp, "report_packs.md")
        proc = common.audit_cmd(dst, report, variant="ai-disclosure")
        out = proc.stdout + proc.stderr
        self.assertEqual(proc.returncode, 0, out)
        self.assertTrue(out.strip().endswith("AUDIT OK"), out)
        with open(report, encoding="utf-8") as fh:
            text = fh.read()
        self.assertIn("分类统计: total=1, art=0, audio=0, text=1", text)
        self.assertIn("台词字段级统计: total_fields=2, active_ai_fields=1, overridden_fields=1, partial_entries=1", text)
        self.assertIn("ai:claude:opus-5.5: 1 (AI 生成、需声明)", text)

        report_no_ai = os.path.join(self.tmp, "report_packs_no_ai.md")
        proc_no_ai = common.audit_cmd(dst, report_no_ai, variant="no-disclosure")
        out_no_ai = proc_no_ai.stdout + proc_no_ai.stderr
        self.assertNotEqual(proc_no_ai.returncode, 0, out_no_ai)
        self.assertTrue(any("packs/story_ai is not a human story pack" in ln for ln in common.item_lines(out_no_ai, 1)),
                        out_no_ai)
        self.assertFalse(any("story_h" in ln for ln in out_no_ai.splitlines() if ln.startswith("AUDIT FAIL")), out_no_ai)

        # without the AI pack the same tree passes the no-disclosure audit
        shutil.rmtree(os.path.join(dst, "packs", "story_ai"))
        proc_human = common.audit_cmd(dst, report_no_ai, variant="no-disclosure")
        self.assertEqual(proc_human.returncode, 0, proc_human.stdout + proc_human.stderr)

    def test_story_pack_bad_paths_provenance_and_percent(self):
        import json
        dst = self.stage("packs-bad")
        self.add_pack(dst, "_dev", "ai", {"p.demo.1938": {"body": "dev"}})
        self.add_pack(dst, "off", "human", {"p.demo.1938": {"body": "off"}}, enabled=False)
        self.add_pack(dst, "bad_prov", "ai", {"p.demo.1938": {"body": "x"}}, _provenance="human:A:2026-10-22")
        base = self.add_pack(dst, "pct", "human", {"p.demo.1938": {"body": "half 50% off"}})
        with open(os.path.join(base, "README.md"), "w", encoding="utf-8") as fh:
            fh.write("notes\n")
        with open(os.path.join(base, "text", "era", "1938", "people.text.json"), encoding="utf-8") as fh:
            doc = json.load(fh)
        doc["p.demo.1938"]["brief"] = "draft note"
        with open(os.path.join(base, "text", "era", "1938", "people.text.json"), "w", encoding="utf-8") as fh:
            json.dump(doc, fh)
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0, out)
        item1 = common.item_lines(out, 1)
        self.assertTrue(any("packs/_dev/pack.json must not be shipped" in ln for ln in item1), out)
        self.assertTrue(any("packs/off is disabled" in ln for ln in item1), out)
        self.assertTrue(any("packs/pct/README.md must not be shipped" in ln for ln in item1), out)
        self.assertTrue(any("packs/pct/text/era/1938/people.text.json key p.demo.1938.brief" in ln for ln in item1), out)
        self.assertTrue(any("packs/bad_prov/pack.json _provenance is not ai:" in ln for ln in common.item_lines(out, 2)), out)
        self.assertTrue(any("packs/pct/text/era/1938/people.text.json: p.demo.1938 contains '%'" in ln
                            for ln in common.item_lines(out, 6)), out)
        self.assertFalse(common.item_lines(out, 5), out)

    def test_pck_story_pack_checked_per_variant(self):
        dst = self.stage("packs-pck")
        pck = os.path.join(self.tmp, "packs.pck")
        common.write_pck(pck, [
            ("packs/story_ai/pack.json", b'{"id": "story_ai", "source": "ai"}'),
            ("packs/off/pack.json", b'{"id": "off", "source": "human", "enabled": false}'),
            ("packs/_dev/pack.json", b'{"id": "_dev", "source": "human"}'),
        ])
        report = os.path.join(self.tmp, "report_pck.md")
        proc = common.audit_cmd(dst, report, pck=pck, variant="no-disclosure")
        out = proc.stdout + proc.stderr
        item9 = common.item_lines(out, 9)
        self.assertTrue(any("story_ai is not human-written" in ln for ln in item9), out)
        self.assertTrue(any("story pack off is disabled" in ln for ln in item9), out)
        self.assertTrue(any("packs/_dev/pack.json must not be shipped" in ln for ln in item9), out)
        proc_ai = common.audit_cmd(dst, report, pck=pck, variant="ai-disclosure")
        item9_ai = common.item_lines(proc_ai.stdout + proc_ai.stderr, 9)
        self.assertFalse(any("story_ai" in ln for ln in item9_ai), proc_ai.stdout)

    def test_ai_asset_missing_provenance_fails_in_ai_disclosure(self):
        import json
        dst = self.stage("ai-unreg")
        os.makedirs(os.path.join(dst, "art", "ai", "cards"), exist_ok=True)
        shutil.copy(
            os.path.join(dst, "art", "cards", "portrait.png"),
            os.path.join(dst, "art", "ai", "cards", "unregistered.png"),
        )
        os.makedirs(os.path.join(dst, "data", "cards", "text_ai", "era", "1938"), exist_ok=True)
        with open(os.path.join(dst, "data", "cards", "text_ai", "era", "1938", "bad.text.json"), "w", encoding="utf-8") as fh:
            json.dump({
                "_meta": {"_provenance": "bad-prov"},
                "ui.bad": {"t": "算盘"},
            }, fh, ensure_ascii=False, indent=2)
        report = os.path.join(self.tmp, "report_unreg.md")
        proc = common.audit_cmd(dst, report, variant="ai-disclosure")
        out = proc.stdout + proc.stderr
        self.assertNotEqual(proc.returncode, 0, out)
        self.assertTrue(any("ui.bad" in ln and "ai:" in ln for ln in common.item_lines(out, 2)), out)
        self.assertTrue(any("unregistered.png" in ln and "missing valid ai:..." in ln for ln in common.item_lines(out, 4)), out)

        # 4-segment provenance in text_ai (missing <model>), entry-only provenance (missing file _meta),
        # and conflicting entry vs file provenance must all fail item 2.
        for label, payload in (
            ("four_seg", {"_meta": {"_provenance": "ai:google-gemini:2026-10-18:212-1"}, "ui.bad": {"t": "算盘"}}),
            ("entry_only", {"_meta": {}, "ui.bad": {"_provenance": "ai:google:gemini-2.5-pro:2026-10-18:212-1", "t": "算盘"}}),
            (
                "conflict",
                {
                    "_meta": {"_provenance": "ai:google:gemini-2.5-pro:2026-10-18:212-1"},
                    "ui.bad": {"_provenance": "ai:other:model:2026-10-18:other", "t": "算盘"},
                },
            ),
        ):
            case_dst = self.stage("ai-prov-" + label)
            os.makedirs(os.path.join(case_dst, "data", "cards", "text_ai", "era", "1938"), exist_ok=True)
            with open(os.path.join(case_dst, "data", "cards", "text_ai", "era", "1938", "bad.text.json"), "w", encoding="utf-8") as fh:
                json.dump(payload, fh, ensure_ascii=False, indent=2)
            rpt_case = os.path.join(self.tmp, "report_%s.md" % label)
            proc_case = common.audit_cmd(case_dst, rpt_case, variant="ai-disclosure")
            out_case = proc_case.stdout + proc_case.stderr
            self.assertNotEqual(proc_case.returncode, 0, out_case)
            self.assertTrue(len(common.item_lines(out_case, 2)) > 0, out_case)

    def test_sfx_converter_manifest_stage_and_audit_both_variants(self):
        import hashlib
        import json
        import stat
        src = os.path.join(self.tmp, "sfx_src")
        common.build_stage(src)
        os.makedirs(os.path.join(src, "scripts", "cards", "core"), exist_ok=True)
        shutil.copy(
            os.path.join(common.FIX, "stage_src", "scripts", "cards", "core", "validate_main.gd"),
            os.path.join(src, "scripts", "cards", "core", "validate_main.gd"),
        )
        os.makedirs(os.path.join(src, "scripts", "ship"), exist_ok=True)
        shutil.copy(
            os.path.join(common.FIX, "stage_src", "scripts", "ship", "validate_helper.gd"),
            os.path.join(src, "scripts", "ship", "validate_helper.gd"),
        )
        shutil.copy(os.path.join(common.ROOT, "export_presets.cfg"), os.path.join(src, "export_presets.cfg"))

        # Generate a tiny MP3 fixture and run the real converter tools/audio/prepare_ai_audio.py (--kind sfx).
        # Use system ffmpeg if available; otherwise provide a local ffmpeg shim in PATH so prepare_ai_audio.py
        # executes its full two-pass loudnorm + atomic manifest/ogg write pipeline without skipping.
        mp3_path = os.path.join(self.tmp, "click_src.mp3")
        conv_env = os.environ.copy()
        if shutil.which("ffmpeg"):
            gen = common.run([
                "ffmpeg", "-v", "error", "-nostdin", "-f", "lavfi",
                "-i", "sine=frequency=440:duration=3", "-af", "volume=0.1",
                "-c:a", "libmp3lame", mp3_path,
            ])
            self.assertEqual(gen.returncode, 0, gen.stdout + gen.stderr)
        else:
            with open(mp3_path, "wb") as fh:
                fh.write(b"ID3\x03\x00\x00\x00\x00\x00\x0f\xff\xfb\x90d" + b"\x00" * 128)
            shim_dir = os.path.join(self.tmp, "ffmpeg_shim")
            os.makedirs(shim_dir, exist_ok=True)
            shim_path = os.path.join(shim_dir, "ffmpeg")
            with open(shim_path, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(
                    "#!%s\n"
                    "import sys\n"
                    "args = sys.argv[1:]\n"
                    "if 'null' in args and '-' in args:\n"
                    "    sys.stderr.write('{\"input_i\": \"-16.00\", \"input_tp\": \"-2.00\", "
                    "\"input_lra\": \"4.00\", \"input_thresh\": \"-26.00\", \"target_offset\": \"0.00\"}\\n')\n"
                    "    sys.exit(0)\n"
                    "out = args[-1]\n"
                    "open(out, 'wb').write(b'OggS-normalized-sfx-click')\n"
                    % common.PY
                )
            os.chmod(shim_path, os.stat(shim_path).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
            conv_env["PATH"] = shim_dir + os.pathsep + conv_env.get("PATH", "")

        converter = os.path.join(common.ROOT, "tools", "audio", "prepare_ai_audio.py")
        conv = common.run(
            [
                common.PY, converter, mp3_path,
                "--root", src,
                "--kind", "sfx",
                "--id", "click",
                "--tool", "google-flow",
                "--model", "lyria",
                "--date", "2026-10-18",
                "--prompt-id", "sfx-click-v1",
            ],
            env=conv_env,
        )
        self.assertEqual(conv.returncode, 0, conv.stdout + conv.stderr)
        self.assertTrue(os.path.isfile(os.path.join(src, "audio", "ai", "sfx", "click.ogg")))
        self.assertTrue(os.path.isfile(os.path.join(src, "audio", "ai", "sfx", "manifest.json")))

        # 1. Stage in ai-disclosure mode: provenance preserved in audio/ai/sfx/manifest.json and audit passes
        stg_ai = os.path.join(self.tmp, "sfx_stg_ai")
        res_stg_ai = common.run([
            common.PY, os.path.join(common.AUDIT, "stage_ship.py"),
            stg_ai, "--src=" + src, "--variant=ai-disclosure",
        ])
        self.assertEqual(res_stg_ai.returncode, 0, res_stg_ai.stdout + res_stg_ai.stderr)
        shutil.copytree(os.path.join(src, "legal"), os.path.join(stg_ai, "legal"))
        staged_manifest_path = os.path.join(stg_ai, "audio", "ai", "sfx", "manifest.json")
        self.assertTrue(os.path.isfile(staged_manifest_path))
        with open(staged_manifest_path, encoding="utf-8") as fh:
            staged_manifest = json.load(fh)
        self.assertEqual(
            staged_manifest["cues"]["click"]["_provenance"],
            "ai:google-flow:lyria:2026-10-18:sfx-click-v1",
        )
        self.assertEqual(staged_manifest["cues"]["click"]["ai"], "audio/ai/sfx/click.ogg")

        rpt_ai_ok = os.path.join(self.tmp, "rpt_sfx_ai_ok.md")
        proc_ai_ok = common.audit_cmd(stg_ai, rpt_ai_ok, variant="ai-disclosure")
        out_ai_ok = proc_ai_ok.stdout + proc_ai_ok.stderr
        self.assertEqual(proc_ai_ok.returncode, 0, out_ai_ok)
        with open(rpt_ai_ok, encoding="utf-8") as fh:
            rpt_ai_text = fh.read()
        self.assertIn("分类统计: total=1, art=0, audio=1, text=0", rpt_ai_text)
        self.assertIn("ai:google-flow:lyria: 1 (AI 生成、需声明)", rpt_ai_text)

        # 2. Missing referenced AI SFX file -> audit fails item 3
        os.remove(os.path.join(stg_ai, "audio", "ai", "sfx", "click.ogg"))
        rpt_ai_miss = os.path.join(self.tmp, "rpt_sfx_ai_miss.md")
        proc_ai_miss = common.audit_cmd(stg_ai, rpt_ai_miss, variant="ai-disclosure")
        out_ai_miss = proc_ai_miss.stdout + proc_ai_miss.stderr
        self.assertNotEqual(proc_ai_miss.returncode, 0, out_ai_miss)
        self.assertTrue(
            any("audio cue click ai file is missing: audio/ai/sfx/click.ogg" in ln for ln in common.item_lines(out_ai_miss, 3)),
            out_ai_miss,
        )

        # 3. Stage in no-disclosure mode with human SFX missing -> audit fails item 3
        stg_no_ai = os.path.join(self.tmp, "sfx_stg_no_ai")
        res_stg_no_ai = common.run([
            common.PY, os.path.join(common.AUDIT, "stage_ship.py"),
            stg_no_ai, "--src=" + src, "--variant=no-disclosure",
        ])
        self.assertEqual(res_stg_no_ai.returncode, 0, res_stg_no_ai.stdout + res_stg_no_ai.stderr)
        shutil.copytree(os.path.join(src, "legal"), os.path.join(stg_no_ai, "legal"))
        self.assertFalse(os.path.exists(os.path.join(stg_no_ai, "audio", "ai")))
        self.assertTrue(os.path.isfile(os.path.join(stg_no_ai, "data", "cards", "audio", "sfx.json")))
        rpt_no_ai_miss = os.path.join(self.tmp, "rpt_sfx_no_ai_miss.md")
        proc_no_ai_miss = common.audit_cmd(stg_no_ai, rpt_no_ai_miss, variant="no-disclosure")
        out_no_ai_miss = proc_no_ai_miss.stdout + proc_no_ai_miss.stderr
        self.assertNotEqual(proc_no_ai_miss.returncode, 0, out_no_ai_miss)
        self.assertTrue(
            any("audio cue click file is missing: audio/cards/sfx/click.ogg" in ln for ln in common.item_lines(out_no_ai_miss, 3)),
            out_no_ai_miss,
        )

        # 4. Provide human SFX file and register in ASSET_PROVENANCE.csv -> no-disclosure passes
        human_sfx = os.path.join(src, "audio", "cards", "sfx", "click.ogg")
        os.makedirs(os.path.dirname(human_sfx), exist_ok=True)
        with open(human_sfx, "wb") as fh:
            fh.write(b"OggS-human-click-sfx")
        human_sha = hashlib.sha256(b"OggS-human-click-sfx").hexdigest()
        with open(os.path.join(src, "legal", "ASSET_PROVENANCE.csv"), "a", encoding="utf-8", newline="\n") as fh:
            fh.write(
                "audio/cards/sfx/click.ogg,%s,painter-a,foley,click.wav,CC-BY-4.0,LICENSE,2,signed,2026-01-15,painter-a\n"
                % human_sha
            )
        stg_no_ai_ok = os.path.join(self.tmp, "sfx_stg_no_ai_ok")
        res_stg_no_ai_ok = common.run([
            common.PY, os.path.join(common.AUDIT, "stage_ship.py"),
            stg_no_ai_ok, "--src=" + src, "--variant=no-disclosure",
        ])
        self.assertEqual(res_stg_no_ai_ok.returncode, 0, res_stg_no_ai_ok.stdout + res_stg_no_ai_ok.stderr)
        shutil.copytree(os.path.join(src, "legal"), os.path.join(stg_no_ai_ok, "legal"))
        rpt_no_ai_ok = os.path.join(self.tmp, "rpt_sfx_no_ai_ok.md")
        proc_no_ai_ok = common.audit_cmd(stg_no_ai_ok, rpt_no_ai_ok, variant="no-disclosure")
        out_no_ai_ok = proc_no_ai_ok.stdout + proc_no_ai_ok.stderr
        self.assertEqual(proc_no_ai_ok.returncode, 0, out_no_ai_ok)

    def test_partial_human_text_override_does_not_count_as_full_override(self):
        import json
        import importlib.util
        spec = importlib.util.spec_from_file_location("k15audit", os.path.join(common.AUDIT, "audit.py"))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)

        dst = self.stage("ai-partial-text")
        # Human text only writes 'title' for p.demo.1938; 'body' and 'lines.greet' are omitted
        human_text_path = os.path.join(dst, "data", "cards", "text", "era", "1938", "people.text.json")
        with open(human_text_path, "w", encoding="utf-8") as fh:
            json.dump({
                "_meta": {"owner": "A", "schema": 1},
                "p.demo.1938": {
                    "title": "Title",
                    "_provenance": "human:A:2026-01-15",
                },
            }, fh, ensure_ascii=False, indent=2)
        # AI text supplies title, body, and lines.greet
        ai_text_dir = os.path.join(dst, "data", "cards", "text_ai", "era", "1938")
        os.makedirs(ai_text_dir, exist_ok=True)
        with open(os.path.join(ai_text_dir, "people.text.json"), "w", encoding="utf-8") as fh:
            json.dump({
                "_meta": {"_provenance": "ai:google:gemini-2.5-pro:2026-10-18:212-partial"},
                "p.demo.1938": {
                    "title": "Title",
                    "body": "Body",
                    "lines": {"greet": "Hello"},
                },
            }, fh, ensure_ascii=False, indent=2)

        summary = mod.collect_ai_assets(dst)
        self.assertEqual(summary["by_category"]["text"], 1)
        # Not fully overridden because 'body' and 'lines.greet' still come from AI
        self.assertEqual(summary["overridden_by_human"]["text"], [])
        self.assertEqual(summary["partially_overridden_by_human"]["text"], ["p.demo.1938"])
        self.assertEqual(summary["text_fields"], {
            "total": 3,
            "active_ai": 2,
            "overridden_by_human": 1,
            "partial_entries": 1,
        })
        rec = next(r for r in summary["records"] if r["category"] == "text" and r["id"] == "p.demo.1938")
        self.assertFalse(rec["overridden_by_human"])
        self.assertTrue(rec["partially_overridden_by_human"])
        self.assertEqual(rec["override_state"], "partial")
        self.assertEqual(rec["overridden_fields"], ["title"])
        self.assertEqual(rec["active_ai_fields"], ["body", "lines.greet"])

        # In ai-disclosure mode, partial human + AI fallback passes audit
        report_ai = os.path.join(self.tmp, "report_partial_ai.md")
        proc_ai = common.audit_cmd(dst, report_ai, variant="ai-disclosure")
        out_ai = proc_ai.stdout + proc_ai.stderr
        self.assertEqual(proc_ai.returncode, 0, out_ai)
        with open(report_ai, encoding="utf-8") as fh:
            rpt_text = fh.read()
        self.assertIn("已被人工资产覆盖: art=0, audio=0, text=0", rpt_text)
        self.assertIn("台词字段级统计: total_fields=3, active_ai_fields=2, overridden_fields=1, partial_entries=1", rpt_text)

        # In no-disclosure mode (even after removing text_ai), missing human 'body' / 'lines.greet' fails item 2!
        shutil.rmtree(os.path.join(dst, "data", "cards", "text_ai"))
        os.makedirs(os.path.join(dst, "data", "cards", "guide"), exist_ok=True)
        with open(os.path.join(dst, "data", "cards", "guide", "steps.json"), "w", encoding="utf-8") as fh:
            json.dump({
                "_meta": {"owner": "K16", "schema": 1},
                "cards": [{"id": "gd.partial", "type": "guide_step", "era": ["1938"], "anchor": "a.top"}],
            }, fh)
        report_no_ai = os.path.join(self.tmp, "report_partial_no_ai.md")
        proc_no_ai = common.audit_cmd(dst, report_no_ai, variant="no-disclosure")
        out_no_ai = proc_no_ai.stdout + proc_no_ai.stderr
        self.assertNotEqual(proc_no_ai.returncode, 0, out_no_ai)
        self.assertTrue(any("V27" in ln and "gd.partial" in ln for ln in common.item_lines(out_no_ai, 2)), out_no_ai)

    def test_ai_only_text_without_human_text_dir_passes_ai_disclosure_and_fails_no_disclosure(self):
        import json
        dst = self.stage("ai-only-text")
        # Remove data/cards/text completely and provide all required text in data/cards/text_ai
        text_dir = os.path.join(dst, "data", "cards", "text")
        text_ai_dir = os.path.join(dst, "data", "cards", "text_ai")
        shutil.move(text_dir, text_ai_dir)
        for dirpath, _dirs, files in os.walk(text_ai_dir):
            for name in files:
                if not name.endswith(".json"):
                    continue
                p = os.path.join(dirpath, name)
                with open(p, encoding="utf-8") as fh:
                    doc = json.load(fh)
                doc.setdefault("_meta", {})["_provenance"] = "ai:google:gemini-2.5-pro:2026-10-18:212-ai-only"
                for k, v in list(doc.items()):
                    if not str(k).startswith("_") and isinstance(v, dict):
                        v.pop("_provenance", None)
                with open(p, "w", encoding="utf-8") as fh:
                    json.dump(doc, fh, ensure_ascii=False, indent=2)

        report_ai = os.path.join(self.tmp, "report_ai_only.md")
        proc_ai = common.audit_cmd(dst, report_ai, variant="ai-disclosure")
        out_ai = proc_ai.stdout + proc_ai.stderr
        self.assertEqual(proc_ai.returncode, 0, out_ai)

        # Stripping text_ai for no-disclosure must fail items 2, 6, 7 when human text is absent
        shutil.rmtree(text_ai_dir)
        report_no_ai = os.path.join(self.tmp, "report_ai_only_no_disc.md")
        proc_no_ai = common.audit_cmd(dst, report_no_ai, variant="no-disclosure")
        out_no_ai = proc_no_ai.stdout + proc_no_ai.stderr
        self.assertNotEqual(proc_no_ai.returncode, 0, out_no_ai)
        self.assertTrue(any("data/cards/text is missing" in ln for ln in common.item_lines(out_no_ai, 2)), out_no_ai)
        self.assertTrue(any("data/cards/text is missing" in ln for ln in common.item_lines(out_no_ai, 6)), out_no_ai)
        self.assertTrue(any("data/cards/text is missing" in ln for ln in common.item_lines(out_no_ai, 7)), out_no_ai)

    def test_audio_missing_file_and_no_disclosure_missing_human_audio_fail(self):
        import json
        # 1. Referenced AI audio file does not exist on disk -> fails item 3 in ai-disclosure mode
        dst_missing_ai = self.stage("audio-missing-ai")
        os.remove(os.path.join(dst_missing_ai, "audio", "cards", "music", "day.ogg"))
        music_path = os.path.join(dst_missing_ai, "data", "cards", "audio", "music.json")
        with open(music_path, "w", encoding="utf-8") as fh:
            json.dump({
                "_meta": {"owner": "C16", "schema": 1},
                "cues": {
                    "day": {
                        "human": "",
                        "ai": "audio/ai/music/nonexistent.ogg",
                        "_provenance": "ai:google-lyria:2026-10-18:cue.day.v1",
                    }
                },
            }, fh)
        rpt1 = os.path.join(self.tmp, "rpt_audio_missing_ai.md")
        proc1 = common.audit_cmd(dst_missing_ai, rpt1, variant="ai-disclosure")
        out1 = proc1.stdout + proc1.stderr
        self.assertNotEqual(proc1.returncode, 0, out1)
        self.assertTrue(
            any("audio cue day ai file is missing: audio/ai/music/nonexistent.ogg" in ln for ln in common.item_lines(out1, 3)),
            out1,
        )

        # 2. no-disclosure pack where AI audio was stripped and human audio is empty / missing on disk -> fails item 3
        dst_no_human = self.stage("audio-no-human")
        os.remove(os.path.join(dst_no_human, "audio", "cards", "music", "day.ogg"))
        with open(os.path.join(dst_no_human, "data", "cards", "audio", "music.json"), "w", encoding="utf-8") as fh:
            json.dump({
                "_meta": {"owner": "C16", "schema": 1},
                "cues": {
                    "day": {
                        "human": "",
                    }
                },
            }, fh)
        rpt2 = os.path.join(self.tmp, "rpt_audio_no_human.md")
        proc2 = common.audit_cmd(dst_no_human, rpt2, variant="no-disclosure")
        out2 = proc2.stdout + proc2.stderr
        self.assertNotEqual(proc2.returncode, 0, out2)
        self.assertTrue(
            any("audio cue day human path is not under audio/cards/" in ln for ln in common.item_lines(out2, 3)),
            out2,
        )

        # 3. Referenced human audio path under audio/cards/ whose file is missing on disk -> fails item 3
        with open(os.path.join(dst_no_human, "data", "cards", "audio", "music.json"), "w", encoding="utf-8") as fh:
            json.dump({
                "_meta": {"owner": "C16", "schema": 1},
                "cues": {
                    "day": {
                        "human": "audio/cards/music/missing_day.ogg",
                    }
                },
            }, fh)
        rpt3 = os.path.join(self.tmp, "rpt_audio_missing_human_file.md")
        proc3 = common.audit_cmd(dst_no_human, rpt3, variant="no-disclosure")
        out3 = proc3.stdout + proc3.stderr
        self.assertNotEqual(proc3.returncode, 0, out3)
        self.assertTrue(
            any("audio cue day file is missing: audio/cards/music/missing_day.ogg" in ln for ln in common.item_lines(out3, 3)),
            out3,
        )

    def test_ship_main_scene_override_checked_in_staging_and_pck(self):
        dst = self.stage("bad-main-scene")
        # Point project.godot at excluded scenes/Main.tscn without ship override
        with open(os.path.join(dst, "project.godot"), "w", encoding="utf-8") as fh:
            fh.write('config_version=5\n\n[application]\nrun/main_scene="res://scenes/Main.tscn"\n')
        proc, out, _report = self.run_audit(dst)
        self.assertNotEqual(proc.returncode, 0, out)
        self.assertTrue(
            any("project.godot main_scene must resolve to res://scenes/cards/CardGame.tscn" in ln for ln in common.item_lines(out, 1)),
            out,
        )

        # Restore staging project.godot, but pass a .pck whose project.binary points at res://scenes/Main.tscn
        with open(os.path.join(dst, "project.godot"), "w", encoding="utf-8") as fh:
            fh.write(
                'config_version=5\n\n[application]\n'
                'run/main_scene="res://scenes/cards/CardGame.tscn"\n'
                'run/main_scene.ship="res://scenes/cards/CardGame.tscn"\n'
            )
        bad_pck = os.path.join(self.tmp, "bad_main.pck")
        common.write_pck(bad_pck, [("project.binary", b"ECFG...res://scenes/Main.tscn...")])
        proc_pck, out_pck, _rpt = self.run_audit(dst, pck=bad_pck)
        self.assertNotEqual(proc_pck.returncode, 0, out_pck)
        self.assertTrue(
            any("project.binary points main_scene at excluded res://scenes/Main.tscn" in ln for ln in common.item_lines(out_pck, 9)),
            out_pck,
        )

    def test_stage_audit_export_pck_and_boot_cardgame_both_variants(self):
        import json
        # Build an isolated source project that has scenes/Main.tscn as dev main_scene
        # and scenes/cards/CardGame.tscn as run/main_scene.ship.
        src = os.path.join(self.tmp, "iso_src")
        common.build_stage(src)
        with open(os.path.join(src, "project.godot"), "w", encoding="utf-8") as fh:
            fh.write(
                'config_version=5\n\n[application]\n'
                'config/name="IsoShipTest"\n'
                'run/main_scene="res://scenes/Main.tscn"\n'
                'run/main_scene.ship="res://scenes/cards/CardGame.tscn"\n'
            )
        os.makedirs(os.path.join(src, "scenes", "cards"), exist_ok=True)
        with open(os.path.join(src, "scenes", "Main.tscn"), "w", encoding="utf-8") as fh:
            fh.write('[gd_scene format=3]\n\n[node name="OldMain" type="Node"]\n')
        os.makedirs(os.path.join(src, "scripts", "cards", "ui"), exist_ok=True)
        with open(os.path.join(src, "scripts", "cards", "ui", "boot_probe.gd"), "w", encoding="utf-8") as fh:
            fh.write(
                'extends Node\n'
                'func _ready() -> void:\n'
                '\tprint("CARDGAME_BOOT_OK")\n'
                '\tget_tree().quit(0)\n'
            )
        with open(os.path.join(src, "scenes", "cards", "CardGame.tscn"), "w", encoding="utf-8") as fh:
            fh.write(
                '[gd_scene load_steps=2 format=3]\n\n'
                '[ext_resource type="Script" path="res://scripts/cards/ui/boot_probe.gd" id="1"]\n\n'
                '[node name="CardGame" type="Node"]\n'
                'script = ExtResource("1")\n'
            )
        os.makedirs(os.path.join(src, "scripts", "cards", "core"), exist_ok=True)
        shutil.copy(
            os.path.join(common.FIX, "stage_src", "scripts", "cards", "core", "validate_main.gd"),
            os.path.join(src, "scripts", "cards", "core", "validate_main.gd"),
        )
        os.makedirs(os.path.join(src, "scripts", "ship"), exist_ok=True)
        shutil.copy(
            os.path.join(common.FIX, "stage_src", "scripts", "ship", "validate_helper.gd"),
            os.path.join(src, "scripts", "ship", "validate_helper.gd"),
        )
        shutil.copy(os.path.join(common.ROOT, "export_presets.cfg"), os.path.join(src, "export_presets.cfg"))

        # Add AI art, AI audio, and AI text in src so ai-disclosure stages them and no-disclosure strips them
        os.makedirs(os.path.join(src, "art", "ai", "cards"), exist_ok=True)
        shutil.copy(
            os.path.join(src, "art", "cards", "portrait.png"),
            os.path.join(src, "art", "ai", "cards", "portrait.png"),
        )
        with open(os.path.join(src, "data", "cards", "art", "manifest.json"), "w", encoding="utf-8") as fh:
            json.dump({
                "_meta": {"owner": "K12", "schema": 1},
                "missing": "art/cards/portrait.png",
                "art": {
                    "portrait.demo": {
                        "base": [48, 64],
                        "human": "art/cards/portrait.png",
                        "ai": "art/ai/cards/portrait.png",
                        "_provenance": "ai:google-imagen:2026-10-18:portrait.demo.v1",
                    }
                },
            }, fh, indent=2)
        os.makedirs(os.path.join(src, "audio", "ai", "music"), exist_ok=True)
        with open(os.path.join(src, "audio", "ai", "music", "day.ogg"), "wb") as fh:
            fh.write(b"OggS-ai-day-audio")
        with open(os.path.join(src, "data", "cards", "audio", "music.json"), "w", encoding="utf-8") as fh:
            json.dump({
                "_meta": {"owner": "C16", "schema": 1},
                "cues": {
                    "day": {
                        "human": "audio/cards/music/day.ogg",
                        "ai": "audio/ai/music/day.ogg",
                        "_provenance": "ai:google-lyria:2026-10-18:cue.day.v1",
                    }
                },
            }, fh, indent=2)
        os.makedirs(os.path.join(src, "data", "cards", "text_ai", "era", "1938"), exist_ok=True)
        with open(os.path.join(src, "data", "cards", "text_ai", "era", "1938", "people.text.json"), "w", encoding="utf-8") as fh:
            json.dump({
                "_meta": {"_provenance": "ai:google:gemini-2.5-pro:2026-10-18:212-iso"},
                "p.demo.1938": {"title": "Title", "body": "Body", "lines": {"greet": "Hello"}},
            }, fh, indent=2)

        # Stage and audit both variants
        stage_ai = os.path.join(self.tmp, "stage_ai")
        stage_no_ai = os.path.join(self.tmp, "stage_no_ai")
        for stg, var_name in ((stage_ai, "ai-disclosure"), (stage_no_ai, "no-disclosure")):
            res_stg = common.run([
                common.PY, os.path.join(common.AUDIT, "stage_ship.py"),
                stg, "--src=" + src, "--variant=" + var_name,
            ])
            self.assertEqual(res_stg.returncode, 0, res_stg.stdout + res_stg.stderr)
            shutil.copytree(os.path.join(src, "legal"), os.path.join(stg, "legal"))
            self.assertFalse(os.path.exists(os.path.join(stg, "scenes", "Main.tscn")))
            self.assertTrue(os.path.isfile(os.path.join(stg, "scenes", "cards", "CardGame.tscn")))
            rpt = os.path.join(self.tmp, "audit_%s.md" % var_name)
            res_aud = common.audit_cmd(stg, rpt, variant=var_name)
            self.assertEqual(res_aud.returncode, 0, res_aud.stdout + res_aud.stderr)

        # Resolve Godot engine from env GODOT, else shutil.which("godot").
        # If missing, skip explicitly (or fail when CARDS_REQUIRE_GODOT=1).
        real_godot = os.environ.get("GODOT") or shutil.which("godot") or ""
        if real_godot and not os.path.isfile(real_godot):
            real_godot = shutil.which(real_godot) or ""
        if not real_godot or not (os.path.isfile(real_godot) and os.access(real_godot, os.X_OK)):
            reason = "Godot binary not found via GODOT env or PATH (set GODOT=/path/to/godot)"
            if os.environ.get("CARDS_REQUIRE_GODOT") == "1":
                self.fail(reason)
            self.skipTest(reason)

        for stg, var_name, preset in (
            (stage_ai, "ai-disclosure", "Steam (AI Disclosure)"),
            (stage_no_ai, "no-disclosure", "Steam (No AI Disclosure)"),
        ):
            pck_out = os.path.join(self.tmp, "%s.pck" % var_name)
            fonts_dir = os.path.join(stg, "fonts")
            fonts_bak = os.path.join(self.tmp, "fonts_bak_%s" % var_name)
            shutil.move(fonts_dir, fonts_bak)
            try:
                exp = common.run([real_godot, "--headless", "--path", stg, "--export-pack", preset, pck_out])
            finally:
                shutil.move(fonts_bak, fonts_dir)
            self.assertEqual(exp.returncode, 0, exp.stdout + exp.stderr)
            self.assertTrue(os.path.isfile(pck_out))
            rpt_pck = os.path.join(self.tmp, "audit_pck_%s.md" % var_name)
            res_pck_aud = common.audit_cmd(stg, rpt_pck, pck=pck_out, variant=var_name)
            self.assertEqual(res_pck_aud.returncode, 0, res_pck_aud.stdout + res_pck_aud.stderr)
            # Boot exported .pck with --main-pack from a fresh empty directory containing no project.godot or source tree
            boot_cwd = os.path.join(self.tmp, "boot_isolated_%s" % var_name)
            os.makedirs(boot_cwd, exist_ok=True)
            self.assertEqual(os.listdir(boot_cwd), [])
            self.assertFalse(os.path.exists(os.path.join(boot_cwd, "project.godot")))
            boot = common.run([real_godot, "--headless", "--main-pack", pck_out], cwd=boot_cwd)
            self.assertEqual(boot.returncode, 0, boot.stdout + boot.stderr)
            self.assertIn("CARDGAME_BOOT_OK", boot.stdout)


if __name__ == "__main__":
    unittest.main()
