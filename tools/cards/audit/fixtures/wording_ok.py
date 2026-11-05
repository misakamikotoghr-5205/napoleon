#!/usr/bin/env python3
"""Stand-in for K13 wording_lint.py. Exits 0 so a good pack can pass item 6."""
import sys


def main(argv):
    if len(argv) < 1:
        print("usage: wording_ok.py <text dir> --scope=text --fail-on=must")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
