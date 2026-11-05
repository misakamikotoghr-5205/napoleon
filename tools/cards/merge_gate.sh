#!/usr/bin/env bash
# 合并门禁（集成用）：按计划文件把 PR 合到集成分支最新提交上，一批一批测；某批红了，就退回这批开头，
# 把这批逐个合、逐个测（首轮因冲突被拒的也重试），只留下全绿的。不推送——集成人看日志、跑全量
# tools/run_tests.sh 后自己 push。合同 §13.4、HANDOFF §6“合并门禁”。
#
# 用法：GODOT=<Godot 4.7.1> tools/cards/merge_gate.sh <计划文件> [工作目录]
# 计划每行：批次<TAB>任务号<TAB>PR号<TAB>分支<TAB>head SHA（40 位，审过的那个提交）；空行和 # 注释忽略。
#   每行在合并前都和 GitHub 上的 PR 对一遍：base 是集成分支、head 分支名一致、PR 开着、head 还是这个 SHA，
#   本地取到的 origin/<分支> 也还是这个 SHA；对不上就拒（分支动过 → MOVED，别的 → MISMATCH），不跑路径检查、不合。
#   合的是 SHA 本身，不是分支名；路径检查用 PR 在 GitHub 上的真实作者。
# 环境变量：GODOT（必填）；GATE_BASE（集成分支，默认 claude/festive-ride-vud32a）；GATE_JOBS（并行数，默认 3）。
# 不会清理旧 worktree / 分支（已存在就报错退出），不会推送。
# 日志：工作目录/gate.<时间戳>.<PID>.log；首次失败另存同名前缀 .failure；末尾是逐 PR 结果表，任何一行不是 APPLIED 就非零退出。
set -euo pipefail
if (( $# < 1 || $# > 2 )); then
  echo "Usage: GODOT=<binary> $0 <plan> [work-dir]" >&2
  exit 2
fi
WD=$(realpath -m "${2:-/tmp/merge_gate}")
mkdir -p "$WD"
LOG="$WD/gate.$(date -u +%Y%m%dT%H%M%SZ).$$.log"
FAILURE="${LOG%.log}.failure"

# 在管道的独立进程内执行，EXIT trap 的汇总也进入 tee。
gate() (
  set -Eeuo pipefail
  FIRST_FAILURE=0
  STEP=initialization
  BASE=${GATE_BASE:-claude/festive-ride-vud32a}
  declare -a batches=() ids=() prs=() branches=() shas=() results=()
  record_failure() {
    local step=$1 code=$2
    printf 'FAIL step=%s exit=%s\n' "$step" "$code"
    if (( FIRST_FAILURE == 0 )); then
      FIRST_FAILURE=$code
      printf 'FIRST_FAILURE step=%s exit=%s\n' "$step" "$code" > "$FAILURE"
    fi
  }
  finish() {
    local code=$?
    trap - EXIT ERR
    if (( code != 0 && FIRST_FAILURE == 0 )); then record_failure "$STEP" "$code"; fi
    printf '\nBATCH\tTASK\tPR\tSHA\tRESULT\n'
    local i
    for i in "${!prs[@]}"; do
      printf '%s\t%s\t#%s\t%s\t%s\n' "${batches[i]}" "${ids[i]}" "${prs[i]}" "${shas[i]:0:12}" "${results[i]}"
      if [[ ${results[i]} != APPLIED && $code == 0 ]]; then code=1; fi
    done
    printf 'LOG=%s\nEXIT=%s\n' "$LOG" "$code"
    exit "$code"
  }
  trap finish EXIT
  trap 'code=$?; record_failure "$STEP" "$code"; exit "$code"' ERR
  run() {
    STEP=$1; shift
    printf '\nSTEP %s\n' "$STEP"
    local code
    if "$@"; then return 0; else code=$?; fi
    record_failure "$STEP" "$code"
    return "$code"
  }
  capture() {
    local variable=$1 value code
    STEP=$2; shift 2
    if value=$("$@"); then
      printf '%s: %s\n' "$STEP" "$value"
      printf -v "$variable" '%s' "$value"
    else
      code=$?
      printf '%s\n' "$value"
      record_failure "$STEP" "$code"
      return "$code"
    fi
  }
  PLAN=$(realpath "$1")
  R=$(git rev-parse --show-toplevel)
  : "${GODOT:?set GODOT to a Godot binary}"
  export GODOT
  # 外部的套件过滤会造成假绿；门禁必须运行所有套件并强制 strict。
  unset CARDS_SUITES
  export CARDS_VALIDATE_MODE=strict
  echo "CARDS_SUITES unset; CARDS_VALIDATE_MODE=strict; base=$BASE"
  while IFS=$'\t' read -r b id pr br sha extra || [[ -n $b ]]; do
    [[ -z $b || $b == \#* ]] && continue
    if [[ -z $id || ! $pr =~ ^[0-9]+$ || -z $br || ! $sha =~ ^[0-9a-f]{40}$ || -n $extra ]]; then
      record_failure plan-format 2; exit 2
    fi
    batches+=("$b"); ids+=("$id"); prs+=("$pr"); branches+=("$br"); shas+=("$sha"); results+=(FAILED)
  done < "$PLAN"
  if (( ${#prs[@]} == 0 )); then record_failure empty-plan 2; exit 2; fi
  W="$WD/stage"
  # 固定名字若已存在就报错（包括空目录），由操作者决定如何保留/清理。
  if [[ -e $W || -L $W ]]; then record_failure existing-worktree 1; exit 1; fi
  run fetch git -C "$R" fetch origin '+refs/heads/*:refs/remotes/origin/*' || exit "$?"
  run worktree-add git -C "$R" worktree add -b merge-gate "$W" "origin/$BASE" || exit "$?"
  run cd cd -- "$W" || exit "$?"
  EXPECTED_W=$(realpath "$W")
  EXPECTED_COMMON=$(git -C "$R" rev-parse --path-format=absolute --git-common-dir)
  EXPECTED_GIT_DIR=$(git rev-parse --absolute-git-dir)
  guard() {
    local here top gd common pointer backlink
    here=$(pwd -P) || return "$?"
    top=$(git rev-parse --show-toplevel) || return "$?"
    gd=$(git rev-parse --absolute-git-dir) || return "$?"
    common=$(git rev-parse --path-format=absolute --git-common-dir) || return "$?"
    [[ -f $W/.git ]] || return 1
    IFS= read -r pointer < "$W/.git" || return "$?"
    [[ -f $gd/gitdir ]] || return 1
    IFS= read -r backlink < "$gd/gitdir" || return "$?"
    [[ $here == "$EXPECTED_W" && $top == "$EXPECTED_W" &&
       $gd == "$EXPECTED_GIT_DIR" && $common == "$EXPECTED_COMMON" &&
       $gd == "$EXPECTED_COMMON"/worktrees/* &&
       $pointer == "gitdir: $gd" && $backlink == "$EXPECTED_W/.git" ]]
  }
  safe_git() {
    # 每次 merge（含 abort）、reset 和 commit 前重新验证目录和双向指针。
    run worktree-guard guard || exit "$?"
    run "git-$1" git "$@"
  }
  run worktree-guard guard || exit "$?"
  run godot-version "$GODOT" --version || exit "$?"
  # 计划行 ↔ PR 绑定：GitHub 上的 base、head 分支、状态、head SHA 和本地 origin/<分支> 都要对上计划。
  bind() {
    local i=$1 meta login pbase phead poid pstate local_sha
    capture meta "pr-meta-#${prs[i]}" gh pr view "${prs[i]}" --json author,baseRefName,headRefName,headRefOid,state \
      --jq '[.author.login, .baseRefName, .headRefName, .headRefOid, .state] | @tsv' || return "$?"
    IFS=$'\t' read -r login pbase phead poid pstate <<< "$meta"
    if ! capture local_sha "branch-sha-#${prs[i]}" git rev-parse --verify -q "origin/${branches[i]}^{commit}"; then
      results[i]=MISMATCH; return 1
    fi
    if [[ -z $login || $login == null || $pbase != "$BASE" || $phead != "${branches[i]}" || $pstate != OPEN ]]; then
      printf 'PR #%s is %s -> %s (%s, author %s); plan says %s -> %s\n' \
        "${prs[i]}" "$phead" "$pbase" "$pstate" "$login" "${branches[i]}" "$BASE"
      results[i]=MISMATCH; record_failure "bind-#${prs[i]}" 1; return 1
    fi
    if [[ $poid != "${shas[i]}" || $local_sha != "${shas[i]}" ]]; then
      printf 'PR #%s moved: plan %s, GitHub %s, origin/%s %s\n' "${prs[i]}" "${shas[i]}" "$poid" "${branches[i]}" "$local_sha"
      results[i]=MOVED; record_failure "bind-#${prs[i]}" 1; return 1
    fi
    PR_LOGIN=$login
  }
  domerge() {
    local i=$1 base author subject sha=${shas[i]}
    results[i]=FAILED
    bind "$i" || return "$?"
    capture base merge-base git merge-base HEAD "$sha" || return "$?"
    # GitHub login 用于路径权限检查，原提交 name/email 用于提交署名。
    capture author commit-author git log -1 --format='%an <%ae>' "$sha" || return "$?"
    capture subject commit-subject git log -1 --format=%s "$sha" || return "$?"
    if run "paths-#${prs[i]}" python3 tools/cards/audit/check_pr_paths.py "$base" "$sha" "--author=$PR_LOGIN" "--task=${ids[i]}"; then
      :
    else
      results[i]=REJECTED; return 1
    fi
    if safe_git merge --no-ff --no-commit "$sha"; then
      # 已合并的分支没有 MERGE_HEAD，不创建空提交。
      if [[ -f $EXPECTED_GIT_DIR/MERGE_HEAD ]]; then
        safe_git commit "--author=$author" -m "合并 #${prs[i]} [${ids[i]}] $subject" || exit "$?"
      fi
    else
      results[i]=CONFLICT
      if [[ -f $EXPECTED_GIT_DIR/MERGE_HEAD ]]; then safe_git merge --abort || exit "$?"; fi
      return 1
    fi
  }
  runtests() {
    local sha suite_count test_count
    capture sha tested-sha git rev-parse HEAD || exit "$?"
    local -a suites=()
    shopt -s nullglob
    suites=(scripts/tests/cards/suites/*.txt)
    suite_count=${#suites[@]}
    if (( suite_count == 0 )); then record_failure no-suites 1; return 1; fi
    capture test_count suite-test-count awk '!/^[[:space:]]*(#|$)/ {n++} END {print n+0}' "${suites[@]}" || exit "$?"
    printf 'TEST SHA=%s suites=%s tests=%s mode=%s\n' "$sha" "$suite_count" "$test_count" "$CARDS_VALIDATE_MODE"
    # 只看退出码，不靠成功字样；任何一次失败都会留下首次失败记录。旧版冒烟偶发超时，红了重跑一次。
    run cards env JOBS="${GATE_JOBS:-3}" timeout 2400 bash tools/run_card_tests.sh || return "$?"
    run legacy-smoke timeout 1800 bash tools/run_legacy_smoke.sh \
      || run legacy-smoke-retry timeout 1800 bash tools/run_legacy_smoke.sh || return "$?"
  }
  declare -A seen=()
  for B in "${batches[@]}"; do
    [[ -n ${seen[$B]:-} ]] && continue
    seen[$B]=1
    capture start batch-start git rev-parse HEAD
    pending=(); retry=()
    for i in "${!prs[@]}"; do
      [[ ${batches[i]} == "$B" ]] || continue
      if domerge "$i"; then pending+=("$i"); retry+=("$i")
      elif [[ ${results[i]} == CONFLICT ]]; then retry+=("$i"); fi
    done
    (( ${#pending[@]} > 0 )) || continue
    if runtests; then
      for i in "${pending[@]}"; do results[i]=APPLIED; done
      continue
    fi
    # 批次红了：退回批次开头，按计划顺序逐个重来；首轮因为和同批别的 PR 冲突被拒的也在这里重试。
    echo "Batch $B failed; retry each PR (merged and conflicting)"
    safe_git reset --hard "$start" || exit "$?"
    for i in "${retry[@]}"; do
      capture before pr-start git rev-parse HEAD
      if domerge "$i"; then
        if runtests; then results[i]=APPLIED
        else results[i]=FAILED; safe_git reset --hard "$before" || exit "$?"; fi
      fi
    done
  done
  capture final_sha final-sha git rev-parse HEAD
)
# 不让 errexit 提前跳过 PIPESTATUS；gate 内部单独启用严格错误处理。
set +e
gate "$@" 2>&1 | tee "$LOG"
codes=("${PIPESTATUS[@]}")
set -e
if (( codes[1] != 0 )); then
  printf 'Log tee failed: exit=%s\n' "${codes[1]}" >&2
  exit "${codes[1]}"
fi
exit "${codes[0]}"
