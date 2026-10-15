"""HD weapon package admission checks real IQM structure and Gold frame authority."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import zipfile

import hd_weapons
import hd_weapon_assemble
import iqm
import numpy as np
import skeletal_iqm


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

    def test_parts_keep_independent_motion_and_muzzle_joint(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = 'models/e4/w_glock.dkm'
            material = 'models/hd-weapons/glock/metal'
            reference = np.array([[0., 0., 0.], [1., 0., 0.], [0., 1., 0.]])
            moved = reference + [2., 0., 0.]
            turned = reference @ np.array([[0., 1., 0.], [-1., 0., 0.], [0., 0., 1.]]) + [0., 3., 0.]
            marker = np.stack((reference + [0., 0., 1.], reference + [2., 0., 1.]))
            for name, points in (('frame', np.stack((reference, moved))),
                                 ('slide', np.stack((reference, turned)))):
                np.savez(root / f'{name}.npz', **{'0_points': points})
                mesh = iqm.Mesh(name, material, tuple(map(tuple, reference)),
                                ((0., 0., 1.),) * 3, ((0., 0.), (1., 0.), (0., 1.)), ((0, 1, 2),))
                (root / f'{name}.iqm').write_bytes(iqm.encode([mesh]))
            manifest = root / 'assembly.json'
            manifest.write_text(json.dumps(dict(format=1, source=source, reference_frame=0,
                parts=[dict(name=name, model=f'{name}.iqm', source_points=f'{name}.npz', max_rms=0.01)
                       for name in ('frame', 'slide')])))
            base = root / 'base.pk3'
            with zipfile.ZipFile(base, 'w') as archive:
                archive.writestr(source + '.md3', b'fixture')
                archive.writestr(source + '.anim', 'dk3_animation 1\n2\n"idle" 0 1 10\n')
            original = [dict(name='body', points=np.stack((reference, reference))),
                        dict(name='hr_muzzle', points=marker)]
            with mock.patch.object(hd_weapon_assemble, 'read_md3', return_value=(original, None)):
                result = hd_weapon_assemble.assemble(manifest, base, root / 'view.iqm', root / 'report.json')
            self.assertEqual(result['frames'], 2)
            model = skeletal_iqm.read((root / 'view.iqm').read_bytes())
            self.assertEqual(model.names, ['frame', 'slide', 'hr_muzzle'])
            skinned = skeletal_iqm.skin(model)
            np.testing.assert_allclose(skinned[1, :3], moved, atol=2e-4)
            np.testing.assert_allclose(skinned[1, 3:], turned, atol=2e-4)
            anchored = json.loads(manifest.read_text())
            anchored['parts'][1].update(anchor_to='frame', anchor_point=[0., 0., 0.], max_anchor_shift=5.)
            manifest.write_text(json.dumps(anchored))
            with mock.patch.object(hd_weapon_assemble, 'read_md3', return_value=(original, None)):
                result = hd_weapon_assemble.assemble(manifest, base, root / 'anchored.iqm', root / 'anchored.json')
            self.assertGreater(result['parts'][1]['max_anchor_shift'], 0)
            anchored_skin = skeletal_iqm.skin(skeletal_iqm.read((root / 'anchored.iqm').read_bytes()))
            np.testing.assert_allclose(anchored_skin[1, 3], anchored_skin[1, 0], atol=2e-4)

    def test_authored_part_motion_uses_source_clip_frames(self):
        transforms = np.repeat(np.eye(4)[None], 3, axis=0)
        summary = hd_weapon_assemble.apply_authored_motion(transforms, [dict(
            clip='shoota', max_translation=.6, keys=[
                dict(frame=0), dict(frame=1, translation=[.5, 0., 0.]), dict(frame=2)])],
            {'shoota': dict(first=0, last=2)})
        self.assertEqual(summary[0]['last'], 2)
        np.testing.assert_allclose(transforms[:, 0, 3], [0., .5, 0.])
        with self.assertRaisesRegex(ValueError, 'start and end'):
            hd_weapon_assemble.apply_authored_motion(np.repeat(np.eye(4)[None], 3, axis=0), [dict(
                clip='shoota', max_translation=.6, keys=[
                    dict(frame=0), dict(frame=1, translation=[.5, 0., 0.]),
                    dict(frame=2, translation=[.5, 0., 0.])])], {'shoota': dict(first=0, last=2)})


if __name__ == '__main__':
    unittest.main()
