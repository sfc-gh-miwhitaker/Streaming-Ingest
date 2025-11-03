# 02 - Deployment to Snowflake

**Goal:** Deploy the complete data pipeline to your Snowflake account.

**Time:** ~5 minutes

**Previous:** [`01-SETUP.md`](01-SETUP.md) | **Next:** [`03-CONFIGURATION.md`](03-CONFIGURATION.md)

---

## Overview

This guide deploys the complete RFID Badge Tracking architecture to Snowflake:
- Database and schemas (RAW → STAGING → ANALYTICS)
- Dimensional model (Type 2 SCDs)
- Snowpipe Streaming object
- CDC streams and tasks
- Monitoring views

**Architecture:**
```
RAW_BADGE_EVENTS (landing)
    ↓ [Stream]
STG_BADGE_EVENTS (staging + dedup)
    ↓ [Task → MERGE]
DIM_USERS + DIM_ZONES (dimensions)
    ↓ [Task → JOIN + INSERT]
FCT_ACCESS_EVENTS (fact table)
```

---

## Prerequisites

- ✅ Completed [01-SETUP.md](01-SETUP.md)
- ✅ Snowflake CLI configured
- ✅ Account SYSADMIN role or equivalent

---

## Deployment Options

### Option A: Automated Deployment (Recommended)

Run all setup scripts automatically:

```bash
# Windows
tools\deploy

# macOS/Linux
tools/deploy

# Optional: tools/deploy --connection mydev
```

**Expected Output:**
```
→ Executing 01_database_and_schemas.sql
✓ Completed: 01_database_and_schemas.sql
...
All setup scripts executed successfully.
```

### Option B: Manual Step-by-Step

Execute each SQL script in order using Snowflake CLI:

```bash
cd sql/01_setup

snow sql -f 01_database_and_schemas.sql
snow sql -f 02_raw_table.sql
snow sql -f 03_pipe_object.sql
snow sql -f 04_staging_table.sql
snow sql -f 05_dimension_tables.sql
snow sql -f 06_fact_table.sql
snow sql -f 07_stream.sql
snow sql -f 08_tasks.sql
```

### Option C: Using Snowsight UI
```
1. Open Snowsight Worksheets
2. Upload files from `sql/01_setup/`
3. Execute in numerical order
```

---

## What Gets Created

### 1. Database Structure

```sql
-- Database
SNOWFLAKE_EXAMPLE

-- Schemas
├── STAGE_BADGE_TRACKING      -- Raw landing + pipes
├── TRANSFORM_BADGE_TRACKING  -- Staging + transformation
└── ANALYTICS_BADGE_TRACKING  -- Dimensional model
```

### 2. Tables

**RAW Layer (STAGE_BADGE_TRACKING):**
- `RAW_BADGE_EVENTS` - Landing table for streaming ingestion

**Staging Layer (TRANSFORM_BADGE_TRACKING):**
- `STG_BADGE_EVENTS` - Cleaned and deduplicated events

**Analytics Layer (ANALYTICS_BADGE_TRACKING):**
- `DIM_USERS` - User dimension (Type 2 SCD)
- `DIM_ZONES` - Zone/location dimension
- `FCT_ACCESS_EVENTS` - Badge scan fact table (clustered by date)

### 3. Streaming Objects

- `BADGE_EVENTS_PIPE` - Snowpipe Streaming endpoint
- `raw_badge_events_stream` - CDC stream for incremental processing

### 4. Tasks

- `raw_to_staging_task` - Moves RAW → STAGING (1-minute schedule)
- `staging_to_analytics_task` - Loads dimensions + fact (triggered)

### 5. Monitoring Views

**Created in sql/03_monitoring/:**
- `V_CHANNEL_STATUS` - Streaming channel health
- `V_DATA_FRESHNESS` - Data latency by layer
- `V_END_TO_END_LATENCY` - Pipeline performance
- `V_TASK_EXECUTION_HISTORY` - Task run history

