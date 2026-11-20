"""Явный отказ reader независимо от режима python -O."""


def require(condition: bool, message: str) -> None:
    """Ошибки остаются явными при обычном Python и python -O."""
    if not condition:
        raise ValueError(message)
