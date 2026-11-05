#!/usr/bin/env bash
# 德厚当 全部自动测试。任何 SCRIPT ERROR / ERROR / WARNING 或非零退出码都算失败。
# 用法：tools/run_tests.sh [until]      until 默认 ending（策略全流程跑到哪）；分支计划各自带终点
#       tools/run_tests.sh --dry-run    只打印解析到的 godot 路径后退出
# 环境变量 JOBS=并行数（默认 6）；GODOT=godot 可执行文件路径（默认依次找 PATH 里的 godot、godot4）
set -u
cd "$(dirname "$0")/.."
# godot 路径按优先级解析：GODOT 环境变量 → PATH 里的 godot → godot4 → 旧开发机路径
if [ -z "${GODOT:-}" ]; then
  GODOT=$(command -v godot || command -v godot4 || true)
  if [ -z "$GODOT" ] && [ -x /home/box/.local/bin/godot ]; then GODOT=/home/box/.local/bin/godot; fi
fi
if [ -z "$GODOT" ] || ! command -v "$GODOT" > /dev/null 2>&1; then
  echo "错误：找不到 godot 可执行文件（GODOT='${GODOT}'）。请设置 GODOT=/path/to/godot，或把 godot / godot4 加入 PATH。" >&2
  exit 2
fi
if [ "${1:-}" = "--dry-run" ]; then echo "GODOT=$GODOT"; exit 0; fi
UNTIL=${1:-ending}
JOBS=${JOBS:-6}
LOG=$(mktemp -d)
export GODOT LOG

check_log() {  # name logfile exitcode → prints ✓/✗ line, returns 0/1
  local bad
  bad=$(grep -E "SCRIPT ERROR|^ERROR|ERROR:|WARNING:|Parse Error|PLAYTHROUGH FAILED|DATA ERROR|FAIL:" "$2" | grep -v "Could not set V-Sync" | head -5)
  if [ "$3" != "0" ] || [ -n "$bad" ]; then
    echo "✗ $1 (exit $3)"; echo "$bad" | sed 's/^/    /'; return 1
  fi
  echo "✓ $1"; return 0
}
export -f check_log

run_one() {  # "name|args..."
  local name="${1%%|*}" args="${1#*|}" f
  f="$LOG/$(echo "$name" | tr ' /（）' '____').log"
  # shellcheck disable=SC2086
  timeout 300 "$GODOT" --headless -s res://scripts/tests/run_playthrough.gd -- $args > "$f" 2>&1
  check_log "$name" "$f" $?
}
export -f run_one

FAIL=0
timeout 300 "$GODOT" --headless --import > "$LOG/import.log" 2>&1; check_log "import" "$LOG/import.log" $? || FAIL=1
timeout 120 "$GODOT" --headless -s res://scripts/tests/validate_data.gd > "$LOG/data.log" 2>&1; check_log "数据校验" "$LOG/data.log" $? || FAIL=1
timeout 120 "$GODOT" --headless -s res://scripts/tests/test_dialogue.gd > "$LOG/dialogue.log" 2>&1; check_log "对白框（先补全本句、防连点跳过）" "$LOG/dialogue.log" $? || FAIL=1
timeout 150 "$GODOT" --headless -s res://scripts/tests/test_tidy.gd > "$LOG/tidy.log" 2>&1; check_log "整理库房加成跨夜保留" "$LOG/tidy.log" $? || FAIL=1
timeout 120 "$GODOT" --headless -s res://scripts/tests/test_bargain.gd > "$LOG/bargain.log" 2>&1; check_log "讨价还价有出口（最多五轮）" "$LOG/bargain.log" $? || FAIL=1
timeout 120 "$GODOT" --headless -s res://scripts/tests/test_minds.gd > "$LOG/minds.log" 2>&1; check_log "人格大脑（不同性格议价不同）" "$LOG/minds.log" $? || FAIL=1
timeout 120 "$GODOT" --headless -s res://scripts/tests/test_v03.gd > "$LOG/v03.log" 2>&1; check_log "v0.3b（侧栏按需/全屏柜台/侧边对白/放大镜返回/统一定价）" "$LOG/v03.log" $? || FAIL=1
timeout 120 "$GODOT" --headless -s res://scripts/tests/test_town_assets.gd > "$LOG/town_assets.log" 2>&1; check_log "小镇美术与地图" "$LOG/town_assets.log" $? || FAIL=1
timeout 120 "$GODOT" --headless -s res://scripts/tests/test_town_shops.gd > "$LOG/town_shops.log" 2>&1; check_log "店铺特写配置" "$LOG/town_shops.log" $? || FAIL=1
timeout 120 "$GODOT" --headless -s res://scripts/tests/test_appraise.gd > "$LOG/appraise.log" 2>&1; check_log "验货找不同（图鉴对照、朱笔圈、墨、放大镜、破绽画法、存档）" "$LOG/appraise.log" $? || FAIL=1
timeout 120 "$GODOT" --headless -s res://scripts/tests/test_typewriter.gd > "$LOG/typewriter.log" 2>&1; check_log "打字机逐字音效（静音开/关、标点停顿、补全/跳过立即清停顿）" "$LOG/typewriter.log" $? || FAIL=1
timeout 120 "$GODOT" --headless -s res://scripts/tests/test_pawn_redeem.gd > "$LOG/pawn_redeem.log" 2>&1; check_log "活当到期与赎回机制（当期/月息/赎回/满当入库/账簿展示）" "$LOG/pawn_redeem.log" $? || FAIL=1

