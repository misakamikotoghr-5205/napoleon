#!/usr/bin/env python3
"""Build the authored Napoleon campaign data; does not modify source drafts.

Run from any directory. --content-only is useful while working on a content
slice; the normal invocation generates the complete runtime bundle.
"""
from pathlib import Path
import argparse
import importlib
import json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--content-only", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    modules = ["merge_content", "merge_demo"] if args.content_only else ["merge_presentation", "merge_content", "merge_battles", "merge_maps", "merge_demo"]
    summary = {}
    for name in modules:
        module = importlib.import_module(name)
        summary[name] = module.build(root)
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
