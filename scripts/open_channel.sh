#!/bin/bash
# ============================================================================
# Open Streaming Channel
# ============================================================================
# Opens a Snowpipe Streaming channel for data ingestion
# Requires JWT_TOKEN to be set (run setup_auth.sh first)
# ============================================================================

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
    echo "Error: .env file not found"
    return 1
fi

if [ -z "$JWT_TOKEN" ]; then
    echo "Error: JWT_TOKEN not set"
    echo "Run: source ./scripts/setup_auth.sh"
    return 1
fi

echo "Opening streaming channel..."

ACCOUNT_URL="https://$SNOWFLAKE_ACCOUNT.snowflakecomputing.com"

echo "Step 1: Get control plane hostname..."
HOSTNAME_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT" \
  "$ACCOUNT_URL/v2/streaming/hostname")

HTTP_CODE=$(echo "$HOSTNAME_RESPONSE" | tail -1)
HOSTNAME_BODY=$(echo "$HOSTNAME_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo "Error: Failed to get control plane hostname (HTTP $HTTP_CODE)" >&2
    echo "Response: $HOSTNAME_BODY" >&2
    return 1
fi

CONTROL_HOST="https://${HOSTNAME_BODY#https://}"
echo "Control host: $CONTROL_HOST"

echo ""
echo "Step 2: Open channel '$CHANNEL_NAME'..."
CHANNEL_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  "$CONTROL_HOST/v2/streaming/databases/$SNOWFLAKE_DATABASE/schemas/$SNOWFLAKE_SCHEMA/pipes/$SNOWFLAKE_PIPE:open-channel" \
  -d "{\"channel_name\": \"$CHANNEL_NAME\"}")

HTTP_CODE=$(echo "$CHANNEL_RESPONSE" | tail -1)
CHANNEL_BODY=$(echo "$CHANNEL_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo "Error: Failed to open channel (HTTP $HTTP_CODE)" >&2
    echo "Response: $CHANNEL_BODY" >&2
    if [ "$HTTP_CODE" = "404" ]; then
        echo "" >&2
        echo "The pipe '$SNOWFLAKE_PIPE' was not found." >&2
        echo "Have you run the SQL setup scripts yet?" >&2
        echo "  ./scripts/run_setup_sqls.sh" >&2
        echo "" >&2
        echo "Or manually run scripts in order:" >&2
        echo "  snow sql -f sql/setup/01_database_and_schemas.sql" >&2
        echo "  snow sql -f sql/setup/02_tables.sql" >&2
        echo "  snow sql -f sql/setup/03_pipe_object.sql" >&2
        echo "  ..." >&2
    fi
    return 1
fi

# Parse the JSON response
export INGEST_HOST=$(echo "$CHANNEL_BODY" | python -c "import sys, json; resp = json.load(sys.stdin); print('https://' + resp.get('ingest_host', ''))")
export SCOPED_TOKEN=$(echo "$CHANNEL_BODY" | python -c "import sys, json; print(json.load(sys.stdin).get('scoped_token', ''))")
export CONTINUATION_TOKEN=$(echo "$CHANNEL_BODY" | python -c "import sys, json; print(json.load(sys.stdin).get('continuation_token', ''))")
export OFFSET_TOKEN=$(echo "$CHANNEL_BODY" | python -c "import sys, json; print(json.load(sys.stdin).get('offset_token', '0'))")

if [ -z "$INGEST_HOST" ] || [ -z "$SCOPED_TOKEN" ] || [ -z "$CONTINUATION_TOKEN" ]; then
    echo "Error: Failed to parse channel response" >&2
    echo "Response: $CHANNEL_BODY" >&2
    return 1
fi

echo ""
echo "Channel opened successfully!"
echo "Ingest host: $INGEST_HOST"
echo "Continuation token: ${CONTINUATION_TOKEN:0:50}..."
echo "Offset token: $OFFSET_TOKEN"
echo ""
echo "To use in other scripts, export these variables:"
echo "  export INGEST_HOST='$INGEST_HOST'"
echo "  export SCOPED_TOKEN='$SCOPED_TOKEN'"
echo "  export CONTINUATION_TOKEN='$CONTINUATION_TOKEN'"
echo "  export OFFSET_TOKEN='$OFFSET_TOKEN'"

return 0

