"""Conversion reuse keeps scheduling separate from content and encoding choices."""
import json
import tempfile
import unittest
from pathlib import Path

from assets import Pipeline, TOOLS


class StageIdentityTest(unittest.TestCase):
    def identity(self, root, workers, profile='1.3', major='7', data=None):
        root.mkdir()
        (root / 'inputs.json').write_text(json.dumps(dict(converters={}, profile=profile,
                                                        bspc='compiler', converter_data=data or {})))
        for stage, script in [('images', 'dk_extract.py'), ('textures', 'pack_textures.py'), ('maps', 'convert_all.py')]:
            directory = root / stage
            directory.mkdir()
            command = ['python', '-B', str(TOOLS / script), '--data', str(root / 'input'),
                       '--workers', str(workers)]
            (directory / 'complete.json').write_text(json.dumps(dict(command=command)))
        return Pipeline.stage_identity(root, 'navigation',
            ['python', '-B', str(TOOLS / 'navigation.py'), '--maps', str(root / 'maps'),
             '--jobs', str(workers), '--ffmpeg-major', major])

    def test_worker_change_preserves_dependent_stage_identity(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.assertEqual(self.identity(root / 'first', 12), self.identity(root / 'resumed', 6))

    def test_profile_and_encoding_changes_invalidate_reuse(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            baseline = self.identity(root / 'baseline', 6)
            self.assertNotEqual(baseline, self.identity(root / 'retail', 6, profile='retail'))
            self.assertNotEqual(baseline, self.identity(root / 'encoder', 6, major='8'))

    def test_catalog_and_hull_config_invalidate_only_their_consumers(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data = {'src/multiplayer/appearances.csv': 'catalog-a', 'dkq3/tools/dk3-aas.cfg': 'hull-a'}
            baseline = self.identity(root / 'baseline', 4, data=data)
            catalog = self.identity(root / 'catalog', 4, data=dict(data, **{'src/multiplayer/appearances.csv': 'catalog-b'}))
            hull = self.identity(root / 'hull', 4, data=dict(data, **{'dkq3/tools/dk3-aas.cfg': 'hull-b'}))
            def models(name):
                generation = root / name
                return Pipeline.stage_identity(generation, 'models',
                    ['python', '-B', str(TOOLS / 'dkm2md3.py'), '--data', str(generation / 'input')])
            self.assertEqual(baseline, catalog)
            self.assertNotEqual(baseline, hull)
            self.assertNotEqual(models('baseline'), models('catalog'))
            self.assertEqual(models('baseline'), models('hull'))
