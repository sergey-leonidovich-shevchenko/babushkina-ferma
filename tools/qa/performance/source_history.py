"""Resolve the one moved surface-collector helper inside its recorded Git commit."""
from pathlib import Path
import re
import subprocess

from tools.common.git import git_environment
from tools.assets.contracts.source_paths import MOVED_PATHS, historical_source

LEGACY_HELPER = 'tools/perf_contract_collect.py'


def historical_helper(root: Path, commit: str) -> str:
    """Choose a unique old/new helper from the same commit; never fall back to a live file."""
    if not isinstance(commit, str) or not re.fullmatch('[0-9a-f]{40}', commit):
        raise ValueError('full historical helper commit required')
    aliases = [LEGACY_HELPER, MOVED_PATHS[LEGACY_HELPER]]
    names = subprocess.check_output(['git', '--no-replace-objects', '-C', str(root),
        'ls-tree', '-r', '--name-only', '-z', commit, '--', *aliases], env=git_environment())
    available = set(filter(None, names.decode().split('\0')))
    return historical_source(available, LEGACY_HELPER)
