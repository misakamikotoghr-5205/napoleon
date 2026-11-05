#!/usr/bin/env bash
# K14 screenshots and the headless walk.
#   bash tools/cards/qa/shots.sh <out_dir> [extra play_ui args]
# With a working xvfb-run: 1280x720 opengl3 capture, then sheet.gd.
# If K14_SHOTS_BASE is set to a previous out dir, also run compare_shots.gd.
# If xvfb-run is missing, or it cannot create a display, print NOTE and run the
# same walk headless with no png (play_ui also refuses to write fake images).
set -euo pipefail
cd "$(dirname "$0")/../../.."
GODOT=${GODOT:-godot}
OUT=${1:?usage: bash tools/cards/qa/shots.sh <out_dir>}
shift
mkdir -p "$OUT"

run_headless() {
	"$GODOT" --headless --path . -s res://scripts/tests/cards/K14/play_ui.gd -- \
		--engine=mock --seed=7 --days=30 --guide=off "$@"
}

if ! command -v xvfb-run >/dev/null 2>&1; then
	echo "NOTE: no xvfb, screenshots skipped"
	run_headless "$@"
	exit $?
fi

set +e
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --audio-driver Dummy --path . \
	-s res://scripts/tests/cards/K14/play_ui.gd -- \
	--engine=mock --seed=7 --days=30 --guide=off --shots="$OUT" "$@"
xvfb_code=$?
set -e
if [ "$xvfb_code" != "0" ]; then
	echo "NOTE: xvfb-run could not create a display, screenshots skipped"
	run_headless "$@"
	exit $?
fi
"$GODOT" --headless --path . -s res://scripts/tests/cards/K14/sheet.gd -- --dir="$OUT" --out="$OUT/sheet.png"
if [ -n "${K14_SHOTS_BASE:-}" ]; then
	"$GODOT" --headless --path . -s res://scripts/tests/cards/K14/compare_shots.gd -- --a="$K14_SHOTS_BASE" --b="$OUT"
fi
