#!/bin/sh
# Rebuild every registered scene variant: toon render -> pix.py (-> comparison sheet with --compare).
#   sh tools/blender/make_samples.sh [--compare] [out_dir]     default out_dir: tools/blender/out (git-ignored)
#   BLENDER=/path/to/blender to use another Blender binary (macOS: /Applications/Blender.app/Contents/MacOS/Blender).
# --compare also writes <id>.compare.png next to the image the game uses now. Leave it off while
# composing a scene: an AI operator must not see the current AI art (BLENDER_PIPELINE.md red line 2).
# Each render's log is kept as <id>.log; the script exits 1 if any render failed.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
COMPARE=0
if [ "${1:-}" = "--compare" ]; then COMPARE=1; shift; fi
OUT=${1:-$HERE/out}
BLENDER=${BLENDER:-blender}
command -v "$BLENDER" >/dev/null 2>&1 || { echo "Blender not found: $BLENDER (set BLENDER=/path/to/blender)" >&2; exit 1; }
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
JOBS="$OUT/.jobs"
trap 'rm -f "${OUT:?}/.jobs"' EXIT
"$BLENDER" -b --factory-startup -noaudio --python-exit-code 1 --python "$HERE/list_jobs.py" -- "$JOBS" >"$OUT/list_jobs.log" 2>&1 \
  || { echo "could not read the scene list (see $OUT/list_jobs.log)" >&2; tail -5 "$OUT/list_jobs.log" >&2; exit 1; }
fail=0
while read -r scene variant art_id colors method; do
  raw="$OUT/$art_id.raw.png"
  rm -f "${OUT:?}/${art_id:?}.raw.png" "${OUT:?}/${art_id:?}.png"
  if "$BLENDER" -b --factory-startup -noaudio --python-exit-code 1 --python "$HERE/render.py" -- \
       --scene "$scene" --variant "$variant" --out "$raw" >"$OUT/$art_id.log" 2>&1 && [ -f "$raw" ]; then
    echo "RENDERED $raw"
    python3 "$HERE/pix.py" "$raw" "$OUT/$art_id.png" --colors "$colors" --method "$method"
    if [ "$COMPARE" = 1 ]; then python3 "$HERE/compare.py" "$art_id" "$OUT/$art_id.png" "$OUT/$art_id.compare.png"; fi
  else
    echo "FAILED $art_id (see $OUT/$art_id.log)" >&2
    grep -E "Error|error:" "$OUT/$art_id.log" | grep -v "EGL Error" | tail -5 >&2 || true
    fail=1
  fi
done < "$JOBS"
exit $fail
