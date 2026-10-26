#!/bin/zsh
# Публичный hook/CI вход; единственная реализация находится в quality.
exec zsh "${0:A:h}/quality/check_architecture.sh" "$@"