---

## Verification Steps

### Step 1: Verify Database and Schemas

```sql
USE DATABASE SNOWFLAKE_EXAMPLE;

SHOW SCHEMAS;
-- Expected: 3 schemas (STAGE_, TRANSFORM_, ANALYTICS_)
```

### Step 2: Verify Tables

```sql
-- Raw layer
SHOW TABLES IN SCHEMA STAGE_BADGE_TRACKING;
-- Expected: RAW_BADGE_EVENTS

-- Staging layer
SHOW TABLES IN SCHEMA TRANSFORM_BADGE_TRACKING;
-- Expected: STG_BADGE_EVENTS

-- Analytics layer
SHOW TABLES IN SCHEMA ANALYTICS_BADGE_TRACKING;
-- Expected: DIM_USERS, DIM_ZONES, FCT_ACCESS_EVENTS
```

### Step 3: Verify Snowpipe Streaming

```sql
USE SCHEMA STAGE_BADGE_TRACKING;

SHOW PIPES;
-- Expected: BADGE_EVENTS_PIPE with type 'STREAMING'

DESC PIPE BADGE_EVENTS_PIPE;
```

### Step 4: Verify CDC Stream

```sql
SHOW STREAMS IN SCHEMA STAGE_BADGE_TRACKING;
-- Expected: RAW_BADGE_EVENTS_STREAM

-- Check stream status (should be empty initially)
SELECT SYSTEM$STREAM_HAS_DATA('raw_badge_events_stream');
-- Expected: False
```

### Step 5: Verify Tasks

```sql
SHOW TASKS IN DATABASE SNOWFLAKE_EXAMPLE;
-- Expected: 2 tasks (raw_to_staging_task, staging_to_analytics_task)

-- Check task status (should be 'started')
SELECT name, state, schedule
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE database_name = 'SNOWFLAKE_EXAMPLE'
LIMIT 5;
```

### Step 6: Verify Dimensions Seeded

```sql
USE SCHEMA ANALYTICS_BADGE_TRACKING;

-- Check users (should have 5 seed records)
SELECT COUNT(*) FROM DIM_USERS WHERE is_current = TRUE;
-- Expected: 5

-- Check zones (should have 5 seed records)
SELECT COUNT(*) FROM DIM_ZONES;
-- Expected: 5

-- View sample users
SELECT user_id, user_name, user_type, clearance_level
FROM DIM_USERS
WHERE is_current = TRUE;
```

---

## Architecture Details

### Data Flow

1. **Ingestion:** RFID vendors POST JSON → Snowpipe Streaming REST API
2. **Landing:** Events land in `RAW_BADGE_EVENTS` table
3. **CDC:** Stream captures new rows
4. **Deduplication:** Task moves to `STG_BADGE_EVENTS` using QUALIFY
5. **Dimension Updates:** Task maintains Type 2 SCDs
6. **Fact Loading:** Task joins dimensions and loads fact table

### Clustering Strategy

```sql
-- Fact table clustered by date for time-series queries
FCT_ACCESS_EVENTS CLUSTER BY (event_date)
```

**Why:** Most queries filter by date ranges. Clustering on date (not timestamp) provides:
- Better pruning (lower cardinality)
- Faster time-series queries
- Lower maintenance cost

### Task Scheduling

```sql
-- Parent task (schedule-driven)
raw_to_staging_task
  SCHEDULE = '1 MINUTE'
  WHEN SYSTEM$STREAM_HAS_DATA('raw_badge_events_stream')

-- Child task (event-driven)
staging_to_analytics_task
  AFTER raw_to_staging_task
```

**Benefits:**
- Near-real-time processing (1-minute intervals)
- Cost-efficient (only runs when data available)
- Automatic DAG execution

---

## Troubleshooting

### Issue: "Database already exists"

**Cause:** Running setup scripts multiple times

