# RFID Badge Tracking: Snowflake Native Streaming Ingestion

A production-grade reference implementation demonstrating RFID badge event ingestion using Snowflake's native Snowpipe Streaming REST API. **Zero external infrastructure required** - the RFID vendor POSTs directly to Snowflake endpoints.

## Overview

This project demonstrates how to ingest several million RFID badge events over a 10-day period using Snowflake's high-performance streaming architecture (GA September 2025). Perfect for property access control, asset tracking, and real-time location systems.

### Key Features

- **Snowpipe Streaming GA (Sep 2025)**: Direct REST ingestion with continuation tokens, zero middleware
- **Native Snowflake Solution**: 100% in Snowflake - no external services to deploy
- **High Performance**: Up to 10 GB/sec per table, <10 second query latency
- **In-Flight Transformations**: Clean, validate, and enrich data during ingestion
- **Complete Pipeline**: Raw → Staging → Analytics with CDC using Streams and Tasks
- **Production Ready**: Monitoring, data quality checks, real-time dashboards, and comprehensive documentation

## Quick Start

> **📝 Windows Users**: See [`help/PLATFORM_GUIDE.md`](help/PLATFORM_GUIDE.md) for Windows-specific instructions using `.bat` files.

### Prerequisites

- Snowflake account (any edition, AWS region)
- Snowflake CLI v3.0+ ([Install Guide](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/installation/installation))
- Key-pair authentication configured (see `config/jwt_keypair_setup.md`)
- Python 3.8+ for simulator

**Check Prerequisites & Update CLI:**

```bash
# Windows
check_prerequisites.bat --auto-update

# macOS/Linux  
./check_prerequisites.sh --auto-update

# Or use Python directly (all platforms)
python -m python.cli_tools.check_prerequisites --auto-update
```

This will verify:
- ✓ Snowflake CLI is installed and up-to-date
- ✓ Python version (3.8+)
- ✓ Required Python packages
- ✓ Configuration file exists
- ✓ JWT private key is configured

### 3-Step Setup

**Step 1: Deploy to Snowflake**

Execute the SQL scripts in order:

```bash
# Navigate to sql/setup directory
cd sql/setup

# Execute each script in Snowflake (SnowSQL, Snowsight, or any SQL client)
# Scripts are numbered for execution order
01_database_and_schemas.sql
02_raw_table.sql
03_pipe_object.sql
04_staging_table.sql
05_dimension_tables.sql
06_fact_table.sql
07_stream.sql
08_tasks.sql
```

**Step 2: Configure Authentication**

```bash
# Copy environment template
cp config/.env.example config/.env

# Edit config/.env with your Snowflake account details
# Follow config/jwt_keypair_setup.md for key-pair setup
```

**Step 3: Run the Simulator**

```bash
# Install Python dependencies
pip install -r python/requirements.txt

# Run the RFID vendor simulator
python -m python.rfid_simulator.simulator
```

### First Event Test

Send a test event using curl:

```bash
# See scripts/post_events.sh for complete example
source scripts/setup_auth.sh   # Generate JWT token in current shell
source scripts/open_channel.sh # Open streaming channel (exports tokens)
./scripts/post_events.sh       # POST test event
```

## Guided Customer Lab

Need the storyline for executives and integrators? Start with `help/LAB_GUIDE.md`. It compresses the deployment into five phases, spotlights the Snowpipe Streaming GA enhancements, and arms partners with the instructions they need even if they cannot run the full lab immediately.

## Project Structure

```
├── sql/                      # Snowflake SQL scripts
│   ├── setup/               # Database, tables, PIPE, streams, tasks
│   ├── views/               # Monitoring views
│   └── data_quality/        # Data quality checks
├── python/                   # Python simulator and utilities
│   ├── rfid_simulator/      # RFID vendor simulator
│   ├── load_testing/        # Load testing with Locust
│   └── shared/              # Shared models and validation
├── scripts/                  # Shell scripts for REST API interaction
├── config/                   # Configuration templates
├── help/                     # Detailed documentation
└── cleanup/                  # Teardown scripts
```

## Architecture

### Data Flow

