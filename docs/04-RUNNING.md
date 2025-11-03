# 04 - Running the Simulator

**Goal:** Generate and validate RFID badge events flowing through the pipeline.

**Time:** ~10 minutes

**Previous:** [`03-CONFIGURATION.md`](03-CONFIGURATION.md) | **Next:** [`05-MONITORING.md`](05-MONITORING.md)

---

## Overview

Run the RFID badge event simulator to generate realistic data and validate the complete pipeline.

---

## Prerequisites

- ✅ Completed [03-CONFIGURATION.md](03-CONFIGURATION.md)
- ✅ Python dependencies installed
- ✅ Authentication configured

---

## Running the Simulator

### Quick Test (30 seconds of events)

```bash
python -m python.simulator
# Press Ctrl+C after ~30 seconds
```

**Expected Output:**
```
INFO: Initializing RFID Simulator
INFO: Opening streaming channel...
INFO: Channel 'rfid_channel_001' opened successfully
INFO: Generating events for 10 days...
INFO: Successfully inserted 100 rows
INFO: Successfully inserted 100 rows
...
```

### Continuous Mode (Until Interrupted)

```bash
python -m python.simulator --continuous
```

### Custom Parameters

```bash
# High throughput (500 events/sec)
python -m python.simulator --events-per-second 500

# Longer duration (30 days)
python -m python.simulator --duration-days 30

# Combined
python -m python.simulator --duration-days 7 --events-per-second 100
```

---

## Validating the Pipeline

### Quick Validation

**Windows:**
```powershell
tools\validate quick
```

**macOS/Linux:**
```bash
tools/validate quick
```

**All Platforms:**
```bash
python -m python.cli.validate quick
```

**Expected Output:**
```
Layer      | Row Count
-----------|----------
RAW        | 1200
STAGING    | 1200
ANALYTICS  | 1200

Stream Status: False (empty)
```

✅ **Success!** Data flowed through all layers.

### Full Validation

For comprehensive analysis:

```bash
# Windows
tools\validate full

# macOS/Linux
tools/validate full

# Python
python -m python.cli.validate full
```

This shows:
- Row counts across all layers
- Event distribution by date
- Signal quality analysis
- Task execution history
- Processing latency metrics

---

## Verification Queries

### Check Raw Ingestion

```sql
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA STAGE_BADGE_TRACKING;

-- View recent events
SELECT * FROM RAW_BADGE_EVENTS 
ORDER BY ingestion_time DESC 
LIMIT 10;

-- Count total events
SELECT COUNT(*) AS total_events FROM RAW_BADGE_EVENTS;
```

### Check Staging Layer

```sql
USE SCHEMA TRANSFORM_BADGE_TRACKING;

SELECT COUNT(*) FROM STG_BADGE_EVENTS;

-- View sample
SELECT * FROM STG_BADGE_EVENTS 
ORDER BY staging_time DESC 
LIMIT 10;
```

### Check Analytics Layer

```sql
USE SCHEMA ANALYTICS_BADGE_TRACKING;

-- Fact table count
SELECT COUNT(*) FROM FCT_ACCESS_EVENTS;

-- Top 5 active zones
SELECT z.zone_name, COUNT(*) as access_count
FROM FCT_ACCESS_EVENTS f
JOIN DIM_ZONES z ON f.zone_key = z.zone_key
GROUP BY z.zone_name
ORDER BY access_count DESC
LIMIT 5;

-- Events by date
SELECT event_date, COUNT(*) as event_count
FROM FCT_ACCESS_EVENTS
GROUP BY event_date
ORDER BY event_date DESC;
```

---

## Understanding the Output

### Simulator Metrics

```
Total events sent: 1,200
Total events rejected: 0
Duration: 9.9 seconds
Average rate: 121 events/sec
```

- **Events sent:** Successfully transmitted to Snowflake
- **Rejected:** Failed validation (should be 0)
- **Average rate:** Actual throughput achieved

