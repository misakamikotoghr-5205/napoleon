# G01 validator fixtures

`good/` is a complete 130-card synthetic corpus. It supplies all eras, demand combinations, fortune grades, guide coverage and ASCII human-text placeholders; default, strict and ship validation pass. These text fixtures are test data only.

`bad/V01/` through `bad/V37/` are single-document mutations. `test_validator_rules.gd` copies `good/` to its isolated `user://test/` directory, overlays each mutation, and validates that complete root. Every error must have the requested rule number. NOTE rules additionally pass default mode and produce a note. No production corpus or shared test directory is written.

The fixture directories mirror `data/cards/`; the test supplies the materialized path as the validator root. This avoids 37 copies of unchanged files and works without filesystem symlink support.
