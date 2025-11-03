"""Command dispatcher for python.cli package."""

import argparse


def main() -> None:
    """Display available CLI entry points."""
    parser = argparse.ArgumentParser(
        prog="python -m python.cli",
        description="Command-line utilities for the RFID Streaming Ingest demo",
    )
    parser.add_argument(
        "command",
        nargs="?",
        help="Use one of: check, validate, deploy (coming soon)",
    )
    args, _ = parser.parse_known_args()

    if args.command == "check":
        from .check import main as check_main

        check_main()
    elif args.command == "validate":
        from .validate import main as validate_main

        validate_main()
    elif args.command is None:
        parser.print_help()
        print()
        print("Examples:")
        print("  python -m python.cli.check --auto-update")
        print("  python -m python.cli.validate quick")
    else:
        parser.error(f"Unknown command: {args.command}")


if __name__ == "__main__":
    main()


