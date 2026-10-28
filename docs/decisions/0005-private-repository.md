# 0005: A private repository, every asset with its source

**Status**: accepted, 2026-10-27.

**Context**: the repository was public while it held files whose licence forbids redistribution.
The owner makes it private (it was public only for an AI's access).

**Decision**: the repository is private. Every file under assets/ keeps its source, author and
licence in REUSE.toml; only CC0 is approved.

**Consequences**: a new file needs its REUSE.toml entry in the same commit; another licence needs
a new decision. Checked: `tools/design/check.py` (provenance).
