#!/usr/bin/env python3
"""Public performance CLI/import; the single implementation lives in qa.performance."""
if __package__:
    from .common.launch import facade
else:
    from common.launch import facade

facade(__name__, "tools.qa.performance.performance_gate")
