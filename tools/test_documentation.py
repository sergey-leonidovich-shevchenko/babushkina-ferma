#!/usr/bin/env python3
"""Проверяет границы обхода документации после добавления веб-зависимостей."""

from pathlib import Path
from tempfile import TemporaryDirectory

from check_documentation import REQUIRED_DOCUMENTS, markdown_files, validate


def test_project_links_stay_checked() -> None:
    """Сценарий: свои ссылки wiki повреждены, ссылки внешнего npm-пакета не существуют.
    Исходное состояние: обязательные документы, npm-зависимость и готовая сборка.
    Ожидаемый результат: чужие README исключены, свой отсутствующий путь блокирует gate.
    """
    with TemporaryDirectory(prefix="farm-wiki-documents-") as temporary:
        root = Path(temporary)
        for name in REQUIRED_DOCUMENTS:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("# Документ\n", encoding="utf-8")
        own = root / "wiki" / "README.md"
        own.parent.mkdir(parents=True)
        own.write_text("[Своя статья](missing.md)\n", encoding="utf-8")
        for folder in ["node_modules/package", "dist", ".cache/build", ".runtime/node"]:
            external = root / "wiki" / folder / "README.md"
            external.parent.mkdir(parents=True, exist_ok=True)
            external.write_text("[Чужая ссылка](not-in-package.md)\n", encoding="utf-8")
        documents = markdown_files(root)
        assert own in documents
        assert not any(path.parts[-2] in {"package", "dist", "build", "node"} for path in documents)
        errors = validate(root)
        assert len(errors) == 1 and "wiki/README.md" in errors[0] and "missing.md" in errors[0]
        own.write_text("[Игра](../README.md)\n", encoding="utf-8")
        assert not validate(root)
        (root / "TESTING.md").unlink()
        assert any("TESTING.md" in error for error in validate(root))


if __name__ == "__main__":
    test_project_links_stay_checked()
    print("DOCUMENTATION TEST: свои ссылки проверяются, зависимости и сборки исключены")
