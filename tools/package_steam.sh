#!/usr/bin/env bash
# Steam 发行打包脚本（CARDS_INTERFACES.md §11.6，#202 / #212）：
# 支持两条出包变体：
#   1. --variant=ai-disclosure（默认）：带 AI 声明版，包含 art/ai/**、audio/ai/**、data/cards/text_ai/**，
#      导出预设 "Steam (AI Disclosure)"（custom_features="ship,ai_disclosure"）。
#   2. --variant=no-disclosure（或 --no-ai）：无 AI 声明纯人工版，排除一切 *_ai / art/ai / audio/ai 路径，
#      缺任何一张人工图或残留任何一件 AI 资产直接失败，导出预设 "Steam (No AI Disclosure)"（custom_features="ship,no_ai"）。
#
# 用法：
#   bash tools/package_steam.sh [--variant=ai-disclosure|no-disclosure] [--no-ai]
#                               [--src=<repo>] [--staging=<dir>] [--out=<file.pck>]
#                               [--report=<audit.md>] [--godot=<binary>] [--stage-only]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT"
VARIANT="ai-disclosure"
STAGING=""
OUT_PCK=""
REPORT=""
GODOT_BIN="${GODOT:-godot}"
STAGE_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --variant=*)
      VARIANT="${arg#*=}"
      ;;
    --no-ai|--no-disclosure|--human-only)
      VARIANT="no-disclosure"
      ;;
    --ai-disclosure|--with-ai)
      VARIANT="ai-disclosure"
      ;;
    --src=*)
      SRC="${arg#*=}"
      ;;
    --staging=*)
      STAGING="${arg#*=}"
      ;;
    --out=*|--pck=*)
      OUT_PCK="${arg#*=}"
      ;;
    --report=*)
      REPORT="${arg#*=}"
      ;;
    --godot=*)
      GODOT_BIN="${arg#*=}"
      ;;
    --stage-only)
      STAGE_ONLY=1
      ;;
    -h|--help)
      sed -n '2,12p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "package_steam.sh: unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

case "$VARIANT" in
  ai|ai-disclosure|with-ai|disclosure)
    VARIANT="ai-disclosure"
    PRESET="Steam (AI Disclosure)"
    DEFAULT_SUBDIR="steam_ai"
    ;;
  no-ai|no-disclosure|human-only|human)
    VARIANT="no-disclosure"
    PRESET="Steam (No AI Disclosure)"
    DEFAULT_SUBDIR="steam_human"
    ;;
  *)
    echo "package_steam.sh: unknown variant '$VARIANT' (expected ai-disclosure or no-disclosure)" >&2
    exit 2
    ;;
esac

if [[ -z "$STAGING" ]]; then
  STAGING="$ROOT/.build/staging_${DEFAULT_SUBDIR}"
fi
if [[ -z "$OUT_PCK" ]]; then
  OUT_PCK="$ROOT/export/${DEFAULT_SUBDIR}/dehoudang.pck"
fi
if [[ -z "$REPORT" ]]; then
  REPORT="$ROOT/docs/cards/audit/last_audit_${DEFAULT_SUBDIR}.md"
fi

echo "=== [1/4] Stage ($VARIANT) -> $STAGING ==="
python3 "$ROOT/tools/cards/audit/stage_ship.py" "$STAGING" --src="$SRC" --variant="$VARIANT"

if [[ "$STAGE_ONLY" -eq 1 ]]; then
  echo "PACKAGE STAGE OK ($VARIANT): $STAGING"
  exit 0
fi

echo "=== [2/4] Pre-export Audit ($VARIANT) ==="
python3 "$ROOT/tools/cards/audit/audit.py" "$STAGING" \
  --src="$SRC" \
  --variant="$VARIANT" \
  --godot="$GODOT_BIN" \
  --report="$REPORT"

echo "=== [3/4] Export PCK ($PRESET) -> $OUT_PCK ==="
mkdir -p "$(dirname "$OUT_PCK")"
"$GODOT_BIN" --headless --path "$STAGING" --export-pack "$PRESET" "$OUT_PCK"

echo "=== [4/4] Post-export PCK Audit ($VARIANT) ==="
python3 "$ROOT/tools/cards/audit/audit.py" "$STAGING" \
  --src="$SRC" \
  --variant="$VARIANT" \
  --godot="$GODOT_BIN" \
  --pck="$OUT_PCK" \
  --report="$REPORT"

echo "PACKAGE OK ($VARIANT): $OUT_PCK"
