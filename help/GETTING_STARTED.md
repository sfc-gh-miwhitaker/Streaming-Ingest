# Getting Started: 5-Minute Quickstart

This guide gets you from zero to streaming RFID badge events into Snowflake in 5 minutes.

## Prerequisites

- Snowflake account (any edition, AWS region)
- Python 3.8 or higher
- Terminal access
- OpenSSL (for key generation)

## Step 1: Deploy to Snowflake (2 minutes)

Execute the SQL scripts in order using your preferred SQL client (SnowSQL, Snowsight, or any tool):

```bash
# Navigate to project directory
cd /path/to/Streaming-Ingest

# Execute setup scripts in order
snowsql -f sql/setup/01_database_and_schemas.sql
snowsql -f sql/setup/02_raw_table.sql
snowsql -f sql/setup/03_pipe_object.sql
snowsql -f sql/setup/04_staging_table.sql
snowsql -f sql/setup/05_dimension_tables.sql
snowsql -f sql/setup/06_fact_table.sql
snowsql -f sql/setup/07_stream.sql
snowsql -f sql/setup/08_tasks.sql

# Create monitoring views
snowsql -f sql/views/monitoring_views.sql
```

**Verify deployment:**
```sql
USE DATABASE SNOWFLAKE_EXAMPLE;
SHOW SCHEMAS;
SHOW PIPES IN SCHEMA STAGE_BADGE_TRACKING;
SHOW TASKS;
```

## Step 2: Setup Authentication (1 minute)

Generate RSA key pair and register with Snowflake:

```bash
# Generate key pair
openssl genrsa -out config/private_key.pem 2048
openssl rsa -in config/private_key.pem -pubout -out config/public_key.pem

# Extract public key for Snowflake (single line, no headers)
cat config/public_key.pem | grep -v "BEGIN PUBLIC KEY" | grep -v "END PUBLIC KEY" | tr -d '\n'

# Copy the output
```

Register public key in Snowflake:
```sql
ALTER USER your_username SET RSA_PUBLIC_KEY='<paste_public_key_here>';

# Verify
DESC USER your_username;
```

## Step 3: Configure Environment (30 seconds)

```bash
# Copy environment template
cp config/.env.example config/.env

# Edit config/.env with your values
# Required: SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PRIVATE_KEY_PATH
```

## Step 4: Install Python Dependencies (30 seconds)

```bash
pip install -r python/requirements.txt

# Or for development
pip install -e .
```

## Step 5: Run the Simulator (1 minute)

### Quick Test (1 minute of events)

```bash
python -m python.rfid_simulator.simulator --duration-days 0 --events-per-second 100
```

### Full 10-Day Simulation

```bash
python -m python.rfid_simulator.simulator
```

### Continuous Mode (Real-Time)

```bash
python -m python.rfid_simulator.simulator --continuous
```

## Verify Data Flow

### Check Raw Ingestion

```sql
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA STAGE_BADGE_TRACKING;

-- View raw events
SELECT * FROM RAW_BADGE_EVENTS 
ORDER BY ingestion_time DESC 
LIMIT 10;

-- Check ingestion metrics
SELECT * FROM V_CHANNEL_STATUS;
```

### Check Staging Layer

```sql
USE SCHEMA TRANSFORM_BADGE_TRACKING;

SELECT * FROM STG_BADGE_EVENTS 
ORDER BY staging_time DESC 
LIMIT 10;
```

### Check Analytics Layer

```sql
USE SCHEMA ANALYTICS_BADGE_TRACKING;

-- View fact table
SELECT * FROM FCT_ACCESS_EVENTS 
ORDER BY fact_load_time DESC 
LIMIT 10;

-- Check dimensions
SELECT * FROM DIM_USERS WHERE is_current = TRUE;
SELECT * FROM DIM_ZONES;
```

## Monitor Pipeline Health

```sql
-- End-to-end latency
SELECT * FROM STAGE_BADGE_TRACKING.V_END_TO_END_LATENCY;

-- Data freshness
SELECT * FROM STAGE_BADGE_TRACKING.V_DATA_FRESHNESS;

-- Task execution history
SELECT * FROM STAGE_BADGE_TRACKING.V_TASK_EXECUTION_HISTORY
ORDER BY scheduled_time DESC
LIMIT 10;
```

## Using Shell Scripts (Alternative)

Instead of Python simulator, use curl via shell scripts:

```bash
# Setup and open channel
source scripts/setup_auth.sh
source scripts/open_channel.sh

# Post sample events
./scripts/post_events.sh

# Check status
./scripts/check_channel_status.sh
```

## Troubleshooting

### "Failed to load private key"
- Verify file exists: `ls -la config/private_key.pem`
- Check permissions: `chmod 600 config/private_key.pem`

### "Authentication failed"
- Verify public key registered: `DESC USER your_username;`
- Check account identifier (no `.snowflakecomputing.com`)

### "Channel not found"
- Verify PIPE created: `SHOW PIPES IN SCHEMA STAGE_BADGE_TRACKING;`
- Check database/schema names match `.env`

### "Tasks not running"
- Verify tasks are resumed: `SHOW TASKS;`
- Check task history: `SELECT * FROM V_TASK_EXECUTION_HISTORY;`

## Next Steps

- **Architecture**: See `help/ARCHITECTURE.md` for detailed design
- **REST API**: See `help/REST_API_GUIDE.md` for complete API reference
- **Tuning**: See `help/TUNING_GUIDE.md` for performance optimization
- **Vendor Integration**: See `help/VENDOR_INTEGRATION.md` for production deployment

## Cleanup

To remove all objects:

```bash
snowsql -f cleanup/teardown_all.sql
```

To pause pipeline only (preserve data):

```bash
snowsql -f cleanup/teardown_tasks_only.sql
```

