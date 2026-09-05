import json
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'plugins/skills/pull-request/pr-review-verify/scripts/verify.sh'


class VerificationCLI(unittest.TestCase):
    def test_missing_values_return_immediately(self):
        for args in (['--repo'], ['--commands-file'], []):
            result = subprocess.run(['bash', str(SCRIPT), *args], capture_output=True, text=True, timeout=3)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(json.loads(result.stdout)['status'], 'error')

    def test_stdout_is_json_and_failure_stops_remaining_commands(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            commands = root / 'commands.json'
            commands.write_text(json.dumps(['printf stdout; printf stderr >&2', 'exit 7', 'touch forbidden']))
            result = subprocess.run(['bash', str(SCRIPT), '--repo', str(root), '--commands-file', str(commands)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 3)
            value = json.loads(result.stdout)
            self.assertEqual(value['commands'], 2)
            self.assertEqual(value['results'][1]['exit_code'], 7)
            self.assertEqual(Path(value['results'][0]['log_path']).read_text(), 'stdoutstderr')
            self.assertFalse((root / 'forbidden').exists())
            commands.write_text(json.dumps(['printf success']))
            result = subprocess.run(['bash', str(SCRIPT), '--repo', str(root), '--commands-file', str(commands)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(json.loads(result.stdout)['status'], 'passed')


if __name__ == '__main__':
    unittest.main()
