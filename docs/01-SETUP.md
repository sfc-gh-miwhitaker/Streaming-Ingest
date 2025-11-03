# 01 - Setup & Prerequisites

**Goal:** Install all required tools and verify your environment is ready.

**Time:** ~10 minutes

**Next:** [`02-DEPLOYMENT.md`](02-DEPLOYMENT.md) - Deploy to Snowflake

---

## Overview

This guide ensures you have everything needed to run the RFID Badge Tracking streaming ingestion demo. We'll verify:
- ✓ Snowflake account access
- ✓ Snowflake CLI installation
- ✓ Python 3.8+ with required packages
- ✓ Configuration files

## Prerequisites

### Required

1. **Snowflake Account**
   - Any edition (Standard, Enterprise, Business Critical)
   - AWS region preferred (demo tested on AWS)
   - Account administrator or equivalent privileges

2. **Python 3.8 or Higher**
   - Download: [python.org/downloads](https://www.python.org/downloads/)
   - Verify: `python --version` or `python3 --version`

3. **Snowflake CLI v3.0+**
   - Install: [Snowflake CLI Documentation](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/installation/installation)
   - Verify: `snow --version`

### Optional

- **Git** (for cloning repository)
- **Text Editor** (VS Code, Sublime, etc.)

---

## Step 1: Create Virtual Environment (MANDATORY)

**Option A: Automated Setup (RECOMMENDED)**

The easiest way - this script creates the venv, installs dependencies, and runs checks:

```bash
# macOS/Linux
sh tools/setup-env.sh

# Windows
tools\setup-env.bat
```

This script will:
1. Create a virtual environment named `streaming-ingest-example`
2. Activate it automatically
3. Install all Python dependencies
4. Run the prerequisites check
5. Tell you how to reactivate it later

**Option B: Manual Setup**

If you prefer manual control:

```bash
# Navigate to project root
cd Streaming-Ingest

# Create virtual environment
python -m venv streaming-ingest-example

# Activate it
# macOS/Linux:
source streaming-ingest-example/bin/activate

# Windows (Command Prompt):
streaming-ingest-example\Scripts\activate.bat

# Windows (PowerShell):
streaming-ingest-example\Scripts\Activate.ps1
```

**Verify activation** - your prompt should show the venv name:
```
(streaming-ingest-example) user@machine Streaming-Ingest %
```

**Install dependencies:**
```bash
pip install -r python/requirements.txt
```

---

## Step 2: Check Prerequisites

Run the automated prerequisites checker:

**Windows:**
```powershell
tools\check.bat
```

**macOS/Linux:**
```bash
sh tools/check.sh
```

**All Platforms (Python):**
```bash
python -m python.cli.check
```

### Expected Output

```
============================================================================
RFID Badge Tracking: Prerequisites Check
============================================================================

Checking Snowflake CLI...
  ✓ Snowflake CLI installed: v3.0.2

Checking Python...
  ✓ Python installed: v3.11.5

Checking Python dependencies...
  ✓ pydantic installed
  ✓ python-dotenv installed
  ✓ cryptography installed
  ✓ requests installed

Checking configuration...
  ⚠ Configuration file not found: config/.env

============================================================================
⚠ Found 1 issue(s) that need attention
============================================================================
```

---

## Step 2: Install Missing Components

### If Snowflake CLI is Missing

**Windows:**
- Download installer from [Snowflake Documentation](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/installation/installation)
- Run installer and follow prompts

**macOS (Homebrew):**
```bash
brew tap snowflake/snowcli
brew install snowflake
```

**Linux:**
```bash
# Download and install from Snowflake docs
# Package managers vary by distribution
```

### If Python is Missing or Too Old

**Windows:**
- Download from [python.org](https://www.python.org/downloads/)
- ✅ Check "Add Python to PATH" during installation

**macOS (Homebrew):**
```bash
brew install python@3.11
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install python3 python3-pip

# RHEL/CentOS
sudo yum install python3 python3-pip

# Arch
sudo pacman -S python python-pip
```

### If Python Packages are Missing

```bash
# Install from requirements file
pip install -r python/requirements.txt

# Or install individually
pip install pydantic python-dotenv cryptography requests
```

---

## Step 3: Update Snowflake CLI (Recommended)

Keep your CLI up-to-date to avoid compatibility issues:

```bash
# Check for updates and install
snow update
```

Or use the automated checker:

```bash
# Windows
tools\check --auto-update

# macOS/Linux
tools/check --auto-update

# Python (all platforms)
python -m python.cli.check --auto-update
```

---

## Step 4: Verify Your Snowflake Account

### Get Your Account Identifier

Log into Snowflake and find your account identifier:

**Format:** `ORGNAME-ACCOUNTNAME`  
**Example:** `MYORG-PROD_AWS`

**Not this:** `myorg-prod.snowflakecomputing.com` ❌

### Test Connection

```bash
snow connection test
```

If not configured, you'll be prompted to set up a connection. We'll do this in Step 5.

---

## Step 5: Configure Snowflake Connection

### Option A: Using Snowflake CLI (Recommended)

```bash
# Add a connection
snow connection add

# Follow prompts:
# - Connection name: streaming-ingest
# - Account: YOUR_ACCOUNT_IDENTIFIER
# - User: YOUR_USERNAME
# - Password or key-pair: (we'll use key-pair in 03-CONFIGURATION)
```

### Option B: Manual Configuration

Create `~/.snowflake/config.toml`:

```toml
[connections.streaming-ingest]
account = "ORGNAME-ACCOUNTNAME"
user = "YOUR_USERNAME"
# We'll add key-pair auth in 03-CONFIGURATION
```

---

## Platform-Specific Notes

### Windows

**PowerShell Execution Policy:**
If you get "script execution is disabled":
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Path Separators:**
Windows uses backslashes (`\`) in paths:
```powershell
python\requirements.txt
config\.env
```

### macOS/Linux

**Make Scripts Executable:**
```bash
chmod +x tools/check tools/deploy tools/simulate tools/validate
```

**Python Command:**
If `python` doesn't work, try `python3`:
```bash
python3 --version
python3 -m python.cli.check
```

---

## Verification Checklist

Before proceeding to deployment, verify:

- [ ] Snowflake CLI installed (`snow --version`)
- [ ] Python 3.8+ installed (`python --version`)
- [ ] Python packages installed (`pip list | grep pydantic`)
- [ ] Snowflake account accessible
- [ ] Connection configured (`snow connection test`)

---

## Troubleshooting

### Issue: "command not found: snow"

**Cause:** Snowflake CLI not in PATH

**Solution:**
- **Windows:** Reinstall CLI, ensure "Add to PATH" is checked
- **macOS/Linux:** Add to shell profile:
  ```bash
  export PATH="$PATH:/path/to/snow"
  ```

### Issue: "command not found: python"

**Cause:** Python not in PATH or not installed

**Solution:**
- Verify installation: `which python` or `which python3`
- Try `python3` instead of `python`
- Reinstall Python with "Add to PATH" option

### Issue: "Permission denied" (macOS/Linux)

**Cause:** Scripts not executable

**Solution:**
```bash
chmod +x tools/check tools/deploy tools/simulate tools/validate
```

### Issue: "Module not found: pydantic"

**Cause:** Python packages not installed

**Solution:**
```bash
pip install -r python/requirements.txt
```

### Issue: "Cannot connect to Snowflake"

**Cause:** Network, credentials, or account identifier issue

**Solution:**
1. Verify account identifier (no `.snowflakecomputing.com`)
2. Check network/firewall
3. Verify credentials
4. Try: `snow connection test --debug`

---

## Next Steps

✅ **Prerequisites verified!** 

Continue to:
👉 **[02-DEPLOYMENT.md](02-DEPLOYMENT.md)** - Deploy the data pipeline to Snowflake

---

## Additional Resources

- **Platform-Specific Help:** [`PLATFORM_GUIDE.md`](PLATFORM_GUIDE.md)
- **Snowflake CLI Docs:** [docs.snowflake.com](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2)
- **Python Installation:** [python.org](https://www.python.org/)
- **Quick Start:** [`../QUICKSTART.md`](../QUICKSTART.md) for 5-minute demo

---

**Guide:** 01-SETUP | **Next:** [02-DEPLOYMENT](02-DEPLOYMENT.md) →

