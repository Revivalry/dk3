# SPDX-License-Identifier: GPL-2.0-or-later
"""Evidence parsing and launch settings of the co-op bot runner (no engine run)."""
from pathlib import Path
from types import SimpleNamespace
import unittest
import tempfile
from unittest.mock import patch

import runtime_coop_bot as runner

LOG = '''\
dk3 coop: event=loaded script=coop/campaign.lua skill=10 deaths_allowed=0 deaths_used=0
]dk3 coop: t=300 event=level detail="map=intro visit=1 resumed=0 from=-"
dk3 coop: t=300 event=action detail="op=cinematic target=- map= timeout=900"
dk3 coop: t=567200 event=done op=cinematic ms=566900 detail="finished"
dk3 coop: t=568000 event=level detail="map=e1m1a visit=1 resumed=0 from=intro"
dk3 coop: t=600000 event=status map=e1m1a op=exit mode=normal hp=100 armor=0 weapon=2 ammo=37
dk3 coop: t=610000 event=death detail="deaths=1 level_deaths=1 allowed=4/0 op=kill pos=1,2,3"
dk3 coop: t=620000 event=failed op=exit ms=8100 detail="no progress for 25 s at 1,2,3"
dk3 coop: t=620000 event=fail map=e1m1a reason="coop/episode1.lua:9: exit: no progress"
'''


class CoopBotRunnerTest(unittest.TestCase):
    def test_cleanup_reaps_only_the_reported_job_with_its_unique_profile(self):
        with tempfile.TemporaryDirectory() as folder:
            proc = Path(folder)
            leader = proc / '123'
            leader.mkdir()
            command = leader / 'cmdline'
            log = 'dkguard: started pid=123 pgid=123\n'
            with patch.object(runner.os, 'killpg') as kill:
                command.write_bytes(b'dk3ded\0+set\0fs_homepath\0/tmp/this-replay\0')
                runner.reap_isolated_job(log, Path('/tmp/this-replay'), proc)
                kill.assert_called_once_with(123, runner.signal.SIGKILL)
                kill.reset_mock()
                command.write_bytes(b'dk3ded\0+set\0fs_homepath\0/tmp/another-game\0')
                runner.reap_isolated_job(log, Path('/tmp/this-replay'), proc)
                command.unlink()
                runner.reap_isolated_job(log, Path('/tmp/this-replay'), proc)
                kill.assert_not_called()

    def test_events_parse_quoted_fields_and_tolerate_console_prefixes(self):
        events = [event for event in map(runner.parse_event, LOG.splitlines()) if event]
        self.assertEqual(len(events), 9)
        level = events[1]
        self.assertEqual(level['event'], 'level')
        self.assertEqual(level['detail'], 'map=intro visit=1 resumed=0 from=-')
        self.assertEqual(events[-1]['reason'], 'coop/episode1.lua:9: exit: no progress')
        self.assertIsNone(runner.parse_event('ordinary engine output'))

    def test_summary_reports_route_outcome_and_speed(self):
        events = [event for event in map(runner.parse_event, LOG.splitlines()) if event]
        result = runner.summarise(events, wall_seconds=31.0, exit_code=0)
        self.assertEqual(result['outcome'], 'failed')
        self.assertEqual(result['maps'], ['intro', 'e1m1a'])
        self.assertEqual(result['actions_started'], 1)
        self.assertEqual(result['actions_done'], 1)
        self.assertEqual(len(result['deaths']), 1)
        self.assertEqual(result['game_ms'], 620000)
        self.assertEqual(result['speedup'], 20.0)
        self.assertEqual(result['last_status']['ammo'], '37')

    def test_finish_without_failure_is_the_only_success(self):
        finished = [{'event': 'level', 'detail': 'map=end visit=1', 't': '1'}, {'event': 'finish', 't': '2'}]
        self.assertEqual(runner.summarise(finished)['outcome'], 'finished')
        self.assertEqual(runner.summarise(finished + [{'event': 'fail'}])['outcome'], 'failed')
        self.assertEqual(runner.summarise(finished[:1])['outcome'], 'incomplete')

    def test_settings_run_the_real_campaign_fast_and_isolated(self):
        home = Path('/tmp/profile')
        args = SimpleNamespace(assets=Path('/assets'), skill=3, cinematics=1, jobs=4, script='campaign.lua',
                               bot_skill=10, developer=0, realtime=False, load=None, stage=None, map='intro', status_ms=1000,
                               resident_worlds=False)
        values = runner.settings(args, home)
        self.assertEqual(values['g_gametype'], '2')
        self.assertEqual(values['dk3_runtime_probe'], '2')
        self.assertEqual((values['fixedtime'], values['timedemo'], values['sv_fps']), ('50', '1', '20'))
        self.assertEqual(values['fs_homepath'], str(home))
        self.assertEqual(values['dk3_coop_script'], 'coop/campaign.lua')
        self.assertEqual(values['g_residentWorlds'], '0')
        self.assertNotIn('dk3_coop_load', values)
        args.realtime, args.load, args.stage, args.map = True, Path('/saves/x.sav'), 5, 'e1m1b'
        args.resident_worlds = True
        values = runner.settings(args, home)
        self.assertNotIn('fixedtime', values)
        self.assertEqual(values['dk3_coop_load'], 'coop-resume')
        self.assertEqual(values['dk3_coop_checkpoint'], 'e1m1b 5')
        self.assertEqual(values['g_residentWorlds'], '1')

    def test_resumed_tracing_cannot_drop_the_startup_map(self):
        with tempfile.TemporaryDirectory() as folder:
            home = Path(folder)
            (home / 'dk3').mkdir()
            args = SimpleNamespace(assets=Path('/assets'), skill=1, cinematics=1, jobs=4,
                script='campaign.lua', bot_skill=10, developer=2, realtime=False,
                load=Path('/save.sav'), stage=1, map='e2m5e', status_ms=1000,
                resident_worlds=True, motion_trace=True, guard=Path('/dkguard'),
                mem='8G', timeout=300, engine=Path('/engine'))
            values = runner.settings(args, home)
            values.update({f'future_option_{i}': str(i) for i in range(64)})
            command = runner.launch_command(args, home, values)
            self.assertEqual(command[-2:], ['+map', 'e2m5e'])
            self.assertLess(command.count('+set') + 2, 31)
            config = (home / 'dk3/autoexec.cfg').read_text()
            self.assertIn('set dk3_coop_resume_checkpoint "e2m5e 1"\n', config)
            self.assertIn('set dk3_coop_motion_trace "1"\n', config)
            self.assertIn('set future_option_63 "63"\n', config)


if __name__ == '__main__':
    unittest.main()
