# Decisions

What the owner has decided, and why. Agents read this before proposing anything that touches
it, and never reopen a decision on their own: a decision is **replaced** by a new numbered one
that cites it (the old one stays, marked "Replaced by"), never rewritten. AGENTS.md "Ask the
owner first" lists what needs a new decision.

| # | Decision | Date |
|---|---|---|
| [0001](0001-roguelike-only.md) | This repository is a real-time action roguelike; any RPG is a separate project | 2026-10-26 |
| [0002](0002-one-art-source.md) | World art from Ninja Adventure only; UI from the Kenney skin | 2026-10-27 |
| [0003](0003-one-ui-skin.md) | One UI skin, built only from src/ui/common/ | 2026-10-27 |
| [0004](0004-no-ground-tint.md) | Ground art is never darkened or coloured by a tint | 2026-10-27 |
| [0005](0005-private-repository.md) | The repository is private; every asset keeps its source in REUSE.toml | 2026-10-27 |
| [0006](0006-kagari-districts.md) | Kagari is laid out by districts around the Well | 2026-10-27 |

Template for a new one (`NNNN-short-name.md`): **Status** (accepted / replaced by NNNN),
**Context** (what made it necessary), **Decision** (one or two sentences), **Consequences** (what
agents must and must not do; which check enforces it).
