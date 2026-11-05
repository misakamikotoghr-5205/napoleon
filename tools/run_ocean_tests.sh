#!/usr/bin/env bash
# Focused real-data campaign and UI acceptance; legacy smoke has its own runner.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
JOBS=${JOBS:-2}
if ! [[ "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
  echo "JOBS must be a positive integer"
  exit 2
fi
# C1 (de-pawnshop, WORLD_MAP_DESIGN 12.3): anti-regression word scan over the Napoleon-line data, scripts and screens
c_suites="content"
log_dir=$(mktemp -d "${TMPDIR:-/tmp}/dehoudang-ocean-tests.XXXXXX")
check_log() {
  local file=$1
  if rg -n 'SCRIPT ERROR|ERROR:|^ERROR|WARNING|Parse Error|FAIL:|leaked at exit|ObjectDB instances leaked' "$file"; then
    return 1
  fi
}
if ! timeout 300 "$GODOT" --headless --path . --import >"$log_dir/import.log" 2>&1; then
  cat "$log_dir/import.log"
  echo "Ocean import failed; logs: $log_dir"
  exit 1
fi
if ! check_log "$log_dir/import.log"; then
  echo "Ocean import reported errors; logs: $log_dir"
  exit 1
fi
# B1 (battle rules slice 5): terrain / weather / tag unit tests and the section 8.5 level smoke
b_suites="battle_terrain battle_levels"
# Authored volume one: template balance, runtime contracts, full routes and real controls.
n_suites="battle_content napoleon_contracts napoleon_view napoleon napoleon_ui"
v_suites="battle_orders companion_volume2 battle_volume2 napoleon_branch_start napoleon_volume2_content napoleon_volumes napoleon_promotion napoleon_volume2 napoleon_demo"
suites=(campaign ui battle_v2 battle_campaign hd_kit vn battle_field battle_hud hub golden run_book map run_replay map_ui $b_suites $c_suites $n_suites $v_suites)
# Optional comma-separated subset for rerunning affected suites after a fix.
if [[ -n ${OCEAN_SUITES:-} ]]; then
  IFS=',' read -r -a selected_suites <<< "$OCEAN_SUITES"
  for name in "${selected_suites[@]}"; do
    if [[ " ${suites[*]} " != *" $name "* ]]; then
      echo "Unknown Ocean suite: $name"
      exit 2
    fi
  done
  suites=("${selected_suites[@]}")
fi
run_suite() {
  local test_name=$1 test_log="$log_dir/$1.log" test_timeout=240
  case "$test_name" in
    battle_v2|battle_content|battle_volume2|napoleon|napoleon_volume2|napoleon_demo) test_timeout=900 ;;
    ui) test_timeout=600 ;; # Full mouse-driven campaign under parallel CPU load.
  esac
  # Each suite has its own saves/profile, including when several runners overlap.
  if ! XDG_DATA_HOME="$log_dir/userdata/$test_name" timeout "$test_timeout" "$GODOT" --headless --path . -s "res://scripts/tests/cards/OCEAN/test_$test_name.gd" >"$test_log" 2>&1; then
    cat "$test_log"
    echo "Ocean $test_name tests failed; logs: $log_dir"
    return 1
  fi
  if ! check_log "$test_log" || [[ $(awk 'NF { last=$0 } END { print last }' "$test_log") != "CARDS TEST PASS OCEAN_$test_name" ]]; then
    cat "$test_log"
    echo "Ocean $test_name tests did not complete cleanly; logs: $log_dir"
    return 1
  fi
  cat "$test_log"
}
export GODOT log_dir
export -f run_suite check_log
if ! printf '%s\0' "${suites[@]}" | xargs -0 -P "$JOBS" -I{} bash -c 'run_suite "$1"' _ {}; then
  echo "Ocean/Napoleon acceptance failed; logs: $log_dir"
  exit 1
fi
echo "All ${#suites[@]} Ocean/Napoleon backend, content, battle, route, replay and UI suites passed; logs: $log_dir"
