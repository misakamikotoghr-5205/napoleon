"""check_pr_paths.py: ownership, human-only, renames, deletes. No K13 special case."""
import json
import os
import shutil
import subprocess
import tempfile
import unittest

import common


OWNERSHIP = {
    "paths": {
        "K15": ["tools/cards/audit/**"],
        "K01": ["data/cards/era/**"],
        "K13": ["tools/cards/review/**"],
    },
    "default_owned": [
        "scripts/tests/cards/{ID}/**",
        "scripts/tests/cards/suites/{ID}.txt",
        "data/cards/tags/{ID}.json",
        "data/cards/ui_keys/{ID}.json",
    ],
    "human_only": [
        "data/cards/text/**",
        "art/cards/**",
        "audio/cards/**",
        "data/cards/theme/palette.json",
        "legal/**",
        "fonts/**",
    ],
}


class CheckPrPathsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="k15-paths-")
        os.makedirs(os.path.join(self.tmp, "docs", "cards"))
        with open(os.path.join(self.tmp, "docs", "cards", "ownership.json"), "w", encoding="utf-8") as fh:
            json.dump(OWNERSHIP, fh)
        self.git(["init", "-b", "main"])
        self.git(["config", "user.email", "k15@example.com"])
        self.git(["config", "user.name", "k15"])

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def git(self, args):
        proc = subprocess.run(["git"] + args, cwd=self.tmp, capture_output=True, text=True)
        if proc.returncode != 0:
            raise AssertionError("git %s failed: %s" % (args, proc.stderr))
        return proc

    def write(self, rel, text="x\n"):
        path = os.path.join(self.tmp, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
        return rel

    def commit(self, message):
        self.git(["add", "-A"])
        self.git(["commit", "-m", message])
        return self.git(["rev-parse", "HEAD"]).stdout.strip()

    def check(self, base, head, author="ai-bot", task="", branch=""):
        cmd = [common.PY, os.path.join(common.AUDIT, "check_pr_paths.py"), base, head, "--author=" + author]
        if task:
            cmd.append("--task=" + task)
        if branch:
            cmd.append("--branch=" + branch)
        return common.run(cmd, cwd=self.tmp)

    def test_usage_is_unchanged(self):
        proc = common.run([common.PY, os.path.join(common.AUDIT, "check_pr_paths.py")])
        self.assertEqual(proc.returncode, 2)
        self.assertIn("check_pr_paths.py <base> <head> --author=<github login>", proc.stdout)

    def test_outside_path_and_human_only(self):
        self.write("tools/cards/audit/a.txt", "a\n")
        self.write("legal/human_authors.json", json.dumps(["human-a"]))
        base = self.commit("base")
        self.write("data/cards/era/1938/people.json", "{}\n")
        self.write("data/cards/text/era/1938/people.text.json", "{}\n")
        head = self.commit("bad")
        proc = self.check(base, head, author="ai-bot", branch="cards/K15-audit-provenance")
        out = proc.stdout
        self.assertEqual(proc.returncode, 1, out + proc.stderr)
        self.assertIn("PATH ERROR: data/cards/era/1938/people.json is outside K15's paths", out)
        self.assertIn("PATH ERROR: data/cards/text/era/1938/people.text.json is human-only (author ai-bot is not in legal/human_authors.json)", out)
        self.assertRegex(out.strip().splitlines()[-1], r"^PATHS FAILED: \d+ files, \d+ problems$")

    def test_owned_sidecar_passes(self):
        self.write("legal/human_authors.json", json.dumps({"humans": [{"login": "human-a"}]}))
        self.write("tools/cards/audit/a.txt", "a\n")
        base = self.commit("base")
        self.write("tools/cards/audit/a.txt.uid", "uid://x\n")
        self.write("scripts/tests/cards/K15/test_one.gd", "extends Node\n")
        head = self.commit("ok")
        proc = self.check(base, head, author="ai-bot", branch="cards/K15-audit-provenance")
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("PATHS OK:", proc.stdout)

    def test_k13_is_not_special(self):
        self.write("data/cards/era/1938/people.json", "{}\n")
        base = self.commit("base")
        self.write("data/cards/era/1938/people.json", "{\"touched\": true}\n")
        head = self.commit("k13")
        proc = self.check(base, head, author="ai-bot", branch="cards/K13-review-history")
        self.assertEqual(proc.returncode, 1, proc.stdout)
        self.assertIn("PATH ERROR: data/cards/era/1938/people.json is outside K13's paths", proc.stdout)

    def test_rename_checks_both_paths(self):
        self.write("data/cards/era/old.json", "same-bytes\n")
        base = self.commit("base")
        self.git(["mv", "data/cards/era/old.json", "data/cards/era/new.json"])
        head = self.commit("rename")
        proc = self.check(base, head, author="ai-bot", branch="cards/K15-audit-provenance")
        out = proc.stdout
        self.assertEqual(proc.returncode, 1, out + proc.stderr)
        self.assertIn("PATH ERROR: data/cards/era/old.json is outside K15's paths", out)
        self.assertIn("PATH ERROR: data/cards/era/new.json is outside K15's paths", out)

    def test_delete_checks_the_removed_path(self):
        self.write("data/cards/era/gone.json", "{}\n")
        base = self.commit("base")
        self.git(["rm", "data/cards/era/gone.json"])
        head = self.commit("delete")
        proc = self.check(base, head, author="ai-bot", branch="cards/K15-audit-provenance")
        self.assertEqual(proc.returncode, 1, proc.stdout + proc.stderr)
        self.assertIn("PATH ERROR: data/cards/era/gone.json is outside K15's paths", proc.stdout)

    def test_note_when_branch_is_not_a_task(self):
        self.write("README.txt", "hi\n")
        base = self.commit("base")
        self.write("README.txt", "yo\n")
        head = self.commit("content")
        proc = self.check(base, head, author="human-a", branch="content/story")
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("NOTE: no task id (use --task or a cards/<ID>-<slug> branch); ownership check skipped", proc.stdout)
        self.assertIn("PATHS OK:", proc.stdout)

    def test_missing_human_authors_treats_everyone_as_ai(self):
        self.write("fonts/a.ttf", "font\n")
        base = self.commit("base")
        self.write("fonts/a.ttf", "font2\n")
        head = self.commit("font")
        proc = self.check(base, head, author="human-a", branch="content/fonts")
        self.assertEqual(proc.returncode, 1, proc.stdout + proc.stderr)
        self.assertIn("PATH ERROR: fonts/a.ttf is human-only (author human-a is not in legal/human_authors.json)", proc.stdout)

    def test_ai_paths_allowed_for_ai_authors_while_human_only_stays_blocked(self):
        self.write("legal/human_authors.json", json.dumps(["human-a"]))
        base = self.commit("base")
        self.write("art/ai/cards/portrait/linsao.png", "png\n")
        self.write("art/ai/cards/portrait/linsao.png.import", "import\n")
        self.write("audio/ai/music/day.ogg", "ogg\n")
        self.write("data/cards/text_ai/era/1938/people.text.json", "{}\n")
        head = self.commit("ai-assets")
        proc_task = self.check(base, head, author="ai-bot", branch="cards/K15-ai-assets")
        self.assertEqual(proc_task.returncode, 0, proc_task.stdout + proc_task.stderr)
        self.assertIn("PATHS OK:", proc_task.stdout)

        proc_branch = self.check(base, head, author="ai-bot", branch="agy/201-ai-art")
        self.assertEqual(proc_branch.returncode, 0, proc_branch.stdout + proc_branch.stderr)
        self.assertIn("PATHS OK:", proc_branch.stdout)

        # Touching human_only paths as an AI author must still fail.
        self.write("art/cards/portrait/linsao.png", "human-png\n")
        self.write("audio/cards/music/day.ogg", "human-ogg\n")
        self.write("data/cards/text/era/1938/people.text.json", "{}\n")
        bad_head = self.commit("touch-human-only")
        proc_bad = self.check(head, bad_head, author="ai-bot", branch="cards/K15-ai-assets")
        self.assertEqual(proc_bad.returncode, 1, proc_bad.stdout + proc_bad.stderr)
        self.assertIn("PATH ERROR: art/cards/portrait/linsao.png is human-only", proc_bad.stdout)
        self.assertIn("PATH ERROR: audio/cards/music/day.ogg is human-only", proc_bad.stdout)
        self.assertIn("PATH ERROR: data/cards/text/era/1938/people.text.json is human-only", proc_bad.stdout)

    def test_human_story_pack_is_human_only(self):
        self.write("legal/human_authors.json", json.dumps(["human-a"]))
        self.write("packs/hum/pack.json", json.dumps({"id": "hum", "source": "human"}))
        self.write("packs/aip/pack.json", json.dumps({"id": "aip", "source": "ai"}))
        base = self.commit("base")
        self.write("packs/hum/text/era/1938/people.text.json", "{}\n")
        self.write("packs/aip/text/era/1938/people.text.json", "{}\n")
        head = self.commit("story")
        proc = self.check(base, head, author="ai-bot", branch="content/story")
        out = proc.stdout
        self.assertEqual(proc.returncode, 1, out + proc.stderr)
        self.assertIn("PATH ERROR: packs/hum/text/era/1938/people.text.json is in a human story pack", out)
        self.assertNotIn("packs/aip/", out)
        proc_human = self.check(base, head, author="human-a", branch="content/story")
        self.assertEqual(proc_human.returncode, 0, proc_human.stdout + proc_human.stderr)
        # An AI line may write an AI pack, but may not create a pack that claims to be human-written.
        self.write("packs/fake/pack.json", json.dumps({"id": "fake", "source": "human"}))
        fake = self.commit("fake human pack")
        proc_fake = self.check(head, fake, author="ai-bot", branch="content/story")
        self.assertEqual(proc_fake.returncode, 1, proc_fake.stdout)
        self.assertIn("PATH ERROR: packs/fake/pack.json is in a human story pack", proc_fake.stdout)
        # Turning a human pack into an AI pack is still a change to a human pack (source human at base).
        self.write("packs/hum/pack.json", json.dumps({"id": "hum", "source": "ai"}))
        flip = self.commit("flip")
        proc_flip = self.check(fake, flip, author="ai-bot", branch="content/story")
        self.assertEqual(proc_flip.returncode, 1, proc_flip.stdout)
        self.assertIn("PATH ERROR: packs/hum/pack.json is in a human story pack", proc_flip.stdout)

    def test_repo_ownership_json_registers_story_packs(self):
        with open(os.path.join(common.ROOT, "docs", "cards", "ownership.json"), encoding="utf-8") as fh:
            real_own = json.load(fh)
        self.assertEqual(real_own["paths"].get("packs"), ["packs/**"])
        self.assertNotIn("packs/**", real_own.get("human_only") or [])
        self.assertNotIn("packs/**", real_own.get("ai_paths") or [])

    def test_repo_ownership_json_registers_ai_paths_and_keeps_human_only(self):
        real_path = os.path.join(common.ROOT, "docs", "cards", "ownership.json")
        with open(real_path, encoding="utf-8") as fh:
            real_own = json.load(fh)
        self.assertEqual(
            sorted(real_own.get("ai_paths") or []),
            ["art/ai/**", "audio/ai/**", "data/cards/text_ai/**"],
        )
        for p in ("data/cards/text/**", "art/cards/**", "audio/cards/**",
                  "data/cards/theme/palette.json", "legal/**", "fonts/**"):
            self.assertIn(p, real_own.get("human_only") or [])
        for p in ("art/ai/**", "audio/ai/**", "data/cards/text_ai/**"):
            self.assertNotIn(p, real_own.get("human_only") or [])


if __name__ == "__main__":
    unittest.main()