```
RFID Vendor → POST https://[account].snowflakecomputing.com/v2/streaming/...
           ↓
    PIPE Object (in-flight transformations)
           ↓
    RAW_BADGE_EVENTS
           ↓
    Stream (CDC)
           ↓
    Task (1-min, triggered by stream)
           ↓
    STG_BADGE_EVENTS (deduplication)
           ↓
    Task (MERGE operations)
           ↓
    Analytics: DIM_USERS, DIM_ZONES, FCT_ACCESS_EVENTS
```

### Use Case

Property access control with RFID badges:
- Users wearing badges (employees, visitors, contractors)
- Badge readers at entry/exit points, zone transitions, secure areas
- Real-time tracking of movement and occupancy
- Security alerts and access control

## Documentation

| Document | Description |
|----------|-------------|
| `help/GETTING_STARTED.md` | Step-by-step 5-minute quickstart |
| `help/ARCHITECTURE.md` | Detailed architecture and design decisions |
| `help/REST_API_GUIDE.md` | Complete REST API reference with examples |
| `help/LAB_GUIDE.md` | Customer & partner lab storyline and scaling playbook |
| `help/VENDOR_INTEGRATION.md` | Guide for RFID vendor integration |
| `help/TUNING_GUIDE.md` | Performance optimization strategies |
| `help/DATA_DICTIONARY.md` | Complete schema documentation |

## Key Components

### PIPE Object with In-Flight Transformations

The PIPE object centralizes ingestion logic:

```sql
CREATE PIPE badge_events_pipe
AS COPY INTO RAW_BADGE_EVENTS
FROM (
  SELECT 
    $1:badge_id::STRING as badge_id,
    $1:user_id::STRING as user_id,
    TRY_TO_TIMESTAMP_NTZ($1:event_timestamp) as event_timestamp,
    COALESCE($1:signal_strength::NUMBER, -999) as signal_strength,
    CASE 
      WHEN $1:signal_strength::NUMBER < -80 THEN 'WEAK'
      ELSE 'STRONG'
    END as signal_quality,
    CURRENT_TIMESTAMP() as ingestion_time
  FROM TABLE(DATA_SOURCE(TYPE => 'STREAMING'))
)
FILE_FORMAT = (TYPE = JSON);
```

### CDC Pipeline

Streams and Tasks provide near-real-time transformation:

```sql
-- Stream captures changes
CREATE STREAM raw_badge_events_stream 
ON TABLE RAW_BADGE_EVENTS;

-- Task processes changes every minute
CREATE TASK raw_to_staging_task
  WAREHOUSE = etl_wh
  SCHEDULE = '1 MINUTE'
WHEN SYSTEM$STREAM_HAS_DATA('raw_badge_events_stream')
AS
  INSERT INTO STG_BADGE_EVENTS
  SELECT * FROM raw_badge_events_stream
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY badge_id, event_timestamp 
    ORDER BY ingestion_time DESC
  ) = 1;
```

## Monitoring

Monitor ingestion health with built-in views:

```sql
-- Check channel status
SELECT * FROM V_INGESTION_METRICS;

-- View end-to-end latency
SELECT * FROM V_END_TO_END_LATENCY;

-- Check clustering efficiency
SELECT * FROM V_PARTITION_EFFICIENCY;
```

For live dashboards, pin these queries in Snowsight Worksheets or your BI tool of choice and point stakeholders to the quick narrative in `help/LAB_GUIDE.md` (Phase 4) for recommended charts and KPIs.

## Cleanup

To remove all deployed resources:

```bash
# Complete teardown (drops all objects)
snowsql -f cleanup/teardown_all.sql

# Stop tasks only (preserve data)
snowsql -f cleanup/teardown_tasks_only.sql
```

## Performance Characteristics

| Metric | Value |
|--------|-------|
| Max Throughput | 10 GB/sec per table |
| Ingest-to-Query Latency | <10 seconds |
| Max Request Size | 16 MB per POST |
| Authentication | JWT with key-pair |
| Pricing | Throughput-based (credits per GB) |

## Support

For questions or issues:
1. Review documentation in `help/` directory
2. Check Snowflake documentation for Snowpipe Streaming
3. Examine monitoring views for ingestion health

## License

This is a reference implementation for educational and demonstration purposes.

