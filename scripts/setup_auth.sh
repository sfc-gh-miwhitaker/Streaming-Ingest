#!/bin/bash
# ============================================================================
# Setup Authentication: Generate JWT Token
# ============================================================================
# This script generates a JWT token for Snowflake authentication
# Required before opening channels or posting events
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Error: run this script with 'source ./scripts/setup_auth.sh' so JWT_TOKEN persists in your shell" >&2
    exit 1
fi

# Determine script location (when sourced from anywhere)
# First, try to use BASH_SOURCE to find the script's actual location
if [[ -n "${BASH_SOURCE[0]}" ]]; then
    if [[ "${BASH_SOURCE[0]}" == /* ]]; then
        # Already absolute
        SCRIPT_PATH="${BASH_SOURCE[0]}"
    else
        # Relative path - make absolute
        SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/$(basename "${BASH_SOURCE[0]}")"
    fi
    SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
    REPO_ROOT="$(cd "${SCRIPT_DIR}/.." 2>/dev/null && pwd)"
else
    # Fallback: assume we're in the repo root or scripts dir
    if [[ -d "./scripts" && -d "./config" ]]; then
        REPO_ROOT="$PWD"
    elif [[ -d "../config" ]]; then
        REPO_ROOT="$(cd .. && pwd)"
    else
        echo "Error: unable to locate repository root" >&2
        return 1
    fi
fi

CONFIG_DIR="${REPO_ROOT}/config"

if [ ! -d "$CONFIG_DIR" ]; then
    echo "Error: could not locate config directory" >&2
    return 1
fi

if [ -f "$CONFIG_DIR/.env" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_DIR/.env"
else
    echo "Error: .env file not found in $CONFIG_DIR"
    echo "Please copy .env.example to .env and configure your settings"
    return 1
fi

export \
    SNOWFLAKE_ACCOUNT \
    SNOWFLAKE_USER \
    SNOWFLAKE_DATABASE \
    SNOWFLAKE_SCHEMA \
    SNOWFLAKE_PIPE \
    SNOWFLAKE_PRIVATE_KEY_PATH \
    SNOWFLAKE_PRIVATE_KEY_PASSPHRASE

: "${SNOWFLAKE_ACCOUNT:?SNOWFLAKE_ACCOUNT is not set in .env}"
: "${SNOWFLAKE_USER:?SNOWFLAKE_USER is not set in .env}"
: "${SNOWFLAKE_PRIVATE_KEY_PATH:?SNOWFLAKE_PRIVATE_KEY_PATH is not set in .env}"

if [ ! -f "$SNOWFLAKE_PRIVATE_KEY_PATH" ]; then
    echo "Error: Private key not found at $SNOWFLAKE_PRIVATE_KEY_PATH"
    echo "Please generate a key pair using: python -m python.rfid_simulator.auth"
    return 1
fi

echo "Generating JWT token for $SNOWFLAKE_USER@$SNOWFLAKE_ACCOUNT..."

export JWT_TOKEN=$(
    PYTHONPATH="${REPO_ROOT}/python:${PYTHONPATH:-}" \
    python - <<'END'
import os
from python.rfid_simulator.auth import SnowflakeAuth

private_key_path = os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"]
private_key_passphrase = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE") or None

auth = SnowflakeAuth(
    account=os.environ["SNOWFLAKE_ACCOUNT"],
    user=os.environ["SNOWFLAKE_USER"],
    private_key_path=private_key_path,
    private_key_passphrase=private_key_passphrase
)

token = auth.generate_jwt_token()
print(token)
END
)

if [ -z "$JWT_TOKEN" ]; then
    echo "Error: Failed to generate JWT token"
    return 1
fi

echo "JWT token generated successfully!"
echo "Token stored in JWT_TOKEN environment variable"
echo ""
echo "Token preview: ${JWT_TOKEN:0:50}..."
echo ""
echo "To use in other scripts:"
echo "  export JWT_TOKEN='$JWT_TOKEN'"

return 0

