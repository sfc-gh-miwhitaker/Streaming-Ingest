#!/bin/bash
# ============================================================================
# Post Events to Streaming Channel
# ============================================================================
# Posts sample RFID badge events to the streaming channel
# Requires INGEST_HOST, SCOPED_TOKEN to be set (run open_channel.sh first)
# ============================================================================

set -e

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config" && pwd)"

if [ -f "$CONFIG_DIR/.env" ]; then
    source "$CONFIG_DIR/.env"
else
    echo "Error: .env file not found"
    exit 1
fi

if [ -z "$INGEST_HOST" ] || [ -z "$SCOPED_TOKEN" ]; then
    echo "Error: INGEST_HOST and SCOPED_TOKEN must be set"
    echo "Run: source ./scripts/open_channel.sh"
    exit 1
fi

echo "Posting sample events to channel '$CHANNEL_NAME'..."

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

curl -X POST \
  -H "Authorization: Bearer $SCOPED_TOKEN" \
  -H "Content-Type: application/json" \
  "$INGEST_HOST/v2/streaming/databases/$SNOWFLAKE_DATABASE/schemas/$SNOWFLAKE_SCHEMA/pipes/$SNOWFLAKE_PIPE/channels/$CHANNEL_NAME:insert-rows" \
  -d "{
    \"rows\": [
      {
        \"badge_id\": \"BADGE-12345\",
        \"user_id\": \"USR-001\",
        \"zone_id\": \"ZONE-LOBBY-1\",
        \"reader_id\": \"RDR-101\",
        \"event_timestamp\": \"$TIMESTAMP\",
        \"signal_strength\": -45.5,
        \"direction\": \"ENTRY\"
      },
      {
        \"badge_id\": \"BADGE-67890\",
        \"user_id\": \"USR-002\",
        \"zone_id\": \"ZONE-OFFICE-2A\",
        \"reader_id\": \"RDR-201\",
        \"event_timestamp\": \"$TIMESTAMP\",
        \"signal_strength\": -38.2,
        \"direction\": \"ENTRY\"
      }
    ]
  }"

echo ""
echo "Events posted successfully!"
echo ""
echo "Verify ingestion in Snowflake:"
echo "  SELECT * FROM RAW_BADGE_EVENTS ORDER BY ingestion_time DESC LIMIT 10;"