JOBLIST=$(mktemp)
if [ -f scripts/tests/plans.json ]; then
  python3 - >> "$JOBLIST" <<'EOF'
import json
plans = list(json.load(open('scripts/tests/plans.json'))['plans'])
for p in plans:
    print(f"分支计划 {p}|--plan={p}")
# 每类挑几条再经由界面跑一遍
ui = [p for p in plans if p.startswith('d1_')][:2] + [p for p in plans if p.startswith('d2_')][:2] + [p for p in plans if p.startswith('n2_') or p.startswith('ending')][:2] + [p for p in plans if p.startswith('v02_')][::4]
for p in ui:
    print(f"分支计划 {p}（经由界面）|--plan={p} --ui")
EOF
fi
for p in fair greedy random1 random2 random3; do echo "全流程（核心，策略 $p，到 $UNTIL）|--policy=$p --until=$UNTIL" >> "$JOBLIST"; done
for p in fair greedy random2; do echo "全流程（经由界面，策略 $p，到 $UNTIL）|--ui --policy=$p --until=$UNTIL" >> "$JOBLIST"; done
for m in esc scene skip; do echo "防卡死：对白用 $m 推进（经由界面，到 $UNTIL）|--ui --say-mode=$m --until=$UNTIL" >> "$JOBLIST"; done
echo "防卡死：每笔都不做（经由界面，到 $UNTIL）|--ui --policy=refuser --until=$UNTIL" >> "$JOBLIST"
echo "防卡死：每笔都不做（核心，到 $UNTIL）|--policy=refuser --until=$UNTIL" >> "$JOBLIST"

tr '\n' '\0' < "$JOBLIST" | xargs -0 -P "$JOBS" -I{} bash -c 'run_one "$1"' _ {} > "$LOG/results.txt"
sort "$LOG/results.txt" | grep -E "^[✓✗]" ; grep -A5 "^✗" "$LOG/results.txt" | grep "^    " || true
if grep -q "^✗" "$LOG/results.txt"; then FAIL=1; fi
echo "共 $(grep -c '^[✓✗]' "$LOG/results.txt") 项并行测试；日志：$LOG"
if [ $FAIL -ne 0 ]; then echo "测试失败"; exit 1; fi
echo "全部通过"

# T01: deterministic town simulation acceptance (legacy checks above stay intact).
TOWN_FAIL=0
for spec in "账本续当与存档|test_sim_ledger" "小镇数据与轮盘规则|test_sim_rules" "小镇存档与外生隔离|test_sim_replay" "小镇流言与账单|test_sim_life" "小镇三难度多种子|test_sim_soak"; do
  town_name="${spec%%|*}"; town_script="${spec#*|}"; town_log="$LOG/$town_script.log"
  timeout 300 "$GODOT" --headless -s "res://scripts/tests/$town_script.gd" > "$town_log" 2>&1
  check_log "$town_name" "$town_log" $? || TOWN_FAIL=1
done
if [ "$TOWN_FAIL" -ne 0 ]; then echo "小镇测试失败；日志：$LOG"; exit 1; fi
echo "T01 小镇测试全部通过"

# T04: actual Director playthroughs, branches, saves and payment boundaries.
town_play_log="$LOG/town_play_acceptance.log"
timeout 600 "$GODOT" --headless --max-fps 0 -s res://scripts/tests/town_play_acceptance.gd > "$town_play_log" 2>&1
check_log "小镇14天玩法、18分支与存档边界" "$town_play_log" $? || { echo "T04 玩法测试失败；日志：$LOG"; exit 1; }
echo "T04 小镇玩法测试全部通过"

