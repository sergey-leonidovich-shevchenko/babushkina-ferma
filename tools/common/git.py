"""Изолирует Git-команды, явно адресованные отдельному репозиторию."""
from __future__ import annotations

import os
from collections.abc import Mapping


def git_environment(environment: Mapping[str, str] | None = None) -> dict[str, str]:
    """Убирает hook/index/config overrides, не изменяя окружение родительского процесса."""
    source = os.environ if environment is None else environment
    return {name: value for name, value in source.items() if not name.startswith("GIT_")}
