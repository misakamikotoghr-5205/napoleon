#!/usr/bin/env python3
"""merge_gate.sh against local fixtures only: no network, no Godot, no real project gate.
Run: python3 -m unittest discover -s tools/cards/tests -p 'test_merge_gate.py' -v
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "merge_gate.sh"
REAL_GIT = shutil.which("git")
BASE = "claude/festive-ride-vud32a"


class MergeGateTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.gh_prs = self.root / "gh_prs.tsv"
        self.gh_log = self.root / "gh.log"
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                        CARDS_SUITES="G06", CARDS_VALIDATE_MODE="default",
                        GH_PRS=str(self.gh_prs), GH_LOG=str(self.gh_log))
        self.env.pop("GATE_BASE", None)
        self.git("init", "-b", BASE)
        self.git("config", "user.name", "Gate Operator")
        self.git("config", "user.email", "gate@example.test")
        # AUDIT_MOVE_REF="<ref> <sha>" moves a remote-tracking ref while the gate runs (a concurrent fetch).
        self.write("tools/cards/audit/check_pr_paths.py", """import os, subprocess, sys
print('AUDIT', *sys.argv[1:])
if os.environ.get('AUDIT_MOVE_REF'):
    subprocess.run(['git', 'update-ref', *os.environ['AUDIT_MOVE_REF'].split()], check=True)
sys.exit(int(os.environ.get('AUDIT_EXIT', '0')))
""")
        self.write("scripts/tests/cards/suites/A.txt", "# comment\none|script|1\n")
        self.write("scripts/tests/cards/suites/B.txt", "two|script|1\n")
        # Success text is printed even on failure: the gate must judge by exit codes only.
        self.write("tools/run_card_tests.sh", """#!/bin/bash
[[ ! ${CARDS_SUITES+x} && $CARDS_VALIDATE_MODE == strict ]] || exit 88
echo 'complete cards output: beginning'
echo '卡牌版测试全部通过'
[[ -f bad.txt ]] && exit 41
exit "${CARDS_EXIT:-0}"
""")
        self.write("tools/run_legacy_smoke.sh", 'echo "legacy output"\nexit "${SMOKE_EXIT:-0}"\n')
        self.write("conflict.txt", "base\n")
        self.git("add", ".")
        self.git("commit", "-m", "fixture base")
        self.sha = self.branch("cards/G01-fixture", {"change.txt": "fixture change\n"}, "fixture PR")
        origin = self.root / "origin.git"
        subprocess.run([REAL_GIT, "clone", "--bare", str(self.repo), str(origin)],
                       check=True, capture_output=True)
        self.git("remote", "add", "origin", str(origin))
        self.gh_prs.write_text("")
        self.pr(123, "cards/G01-fixture", self.sha)
        self.executable("gh", """#!/bin/bash
