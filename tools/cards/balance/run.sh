#!/usr/bin/env bash
# G06: split independent seed ranges across headless processes and aggregate their reports.
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
godot="${GODOT:-godot}"
jobs="${JOBS:-2}"
seeds=200
seed_from=1
seed_to=
out="$root/docs/cards/balance"
report_date="$(date +%F)"
source_rev="$(git -C "$root" rev-parse HEAD)"
forward=()
for arg in "$@"; do
  case "$arg" in
    --seeds=*) seeds="${arg#*=}" ;;
    --fuzz=*) seeds="${arg#*=}"; forward+=("$arg") ;;
    --seed_from=*) seed_from="${arg#*=}" ;;
    --seed_to=*) seed_to="${arg#*=}" ;;
    --out=*) out="${arg#*=}" ;;
    --date=*) report_date="${arg#*=}" ;;
    --update-golden) jobs=1; forward+=("$arg") ;;
    *) forward+=("$arg") ;;
  esac
done
seed_to="${seed_to:-$((seed_from + seeds - 1))}"
mkdir -p "$out"
parts="$(mktemp -d "$out/.parts.XXXXXX")"
pids=()
chunk=$(((seed_to - seed_from + jobs) / jobs))
for ((worker=0; worker<jobs; worker++)); do
  first=$((seed_from + worker * chunk))
  last=$((first + chunk - 1))
  ((first > seed_to)) && break
  ((last > seed_to)) && last=$seed_to
  "$godot" --headless --path "$root" -s res://scripts/cards/sim/balance_main.gd -- \
    "--seed_from=$first" "--seed_to=$last" "--out=$parts" "--date=$report_date" "--source-rev=$source_rev" \
    "${forward[@]}" > "$parts/worker_$worker.log" 2>&1 &
  pids+=("$!")
done
failed=0
for pid in "${pids[@]}"; do wait "$pid" || failed=1; done
for log in "$parts"/worker_*.log; do
  if rg -q 'SCRIPT ERROR|Parse Error|WARNING|ERROR|FAIL:' "$log"; then
    cat "$log"
    failed=1
  fi
done
((failed)) && exit 1
python3 "$root/tools/cards/balance/aggregate.py" --out "$out" --parts "$parts" --date "$report_date"