**Solution:** Scripts are idempotent - they use `CREATE OR REPLACE`. Safe to re-run.

### Issue: "Insufficient privileges"

**Cause:** User lacks required permissions

**Solution:**
```sql
-- Grant necessary roles
GRANT ROLE SYSADMIN TO USER your_username;
GRANT ROLE ACCOUNTADMIN TO USER your_username;  -- If needed
```

### Issue: "Pipe creation failed"

**Cause:** Feature not enabled or permission issue

**Solution:**
1. Verify Snowpipe Streaming is enabled on your account
2. Check with Snowflake support if needed
3. Requires SYSADMIN or higher

### Issue: "Tasks not starting"

**Cause:** Tasks created in suspended state

**Solution:**
```sql
-- Resume tasks (already in script 08_tasks.sql)
ALTER TASK staging_to_analytics_task RESUME;
ALTER TASK raw_to_staging_task RESUME;

-- Verify
SHOW TASKS;
```

### Issue: "Stream shows errors"

**Cause:** Base table doesn't exist yet

**Solution:** Execute scripts in order. Stream requires base table first.

---

## Deployment Best Practices

### For Development

- ✅ Use the provided scripts as-is
- ✅ Run in isolated dev database
- ✅ Test with small data volumes first

### For Production

**Modifications recommended:**

1. **Warehouse Sizing:**
```sql
-- In 08_tasks.sql, adjust warehouse size based on volume
CREATE WAREHOUSE IF NOT EXISTS etl_wh
WITH WAREHOUSE_SIZE = 'SMALL'  -- Increase for production
     AUTO_SUSPEND = 60;
```

2. **Task Schedule:**
```sql
-- Adjust schedule based on latency requirements
SCHEDULE = '1 MINUTE'  -- Or '5 MINUTE' for lower frequency
```

3. **Clustering:**
```sql
-- Monitor and adjust clustering depth
SELECT SYSTEM$CLUSTERING_INFORMATION('FCT_ACCESS_EVENTS');
```

4. **Resource Monitors:**
```sql
-- Add budget controls
CREATE RESOURCE MONITOR prod_etl_monitor
WITH CREDIT_QUOTA = 1000
TRIGGERS
  ON 75 PERCENT DO NOTIFY
  ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE etl_wh SET RESOURCE_MONITOR = prod_etl_monitor;
```

---

## Cost Considerations

### Compute Costs

- **Warehouse:** ETL_WH (XSMALL by default)
  - Auto-suspends after 60 seconds
  - Costs only when tasks run
  - ~$2-3/hour when active (XSMALL)

- **Snowpipe Streaming:** Serverless
  - Billed per GB ingested
  - No warehouse required

### Storage Costs

- **Time Travel:** 1-day retention (default)
- **Fail-safe:** 7 days (automatic)
- **Clustering:** Maintenance costs (minimal for date clustering)

### Optimization Tips

1. **Increase AUTO_SUSPEND aggressiveness** (already set to 60s)
2. **Batch larger volumes** if latency allows
3. **Monitor with Resource Monitors**
4. **Use TRANSIENT tables** for staging (no Fail-safe costs)

---

## Next Steps

✅ **Pipeline deployed!**

Continue to:
👉 **[03-CONFIGURATION.md](03-CONFIGURATION.md)** - Configure authentication and settings

---

## Additional Resources

- **Architecture Deep-Dive:** [`ARCHITECTURE.md`](ARCHITECTURE.md)
- **Data Dictionary:** [`DATA_DICTIONARY.md`](DATA_DICTIONARY.md)
- **Monitoring Guide:** [`05-MONITORING.md`](05-MONITORING.md)
- **SQL Scripts:** [`../sql/01_setup/`](../sql/01_setup/)

---

**Guide:** 02-DEPLOYMENT | ← [01-SETUP](01-SETUP.md) | [03-CONFIGURATION](03-CONFIGURATION.md) →

