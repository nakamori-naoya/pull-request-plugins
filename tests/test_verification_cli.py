import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SKILLS = Path(__file__).resolve().parents[1] / 'plugins/pull-request/skills'
ENTRIES = ('open-pull-request', 'resolve-pr-conflicts', 'respond-to-pr-review')


def git(repo, *args):
    subprocess.run(['git', '-C', str(repo), '-c', 'user.email=t@example.invalid', '-c', 'user.name=t', *args], check=True, capture_output=True)


def configured_repo(root, entry, commands):
    repo = root / entry
    (repo / '.harness-plugins').mkdir(parents=True)
    git(repo, 'init', '-q', '-b', 'main')
    config = repo / '.harness-plugins' / f'{entry}.config.yml'
    shutil.copy(SKILLS / entry / 'assets' / f'{entry}.config.example.yml', config)
    subprocess.run(['yq', '-i', f'.verification.commands = {json.dumps(commands)}', str(config)], check=True)
    return repo


def verify(entry, *args):
    return subprocess.run(['python3', str(SKILLS / entry / 'scripts/verify.py'), *args], capture_output=True, text=True, timeout=30)


class VerificationCLI(unittest.TestCase):
    def test_missing_repo_is_an_argument_error(self):
        for entry in ENTRIES:
            result = verify(entry)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(json.loads(result.stdout)['reason'], 'arguments')

    def test_commands_come_from_the_entry_config_and_failure_stops_the_rest(self):
        for entry in ENTRIES:
            with tempfile.TemporaryDirectory() as temporary:
                repo = configured_repo(Path(temporary), entry, ['printf stdout; printf stderr >&2', 'exit 7', 'touch forbidden'])
                result = verify(entry, '--repo', str(repo))
                self.assertEqual(result.returncode, 3, entry)
                value = json.loads(result.stdout)
                self.assertEqual(value['status'], 'failed')
                self.assertEqual(value['commands'], 2)
                self.assertEqual(value['results'][1]['exit_code'], 7)
                self.assertEqual(Path(value['results'][0]['log_path']).read_text(), 'stdoutstderr')
                self.assertFalse((repo / 'forbidden').exists())

    def test_all_commands_pass_and_empty_list_runs_nothing(self):
        for entry in ENTRIES:
            with tempfile.TemporaryDirectory() as temporary:
                repo = configured_repo(Path(temporary), entry, ['printf success', 'test -d .harness-plugins'])
                result = verify(entry, '--repo', str(repo / '.harness-plugins'))
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertEqual(json.loads(result.stdout)['commands'], 2)
            with tempfile.TemporaryDirectory() as temporary:
                repo = configured_repo(Path(temporary), entry, [])
                result = verify(entry, '--repo', str(repo))
                self.assertEqual((result.returncode, json.loads(result.stdout)['commands']), (0, 0))

    def test_missing_config_is_reported_like_config_py(self):
        for entry in ENTRIES:
            with tempfile.TemporaryDirectory() as temporary:
                repo = Path(temporary)
                git(repo, 'init', '-q', '-b', 'main')
                result = verify(entry, '--repo', str(repo))
                self.assertEqual(result.returncode, 2)
                self.assertEqual(json.loads(result.stdout)['reason'], 'policy_missing')


class ConflictDetectionCLI(unittest.TestCase):
    def detect(self, entry, repo, base, head):
        result = subprocess.run(['python3', str(SKILLS / entry / 'scripts/conflicts.py'), '--repo', str(repo), '--base', base, '--head', head], capture_output=True, text=True, timeout=30)
        return result.returncode, json.loads(result.stdout)

    def test_merge_tree_and_unmerged_index(self):
        for entry in ('open-pull-request', 'resolve-pr-conflicts'):
            with tempfile.TemporaryDirectory() as temporary:
                repo = Path(temporary)
                git(repo, 'init', '-q', '-b', 'main')
                (repo / 'f').write_text('a\n'); git(repo, 'add', 'f'); git(repo, 'commit', '-qm', 'init')
                git(repo, 'checkout', '-q', '-b', 'agent/x'); (repo / 'f').write_text('head\n'); git(repo, 'commit', '-qam', 'head')
                git(repo, 'checkout', '-q', 'main'); (repo / 'f').write_text('base\n'); git(repo, 'commit', '-qam', 'base')
                (repo / 'g').write_text('g\n'); git(repo, 'add', 'g'); git(repo, 'commit', '-qm', 'unrelated')
                before = subprocess.run(['git', '-C', str(repo), 'status', '--porcelain'], capture_output=True, text=True).stdout
                code, value = self.detect(entry, repo, 'main', 'agent/x')
                self.assertEqual((code, value['has_conflicts'], value['files'], value['method']), (0, True, ['f'], 'merge_tree'))
                self.assertEqual(subprocess.run(['git', '-C', str(repo), 'status', '--porcelain'], capture_output=True, text=True).stdout, before)
                code, value = self.detect(entry, repo, 'main', 'main~1')
                self.assertEqual((code, value['has_conflicts'], value['files']), (0, False, []))
                subprocess.run(['git', '-C', str(repo), '-c', 'user.email=t@example.invalid', '-c', 'user.name=t', 'merge', '-q', 'agent/x'], capture_output=True)
                code, value = self.detect(entry, repo, 'main', 'agent/x')
                self.assertEqual((code, value['has_conflicts'], value['files'], value['method']), (0, True, ['f'], 'unmerged_index'))
                code, value = self.detect(entry, repo, 'no-such-branch', 'agent/x')
                self.assertEqual((code, value['reason']), (2, 'unknown_ref'))


if __name__ == '__main__':
    unittest.main()
