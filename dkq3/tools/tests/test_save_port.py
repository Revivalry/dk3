# SPDX-License-Identifier: GPL-2.0-or-later
"""save_port: the engine's map checksum and the DK3SAVE record codec."""
import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import save_port  # noqa: E402


class Checksum(unittest.TestCase):
    def test_md4_matches_the_rfc_vectors(self):
        for message, digest in ((b'', '31d6cfe0d16ae931b73c59d7e0c089c0'), (b'abc', 'a448017aaf21d8525fc10ae87aa6729d'),
                                (b'message digest', 'd9130a8164549fe818874806e1c7014b')):
            self.assertEqual(struct.pack('<4I', *save_port.md4_words(message)).hex(), digest)

    def test_the_map_checksum_folds_the_digest(self):
        a, b, c, d = save_port.md4_words(b'abc')
        self.assertEqual(save_port.map_checksum(b'abc'), a ^ b ^ c ^ d)

    def test_brush_sides_compare_by_plane_only(self):
        old = struct.pack('<4i', 7, 1, 9, 2)
        new = struct.pack('<4i', 7, 3, 9, 4)
        moved = struct.pack('<4i', 8, 1, 9, 2)
        self.assertEqual(save_port.structural('brushsides', old), save_port.structural('brushsides', new))
        self.assertNotEqual(save_port.structural('brushsides', old), save_port.structural('brushsides', moved))


class Records(unittest.TestCase):
    def test_a_save_reads_back_after_rewriting(self):
        records = [('campaign', 0, [['map', 3, b'e1m1a'], ['state', 4, b'{"asset_crc":1}']]),
                   ('native_entity', 7, [['health', 1, struct.pack('<i', 100)]])]
        data = save_port.write_records(records)
        self.assertEqual(data[:8], b'DK3SAVE\0')
        self.assertEqual(save_port.read_records(data), [(name, ident, [list(f) for f in fields]) for name, ident, fields in records])

    def test_a_damaged_save_is_refused(self):
        data = bytearray(save_port.write_records([('campaign', 0, [['map', 3, b'e1m1a']])]))
        data[-1] ^= 1
        with self.assertRaises(ValueError):
            save_port.read_records(bytes(data))


if __name__ == '__main__':
    unittest.main()
