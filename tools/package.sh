#!/usr/bin/env bash
# Package the 德厚当 (Beg) Godot project into a distributable zip.
#
# Usage:
#   tools/package.sh [OUTPUT_ZIP]
#
# Default OUTPUT_ZIP: /workspace/beg-godot_${VERSION}.zip (VERSION env, default v0.2)
# The zip contains a single top-level folder: beg-godot_${VERSION}/
#
# Excluded: claude_logs/, .godot/, *.err, __pycache__/, *.pyc, art/_preview/,
#           *.tmp, .claude/
# Included (required, script fails if missing): project.godot, scenes/, scripts/,
#           data/, model/, fonts/, art/, screenshots/, docs/, tools/,
#           PROGRESS.md, README_CN.md, CLAUDE.md, HELP_REQUESTS.md,
#           HELP_RESPONSES.md, legal/
#
# After writing, the script verifies the listing, test-extracts the zip into a
# fresh temp dir and runs a headless Godot --import (must exit 0 with no
# "SCRIPT ERROR"). Exits non-zero on any failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION="${VERSION:-v0.2}"
PKG_NAME="beg-godot_${VERSION}"
GODOT_BIN="${GODOT_BIN:-/home/box/.local/bin/godot}"
IMPORT_TIMEOUT=300

