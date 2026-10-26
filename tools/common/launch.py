"""Один запуск Python-модулей tools с прежними argv, stdout и кодом завершения."""
import argparse
import importlib
from pathlib import Path
import re
import runpy
import sys

from common.paths import project_root


def module_name(command: str, root: Path) -> str:
    """Разрешает только собственный исходник внутри tools, без traversal и внешних пакетов."""
    if not re.fullmatch(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*", command):
        raise ValueError(f"Некорректная команда tools: {command}")
    source = root / "tools" / Path(*command.split("."))
    source = source.with_suffix(".py").resolve()
    if not source.is_relative_to(root / "tools") or not source.is_file():
        raise ValueError(f"Нет команды tools: {command}")
    return "tools." + command


def prepare_imports(root: Path) -> None:
    """Добавляет только пути выбранного проекта; legacy tools нужен до REFACTOR-03."""
    for path in (root / "tools", root):
        value = str(path)
        sys.path[:] = [entry for entry in sys.path if entry != value]
        sys.path.insert(0, value)


def facade(name: str, target: str) -> None:
    """CLI делегирует один раз, import возвращает ту же реализацию с её mutable globals."""
    prepare_imports(project_root())
    if name == "__main__":
        runpy.run_module(target, run_name="__main__", alter_sys=True)
    else:
        sys.modules[name] = importlib.import_module(target)


def main() -> None:
    """Отделяет аргументы launcher от аргументов выбранной команды без смены cwd."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", action="store_true", help="показать корень проекта")
    parser.add_argument("command", nargs="?")
    parser.add_argument("arguments", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    root = project_root()
    if args.root and args.command is None:
        print(root)
        return
    if args.root or args.command is None:
        parser.error("нужна команда tools либо отдельный --root")
    try:
        target = module_name(args.command, root)
    except ValueError as error:
        parser.error(str(error))
    prepare_imports(root)
    sys.argv = [str(root / "tools" / Path(*args.command.split(".")).with_suffix(".py")),
                *args.arguments]
    runpy.run_module(target, run_name="__main__", alter_sys=True)
