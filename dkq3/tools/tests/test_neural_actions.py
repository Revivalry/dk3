# SPDX-License-Identifier: GPL-2.0-or-later
import unittest
import numpy as np
import skeletal_iqm as sk
import neural_actions as actions
from neural_assets import joint_violations
from neural_monster_skeleton import LANDMARKS, skeleton


def body(slug='skinnyworker', scale=1.5, offset=(40., -10, 30)):
    """A packaged-style humanoid: monster-sized bind and a mesh spanning the 56-unit body."""
    names, parents, bind = skeleton(LANDMARKS[slug])
    channels = sk.channels(bind, parents)
    channels[:, :3] *= scale
    channels[0, :3] += offset
    points = np.array([[0., 0, -24], [0, 0, 32], [0, 5, 0]])*scale+offset
    arrays = {0: points, 1: np.zeros((3, 2)), 2: np.tile([0., 0, 1], (3, 1)),
              4: np.zeros((3, 4), int), 5: np.tile([255, 0, 0, 0], (3, 1))}
    model = sk.Model(arrays, [('body', 'body', 0, 3, 0, 1)], np.array([[0, 1, 2]]), names, parents, channels, channels[None])
    return model, actions.Body(model)


def world(b, channels):
    return sk.matrices(b.world(channels), b.model.parents)[..., :3, 3]


class ActionTest(unittest.TestCase):
    def test_keys_ease_between_poses_and_loops_wrap_to_the_first(self):
        keys = [(0, dict(root=(0., 0, 0))), (4, dict(root=(4., 0, 0)))]
        self.assertAlmostEqual(actions.sample(keys, 2, 8, False)['root'][0], 2)
        self.assertLess(actions.sample(keys, 1, 8, False)['root'][0], 1)       # eased, not linear
        self.assertAlmostEqual(actions.sample(keys, 6, 8, True)['root'][0], 2)   # back toward key 0
        self.assertAlmostEqual(actions.sample(keys, 9, 8, False)['root'][0], 4)  # holds the last key

    def test_the_authoring_frame_recovers_the_normalized_body(self):
        model, b = body()
        self.assertAlmostEqual(b.scale, 1.5)
        np.testing.assert_allclose(b.world(b.bind[None])[0], model.bind, atol=1e-9)
        np.testing.assert_allclose(b.absolute[b.index['foot_l'], 2, 3], LANDMARKS['skinnyworker']['leg'][2][2])

    def test_kneeling_cower_plants_its_shins_and_covers_its_head(self):
        model, b = body()
        frames = actions.perform(b, actions.COWER_KNEEL, 20, 'relaxed')
        self.assertEqual(joint_violations(model, b.world(frames)), {})
        points = world(b, frames)
        floor = -24*b.scale+b.offset[2]
        index = b.index
        for side in 'lr':
            # Knee and ankle down on the floor; the hand rests above the head joint.
            self.assertLess(points[:, index['shin_'+side], 2].max()-floor, 4*b.scale)
            self.assertLess(points[:, index['foot_'+side], 2].max()-floor, 4*b.scale)
            self.assertTrue(np.all(points[:, index['hand_'+side], 2] > points[:, index['head'], 2]))
        # The loop's last frame leads smoothly back into its first.
        step = np.abs(points[1:]-points[:-1]).max()
        self.assertLess(np.abs(points[0]-points[-1]).max(), 2*step+1e-6)

    def test_an_aim_reaches_forward_at_shoulder_height_and_kicks_on_the_shot(self):
        model, b = body('mishimaguard')
        action = actions.ENEMIES['mishimaguard']['actions']['ataka']
        frames = actions.perform(b, action, 6, 'pistol')
        points = world(b, frames)
        hand, shoulder = points[:, b.index['hand_r']], points[:, b.index['upperarm_r']]
        reach = (hand-shoulder)[:, 0]/b.scale
        self.assertGreater(reach[0], 15)
        self.assertLess(reach[1], reach[0])                 # recoil on the shot frame
        np.testing.assert_allclose(points[-1], points[4], atol=1e-6)   # settles aimed for the hold
        self.assertLess(abs(hand[0, 2]-shoulder[0, 2])/b.scale, 2)

    def test_a_held_item_points_along_its_aim_through_a_sweep(self):
        model, b = body('cryotech')
        axis = np.array(actions._SPRAYER[1])
        frames = actions.perform(b, actions.ENEMIES['cryotech']['actions']['bambb'], 29, 'rifle')
        rotations = sk.matrices(b.world(frames), model.parents)[:, b.index['fingers_r'], :3, :3]
        barrel = rotations @ axis
        self.assertTrue(np.all(np.abs(barrel[:, 2]) < .2))      # level throughout
        yaw = np.degrees(np.arctan2(barrel[:, 1], barrel[:, 0]))
        self.assertLess(yaw[8], -15)                             # starts the spray to the right
        self.assertGreater(yaw[22], 15)                          # and ends it to the left

    def test_every_authored_table_names_known_controls(self):
        for slug, spec in actions.ENEMIES.items():
            for name, action in spec['actions'].items():
                for _, key in action['keys']:
                    self.assertLessEqual(set(key), set(actions.CONTROLS), f'{slug} {name}')
