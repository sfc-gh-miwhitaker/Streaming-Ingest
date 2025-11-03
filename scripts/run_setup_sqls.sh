#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Utility: Run numbered SQL setup scripts using SnowSQL profile configuration.
# -----------------------------------------------------------------------------
# Description:
#   Executes every SQL file in `sql/setup/` whose name begins with two digits
#   (e.g., 01_database_and_schemas.sql) in ascending order. The script reads
#   connection defaults from ~/.snowflake/config.toml (SnowSQL profile). You can
#   override the profile with the SNOWFLAKE_PROFILE environment variable.
#
# Usage:
#   ./scripts/run_setup_sqls.sh              # uses default profile
#   SNOWFLAKE_PROFILE=dev ./scripts/run_setup_sqls.sh
#
# Requirements:
#   - SnowSQL (`snowsql`) or the Snowflake CLI (`snow`) installed.
#   - ~/.snowflake/config.toml contains the target profile with credentials.
#   - Scripts reside in project root under sql/setup/ and follow the numbering
#     convention (01_, 02_, ...).
#
# Exit codes:
#   0  success
#   1  missing snowsql or config
#   2  SQL execution failure
# -----------------------------------------------------------------------------

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP_DIR="${BASE_DIR}/sql/setup"
PROFILE="${SNOWFLAKE_PROFILE:-default}"

DEFAULT_CONFIG_PATH="${HOME}/.snowflake/config.toml"
CONFIG_PATH="${SNOWFLAKE_CONFIG_PATH:-$DEFAULT_CONFIG_PATH}"

if [ ! -f "${CONFIG_PATH}" ]; then
  echo "Error: ${CONFIG_PATH} not found. Configure SnowSQL before running this script." >&2
  exit 1
fi

CLI_TYPE=""
if command -v snowsql >/dev/null 2>&1; then
  CLI_TYPE="snowsql"
elif command -v snow >/dev/null 2>&1; then
  CLI_TYPE="snow"
else
  echo "Error: Neither 'snowsql' nor 'snow' CLI found. Install one of them and ensure it is on your PATH." >&2
  exit 1
fi

echo "Using profile/connection: ${PROFILE} (via ${CLI_TYPE})"
if [ "${CONFIG_PATH}" != "${DEFAULT_CONFIG_PATH}" ]; then
  echo "Using custom config path: ${CONFIG_PATH}"
fi

cd "${SETUP_DIR}"

scripts=( $(ls -1 [0-9][0-9]_*.sql 2>/dev/null | sort) )

if [ ${#scripts[@]} -eq 0 ]; then
  echo "No numbered SQL scripts found in ${SETUP_DIR}. Nothing to run." >&2
  exit 0
fi

for script in "${scripts[@]}"; do
  echo "Executing ${script}..."
  if [ "${CLI_TYPE}" = "snowsql" ]; then
    if ! snowsql --config "${CONFIG_PATH}" --profile "${PROFILE}" -f "${script}"; then
      echo "Error: Failed to execute ${script} with snowsql. Aborting." >&2
      exit 2
    fi
  else
    if ! snow sql -c "${PROFILE}" -f "${script}"; then
      echo "Error: Failed to execute ${script} with snow CLI. Aborting." >&2
      exit 2
    fi
  fi
done

echo "All setup scripts completed successfully."

