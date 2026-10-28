#!/bin/zsh
# Public compatibility entry; forward argv and exit exactly once.
exec zsh "${0:A:h}/qa/performance/performance_gate.sh" "$@"
