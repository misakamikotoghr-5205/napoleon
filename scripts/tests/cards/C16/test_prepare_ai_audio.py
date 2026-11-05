#!/usr/bin/env python3
# #212-1：离线后处理的真实 ffmpeg 回归；合同 §12.1、W2_HANDOFF.md 10-18 决定。
# 所有 MP3、OGG 和清单均生成在 TemporaryDirectory 中，不写正式音频目录。
"""Run: python3 -m unittest discover -s scripts/tests/cards/C16 -p 'test_prepare_ai_audio.py' -v"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[4] / 'tools/audio/prepare_ai_audio.py'


def run(*args):
    return subprocess.run(args, capture_output=True, text=True, check=True)


class PrepareAudioTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dh-audio-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'input with spaces.mp3'
        run('ffmpeg', '-v', 'error', '-nostdin', '-f', 'lavfi', '-i',
            'sine=frequency=440:duration=3', '-af', 'volume=0.1',
            '-c:a', 'libmp3lame', str(self.source))
        self.manifest = self.root / 'data/cards/audio/music.json'
        self.manifest.parent.mkdir(parents=True)
        self.original = {
            '_meta': {'owner': 'C16', 'schema': 1},
            'cues': {'day': {'human': 'audio/cards/music/custom.ogg', 'custom': True},
                     'night': {'human': 'audio/cards/music/night.ogg'}},
        }
        self.manifest.write_text(json.dumps(self.original), encoding='utf-8')

    def command(self, kind='music', cue='day'):
        return [sys.executable, str(SCRIPT), str(self.source), '--root', str(self.root),
                '--kind', kind, '--id', cue, '--tool', 'test-fixture', '--model', 'sine',
                '--date', '2026-10-18', '--prompt-id', 'offline-test']

    def assert_audio(self, path):
        info = json.loads(run('ffprobe', '-v', 'error', '-show_streams',
                              '-show_format', '-of', 'json', str(path)).stdout)
        self.assertEqual(info['format']['format_name'], 'ogg')
        self.assertEqual(info['streams'][0]['codec_name'], 'vorbis')
        self.assertEqual(info['streams'][0]['sample_rate'], '48000')
        self.assertAlmostEqual(float(info['format']['duration']), 3.0, delta=0.05)
        # Independent remeasurement of the encoded file, not just recorded metadata.
        log = run('ffmpeg', '-hide_banner', '-nostdin', '-i', str(path), '-af',
                  'loudnorm=I=-16:TP=-2:LRA=11:print_format=json', '-f', 'null', '-').stderr
        measured, _ = json.JSONDecoder().raw_decode(log[log.rfind('{'):])
        self.assertAlmostEqual(float(measured['input_i']), -16.0, delta=0.5)
        self.assertLessEqual(float(measured['input_tp']), -1.0)
        print(f"MEASURED: {path.relative_to(self.root)} {measured['input_i']} LUFS, "
              f"{measured['input_tp']} dBTP", flush=True)

    def test_music_normalized_and_manifest_preserved(self):
        result = run(*self.command())
        print(result.stdout, end='', flush=True)
        output = self.root / 'audio/ai/music/day.ogg'
        self.assert_audio(output)
        doc = json.loads(self.manifest.read_text())
        self.assertEqual(doc['_meta'], self.original['_meta'])
        self.assertEqual(doc['cues']['night'], self.original['cues']['night'])
        entry = doc['cues']['day']
        self.assertEqual(entry['human'], 'audio/cards/music/custom.ogg')
        self.assertTrue(entry['custom'])
        self.assertEqual(entry['ai'], 'audio/ai/music/day.ogg')
        self.assertEqual(entry['_provenance'], 'ai:test-fixture:sine:2026-10-18:offline-test')
        self.assertEqual(entry['source_sha256'], hashlib.sha256(self.source.read_bytes()).hexdigest())
        before = output.read_bytes(), self.manifest.read_bytes()
        failed = subprocess.run(self.command(), capture_output=True, text=True)
        self.assertNotEqual(failed.returncode, 0)
        self.assertIn('output already exists', failed.stderr)
        self.assertEqual(before, (output.read_bytes(), self.manifest.read_bytes()))

    def test_sfx_normalized_from_louder_input(self):
        self.source.unlink()
        run('ffmpeg', '-v', 'error', '-nostdin', '-f', 'lavfi', '-i',
            'sine=frequency=880:duration=3', '-af', 'volume=4',
            '-c:a', 'libmp3lame', str(self.source))
        result = run(*self.command('sfx', 'coin'))
        print(result.stdout, end='', flush=True)
        self.assert_audio(self.root / 'audio/ai/sfx/coin.ogg')
        entry = json.loads((self.root / 'audio/ai/sfx/manifest.json').read_text())['cues']['coin']
        self.assertEqual(entry['ai'], 'audio/ai/sfx/coin.ogg')
        self.assertEqual(entry['_provenance'], 'ai:test-fixture:sine:2026-10-18:offline-test')
        self.assertEqual(json.loads(self.manifest.read_text()), self.original)
        self.assertFalse((self.root / 'audio/cards').exists())

    def test_bad_id_and_provenance_rejected_without_writes(self):
        for flag, value in [('--id', '../escape'), ('--tool', 'bad:tool'),
                            ('--date', '2026-02-30'), ('--prompt-id', '')]:
            command = self.command()
            command[command.index(flag) + 1] = value
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / 'audio').exists())
        self.assertEqual(json.loads(self.manifest.read_text()), self.original)

    def test_silent_input_does_not_publish_audio_or_provenance(self):
        self.source.unlink()
        run('ffmpeg', '-v', 'error', '-nostdin', '-f', 'lavfi', '-i',
            'anullsrc=r=48000:cl=mono', '-t', '1', '-c:a', 'libmp3lame', str(self.source))
        result = subprocess.run(self.command(), capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('no measurable loudness', result.stderr)
        self.assertFalse((self.root / 'audio').exists())
        self.assertEqual(json.loads(self.manifest.read_text()), self.original)

    def test_invalid_manifest_and_failed_decode_do_not_publish(self):
        for content in ('{', '{"cues": []}', '{"cues": {"day": "bad"}}'):
            self.manifest.write_text(content)
            result = subprocess.run(self.command(), capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(self.manifest.read_text(), content)
            self.assertFalse((self.root / 'audio').exists())
        self.manifest.write_text(json.dumps(self.original))
        self.source.write_text('not mp3')
        result = subprocess.run(self.command(), capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / 'audio').exists())
        self.assertEqual(json.loads(self.manifest.read_text()), self.original)


if __name__ == '__main__':
    unittest.main()
