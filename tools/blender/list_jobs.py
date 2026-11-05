# Used by make_samples.sh: write one line per registered scene variant
# ("scene variant art_id colours method") to the file given after "--". Runs inside Blender so that
# scene modules may import any Blender module at top level.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from scenes import SCENES  # noqa: E402

with open(sys.argv[sys.argv.index("--") + 1], "w", encoding="utf-8") as f:
    for name, mod in sorted(SCENES.items()):
        for v in mod.VARIANTS:
            n, method = mod.COLORS
            f.write("%s %s %s %d %s\n" % (name, v, mod.IDS[v], n, method))
