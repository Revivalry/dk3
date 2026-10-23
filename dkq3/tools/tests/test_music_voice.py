"""Source audio aliases repair names without inventing or replacing recordings."""
import argparse
import unittest

import music_voice


class AudioAliasTest(unittest.TestCase):
    def test_alias_resolves_the_original_reference_to_supplied_recording(self):
        target, source = 'sounds/wrong/line.mp3', 'sounds/right/line.mp3'
        packaged, aliases = music_voice.alias_entries(
            {music_voice.package_name(source): b'supplied recording'}, [(target, source)])
        reference = music_voice.Reference('entity', 'map', 'mp3', target, (target,))
        self.assertEqual(music_voice.resolve(reference, set(packaged)),
                         (target, music_voice.package_name(target)))
        self.assertEqual(packaged[music_voice.package_name(target)], b'supplied recording')
        self.assertEqual(aliases, {target: source})

    def test_supplied_target_wins_and_absent_source_creates_nothing(self):
        target, source = 'sounds/line.mp3', 'sounds/other.mp3'
        original = {music_voice.package_name(target): b'owner override',
                    music_voice.package_name(source): b'other recording'}
        packaged, aliases = music_voice.alias_entries(original, [(target, source)])
        self.assertEqual(packaged, original)
        self.assertEqual(aliases, {})
        self.assertEqual(music_voice.alias_entries({}, [(target, source)]), ({}, {}))

    def test_alias_paths_cannot_escape_the_package(self):
        for value in ('../outside.mp3=sounds/line.mp3', 'sounds/line.mp3=/outside.mp3',
                      'not-an-alias', 'sounds/line.wav=sounds/other.mp3'):
            with self.subTest(value=value), self.assertRaises(argparse.ArgumentTypeError):
                music_voice.alias_rule(value)

    def test_unrelated_missing_audio_still_fails_validation(self):
        report = {'files': [], 'references': {'unresolved': ['music/absent.mp3'],
                  'expected_missing': ['music/known-missing.mp3']}, 'subtitles': {'orphans': []}}
        self.assertEqual(music_voice.failures(report, None), ['unresolved reference music/absent.mp3'])
