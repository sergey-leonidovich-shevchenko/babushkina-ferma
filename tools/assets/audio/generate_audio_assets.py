#!/usr/bin/env python3
"""Воспроизводимо создаёт оригинальные камерные темы и мягкие эффекты фермы; требуется NumPy."""

from tools.assets.audio.audio_composer import compose_all
from tools.assets.audio.audio_sound_effects import generate_effects
from tools.assets.audio.audit_audio_assets import audit_library


# Собирает музыку, эффекты и измеримый отчёт; ни один игровой кадр не выполняет синтез.
def main() -> None:
    compose_all()
    generate_effects()
    audit_library()


if __name__ == "__main__":
    main()
