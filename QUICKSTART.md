# Quick Start Guide (5 Minutes)

Get the RFID Badge Tracking demo running in 5 minutes! This guide assumes you already have Python 3.8+ and a Snowflake account.

## 🎯 Goal

Ingest and validate 1,000+ badge events in your Snowflake account.

## 📋 Prerequisites Check

**First, verify you have everything:**

```bash
# Windows
tools\check.bat

# macOS/Linux
tools/check

# Or Python directly (all platforms)
python -m python.cli_tools.check_prerequisites
```

**Expected output:** All green checkmarks ✓

**If anything is missing**, the tool will tell you exactly what to install.

---

## 🚀 Four-Step Setup

### Step 1: Configure Your Snowflake Connection (1 minute)

```bash
# Copy the configuration template
# Windows: copy config\.env.example config\.env
# macOS/Linux: cp config/.env.example config/.env

# Edit config/.env with your details:
SNOWFLAKE_ACCOUNT=your_account_identifier
SNOWFLAKE_USER=your_username
SNOWFLAKE_PRIVATE_KEY_PATH=config/rsa_key.p8
```

**Generate JWT keys** (if you don't have them):
```bash
# See config/jwt_keypair_setup.md for detailed instructions
# Or run the automated setup (macOS/Linux):
./scripts/setup_auth.sh
```

---

### Step 2: Deploy to Snowflake (2 minutes)

Run all setup SQL scripts in order:

```bash
# Option A: Manual (run each file in Snowflake)
# Open sql/setup/ folder and execute 01 through 08 in order

# Option B: Automated using Snowflake CLI
cd sql/setup
snow sql -f 01_database_and_schemas.sql
snow sql -f 02_raw_table.sql
snow sql -f 03_pipe_object.sql
snow sql -f 04_staging_table.sql
snow sql -f 05_dimension_tables.sql
snow sql -f 06_fact_table.sql
snow sql -f 07_stream.sql
snow sql -f 08_tasks.sql
```

**Or use the automated script** (macOS/Linux):
```bash
./scripts/run_setup_sqls.sh
```

---

### Step 3: Generate Test Data (30 seconds)

```bash
# Install Python dependencies (if you haven't)
pip install -r python/requirements.txt

# Run the simulator
python -m python.rfid_simulator.simulator
```

**Let it run for ~30 seconds**, then press `Ctrl+C` to stop.

You should see:
```
INFO: Successfully inserted 100 rows
INFO: Successfully inserted 100 rows
...
Total events sent: 1,200
```

---

### Step 4: Validate the Pipeline (30 seconds)

```bash
# Windows
tools\validate.bat quick

# macOS/Linux
tools/validate quick

# Or Python directly
python -m python.cli_tools.validate_pipeline quick
```

**Expected output:**
```
Layer      | Row Count
-----------|----------
RAW        | 1200
STAGING    | 1200
ANALYTICS  | 1200

Stream Status: False (empty)
```

✅ **Success!** Your data flowed through all pipeline stages.

---

## 🎉 You're Done!

### What Just Happened?

1. ✅ Deployed dimensional model to Snowflake
2. ✅ Generated 1,200+ realistic RFID events
3. ✅ Streamed events via Snowpipe Streaming REST API
4. ✅ Validated data through RAW → STAGING → ANALYTICS

### Next Steps

**View Your Data:**
```sql
-- In Snowflake, run:
USE DATABASE SNOWFLAKE_EXAMPLE;

-- See recent events
SELECT * FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
ORDER BY event_timestamp DESC
LIMIT 10;

-- Top 5 active zones
SELECT z.zone_name, COUNT(*) as access_count
FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS f
JOIN ANALYTICS_BADGE_TRACKING.DIM_ZONES z ON f.zone_key = z.zone_key
GROUP BY z.zone_name
ORDER BY access_count DESC
LIMIT 5;
```

**Learn More:**
- 📘 Full walkthrough: Start with `docs/01-SETUP.md`
- 🔧 Platform-specific help: See `docs/PLATFORM_GUIDE.md`
- 🏗️ Technical details: See `docs/ARCHITECTURE.md`
- 🧹 Cleanup: Run `sql/99_cleanup/teardown_all.sql`

**Run Longer Simulations:**
```bash
# Generate data for 10 days at 200 events/sec
# (Will run until you press Ctrl+C)
python -m python.rfid_simulator.simulator --duration-days 10 --events-per-second 200
```

---

## 🆘 Troubleshooting

### Issue: "Snowflake CLI not found"
```bash
# Install from: https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/installation/installation
```

### Issue: "Timestamp not recognized" errors
- ✅ **Fixed!** This was resolved in the latest version
- Make sure you have the updated `python/shared/models.py`

### Issue: Row counts don't match
- ⏳ **Wait 1-2 minutes** - Tasks run every minute
- 🔄 **Re-run validation** - Data is processing

### Issue: Stream still has data
- ⏳ **Tasks are processing** - Check back in 60 seconds
- 🔍 **Check task status**: `SHOW TASKS IN DATABASE SNOWFLAKE_EXAMPLE;`

### Still stuck?
1. Check `docs/PLATFORM_GUIDE.md` for platform-specific issues
2. Run full validation: `python -m python.cli_tools.validate_pipeline full`
3. Review `docs/05-MONITORING.md` for debugging techniques

---

## 🎓 Learn the Full Story

This quick start got you running fast. For a complete understanding:

1. 📖 **Read**: `docs/01-SETUP.md` → Detailed prerequisites
2. 📖 **Read**: `docs/02-DEPLOYMENT.md` → Snowflake architecture
3. 📖 **Read**: `docs/03-CONFIGURATION.md` → Security & auth
4. 📖 **Read**: `docs/04-RUNNING.md` → Simulation options
5. 📖 **Read**: `docs/05-MONITORING.md` → Production monitoring

Each guide builds on the previous one - **follow them in order** for the complete story!