OUT_ZIP="${1:-/workspace/beg-godot_${VERSION}.zip}"
case "${OUT_ZIP}" in
  /*) ;;
  *) OUT_ZIP="$(pwd)/${OUT_ZIP}" ;;
esac

fail() {
  echo "PACKAGE FAILED: $*" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || fail "python3 not found"
[ -f "${PROJECT_DIR}/project.godot" ] || fail "project.godot not found in ${PROJECT_DIR}"

# Step 1: build the zip with python3 zipfile (deterministic order, ZIP_DEFLATED).
mkdir -p "$(dirname "${OUT_ZIP}")"
TMP_ZIP="${OUT_ZIP}.tmp"
rm -f "${TMP_ZIP}"

python3 -I - "${PROJECT_DIR}" "${TMP_ZIP}" "${PKG_NAME}" <<'PYEOF' || { rm -f "${TMP_ZIP}"; fail "zip creation failed"; }
import os
import sys
import zipfile

project_dir, tmp_zip, pkg = sys.argv[1], sys.argv[2], sys.argv[3]

REQUIRED = [
    "project.godot", "scenes", "scripts", "data", "model", "fonts", "art",
    "screenshots", "docs", "docs/playtest", "docs/review", "tools",
    "PROGRESS.md", "README_CN.md", "CLAUDE.md", "HELP_REQUESTS.md",
    "HELP_RESPONSES.md", "legal",
]

EXCLUDE_DIR_NAMES = {"claude_logs", ".godot", "__pycache__", ".claude"}
EXCLUDE_TOP_PREFIXES = ("art/_preview/", ".claude/", "claude_logs/", ".godot/", "export/")
EXCLUDE_FILE_SUFFIXES = (".err", ".pyc", ".tmp")

def excluded_rel(rel):
    # rel uses forward slashes, relative to project_dir
    parts = rel.split("/")
    for p in parts[:-1]:
        if p in EXCLUDE_DIR_NAMES:
            return True
    if rel.startswith(EXCLUDE_TOP_PREFIXES):
        return True
    name = parts[-1]
    if name.endswith(EXCLUDE_FILE_SUFFIXES):
        return True
    return False

missing = []
for req in REQUIRED:
    full = os.path.join(project_dir, req)
    if not os.path.exists(full):
        missing.append(req)
    elif os.path.isdir(full):
        has_file = False
        for _root, _dirs, files in os.walk(full):
            if any(not excluded_rel(os.path.relpath(os.path.join(_root, f), project_dir).replace(os.sep, "/")) for f in files):
                has_file = True
                break
        if not has_file:
            missing.append(req + " (empty)")
if missing:
    print("PACKAGE FAILED: required paths missing: " + ", ".join(missing), file=sys.stderr)
    sys.exit(1)

entries = []
for root, dirs, files in os.walk(project_dir):
    dirs[:] = sorted(d for d in dirs if d not in EXCLUDE_DIR_NAMES)
    for f in sorted(files):
        full = os.path.join(root, f)
        rel = os.path.relpath(full, project_dir).replace(os.sep, "/")
        if excluded_rel(rel):
            continue
        if os.path.islink(full):
            continue
        entries.append(rel)
entries.sort()

with zipfile.ZipFile(tmp_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
    for rel in entries:
        info = zipfile.ZipInfo(pkg + "/" + rel, date_time=(2026, 10, 10, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        mode = 0o755 if os.access(os.path.join(project_dir, rel), os.X_OK) else 0o644
        info.external_attr = (0o100000 | mode) << 16   # 保留可执行位（tools/*.sh）
        with open(os.path.join(project_dir, rel), "rb") as fh:
            zf.writestr(info, fh.read())
print("WROTE %d entries" % len(entries))
PYEOF

mv -f "${TMP_ZIP}" "${OUT_ZIP}"
echo "ZIP: ${OUT_ZIP}"

# Step 2: verify listing and key files.
python3 -I - "${OUT_ZIP}" "${PKG_NAME}" <<'PYEOF' || fail "listing verification failed"
import sys
import zipfile

zip_path, pkg = sys.argv[1], sys.argv[2]
KEY = [
    "project.godot",
    "scenes/Main.tscn",
    "scripts/core/director.gd",
    "data/story/prologue.json",
    "model/persona_residual.json",
    "fonts/NotoSerifSC-Regular-subset.otf",
    "README_CN.md",
    "tools/run_tests.sh",
]
with zipfile.ZipFile(zip_path) as zf:
    bad = zf.testzip()
    if bad is not None:
        print("corrupt member: " + bad, file=sys.stderr)
        sys.exit(1)
    infos = zf.infolist()
    names = [i.filename for i in infos]
    total = sum(i.file_size for i in infos)
    tops = {n.split("/", 1)[0] for n in names}
    if tops != {pkg}:
        print("bad top-level folders: %s" % sorted(tops), file=sys.stderr)
        sys.exit(1)
    nameset = set(names)
    missing = [k for k in KEY if (pkg + "/" + k) not in nameset]
    shots = [n for n in names if n.startswith(pkg + "/screenshots/") and n.lower().endswith(".png")]
    if missing:
        print("missing key files: " + ", ".join(missing), file=sys.stderr)
        sys.exit(1)
    if not shots:
        print("no screenshots/*.png in zip", file=sys.stderr)
        sys.exit(1)
    bad_excl = [n for n in names if "/claude_logs/" in n or "/.godot/" in n or "/.claude/" in n
                or "/art/_preview/" in n or "__pycache__" in n or n.endswith((".err", ".pyc", ".tmp"))]
    if bad_excl:
        print("excluded entries leaked: " + ", ".join(bad_excl[:10]), file=sys.stderr)
        sys.exit(1)
    print("LISTING: %d files, total uncompressed %d bytes (%.2f MB), zip size %d bytes"
          % (len(names), total, total / 1048576.0, __import__("os").path.getsize(zip_path)))
    print("LISTING: top-level folder = %s" % pkg)
    print("LISTING: screenshots png = %d" % len(shots))
    print("LISTING: key files present = %d/%d" % (len(KEY), len(KEY)))
PYEOF

# Step 3: test-extract into a fresh temp dir and run headless import.
[ -x "${GODOT_BIN}" ] || fail "godot binary not executable: ${GODOT_BIN}"
TEST_DIR="$(mktemp -d)"
cleanup() { rm -rf "${TEST_DIR}"; }
trap cleanup EXIT

python3 -I - "${OUT_ZIP}" "${TEST_DIR}" <<'PYEOF' || fail "test extraction failed"
import sys
import zipfile
zip_path, dest = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zip_path) as zf:
    zf.extractall(dest)
print("EXTRACTED to " + dest)
PYEOF

GAME_DIR="${TEST_DIR}/${PKG_NAME}"
[ -f "${GAME_DIR}/project.godot" ] || fail "extracted project.godot missing"

IMPORT_LOG="${TEST_DIR}/import.log"
set +e
timeout "${IMPORT_TIMEOUT}" "${GODOT_BIN}" --headless --path "${GAME_DIR}" --import >"${IMPORT_LOG}" 2>&1
RC=$?
set -e
if [ "${RC}" -eq 124 ]; then
  tail -n 40 "${IMPORT_LOG}" >&2 || true
  fail "godot --import timed out after ${IMPORT_TIMEOUT}s"
fi
if [ "${RC}" -ne 0 ]; then
  tail -n 40 "${IMPORT_LOG}" >&2 || true
  fail "godot --import exited with code ${RC}"
fi
if grep -q "SCRIPT ERROR" "${IMPORT_LOG}"; then
  grep -n "SCRIPT ERROR" "${IMPORT_LOG}" | head -n 20 >&2 || true
  fail "godot --import reported SCRIPT ERROR"
fi
echo "IMPORT: godot --headless --import exit 0, no SCRIPT ERROR"

echo "PACKAGE OK"
