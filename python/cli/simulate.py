"""Convenience wrapper for launching the RFID simulator."""

from __future__ import annotations

import sys
from typing import List

from ..simulator import simulator


def main(argv: List[str] | None = None) -> None:
    """Delegates to the simulator module."""
    if argv is None:
        argv = sys.argv[1:]

    # simulator.main() reads arguments from sys.argv, so we temporarily
    # replace them to forward any CLI options passed to this wrapper.
    original_argv = sys.argv
    try:
        sys.argv = [original_argv[0], *argv]
        simulator.main()
    finally:
        sys.argv = original_argv


if __name__ == "__main__":
    main()


