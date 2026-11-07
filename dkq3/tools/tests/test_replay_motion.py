# SPDX-License-Identifier: GPL-2.0-or-later
"""Turn evidence distinguishes explicit world cuts from ordinary steering."""
from pathlib import Path
import tempfile
import unittest

from evaluate_replay_motion import evaluate


class ReplayMotionTest(unittest.TestCase):
    def measure(self, middle, final_yaw):
        with tempfile.TemporaryDirectory() as folder:
            record, render = Path(folder) / 'record.log', Path(folder) / 'render.log'
            record.write_text(
                'dk3 coop motion: now=1000 pos=0,0,0 angles=0,0\n'
                'dk3 coop motion: now=1050 pos=8,0,0 angles=0,18\n' + middle +
                'dk3 coop motion: now=1100 pos=8,0,0 angles=0,90\n'
                f'dk3 coop motion: now=1150 pos=16,0,0 angles=0,{final_yaw}\n')
            render.write_text('')
            return evaluate(record, render)

    def test_landing_cut_does_not_hide_subsequent_excessive_steering(self):
        result = self.measure('dk3 world transfer: map=next world=7\n', 110)
        self.assertEqual(result['command_explicit_cuts'], 1)
        self.assertEqual(result['command_yaw_rate_max'], 400)

    def test_same_position_turn_without_explicit_cut_remains_a_failure(self):
        result = self.measure('', 108)
        self.assertEqual(result['command_explicit_cuts'], 0)
        self.assertEqual(result['command_yaw_rate_max'], 1440)

    def test_writing_an_ordinary_save_does_not_cut_steering_evidence(self):
        result = self.measure('dk3 checkpoint: ready\n', 108)
        self.assertEqual(result['command_explicit_cuts'], 0)
        self.assertEqual(result['command_yaw_rate_max'], 1440)

    def test_restored_camera_and_continuous_steering_have_separate_origins(self):
        result = self.measure('dk3 zig client: restoration applied\n', 108)
        self.assertEqual(result['command_turn_samples'], 2)
        self.assertEqual(result['command_yaw_rate_max'], 360)
