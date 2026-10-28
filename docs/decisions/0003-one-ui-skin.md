# 0003: One UI skin

**Status**: accepted, 2026-10-27.

**Context**: an agent gave the village's conversations white dialogue frames from another part of
the pack; every other window is wood with a gold border. The owner saw it at once on the phone.

**Decision**: every window, panel, dialogue box and button is built from src/ui/common/
(OrnateBoard, RpgWindow, RpgDialog, UiParts) with UiSkin colours (docs/design/interface.md
"One skin").

**Consequences**: no StyleBoxFlat or StyleBoxTexture outside src/ui/common/, no light panels, no
new colour token without a decision. Checked: `tools/design/check.py` (UI skin).
