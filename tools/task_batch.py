#!/usr/bin/env python3
"""Публичный совместимый вход; единственная реализация в planning."""
if __package__:
    from .common.launch import facade
else:
    from common.launch import facade

facade(__name__, "tools.planning.task_batch")
