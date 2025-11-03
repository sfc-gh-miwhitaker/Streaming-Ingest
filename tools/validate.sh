#!/bin/bash
# Cross-platform wrapper for pipeline validator
# Works on macOS, Linux, and WSL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"
python -m python.cli.validate "$@"

