"""Проверки окружения, деревни и объектов первой локации."""

from importlib import import_module
from types import ModuleType

from tools.common.launch import COMMAND_ALIASES


def __getattr__(name: str) -> ModuleType:
    """Поддерживает прежние from-import для перемещённых команд World QA."""
    target = COMMAND_ALIASES.get(f"qa.world.{name}")
    if target is None:
        raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
    return import_module(f"tools.{target}")
