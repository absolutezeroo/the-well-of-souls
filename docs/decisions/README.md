# Decisions

What the owner has decided (or delegated to Claude, marked so), and why. Agents read this before proposing anything that touches
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
| [0007](0007-whole-pixels-on-screen.md) | Whole screen pixels per art pixel; no fractional scales | 2026-10-28 |
| [0008](0008-fairness-contract.md) | Wind-ups of at least 0.4 s (bosses 0.5 s) at any difficulty, with a sound | 2026-10-28 |
| [0009](0009-world-tints.md) | Dungeon tints stay a neutral dim; listed narrative exceptions | 2026-10-28 |
| [0010](0010-first-minutes.md) | First run starts at once; a protected first room; Descend again | 2026-10-28 |
| [0011](0011-assist-and-difficulty.md) | Assist option, lowering difficulty in a run, tap-to-charge | 2026-10-28 |
| [0012](0012-luck-and-roles.md) | Bad-luck protection, a heal before bosses, no repeats, roles, floor pacing | 2026-10-28 |
| [0013](0013-run-variety.md) | Behaviour perks, one rule-bending relic per warden's choice, weapon evolutions at the forge, starting kits opened by feats | 2026-10-28 |

Template for a new one (`NNNN-short-name.md`): **Status** (accepted / replaced by NNNN),
**Context** (what made it necessary), **Decision** (one or two sentences), **Consequences** (what
agents must and must not do; which check enforces it).
