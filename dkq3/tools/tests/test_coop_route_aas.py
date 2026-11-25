# SPDX-License-Identifier: GPL-2.0-or-later
"""Offline area-graph search used for co-op route authoring (synthetic graph)."""
import unittest

import coop_route_aas as aas


def graph(areas, links):
    """Areas as (mins, maxs) boxes; links as (from, to, kind, time)."""
    result = object.__new__(aas.Graph)
    result.areas = [(0, 0, 0) + tuple(lo) + tuple(hi) + tuple((a + b) / 2 for a, b in zip(lo, hi)) for lo, hi in [((0, 0, 0), (0, 0, 0))] + areas]
    result.reach, result.settings = [], [(0,) * 7]
    for area in range(1, len(result.areas)):
        own = [link for link in links if link[0] == area]
        result.settings.append((0, 1, 0, 0, 0, len(own), len(result.reach)))
        for _, to, kind, time in own:
            result.reach.append((to, 0, 0, 0, 0, 0, 0, 0, 0, kind, time))
    return result


class CoopRouteAasTest(unittest.TestCase):
    def test_invalid_area_links_cannot_join_disconnected_floors(self):
        boxes = [((0, 0, z), (64, 64, z + 8)) for z in (0, 100, 200)]
        g = graph(boxes, [(1, 0, 6, 1), (1, 99, 6, 1), (2, 3, 2, 10)])
        # Placeholder settings can point into the ordinary reachability list;
        # they must never be entered through an invalid ladder destination.
        g.settings[0] = (0, 0, 0, 0, 0, 1, 2)
        self.assertEqual(set(g.search(1)), {1})
        self.assertEqual(set(g.search(3, reverse=True)), {2, 3})

    def test_standing_keeps_a_thin_upper_floor_above_a_connected_lower_room(self):
        g = graph([((0, 0, 528), (64, 64, 531)),
                   ((0, 0, 344), (64, 64, 376))],
                  [(1, 1, 2, 1), (2, 2, 2, 1)])
        g.area = lambda p: 1 if 528 < p[2] <= 531 else 2 if 344 <= p[2] < 528 else 0
        self.assertEqual(g.standing((32, 32, 528)), 1)

    def test_search_follows_player_travel_and_avoids_closed_doors(self):
        boxes = [((0, 0, 0), (64, 64, 8)), ((64, 0, 0), (128, 64, 8)), ((128, 0, 0), (192, 64, 8)), ((0, 64, 0), (192, 128, 8))]
        # 1 -> 2 -> 3 directly, or the long way round through 4; 1 -> 3 by rocket jump is not for players.
        links = [(1, 2, 2, 10), (2, 3, 2, 10), (1, 4, 2, 30), (4, 3, 8, 30), (1, 3, 12, 1)]
        g = graph(boxes, links)
        best = g.search(1)
        self.assertEqual(best[3][1], 2)
        self.assertEqual(best[3][0], 20)
        door = g.blocked([((70, 10, 0), (100, 50, 8))])
        self.assertEqual(door, {2})
        detour = g.search(1, avoid=door)
        self.assertEqual(detour[3][1], 4)
        self.assertEqual(detour[3][2][2], 8)  # the last leg is a swim
        self.assertIn(1, g.search(3, reverse=True))


if __name__ == '__main__':
    unittest.main()
