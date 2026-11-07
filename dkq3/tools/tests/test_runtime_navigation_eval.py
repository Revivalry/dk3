# SPDX-License-Identifier: GPL-2.0-or-later
"""The navigation score cannot improve by dropping cases or hiding regressions."""
import copy
import unittest

from runtime_navigation_eval import compare


def report(failed):
    rows = [dict(case=i, controller=controller, classname='fixture', reached=i not in failed,
                 hazardous=False, distance=100 if i in failed else 0, time_ms=5000)
            for controller in ('actor', 'follower') for i in range(8)]
    return dict(map='fixture', status='reported', cases_sha256='fixed-inputs', results=rows)


class NavigationScoring(unittest.TestCase):
    def setUp(self):
        self.baseline = dict(maps=[report({0, 1, 2, 3})])

    def test_exact_target_keeps_all_cases_and_both_controllers(self):
        result = compare(self.baseline, [report({0})])
        self.assertTrue(result['met'])
        self.assertEqual(result['controllers']['actor']['relative_failure_reduction'], .75)
        self.assertEqual(result['controllers']['follower']['cases'], 8)

    def test_dropping_a_map_is_failure_not_an_improvement(self):
        result = compare(self.baseline, [])
        self.assertFalse(result['valid'])
        self.assertEqual(result['controllers']['actor']['candidate_failed'], 8)

    def test_missing_result_cannot_shrink_the_divisor(self):
        row = report(set())
        row['results'].pop()
        result = compare(self.baseline, [row])
        self.assertFalse(result['met'])
        self.assertFalse(result['valid'])

    def test_swapping_an_old_success_for_a_new_failure_is_a_regression(self):
        result = compare(self.baseline, [report({7})])
        self.assertEqual(result['controllers']['actor']['relative_failure_reduction'], .75)
        self.assertFalse(result['met'])
        self.assertEqual(result['controllers']['actor']['regressions'], 1)

    def test_new_hazard_fails_even_with_no_remaining_stalls(self):
        row = report(set())
        row['results'][0]['hazardous'] = True
        self.assertFalse(compare(self.baseline, [row])['met'])

    def test_zero_baseline_failures_requires_preserving_zero(self):
        baseline = copy.deepcopy(self.baseline)
        baseline['maps'] = [report(set())]
        result = compare(baseline, [report(set())])
        self.assertTrue(result['met'])
        self.assertIsNone(result['controllers']['actor']['relative_failure_reduction'])
        self.assertFalse(compare(baseline, [report({0})])['met'])
