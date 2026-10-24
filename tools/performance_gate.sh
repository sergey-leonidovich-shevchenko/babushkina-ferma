#!/bin/zsh
set -e

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
# Фиксированное реальное окно и все повторы; ошибки данных не становятся измеренным0 FPS.
exec python3 tools/performance_gate.py "$@"
