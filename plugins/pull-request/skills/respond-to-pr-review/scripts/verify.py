#!/usr/bin/env python3
"""Run an explicitly trusted command list; stdout is exactly one result document."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


class Parser(argparse.ArgumentParser):
    def error(self, message):
        print(json.dumps({'status': 'error', 'error': message}))
        raise SystemExit(2)


def main():
    parser = Parser()
    parser.add_argument('--repo', required=True, type=Path)
    parser.add_argument('--commands-file', required=True, type=Path)
    args = parser.parse_args()
    try:
        repo = args.repo.resolve(strict=True)
        if not repo.is_dir():
            raise ValueError('--repo must be a directory')
        commands = json.loads(args.commands_file.read_text())
        if not isinstance(commands, list) or not commands or any(not isinstance(c, str) or not c.strip() or '\0' in c for c in commands):
            raise ValueError('commands must be a non-empty array of non-empty shell strings')
        logs = Path(tempfile.mkdtemp(prefix='pr-verification-'))
        results = []
        for index, command in enumerate(commands):
            log = logs / f'{index + 1}.log'
            with log.open('w') as stream:
                os.chmod(log, 0o600)
                completed = subprocess.run(['bash', '-c', command], cwd=repo, stdout=stream, stderr=subprocess.STDOUT)
            results.append({'command': command, 'exit_code': completed.returncode, 'log_path': str(log)})
            if completed.returncode:
                print(json.dumps({'status': 'failed', 'commands': len(results), 'results': results}, ensure_ascii=False))
                return 3
        print(json.dumps({'status': 'passed', 'commands': len(results), 'results': results}, ensure_ascii=False))
        return 0
    except (OSError, ValueError) as exc:
        print(json.dumps({'status': 'error', 'error': str(exc)}, ensure_ascii=False))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
