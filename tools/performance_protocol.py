#!/usr/bin/env python3
"""Public protocol import for frozen executable reports; one canonical implementation."""
if __package__:
    from .common.launch import facade
else:
    from common.launch import facade

facade(__name__, "tools.qa.performance.performance_protocol")
