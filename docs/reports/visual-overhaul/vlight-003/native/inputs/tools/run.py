#!/usr/bin/env python3
"""Публичный запуск: python3 /путь/к/tools/run.py planning.project_backlog [аргументы]."""
if __package__:
    from .common.launch import main
else:
    from common.launch import main


if __name__ == "__main__":
    main()
