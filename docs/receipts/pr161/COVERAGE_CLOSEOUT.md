# K12 coverage closeout (PR #161)

Precise HEAD recorded in PR comment after push.

## Coverage
- `python3 tools/cards/art/check_manifest.py --refs=error` → **exit 0**
- Manifest art ids: **422** (was 406 = tip 235 + prior 171 card illus/icon; +16 item/prop baseline)
- Cleared remaining 16 baseline ids: 13 `item.*` (goldbar/papers/silver/silverware) + 3 `prop.fortune.*`
- Unique missing-id count before this commit: **16**; reference-line count in older tip logs could print higher when the same id is cited from multiple sources — that is line count ≠ unique id count.

## Determinism
- Double `gen_placeholders.py --out=<tmp>` → **all N files byte-identical** (N reported in PR comment; includes `.png` + placeholder `manifest.json`).
- `gen_placeholders.py --check --sheet=…` → exit 0 (Pillow path; stamp/size/hash).

## Visual
- Contact sheet: `docs/receipts/pr161/k12_placeholder_sheet.png`
- Thumbnail collage: `docs/receipts/pr161/placeholder_collage_48.png`
- Draft「稿」stamp present on generated placeholders (generator stamp bitmap).

## Scope note
No changes to `templates_extra.json` reference sources or to the coverage checker. Placeholders registered only.