# T07: fast real-economy smoke; the checked-in report uses 200 paired seeds.
balance_log="$LOG/balance_smoke.log"
timeout 600 "$GODOT" --headless --max-fps 0 -s res://scripts/tests/balance_sim.gd -- --quick --report="$LOG/balance_smoke.md" --json="$LOG/balance_smoke.json" > "$balance_log" 2>&1
check_log "小镇三难度三策略数值烟测" "$balance_log" $? || { echo "T07 数值烟测失败；日志：$LOG"; exit 1; }
echo "T07 小镇数值烟测全部通过"
# T03: town front end on a real Main instance — walking/doors/collision, shop close-ups, counter hand-off,
# sleep + save/load, living town, pause menu / title round trips, music cues — plus the UI-driven autoplay.
UI_FAIL=0
for spec in "小镇界面：走动、换图、碰撞、门|town_ui_walk" "小镇界面：店铺特写、买卖、打烊|town_ui_shops" "小镇界面：客人进门与柜台衔接|town_ui_counter" "小镇界面：睡觉换天、自动存档、读档一致|town_ui_save" "小镇界面：街上的人、气泡、提示、宵禁、半夜入睡|town_ui_life" "小镇界面：暂停菜单、设置、返回标题往返|town_ui_menu" "小镇界面：音乐挂钩|town_ui_music" "小镇界面：店里的剧情与议价、热键、打字机|town_ui_scene" "小镇界面：睡觉换天不黑屏、告示先于信号、睡觉防重入、日结返回标题、继续|town_ui_night" "小镇界面：前期引导（步骤、按键条、存档不重来、开关）与操作说明|town_ui_guide" "小镇界面：规矩页（谁在什么时候说、不重复、无隐藏数值、关门的说法）|town_ui_rules" "小镇界面：宵禁（夜里每出一趟门的巡夜检查、先说后罚、训诫/罚洋/押回、塞钱走账本、存档保留违规次数）|town_ui_curfew" "小镇界面：只守铺子 + 每天上门的保护费（门口不出、胡二每天来、数目逐日不同、照数给/讲价/求缓/不给/拿货抵、后果升级、存档保留欠账）|town_ui_protect" "小镇界面（试玩反馈）：Esc 全局暂停、暂停冻结、E 关弹窗|town_ui_esc" "小镇界面（试玩反馈）：当铺柜台碰撞与排序、交互提示、电报机规则、出门再进门的客人|town_ui_pawnshop" "小镇界面：去哪儿（门口地图传送、来回耗时、打烊不去、店里能看见人）|town_ui_travel" "小镇界面：只守铺子的过路客人与门口吆喝（门口提示、走进门口不开小窗、E 开 / E·Esc 关、吆喝花钟点、被叫的人进门站定能招呼、柜台上卖架上的货、货架只看、一整天不超员、日结合成一行、断客没人应、没货或没人要灰着、第一天吆喝得应、柜台上写原型名、档案簿人物合成一行、整理库房不露市价、哥哥的话与规矩页、引导）|town_ui_walkin"; do
  ui_name="${spec%%|*}"; ui_script="${spec#*|}"; ui_log="$LOG/$ui_script.log"
  timeout 300 "$GODOT" --headless -s "res://scripts/tests/$ui_script.gd" > "$ui_log" 2>&1
  check_log "$ui_name" "$ui_log" $? || UI_FAIL=1
done
# [shop-only] 本版默认只守铺子：自动试玩不出门，每天接胡二；再单独跑一遍 --shop-only=0（出门版）保住原来的覆盖
for ui_seed in 7 3; do
  ui_log="$LOG/town_autoplay_$ui_seed.log"
  timeout 300 "$GODOT" --headless -- --town --autoplay=town_fair --fast --days=3 --seed=$ui_seed --quit > "$ui_log" 2>&1
  check_log "小镇自动试玩 town_fair 3 天（只守铺子，经由界面，种子 $ui_seed）" "$ui_log" $? || UI_FAIL=1
done
ui_log="$LOG/town_autoplay_shop_greedy.log"
timeout 300 "$GODOT" --headless -- --town --autoplay=town_greedy --fast --days=4 --seed=5 --quit > "$ui_log" 2>&1
check_log "小镇自动试玩 town_greedy 4 天（只守铺子：次次不给，后果一路升，不卡死）" "$ui_log" $? || UI_FAIL=1
for ui_seed in 7; do
  ui_log="$LOG/town_autoplay_out_$ui_seed.log"
  timeout 300 "$GODOT" --headless -- --town --autoplay=town_fair --fast --days=3 --seed=$ui_seed --shop-only=0 --quit > "$ui_log" 2>&1
  check_log "小镇自动试玩 town_fair 3 天（可出门版 --shop-only=0，经由界面，种子 $ui_seed）" "$ui_log" $? || UI_FAIL=1
done
if [ "$UI_FAIL" -ne 0 ]; then echo "T03 小镇界面测试失败；日志：$LOG"; exit 1; fi
echo "T03 小镇界面测试全部通过"
# [shop-only] 过路客人与门口吆喝（v0.4.2，docs/town/DESIGN_walkin.md）：真导演无头跑，不开界面
walkin_log="$LOG/test_walkin.log"
timeout 300 "$GODOT" --headless -s res://scripts/tests/test_walkin.gd > "$walkin_log" 2>&1
check_log "只守铺子：过路客人与门口吆喝（时刻表确定、第一天只等吆喝/断客日/出门版没有、店里站满不进门而叫来的照进、读档不重复、吆喝叫下一位、路上的人也算人数、架上没人要吆喝卖货灰着、买主从当时架上挑买得起的、货没了改挑或体面地走、成交记账、外生隔离、货架只看、夜里不夜卖不露市价）" "$walkin_log" $? || { echo "过路客人测试失败；日志：$LOG"; exit 1; }
echo "过路客人测试全部通过"
# [cards] W0：卡牌版测试（清单在 scripts/tests/cards/suites/*.txt；docs/cards/CARDS_INTERFACES.md §12.1）
GODOT="$GODOT" JOBS="$JOBS" bash tools/run_card_tests.sh || { echo "卡牌版测试失败"; exit 1; }
