#!/usr/bin/env bash
# 肉鸽 v1 平衡对照（RG6；docs/cards/rogue/ROGUE_V1.md §14 RG6 第二阶段）：data/cards 拷两份，同种子、同策略、连续三关。
#   on  = 现在的真数据（给了候选覆盖就先深合并进去，调数批次用）；
#   off = 同一份（含同样的候选覆盖），再在 rules/balance_overrides.json 加
#         {"relics": {"enabled": false}, "stock": {"enabled": false}}（两个规则文件都有 enabled 键，覆盖校验允许）。
# 用法：GODOT=<4.7.1> bash tools/cards/balance/rogue_ab.sh <输出目录> [候选覆盖.json]
#   候选覆盖：与 balance_overrides.json 同形的 JSON，只许改已有标量键（CardDB 与 strict 校验都会拦）。
# 环境：SEEDS（默认 20）、JOBS（每份的进程数，默认 2；两份同时跑）、POLICIES（默认 refuser,fair,trader,idle）、
#       ON_EXTRA（默认 random：只在 on 份多跑，供 A7“trader 或 random 每件都挑过”；设空字符串就不跑）、
#       DATE（报告日期，默认 2026-10-25；引擎不读墙钟）。XDG_DATA_HOME 不设时放在输出目录里（user:// 不和别人共用）。
# 输出：<输出目录>/input_manifest.json、validate_{on,off}.log、{on,off}/report_<DATE>.{json,md}（逐局 runs_*.json
#       在 {on,off}/.parts.*/ 里）、ab_<DATE>.{json,md}（A1–A7 对照表，aggregate.py --ab-on/--ab-off 生成）。
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
godot="${GODOT:?set GODOT to the Godot 4.7.1 binary}"
out="${1:?output directory}"
candidate="${2:-}"
seeds="${SEEDS:-20}"
jobs="${JOBS:-2}"
policies="${POLICIES:-refuser,fair,trader,idle}"
extra="${ON_EXTRA-random}"
report_date="${DATE:-2026-10-25}"
if [[ -n "$candidate" && ! -f "$candidate" ]]; then
  echo "Candidate overrides not found: $candidate" >&2
  exit 2
fi
mkdir -p "$out"
out="$(cd "$out" && pwd)"
if [[ -e "$out/on" || -e "$out/off" ]]; then
  echo "Output directory already holds a comparison: $out (use a fresh one per batch)" >&2
  exit 2
fi
data_on="$(mktemp -d "$out/data_on.XXXXXX")"
data_off="$(mktemp -d "$out/data_off.XXXXXX")"
cp -a "$root/data/cards/." "$data_on/"
cp -a "$root/data/cards/." "$data_off/"
python3 - "$data_on" "$data_off" "$candidate" "$out/input_manifest.json" "$root" <<'PY'
import hashlib
import json
import sys
from pathlib import Path


def merge(base, over):
    for key, value in over.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            merge(base[key], value)
        else:
            base[key] = value
    return base


on, off, candidate, manifest, repo = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], Path(sys.argv[4]), Path(sys.argv[5])
rel = Path('rules/balance_overrides.json')
base = json.loads((on / rel).read_text())
extra = json.loads(Path(candidate).read_text()) if candidate else {}
extra = {key: value for key, value in extra.items() if not key.startswith('_')}
on_doc = merge(json.loads(json.dumps(base)), extra)
off_doc = merge(json.loads(json.dumps(on_doc)), {'relics': {'enabled': False}, 'stock': {'enabled': False}})
(on / rel).write_text(json.dumps(on_doc, ensure_ascii=False, indent=2) + '\n')
(off / rel).write_text(json.dumps(off_doc, ensure_ascii=False, indent=2) + '\n')


def hashes(folder):
    return {str(p.relative_to(folder)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(folder.rglob('*.json'))}


on_files, off_files = hashes(on), hashes(off)
diff = sorted(name for name in set(on_files) | set(off_files) if on_files.get(name) != off_files.get(name))
sources = sorted((repo / 'scripts/cards').rglob('*.gd')) + [repo / 'tools/cards/balance/aggregate.py',
                                                          repo / 'tools/cards/balance/rogue_ab.sh', repo / 'project.godot']
manifest.write_text(json.dumps({
    'dataset': 'production data/cards copies (rogue v1 A/B)', 'candidate_overrides': extra,
    'on_overrides': on_doc, 'off_overrides': off_doc, 'differing_files': diff,
    'on_sha256': on_files, 'source_sha256': {str(p.relative_to(repo)): hashlib.sha256(p.read_bytes()).hexdigest()
                                             for p in sources}}, ensure_ascii=False, indent=2) + '\n')
if diff != [str(rel)]:
    raise SystemExit('on/off copies differ beyond balance_overrides.json: %s' % diff)
PY
export GODOT_SILENCE_ROOT_WARNING=1
export XDG_DATA_HOME="${XDG_DATA_HOME:-$out/userdata}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$out/config}"
for side in on off; do
  data="$data_on"
  [[ "$side" == off ]] && data="$data_off"
  log="$out/validate_$side.log"
  code=0
  timeout 300 "$godot" --headless --path "$root" -s res://scripts/cards/core/validate_main.gd -- \
    --mode=strict "--root=$data" "--name=rogue_ab_$side" > "$log" 2>&1 || code=$?
  if [[ "$code" != 0 ]] || [[ "$(grep -v '^[[:space:]]*$' "$log" | tail -n 1)" != "CARDS TEST PASS rogue_ab_$side" ]]; then
    cat "$log"
    echo "Strict validation failed for the $side copy" >&2
    exit 1
  fi
done
on_policies="$policies"
[[ -n "$extra" ]] && on_policies="$policies,$extra"
pids=()
JOBS="$jobs" bash "$root/tools/cards/balance/run.sh" "--seeds=$seeds" "--policies=$on_policies" --stages=3 --data=real \
  "--data-root=$data_on" --label=rogue_v1_on "--out=$out/on" "--date=$report_date" > "$out/run_on.log" 2>&1 &
pids+=("$!")
JOBS="$jobs" bash "$root/tools/cards/balance/run.sh" "--seeds=$seeds" "--policies=$policies" --stages=3 --data=real \
  "--data-root=$data_off" --label=rogue_v1_off "--out=$out/off" "--date=$report_date" > "$out/run_off.log" 2>&1 &
pids+=("$!")
failed=0
for pid in "${pids[@]}"; do wait "$pid" || failed=1; done
tail -n 3 "$out/run_on.log" "$out/run_off.log"
((failed)) && { echo "A simulation batch failed; see run_on.log / run_off.log" >&2; exit 1; }
python3 "$root/tools/cards/balance/aggregate.py" --out "$out" --date "$report_date" \
  --ab-on "$out/on/report_$report_date.json" --ab-off "$out/off/report_$report_date.json" --ab-data "$data_on"
