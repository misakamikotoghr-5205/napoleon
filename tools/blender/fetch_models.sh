#!/bin/sh
# Download the CC0 KayKit model packs used by the Blender scenes (Kay Lousberg, www.kaylousberg.com).
# Packs are pinned to the commits the samples were made with and registered in
# docs/cards/art/blender/MODELS.csv. They are not committed to this repo.
#   sh tools/blender/fetch_models.sh [target_dir]      default: tools/blender/models (git-ignored)
#   KAYKIT_DIR=<dir> must point at the same directory when rendering if you choose another target.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
DEST=${1:-${KAYKIT_DIR:-$HERE/models}}
mkdir -p "$DEST"
fetch() {
  name=$1; sha=$2
  if [ -d "$DEST/$name/.git" ]; then
    echo "have $name"
  else
    git clone --quiet "https://github.com/KayKit-Game-Assets/$name" "$DEST/$name"
  fi
  git -C "$DEST/$name" checkout --quiet "$sha"
  echo "ok   $name @ $sha"
}
fetch KayKit-Furniture-Bits-1.0     96d5930a8dbdb363409bbc2d3341718b00e17c9c
fetch KayKit-Restaurant-Bits-1.0    153c8a7535b48237854cb54ff6890679f8c574d1
fetch KayKit-City-Builder-Bits-1.0  63976910ca04d16f0fc531b9c614244be8128713
echo "models in $DEST"
