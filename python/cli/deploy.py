"""Deploy Snowflake objects for the RFID streaming ingest demo."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path
from typing import Iterable


SQL_SETUP_DIR = Path(__file__).resolve().parents[2] / "sql" / "01_setup"


def iter_setup_scripts() -> Iterable[Path]:
    """Yield SQL files in execution order (sorted by filename)."""
    if not SQL_SETUP_DIR.exists():
        raise FileNotFoundError(f"Setup directory not found: {SQL_SETUP_DIR}")

    for path in sorted(SQL_SETUP_DIR.glob("*.sql")):
        yield path


def run_sql(file_path: Path, connection: str | None = None, dry_run: bool = False) -> int:
    """Execute a SQL file using the Snowflake CLI."""
    cmd = ["snow", "sql", "-f", str(file_path)]
    if connection:
        cmd.extend(["--connection", connection])

    if dry_run:
        print("DRY RUN:", " ".join(cmd))
        return 0

    print(f"→ Executing {file_path.name}")
    result = subprocess.run(cmd, check=False)
    if result.returncode != 0:
        print(f"✗ Failed: {file_path.name}", file=sys.stderr)
    else:
        print(f"✓ Completed: {file_path.name}")
    print()
    return result.returncode


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Deploy Snowflake objects for the RFID streaming ingest demo",
    )
    parser.add_argument(
        "--connection",
        help="Snowflake CLI connection name (optional)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print commands without executing them",
    )

    args = parser.parse_args()

    failures = 0
    for script in iter_setup_scripts():
        rc = run_sql(script, connection=args.connection, dry_run=args.dry_run)
        if rc != 0:
            failures += 1
            break

    if failures:
        print("Deployment failed.", file=sys.stderr)
        sys.exit(1)

    if args.dry_run:
        print("Dry run complete. No scripts executed.")
    else:
        print("All setup scripts executed successfully.")


if __name__ == "__main__":
    main()


