#!/usr/bin/env bash
# 旧版冒烟（W0，Claude 维护）：几分钟内跑完，证明卡牌版的改动没碰坏旧游戏（PR 里和 run_card_tests.sh 一起跑；
# 全量 tools/run_tests.sh 由 Claude 合并时跑，§12.1）。另外冒烟一次主入口 --cards（Mock 情景自动走几十步）。
# 环境变量：GODOT（Godot 4.7）。任何 SCRIPT ERROR / ERROR / WARNING / FAIL 行或非零退出码都算失败。
set -u
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
LOG=$(mktemp -d)
FAIL=0

check() {  # 名字 日志 退出码 [最后要有的一行]
  local bad
  bad=$(grep -E "SCRIPT ERROR|ERROR:|^ERROR|WARNING|Parse Error|PLAYTHROUGH FAILED|DATA ERROR|FAIL:|leaked at exit" "$2" \
    | grep -v "Could not set V-Sync" | head -5)
  if [ "$3" != "0" ] || [ -n "$bad" ] || { [ -n "${4:-}" ] && ! grep -q "$4" "$2"; }; then
    echo "✗ $1 (exit $3)"; echo "$bad" | sed 's/^/    /'; FAIL=1
  else
    echo "✓ $1"
  fi
}

timeout 300 "$GODOT" --headless --path . --import > "$LOG/import.log" 2>&1; check "import" "$LOG/import.log" $?
for spec in "数据校验|validate_data" "对白框|test_dialogue" "验货找不同|test_appraise" "小镇数据与轮盘规则|test_sim_rules" \
            "暂停菜单、设置、返回标题|town_ui_menu" "过路客人与门口吆喝|test_walkin"; do
  name="${spec%%|*}"; script="${spec#*|}"
  timeout 300 "$GODOT" --headless --path . -s "res://scripts/tests/$script.gd" > "$LOG/$script.log" 2>&1
  check "$name" "$LOG/$script.log" $?
done
timeout 300 "$GODOT" --headless --path . -s res://scripts/tests/run_playthrough.gd -- --policy=fair --until=ending > "$LOG/play.log" 2>&1
check "全流程（核心，策略 fair）" "$LOG/play.log" $?
timeout 300 "$GODOT" --headless --path . -s res://scripts/tests/run_playthrough.gd -- --ui --policy=fair --until=ending > "$LOG/play_ui.log" 2>&1
check "全流程（经由界面，策略 fair）" "$LOG/play_ui.log" $?
timeout 300 "$GODOT" --headless --path . -- --town --autoplay=town_fair --fast --days=2 --seed=7 --quit > "$LOG/town.log" 2>&1
check "小镇自动试玩 2 天" "$LOG/town.log" $?
timeout 120 "$GODOT" --headless --path . -- --cards --cards-mock --cards-autoplay=60 > "$LOG/cards_entry.log" 2>&1
check "主入口 --cards（Mock 情景走 60 步）" "$LOG/cards_entry.log" $? "^CARDS AUTOPLAY"
echo "旧版冒烟日志：$LOG"
if [ $FAIL -ne 0 ]; then echo "旧版冒烟失败"; exit 1; fi
echo "旧版冒烟全部通过"
