# 0009: How far world art may be tinted

**Status**: accepted, 2026-10-28 (nuances 0004 for the dungeon; decided by Claude on the
owner's delegation).

**Context**: 10 of 12 dungeon themes multiplied floors and walls far past the neutral dim of
decision 0004, and the biome screen grading added to it. Some places are meant to feel wrong.

**Decision**:
- Theme tints on tiles (`DungeonTheme`) stay a **neutral dim**: every channel at least 0.75,
  within 0.12 of each other. A biome's identity comes from its tileset, its props, its light
  (LightField) and a recoloured tileset variant, not from a colour multiply.
- The screen grading (`AmbienceDef`) may colour a biome, but its **combined** effect with the
  theme on a mid-tone keeps every channel at least 0.6 and threats readable (greyscale check).
- **Narrative exceptions**, listed in data and in this record, may go further: the Threshold
  (Seuil), the Deeps (Tréfonds), the Well's Bottom, the Blood Moon and curses. They must still
  keep the hero, threats and telegraphs readable.
- Kagari: no tint at all on props (the Well's roots are pack art drawn as roots, not tinted trees).

**Consequences**: a test checks theme tints and the combined grading, with the exceptions listed.
