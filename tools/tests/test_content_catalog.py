"""Stable catalog generation: migration aliases and accidental identity reuse."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('content_catalog_builder', ROOT / 'tools/saves/build_catalog.py')
catalog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(catalog)


class ContentCatalog(unittest.TestCase):
    def test_moving_content_preserves_legacy_aliases(self):
        before = catalog.render({'item:katana': 'res://data/old/katana.tres'})
        after = catalog.render({'item:katana': 'res://data/new/blade.tres'}, before)
        self.assertIn('"res://data/old/katana.tres": "item:katana"', after)
        self.assertIn('"res://data/new/blade.tres": "item:katana"', after)
        self.assertEqual(catalog.render({'item:katana': 'res://data/new/blade.tres'}, after), after)

    def test_reusing_an_old_path_for_another_identity_is_rejected(self):
        before = catalog.render({'item:katana': 'res://data/katana.tres'})
        with self.assertRaises(ValueError):
            catalog.render({'item:axe': 'res://data/katana.tres'}, before)

    def test_duplicate_ids_are_rejected_and_subresource_ids_are_ignored(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'src').mkdir()
            (root / 'data').mkdir()
            first = root / 'data/first.tres'
            first.write_text('[gd_resource script_class="ItemDef"]\n[sub_resource type="Resource" id="nested"]\nid = &"wrong"\n[resource]\nid = &"kept"\n')
            self.assertEqual(catalog.collect(root), {'item:kept': 'res://data/first.tres'})
            (root / 'data/second.tres').write_text(first.read_text())
            with self.assertRaises(ValueError):
                catalog.collect(root)

    def test_shipped_catalog_is_current(self):
        old = catalog.OUTPUT.read_text()
        self.assertEqual(catalog.render(catalog.collect(ROOT), old), old)
