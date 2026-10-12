"""HD weapon package admission checks real IQM structure and Gold frame authority."""
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

import hd_weapons
import iqm


class HdWeaponsTest(unittest.TestCase):
    def fixture(self, root, source='models/e4/a_glock.dkm', source_frames=5):
        art, base = root / 'art', root / 'models.pk3'
        target = 'models/hd-weapons/glock/world.iqm'
        material = 'models/hd-weapons/glock/metal'
        (art / target).parent.mkdir(parents=True)
        mesh = iqm.Mesh('body', material,
                        ((0., 0., 0.), (1., 0., 0.), (0., 1., 0.)),
                        ((0., 0., 1.),) * 3, ((0., 0.), (1., 0.), (0., 1.)), ((0, 1, 2),))
        (art / target).write_bytes(iqm.encode([mesh], frame_count=5))
        (art / (material + '.png')).write_bytes(b'\x89PNG\r\n\x1a\nfixture')
        (art / 'reviews/glock').mkdir(parents=True)
        (art / 'reviews/glock/world.png').write_bytes(b'review')
        admission = root / 'admission.json'
        admission.write_text(json.dumps(dict(format=1, models=[dict(source=source, target=target,
            review='accepted', evidence='reviews/glock/world.png')])))
        with zipfile.ZipFile(base, 'w') as archive:
            archive.writestr(source + '.md3', b'source')
            archive.writestr(source + '.anim', f'dk3_animation 1\n{source_frames}\n"stand" 0 {source_frames-1} 10\n')
        return art, admission, base

    def test_roster_covers_registered_classes_and_shared_models(self):
        rows = hd_weapons.roster()
        self.assertEqual(len(rows), 28)
        self.assertEqual(next(r for r in rows if r['class_name'] == 'flashlight')['view'],
                         next(r for r in rows if r['class_name'] == 'sunflare')['view'])
        self.assertEqual(next(r for r in rows if r['class_name'] == 'cordite')['view'],
                         next(r for r in rows if r['class_name'] == 'slugger')['view'])

    def test_build_and_validate_accepted_world_model(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            art, admission, base = self.fixture(root)
            output = root / 'weapons.pk3'
            hd_weapons.build(art, admission, base, output)
            report = hd_weapons.validate_package(output, base)
            self.assertEqual(len(report['models']), 1)
            with zipfile.ZipFile(output) as archive:
                self.assertEqual(archive.read(hd_weapons.MAPPING).decode(),
                                 'models/e4/a_glock.dkm models/hd-weapons/glock/world.iqm\n')

    def test_visual_review_and_authoritative_frames_are_required(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = 'models/e4/w_glock.dkm'
            art, admission, base = self.fixture(root, source, source_frames=140)
            data = json.loads(admission.read_text())
            data['models'][0]['review'] = 'unverified'
            admission.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, 'visually accepted'):
                hd_weapons.build(art, admission, base, root / 'weapons.pk3')
            data['models'][0]['review'] = 'accepted'
            admission.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, 'frame count'):
                hd_weapons.build(art, admission, base, root / 'weapons.pk3')

    def test_unverified_candidate_is_explicit_preview_only(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            art, admission, base = self.fixture(root)
            data = json.loads(admission.read_text())
            data['models'][0]['review'] = 'unverified'
            admission.write_text(json.dumps(data))
            output = root / 'preview.pk3'
            hd_weapons.build(art, admission, base, output, preview=True)
            with self.assertRaisesRegex(ValueError, 'cannot be installed as a default'):
                hd_weapons.validate_package(output, base)
            self.assertTrue(hd_weapons.validate_package(output, base, allow_preview=True)['preview'])


if __name__ == '__main__':
    unittest.main()
