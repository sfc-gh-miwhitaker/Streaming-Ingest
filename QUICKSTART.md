# Quick Start Guide (5 Minutes)

Get the RFID Badge Tracking demo running in 5 minutes! This guide assumes you already have Python 3.8+ and a Snowflake account.

## 🎯 Goal

Ingest and validate 1,000+ badge events in your Snowflake account.

---

## Choose Your Setup Path

Pick the option that matches your system and preference:

| Jump To | Description |
|---------|-------------|
| [🚀 macOS/Linux - Automated](#macos-linux---automated-setup) | **Recommended** - Script handles everything |
| [⚙️ macOS/Linux - Manual](#macos-linux---manual-setup) | Full control over each step |
| [🚀 Windows - Automated](#windows---automated-setup) | **Recommended** - Script handles everything |
| [⚙️ Windows - Manual](#windows---manual-setup) | Full control over each step |

---

# macOS/Linux - Automated Setup

**Time:** ~5 minutes hands-off

This script creates a virtual environment, installs dependencies, and runs prerequisite checks automatically.

## Step 1: Run Setup Script

```bash
cd Streaming-Ingest
sh tools/setup-env.sh
```

**What it does:**
1. Creates `streaming-ingest-example` venv
2. Installs all Python dependencies
3. Runs prerequisites check
4. Shows activation command for next time

## Step 2: Configure Snowflake

```bash
# Copy template
cp config/.env.example config/.env

# Edit with your details
nano config/.env  # or vim, code, etc.
```

**Required fields:**
```ini
SNOWFLAKE_ACCOUNT=xy12345.us-east-1
SNOWFLAKE_USER=your_username
SNOWFLAKE_PRIVATE_KEY_PATH=config/rsa_key.p8
```

**Generate JWT keys** (if needed):
```bash
# Generate key pair
openssl genrsa -out config/rsa_key.p8 2048
openssl rsa -in config/rsa_key.p8 -pubout -out config/rsa_key.pub

# Register public key in Snowflake (copy the output)
cat config/rsa_key.pub
```

Then in Snowflake:
```sql
ALTER USER your_username SET RSA_PUBLIC_KEY='<paste_key_here>';
```

## Step 3: Deploy to Snowflake

```bash
# Run all setup scripts
cd sql/01_setup
for file in *.sql; do snow sql -f "$file"; done
cd ../..
```

Or manually:
```bash
snow sql -f sql/01_setup/01_database_and_schemas.sql
snow sql -f sql/01_setup/02_raw_table.sql
snow sql -f sql/01_setup/03_pipe_object.sql
snow sql -f sql/01_setup/04_staging_table.sql
snow sql -f sql/01_setup/05_dimension_tables.sql
snow sql -f sql/01_setup/06_fact_table.sql
snow sql -f sql/01_setup/07_stream.sql
snow sql -f sql/01_setup/08_tasks.sql
```

## Step 4: Run Simulator

```bash
# Activate venv if not already active
source streaming-ingest-example/bin/activate

# Run simulator (Ctrl+C to stop after 30 seconds)
python -m python.simulator
```

**Expected output:**
```
INFO: Initializing RFID Simulator
INFO: Opening streaming channel...
INFO: Successfully inserted 100 rows
INFO: Successfully inserted 100 rows
...
```

## Step 5: Validate

```bash
sh tools/validate.sh quick
```

**Expected:**
```
Layer      | Row Count
-----------|----------
RAW        | 1200
STAGING    | 1200
ANALYTICS  | 1200

Stream Status: False (empty)
✅ Pipeline working!
```

**Done!** [See What's Next](#whats-next)

---

# macOS/Linux - Manual Setup

**Time:** ~5-7 minutes with full control

## Step 1: Create Virtual Environment

```bash
cd Streaming-Ingest

# Create venv
python3 -m venv streaming-ingest-example

# Activate (prompt should change)
source streaming-ingest-example/bin/activate

# Verify activation
which python  # Should show path inside streaming-ingest-example/
```

## Step 2: Install Dependencies

```bash
# Upgrade pip
pip install --upgrade pip

# Install requirements
pip install -r python/requirements.txt

# Verify installation
python -c "import pydantic, cryptography, requests; print('✓ All packages installed')"
```

## Step 3: Check Prerequisites

```bash
sh tools/check.sh
```

**Look for:**
- ✓ Snowflake CLI installed
- ✓ Python 3.8+
- ✓ All Python packages
- ✓ Config file structure

**If missing:** The tool will show exact commands to run.

## Step 4: Configure Snowflake

```bash
# Copy template
cp config/.env.example config/.env

# Edit configuration
nano config/.env  # or your preferred editor
```

**Fill in these values:**
```ini
SNOWFLAKE_ACCOUNT=xy12345.us-east-1  # Your account identifier
SNOWFLAKE_USER=your_username
SNOWFLAKE_PRIVATE_KEY_PATH=config/rsa_key.p8
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
```

## Step 5: Generate JWT Keys

```bash
# Create private key
openssl genrsa -out config/rsa_key.p8 2048

# Extract public key
openssl rsa -in config/rsa_key.p8 -pubout -out config/rsa_key.pub

# Display public key (for Snowflake)
cat config/rsa_key.pub
```

**Register in Snowflake:**
```sql
-- Run in Snowflake web UI or SnowSQL
ALTER USER your_username SET RSA_PUBLIC_KEY='MIIBIjANBg... (your key)';

-- Verify
DESC USER your_username;
```

## Step 6: Deploy SQL Scripts

Run each script in order:

```bash
snow sql -f sql/01_setup/01_database_and_schemas.sql
snow sql -f sql/01_setup/02_raw_table.sql
snow sql -f sql/01_setup/03_pipe_object.sql
snow sql -f sql/01_setup/04_staging_table.sql
snow sql -f sql/01_setup/05_dimension_tables.sql
snow sql -f sql/01_setup/06_fact_table.sql
snow sql -f sql/01_setup/07_stream.sql
snow sql -f sql/01_setup/08_tasks.sql
```

**Verify objects created:**
```sql
-- In Snowflake
USE DATABASE SNOWFLAKE_EXAMPLE;
SHOW SCHEMAS;
SHOW TABLES;
SHOW STREAMS;
SHOW TASKS;
```

## Step 7: Run Simulator

```bash
# Ensure venv is active
source streaming-ingest-example/bin/activate

# Start simulator
python -m python.simulator

# Let it run for 30-60 seconds, then Ctrl+C
```

**Watch for:**
- ✓ Channel opened successfully
- ✓ Rows inserted (batches of 100)
- ✓ No authentication errors

## Step 8: Validate Pipeline

```bash
sh tools/validate.sh quick
```

**Success looks like:**
```
Layer      | Row Count
-----------|----------
RAW        | 1200
STAGING    | 1200
ANALYTICS  | 1200

Stream Status: False (empty)
```

**If counts don't match:** Wait 1-2 minutes for tasks to process, then re-check.

**Done!** [See What's Next](#whats-next)

---

# Windows - Automated Setup

**Time:** ~5 minutes hands-off

This script creates a virtual environment, installs dependencies, and runs prerequisite checks automatically.

## Step 1: Run Setup Script

```powershell
cd Streaming-Ingest
tools\setup-env.bat
```

**What it does:**
1. Creates `streaming-ingest-example` venv
2. Installs all Python dependencies
3. Runs prerequisites check
4. Shows activation command for next time

## Step 2: Configure Snowflake

```powershell
# Copy template
copy config\.env.example config\.env

# Edit with your details
notepad config\.env
```

**Required fields:**
```ini
SNOWFLAKE_ACCOUNT=xy12345.us-east-1
SNOWFLAKE_USER=your_username
SNOWFLAKE_PRIVATE_KEY_PATH=config/rsa_key.p8
```

**Generate JWT keys** (use Git Bash or WSL):
```bash
# In Git Bash or WSL
openssl genrsa -out config/rsa_key.p8 2048
openssl rsa -in config/rsa_key.p8 -pubout -out config/rsa_key.pub

# Display public key
cat config/rsa_key.pub
```

Then in Snowflake:
```sql
ALTER USER your_username SET RSA_PUBLIC_KEY='<paste_key_here>';
```

## Step 3: Deploy to Snowflake

```powershell
# Run all setup scripts
cd sql\01_setup
snow sql -f 01_database_and_schemas.sql
snow sql -f 02_raw_table.sql
snow sql -f 03_pipe_object.sql
snow sql -f 04_staging_table.sql
snow sql -f 05_dimension_tables.sql
snow sql -f 06_fact_table.sql
snow sql -f 07_stream.sql
snow sql -f 08_tasks.sql
cd ..\..
```

## Step 4: Run Simulator

```powershell
# Activate venv if not already active
streaming-ingest-example\Scripts\activate

# Run simulator (Ctrl+C to stop after 30 seconds)
python -m python.simulator
```

**Expected output:**
```
INFO: Initializing RFID Simulator
INFO: Opening streaming channel...
INFO: Successfully inserted 100 rows
INFO: Successfully inserted 100 rows
...
```

## Step 5: Validate

```powershell
tools\validate.bat quick
```

**Expected:**
```
Layer      | Row Count
-----------|----------
RAW        | 1200
STAGING    | 1200
ANALYTICS  | 1200

Stream Status: False (empty)
✅ Pipeline working!
```

**Done!** [See What's Next](#whats-next)

---

# Windows - Manual Setup

**Time:** ~5-7 minutes with full control

## Step 1: Create Virtual Environment

```powershell
cd Streaming-Ingest

# Create venv
python -m venv streaming-ingest-example

# Activate (prompt should change)
streaming-ingest-example\Scripts\activate

# Verify activation
where python  # Should show path inside streaming-ingest-example\
```

## Step 2: Install Dependencies

```powershell
# Upgrade pip
python -m pip install --upgrade pip

# Install requirements
pip install -r python\requirements.txt

# Verify installation
python -c "import pydantic, cryptography, requests; print('✓ All packages installed')"
```

## Step 3: Check Prerequisites

```powershell
tools\check.bat
```

**Look for:**
- ✓ Snowflake CLI installed
- ✓ Python 3.8+
- ✓ All Python packages
- ✓ Config file structure

**If missing:** The tool will show exact commands to run.

## Step 4: Configure Snowflake

```powershell
# Copy template
copy config\.env.example config\.env

# Edit configuration
notepad config\.env
```

**Fill in these values:**
```ini
SNOWFLAKE_ACCOUNT=xy12345.us-east-1  # Your account identifier
SNOWFLAKE_USER=your_username
SNOWFLAKE_PRIVATE_KEY_PATH=config/rsa_key.p8
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
```

## Step 5: Generate JWT Keys

**Option A: Using Git Bash** (Recommended)
```bash
# Open Git Bash in the project directory
cd config

# Create private key
openssl genrsa -out rsa_key.p8 2048

# Extract public key
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub

# Display public key
cat rsa_key.pub
```

**Option B: Using WSL**
```bash
# In WSL terminal
cd /mnt/c/path/to/Streaming-Ingest/config
openssl genrsa -out rsa_key.p8 2048
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
cat rsa_key.pub
```

**Register in Snowflake:**
```sql
-- Run in Snowflake web UI
ALTER USER your_username SET RSA_PUBLIC_KEY='MIIBIjANBg... (your key)';

-- Verify
DESC USER your_username;
```

## Step 6: Deploy SQL Scripts

Run each script in order:

```powershell
snow sql -f sql\01_setup\01_database_and_schemas.sql
snow sql -f sql\01_setup\02_raw_table.sql
snow sql -f sql\01_setup\03_pipe_object.sql
snow sql -f sql\01_setup\04_staging_table.sql
snow sql -f sql\01_setup\05_dimension_tables.sql
snow sql -f sql\01_setup\06_fact_table.sql
snow sql -f sql\01_setup\07_stream.sql
snow sql -f sql\01_setup\08_tasks.sql
```

**Verify objects created:**
```sql
-- In Snowflake
USE DATABASE SNOWFLAKE_EXAMPLE;
SHOW SCHEMAS;
SHOW TABLES;
SHOW STREAMS;
SHOW TASKS;
```

## Step 7: Run Simulator

```powershell
# Ensure venv is active
streaming-ingest-example\Scripts\activate

# Start simulator
python -m python.simulator

# Let it run for 30-60 seconds, then Ctrl+C
```

**Watch for:**
- ✓ Channel opened successfully
- ✓ Rows inserted (batches of 100)
- ✓ No authentication errors

## Step 8: Validate Pipeline

```powershell
tools\validate.bat quick
```

**Success looks like:**
```
Layer      | Row Count
-----------|----------
RAW        | 1200
STAGING    | 1200
ANALYTICS  | 1200

Stream Status: False (empty)
```

**If counts don't match:** Wait 1-2 minutes for tasks to process, then re-check.

**Done!** [See What's Next](#whats-next)

---

# What's Next?

## ✅ You've Successfully:
- Created streaming ingestion pipeline
- Ingested RFID badge events
- Validated data flows through all layers
- Verified Streams + Tasks CDC pattern works

## 🚀 Next Steps:

### 1. Explore the Data
```sql
-- In Snowflake
USE DATABASE SNOWFLAKE_EXAMPLE;

-- View recent access events
SELECT * FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
ORDER BY event_timestamp DESC
LIMIT 100;

-- See active users
SELECT * FROM ANALYTICS_BADGE_TRACKING.DIM_USERS
WHERE is_current = TRUE;

-- Check zone activity
SELECT * FROM ANALYTICS_BADGE_TRACKING.DIM_ZONES;
```

### 2. Set Up Monitoring
See [`docs/05-MONITORING.md`](docs/05-MONITORING.md) for:
- Real-time dashboards
- Cost monitoring
- Performance metrics
- Data quality checks

### 3. Test REST API Directly
Use curl to send events (see [`README.md#tldr`](README.md#tldr-send-data-with-curl)):
```bash
# Get JWT token
export JWT_TOKEN=$(python -c "from python.simulator.auth import SnowflakeAuth; ...")

# Send events
curl -X POST ... (full example in README)
```

### 4. Customize for Your Use Case
- Modify badge event schema: `sql/01_setup/02_raw_table.sql`
- Add custom transformations: `sql/01_setup/03_pipe_object.sql`
- Extend analytics model: Add new dimension/fact tables
- Integrate with your BI tool (Tableau, Power BI, etc.)

## 📚 Full Documentation

- **Setup Guide**: [`docs/01-SETUP.md`](docs/01-SETUP.md)
- **Deployment**: [`docs/02-DEPLOYMENT.md`](docs/02-DEPLOYMENT.md)
- **Configuration**: [`docs/03-CONFIGURATION.md`](docs/03-CONFIGURATION.md)
- **Running**: [`docs/04-RUNNING.md`](docs/04-RUNNING.md)
- **Monitoring**: [`docs/05-MONITORING.md`](docs/05-MONITORING.md)
- **Architecture**: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

## ❓ Need Help?

### Common Issues:
- **Python not found**: Ensure Python 3.8+ is installed and in PATH
- **Permission denied**: Run `chmod +x tools/*.sh` (macOS/Linux)
- **Authentication failed**: Verify public key is registered in Snowflake
- **Counts don't match**: Wait 1-2 minutes for tasks to process

### Troubleshooting:
- **Detailed validation**: `python -m python.cli.validate full`
- **Check logs**: Review task execution history in Snowflake
- **Re-run checks**: `python -m python.cli.check`

### More Resources:
- **REST API Guide**: [`docs/REST_API_GUIDE.md`](docs/REST_API_GUIDE.md)
- **Data Dictionary**: [`docs/DATA_DICTIONARY.md`](docs/DATA_DICTIONARY.md)
- **Project README**: [`README.md`](README.md)

---

**🎉 Congratulations!** You've successfully deployed Snowflake native streaming ingestion!
