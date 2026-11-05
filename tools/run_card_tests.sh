#!/usr/bin/env bash
# 卡牌版测试（W0，Claude 维护；谁都不改它，§12.1）：
#   1) --import  2) 数据校验（真数据 default 模式；W2 起 CARDS_VALIDATE_MODE=strict）
#   3) 按文件名顺序读 scripts/tests/cards/suites/*.txt，并行跑每一行：timeout <秒> $GODOT --headless --path . -s <脚本> -- <参数>
# 失败 = 日志里有 SCRIPT ERROR / ERROR / WARNING / Parse Error / FAIL: / DATA ERROR / 退出时泄漏，或退出码非零，
#        或最后一行不是 "CARDS TEST PASS <名字>"。
# 环境变量：GODOT（Godot 4.7）、JOBS（并行数，默认 4）、CARDS_VALIDATE_MODE（default|strict）、CARDS_SUITES（只跑这些清单，逗号分隔的任务号）
set -u
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
JOBS=${JOBS:-4}
MODE=${CARDS_VALIDATE_MODE:-default}
LOG=$(mktemp -d)
export GODOT LOG

bad_lines() {  # logfile → 打印可疑行
  grep -E "SCRIPT ERROR|ERROR:|^ERROR|WARNING|Parse Error|FAIL:|DATA ERROR|leaked at exit|ObjectDB instances leaked" "$1" \
    | grep -v "Could not set V-Sync" | head -8
}
export -f bad_lines

run_line() {  # "名字|脚本|超时|参数"
  local line="$1" name script tmo params f bad last code
  IFS='|' read -r name script tmo params <<< "$line"
  f="$LOG/$(echo "$name" | tr -c 'A-Za-z0-9_.-' '_').log"
  # shellcheck disable=SC2086
  timeout "${tmo:-120}" "$GODOT" --headless --path . -s "$script" -- $params > "$f" 2>&1
  code=$?
  bad=$(bad_lines "$f")
  last=$(grep -v '^[[:space:]]*$' "$f" | tail -n 1)
  if [ "$code" != "0" ] || [ -n "$bad" ] || [ "$last" != "CARDS TEST PASS $name" ]; then
    echo "✗ $name (exit $code)"
    [ -n "$bad" ] && echo "$bad" | sed 's/^/    /'
    [ "$last" != "CARDS TEST PASS $name" ] && echo "    last line: $last"
    return 1
  fi
  echo "✓ $name"
}
export -f run_line

FAIL=0
timeout 300 "$GODOT" --headless --path . --import > "$LOG/import.log" 2>&1
code=$?; bad=$(bad_lines "$LOG/import.log")
if [ "$code" != "0" ] || [ -n "$bad" ]; then echo "✗ import (exit $code)"; echo "$bad" | sed 's/^/    /'; FAIL=1; else echo "✓ import"; fi
timeout 120 "$GODOT" --headless --path . -s res://scripts/cards/core/validate_main.gd -- --mode="$MODE" --name=cards_data_validate > "$LOG/validate.log" 2>&1
code=$?; bad=$(bad_lines "$LOG/validate.log"); last=$(grep -v '^[[:space:]]*$' "$LOG/validate.log" | tail -n 1)
if [ "$code" != "0" ] || [ -n "$bad" ] || [ "$last" != "CARDS TEST PASS cards_data_validate" ]; then
  echo "✗ 数据校验（$MODE）(exit $code)"; echo "$bad" | sed 's/^/    /'; FAIL=1
else
  echo "✓ 数据校验（$MODE）：$(grep '^CARDS VALID' "$LOG/validate.log")"
fi

JOBLIST="$LOG/jobs.txt"
: > "$JOBLIST"
for suite in $(ls scripts/tests/cards/suites/*.txt 2>/dev/null | sort); do
  id=$(basename "$suite" .txt)
  if [ -n "${CARDS_SUITES:-}" ] && ! echo ",$CARDS_SUITES," | grep -q ",$id,"; then continue; fi
  grep -v '^[[:space:]]*#' "$suite" | grep -v '^[[:space:]]*$' >> "$JOBLIST"
done
COUNT=$(wc -l < "$JOBLIST")
tr '\n' '\0' < "$JOBLIST" | xargs -0 -P "$JOBS" -I{} bash -c 'run_line "$1"' _ {} > "$LOG/results.txt"
cat "$LOG/results.txt"
if grep -q "^✗" "$LOG/results.txt"; then FAIL=1; fi
echo "卡牌版：$COUNT 项清单测试；日志：$LOG"
if [ $FAIL -ne 0 ]; then echo "卡牌版测试失败"; exit 1; fi
echo "卡牌版测试全部通过"
