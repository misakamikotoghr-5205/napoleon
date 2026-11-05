#!/usr/bin/env bash
# W2-5 / G06：同种子真数据改前、改后；只复制生产数据，不生成测试牌。
# 用法：bash tools/cards/balance/w2_run.sh before|after <输出目录>；SEEDS/JOBS 可覆盖。
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
phase="${1:?before or after}"
out="${2:?output directory}"
case "$phase" in before|after) ;; *) echo 'Expected before or after' >&2; exit 2 ;; esac
mkdir -p "$out"
out="$(cd "$out" && pwd)"
data="$(mktemp -d "$out/data.XXXXXX")"
cp -a "$root/data/cards/." "$data/"
if [[ "$phase" == before ]]; then
  # 0d917678 的完整空覆盖；其余真数据原样保留。
  cp "$root/docs/cards/balance/w2_198/before_overrides.json" "$data/rules/balance_overrides.json"
fi
python3 - "$data" "$out/input_manifest.json" "$root" <<'PY'
import hashlib
import json
import sys
from pathlib import Path
root = Path(sys.argv[1])
files = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
         for p in sorted(root.rglob('*.json'))}
repo = Path(sys.argv[3])
sources = sorted((repo / 'scripts').rglob('*.gd'))
sources += sorted(p for p in (repo / 'data').rglob('*.json') if not p.is_relative_to(repo / 'data/cards'))
sources += [repo / 'tools/cards/balance/aggregate.py', repo / 'project.godot']
source_hashes = {str(p.relative_to(repo)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
Path(sys.argv[2]).write_text(json.dumps({'dataset': 'production data/cards copy', 'sha256': files,
                                       'source_sha256': source_hashes}, indent=2) + '\n')
PY
export GODOT_SILENCE_ROOT_WARNING=1
export XDG_DATA_HOME="${XDG_DATA_HOME:-$out/userdata}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$out/config}"
export JOBS="${JOBS:-6}"
bash "$root/tools/cards/balance/run.sh" --seeds="${SEEDS:-20}" \
  --policies=fair,greedy,kind,random,refuser,wheel,hoarder --stages=3 --data=real \
  "--data-root=$data" "--label=W2_198_real_$phase" "--out=$out" --date=2026-10-18
