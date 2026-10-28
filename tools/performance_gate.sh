#!/bin/zsh
set -e

repo_root="$(python3 "${0:A:h}/run.py" --root)"
cd "$repo_root"
# Фиксированное реальное окно и все повторы; ошибки данных не становятся измеренным0 FPS.
exec python3 tools/performance_gate.py "$@"