printf '%s\\n' "$*" >> "$GH_LOG"
awk -F'\\t' -v pr="$3" '$1 == pr {print $2 "\\t" $3 "\\t" $4 "\\t" $5 "\\t" $6; found = 1} END {exit !found}' "$GH_PRS"
""")
        self.executable("godot", "#!/bin/bash\necho fixture-Godot-version\n")
        self.env["GODOT"] = str(self.bin / "godot")
        self.plan = self.root / "plan.tsv"
        self.plan.write_text(f"A\tG01\t123\tcards/G01-fixture\t{self.sha}\n")
        self.wd = self.root / "gate"

    def git(self, *args):
        return subprocess.run([REAL_GIT, *args], cwd=self.repo, check=True,
                              text=True, capture_output=True).stdout.strip()

    def write(self, name, content):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def executable(self, name, content):
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)

    def branch(self, name, files, message, push=False):
        """Create a PR branch off the base with the given files; return its head SHA."""
        self.git("switch", "-c", name, BASE)
        for rel, content in files.items():
            self.write(rel, content)
        self.git("add", ".")
        self.git("commit", "--author=Real PR Author <author@example.test>", "-m", message)
        sha = self.git("rev-parse", "HEAD")
        self.git("switch", BASE)
        if push:
            self.git("push", "-q", "origin", name)
        return sha

    def pr(self, number, head, oid, login="real-pr-login", base=BASE, state="OPEN"):
        """What `gh pr view <number>` reports for the PR."""
        rows = [line for line in self.gh_prs.read_text().splitlines() if not line.startswith(f"{number}\t")]
        rows.append("\t".join([str(number), login, base, head, oid, state]))
        self.gh_prs.write_text("\n".join(rows) + "\n")

    def run_gate(self):
        result = subprocess.run(["bash", str(SCRIPT), str(self.plan), str(self.wd)],
                                cwd=self.repo, env=self.env, text=True, capture_output=True)
        logs = list(self.wd.glob("*.log"))
        self.assertEqual(len(logs), 1)
        self.assertEqual(logs[0].read_text(), result.stdout)
        return result

    def stage(self, *args):
        return subprocess.check_output([REAL_GIT, "-C", str(self.wd / "stage"), *args], text=True).strip()

    def inject_cd(self, body):
        hook = self.root / "bash_env"
        hook.write_text(f'cd() {{ {body}; }}\n')
        self.env["BASH_ENV"] = str(hook)

    def test_cd_failure_stops(self):
        self.inject_cd('return 37')
        before = self.git("rev-parse", "HEAD")
        result = self.run_gate()
        self.assertEqual(result.returncode, 37, result.stdout)
        self.assertIn("FIRST_FAILURE step=cd exit=37", next(self.wd.glob("*.failure")).read_text())
        self.assertNotIn("STEP git-merge", result.stdout)
        self.assertEqual(self.git("rev-parse", "HEAD"), before)

    def test_wrong_directory_refuses_merge(self):
        self.inject_cd('return 0')
        result = self.run_gate()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL step=worktree-guard", result.stdout)
        self.assertNotIn("STEP git-merge", result.stdout)

    def test_failure_nonzero_despite_success_text(self):
        self.env["CARDS_EXIT"] = "23"
        result = self.run_gate()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(f"A\tG01\t#123\t{self.sha[:12]}\tFAILED", result.stdout)
        self.assertIn("step=cards exit=23", next(self.wd.glob("*.failure")).read_text())
        self.assertEqual(self.stage("rev-parse", "HEAD"), self.git("rev-parse", "HEAD"))

    def test_author_full_suites_and_exact_sha(self):
        result = self.run_gate()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("--author=real-pr-login", result.stdout)
        self.assertIn("suites=2 tests=2 mode=strict", result.stdout)
        self.assertIn("fixture-Godot-version", result.stdout)
        self.assertIn(f"A\tG01\t#123\t{self.sha[:12]}\tAPPLIED", result.stdout)
        self.assertEqual(self.stage("log", "-1", "--format=%an <%ae>"), "Real PR Author <author@example.test>")
        self.assertEqual(self.stage("rev-parse", "HEAD^2"), self.sha)
        self.assertIn("pr view 123 --json author,baseRefName,headRefName,headRefOid,state", self.gh_log.read_text())

    def test_merges_reviewed_sha_even_if_ref_moves_mid_run(self):
        late = self.branch("cards/G01-late", {"change.txt": "not reviewed\n"}, "late PR", push=True)
        self.env["AUDIT_MOVE_REF"] = f"refs/remotes/origin/cards/G01-fixture {late}"
        result = self.run_gate()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.stage("rev-parse", "HEAD^2"), self.sha)
        self.assertEqual((self.wd / "stage" / "change.txt").read_text(), "fixture change\n")

    def test_rejected_nonzero(self):
        self.env["AUDIT_EXIT"] = "1"
        result = self.run_gate()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(f"A\tG01\t#123\t{self.sha[:12]}\tREJECTED", result.stdout)
        self.assertNotIn("STEP git-merge", result.stdout)

    def test_existing_branch_preserved(self):
        self.git("branch", "merge-gate")
        before = self.git("rev-parse", "merge-gate")
        result = self.run_gate()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL step=worktree-add", result.stdout)
        self.assertNotIn("STEP cd", result.stdout)
        self.assertEqual(self.git("rev-parse", "merge-gate"), before)

    def test_smoke_failure_nonzero_after_one_retry(self):
        self.env["SMOKE_EXIT"] = "29"
        result = self.run_gate()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("STEP legacy-smoke-retry", result.stdout)
        self.assertIn(f"A\tG01\t#123\t{self.sha[:12]}\tFAILED", result.stdout)
        self.assertIn("step=legacy-smoke exit=29", next(self.wd.glob("*.failure")).read_text())

    def test_existing_worktree_preserved(self):
        self.wd.mkdir()
        self.git("worktree", "add", "-b", "existing-stage", str(self.wd / "stage"))
        sentinel = self.wd / "stage" / "keep.txt"
        sentinel.write_text("keep me")
        result = self.run_gate()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("STEP cd", result.stdout)
        self.assertEqual(sentinel.read_text(), "keep me")

    def test_existing_empty_directory_preserved(self):
        (self.wd / "stage").mkdir(parents=True)
        result = self.run_gate()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL step=existing-worktree", result.stdout)
        self.assertNotIn("STEP worktree-add", result.stdout)

    def test_fetch_failure_stops(self):
        self.git("remote", "set-url", "origin", str(self.root / "missing.git"))
        result = self.run_gate()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL step=fetch", result.stdout)
        self.assertNotIn("STEP worktree-add", result.stdout)

    # P2 #204 (1): a red batch retries the PRs that conflicted in the batch round, not only the merged ones.
    def test_red_batch_retries_conflicting_pr(self):
        bad = self.branch("cards/G01-bad", {"conflict.txt": "bad\n", "bad.txt": "breaks tests\n"}, "bad PR", push=True)
        good = self.branch("cards/G02-good", {"conflict.txt": "good\n"}, "good PR", push=True)
        self.pr(101, "cards/G01-bad", bad)
        self.pr(102, "cards/G02-good", good)
        self.plan.write_text(f"A\tG01\t101\tcards/G01-bad\t{bad}\nA\tG02\t102\tcards/G02-good\t{good}\n")
        result = self.run_gate()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Batch A failed; retry each PR", result.stdout)
        self.assertEqual(result.stdout.count("STEP paths-#102"), 2, result.stdout)
        self.assertIn(f"A\tG01\t#101\t{bad[:12]}\tFAILED", result.stdout)
        self.assertIn(f"A\tG02\t#102\t{good[:12]}\tAPPLIED", result.stdout)
        self.assertEqual((self.wd / "stage" / "conflict.txt").read_text(), "good\n")
        self.assertFalse((self.wd / "stage" / "bad.txt").exists())

    def test_green_batch_reports_conflict_without_retry(self):
        first = self.branch("cards/G01-first", {"conflict.txt": "first\n"}, "first PR", push=True)
        second = self.branch("cards/G02-second", {"conflict.txt": "second\n"}, "second PR", push=True)
        self.pr(101, "cards/G01-first", first)
        self.pr(102, "cards/G02-second", second)
        self.plan.write_text(f"A\tG01\t101\tcards/G01-first\t{first}\nA\tG02\t102\tcards/G02-second\t{second}\n")
        result = self.run_gate()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(result.stdout.count("STEP paths-#102"), 1, result.stdout)
        self.assertIn(f"A\tG01\t#101\t{first[:12]}\tAPPLIED", result.stdout)
        self.assertIn(f"A\tG02\t#102\t{second[:12]}\tCONFLICT", result.stdout)

    # P2 #204 (2): each plan line is bound to the PR's base, head branch and head SHA.
    def test_plan_line_requires_full_sha(self):
        for line in ("A\tG01\t123\tcards/G01-fixture\n", f"A\tG01\t123\tcards/G01-fixture\t{self.sha[:12]}\n"):
            self.plan.write_text(line)
            shutil.rmtree(self.wd, ignore_errors=True)
            result = self.run_gate()
            self.assertEqual(result.returncode, 2, result.stdout)
            self.assertIn("FAIL step=plan-format", result.stdout)
            self.assertNotIn("STEP fetch", result.stdout)

    def assert_refused(self, result, verdict):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(f"A\tG01\t#123\t{self.sha[:12]}\t{verdict}", result.stdout)
        self.assertIn("FAIL step=bind-#123", result.stdout)
        self.assertNotIn("STEP paths-#123", result.stdout)
        self.assertNotIn("--author=", result.stdout)
        self.assertNotIn("STEP git-merge", result.stdout)
        self.assertEqual(self.stage("rev-parse", "HEAD"), self.git("rev-parse", BASE))

    def test_branch_moved_after_plan_refused(self):
        self.git("switch", "cards/G01-fixture")
        self.write("change.txt", "pushed after review\n")
        self.git("commit", "-am", "late push")
        moved = self.git("rev-parse", "HEAD")
        self.git("push", "-q", "origin", "cards/G01-fixture")
        self.git("switch", BASE)
        self.pr(123, "cards/G01-fixture", moved)
        result = self.run_gate()
        self.assert_refused(result, "MOVED")
        self.assertIn(f"PR #123 moved: plan {self.sha}", result.stdout)

    def test_github_head_differs_from_fetched_branch_refused(self):
        self.pr(123, "cards/G01-fixture", "f" * 40)
        self.assert_refused(self.run_gate(), "MOVED")

    def test_pr_number_of_another_branch_refused(self):
        self.pr(123, "cards/G02-someone-else", self.sha, login="other-author")
        self.assert_refused(self.run_gate(), "MISMATCH")

    def test_pr_against_other_base_refused(self):
        self.pr(123, "cards/G01-fixture", self.sha, base="main")
        self.assert_refused(self.run_gate(), "MISMATCH")

    def test_closed_pr_refused(self):
        self.pr(123, "cards/G01-fixture", self.sha, state="MERGED")
        self.assert_refused(self.run_gate(), "MISMATCH")

    def test_missing_remote_branch_refused(self):
        self.plan.write_text(f"A\tG01\t123\tcards/G01-gone\t{self.sha}\n")
        self.pr(123, "cards/G01-gone", self.sha)
        result = self.run_gate()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(f"A\tG01\t#123\t{self.sha[:12]}\tMISMATCH", result.stdout)
        self.assertNotIn("STEP paths-#123", result.stdout)


if __name__ == "__main__":
    unittest.main()
