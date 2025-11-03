#!/bin/bash
# ============================================================================
# Check Channel Status
# ============================================================================
# Checks the health and status of the streaming channel
# Requires JWT_TOKEN and CONTROL_HOST (run setup_auth.sh and open_channel.sh)
# ============================================================================

set -e

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config" && pwd)"

if [ -f "$CONFIG_DIR/.env" ]; then
    source "$CONFIG_DIR/.env"
else
    echo "Error: .env file not found"
    exit 1
fi

if [ -z "$JWT_TOKEN" ]; then
    echo "Error: JWT_TOKEN not set"
    echo "Run: source ./scripts/setup_auth.sh"
    exit 1
fi

echo "Checking channel status for '$CHANNEL_NAME'..."

if [ -z "$CONTROL_HOST" ]; then
    ACCOUNT_URL="https://$SNOWFLAKE_ACCOUNT.snowflakecomputing.com"
    CONTROL_HOST=$(curl -s -X GET \
      -H "Authorization: Bearer $JWT_TOKEN" \
      "$ACCOUNT_URL/v2/streaming/hostname" \
      | python3 -c "import sys, json; print('https://' + json.load(sys.stdin)['hostname'])")
fi

curl -s -X POST \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  "$CONTROL_HOST/v2/streaming/databases/$SNOWFLAKE_DATABASE/schemas/$SNOWFLAKE_SCHEMA/pipes/$SNOWFLAKE_PIPE:bulk-channel-status" \
  -d "{\"channel_names\": [\"$CHANNEL_NAME\"]}" \
  | python3 -m json.tool

echo ""
echo "Query Snowflake for detailed metrics:"
echo "  SELECT * FROM V_CHANNEL_STATUS;"