### Pipeline Flow

1. **RAW** - Events land immediately (< 1 second)
2. **STAGING** - Processed within 1-2 minutes (task schedule)
3. **ANALYTICS** - Loaded within 1-2 minutes after staging

**If counts don't match:** Wait 1-2 minutes for tasks to process, then re-validate.

---

## Troubleshooting

### Issue: "Timestamp not recognized"

**Cause:** Old bug (should be fixed)

**Solution:** Verify you have the latest `python/shared/models.py`

### Issue: Row counts don't match

**Cause:** Tasks still processing

**Solution:** Wait 1-2 minutes, then re-run validation

### Issue: Stream still has data

**Cause:** Tasks haven't consumed yet

**Check:**
```sql
SELECT SYSTEM$STREAM_HAS_DATA('STAGE_BADGE_TRACKING.raw_badge_events_stream');
```

Wait and recheck.

### Issue: "Channel not found"

**Cause:** Pipe or channel issue

**Solution:**
```sql
-- Verify pipe exists
SHOW PIPES IN SCHEMA STAGE_BADGE_TRACKING;

-- Check pipe status
DESC PIPE BADGE_EVENTS_PIPE;
```

---

## Next Steps

✅ **Data flowing!**

Continue to:
👉 **[05-MONITORING.md](05-MONITORING.md)** - Monitor and troubleshoot the pipeline

---

## Detailed Validation Queries

For deeper troubleshooting, use these individual diagnostic queries:

### Check Individual Layers
```sql
-- Raw table
SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.RAW_BADGE_EVENTS;

-- Staging table
SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS;

-- Fact table
SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS;
```

### Check Stream Status
```sql
SELECT SYSTEM$STREAM_HAS_DATA(
  'SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.raw_badge_events_stream'
) AS has_data;
```

### Check Task Execution
```sql
SELECT name, state, scheduled_time, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
WHERE database_name = 'SNOWFLAKE_EXAMPLE'
ORDER BY scheduled_time DESC LIMIT 10;
```

### Check Processing Latency
```sql
SELECT 
    MIN(DATEDIFF('second', ingestion_time, fact_load_time)) AS min_latency_sec,
    AVG(DATEDIFF('second', ingestion_time, fact_load_time)) AS avg_latency_sec,
    MAX(DATEDIFF('second', ingestion_time, fact_load_time)) AS max_latency_sec
FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS;
```

---

## Troubleshooting

### Problem: Row counts don't match
**Cause:** Tasks still processing  
**Solution:** Wait 1-2 minutes, re-run validation

### Problem: Stream still has data
**Cause:** Tasks haven't consumed stream  
**Solution:** Wait 1-2 minutes and recheck

### Problem: Fact count < Staging count
**Cause:** Missing dimension keys  
**Check:**
```sql
SELECT s.user_id, COUNT(*) AS event_count
FROM SNOWFLAKE_EXAMPLE.TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS s
LEFT JOIN SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.DIM_USERS u 
    ON s.user_id = u.user_id AND u.is_current = TRUE
WHERE u.user_key IS NULL
GROUP BY s.user_id;
```

### Problem: Tasks show errors
```sql
SELECT name, error_code, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE database_name = 'SNOWFLAKE_EXAMPLE' AND state = 'FAILED'
ORDER BY scheduled_time DESC;
```

---

## Success Criteria

✅ **Pipeline working correctly if:**
- RAW = STAGING = ANALYTICS counts match
- Stream status = False (empty)
- No failed tasks
- Processing latency < 120 seconds
- All dimension keys resolved

---

## Additional Resources

- **Monitoring:** [`05-MONITORING.md`](05-MONITORING.md)
- **REST API:** [`REST_API_GUIDE.md`](REST_API_GUIDE.md)

---

**Guide:** 04-RUNNING | ← [03-CONFIGURATION](03-CONFIGURATION.md) | [05-MONITORING](05-MONITORING.md) →

