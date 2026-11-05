#!/bin/bash
# usage: render.sh [out.png]
S=/tmp/claude-0/-home-user-dehoudang/f413af39-a419-5ad7-b290-de5bfd493b6e/scratchpad
OUT=$S/mockups/c_fast
export OUT_PNG=${1:-$OUT/render.png}
VK_ICD_FILENAMES=$S/lvp/lvp.json timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" \
  $S/godot/Godot_v4.7-stable_linux.x86_64 --rendering-driver vulkan --path $OUT/proj 2>&1 \
  | grep -v -E "ALSA|alsa|audio|snd_|^\s*at:|^$"
