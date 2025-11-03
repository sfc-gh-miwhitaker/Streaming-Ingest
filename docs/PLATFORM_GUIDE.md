# Platform-Specific Guide

This project is designed to work on **Windows**, **macOS**, and **Linux**. This guide explains the platform-specific differences and how to use the tools on each system.

## Quick Reference

| Task | Windows | macOS/Linux |
|------|---------|-------------|
| Check Prerequisites | `tools\check` | `tools/check` |
| Validate Pipeline | `tools\validate` | `tools/validate` |
| Run Simulator | `tools\simulate` | `tools/simulate` |
| Run Setup SQL | Use Snowflake CLI | Use Snowflake CLI |

## Universal Python Commands

All platforms can use Python commands directly:

```bash
# Check prerequisites
python -m python.cli.check --auto-update

# Validate pipeline
python -m python.cli.validate quick

# Run simulator
python -m python.simulator
```

## Windows-Specific Instructions

### Prerequisites

1. **Python 3.8+**: Download from [python.org](https://www.python.org/downloads/)
   - ✅ Check "Add Python to PATH" during installation
   
2. **Snowflake CLI**: Download from [Snowflake Documentation](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/installation/installation)

3. **PowerShell or Command Prompt**: Built-in to Windows

### Running Commands

```powershell
# Check prerequisites with auto-update
tools/check --auto-update

# Deploy to Snowflake
tools/deploy

# Run simulator
tools/simulate

# Validate pipeline
tools/validate quick
```

### Path Separators

Windows uses backslashes (`\`) for paths:
```
config\.env
python\simulator\simulator.py
```

### Line Endings

Windows uses CRLF (`\r\n`). Git should handle this automatically, but if you encounter issues:

```powershell
git config core.autocrlf true
```

### Private Key Generation

On Windows, use Git Bash or WSL for OpenSSL commands:

```bash
# Generate development key pair
openssl genrsa -out config/rsa_key.p8 2048
openssl rsa -in config/rsa_key.p8 -pubout -out config/rsa_key.pub
```

## macOS-Specific Instructions

### Prerequisites

1. **Python 3.8+**: Pre-installed on macOS 10.15+, or install via:
   ```bash
   brew install python@3.11
   ```

2. **Snowflake CLI**: 
   ```bash
   brew tap snowflake/snowcli
   brew install snowflake
   ```

### Running Commands

```bash
# Check prerequisites
tools/check --auto-update

# Install Python dependencies
pip3 install -r python/requirements.txt

# Configure environment
cp config/.env.example config/.env
# Edit config/.env with your credentials

# Run simulator
tools/simulate

# Validate pipeline
tools/validate quick
```

### Make Scripts Executable

If you get "Permission denied":

```bash
chmod +x tools/check tools/deploy tools/simulate tools/validate
```

## Linux-Specific Instructions

### Prerequisites

1. **Python 3.8+**:
   ```bash
   # Ubuntu/Debian
   sudo apt update && sudo apt install python3 python3-pip
   
   # RHEL/CentOS/Fedora
   sudo yum install python3 python3-pip
   
   # Arch
   sudo pacman -S python python-pip
   ```

2. **Snowflake CLI**: Download from [Snowflake Documentation](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/installation/installation)

### Running Commands

```bash
# Check prerequisites
./check_prerequisites.sh --auto-update

# Install Python dependencies
pip3 install -r python/requirements.txt

# Configure environment
cp config/.env.example config/.env
# Edit config/.env with your credentials

# Run simulator
python3 -m python.simulator

# Validate pipeline
./validate_pipeline.sh quick
```

### Make Scripts Executable

```bash
chmod +x check_prerequisites.sh
chmod +x validate_pipeline.sh
```

## Common Cross-Platform Issues

### Issue: Python command not found

**Solution:**
- Windows: Ensure "Add Python to PATH" was checked during install, or add manually
- macOS/Linux: Try `python3` instead of `python`

### Issue: Permission denied (macOS/Linux)

**Solution:**
```bash
chmod +x <script_name>.sh
```

### Issue: Script won't run (Windows)

**Solution:**
- Use `.bat` files instead of `.sh` files
- Or run PowerShell as Administrator if blocked by execution policy:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

### Issue: Line ending problems

**Windows Solution:**
```powershell
git config core.autocrlf true
```

**macOS/Linux Solution:**
```bash
git config core.autocrlf input
```

### Issue: Module not found

**Solution:**
```bash
# Ensure you're in the project root
cd path/to/Streaming-Ingest

# Install dependencies
pip install -r python/requirements.txt

# Verify installation
python -c "import pydantic; print('OK')"
```

## Environment Variables

### Setting Environment Variables

**Windows (PowerShell):**
```powershell
$env:SNOWFLAKE_ACCOUNT = "myaccount"
```

**Windows (Command Prompt):**
```cmd
set SNOWFLAKE_ACCOUNT=myaccount
```

**macOS/Linux (bash/zsh):**
```bash
export SNOWFLAKE_ACCOUNT="myaccount"
```

### Loading from .env File

The project automatically loads variables from `config/.env` - no manual export needed!

## File Paths in Configuration

### Windows

Use either forward slashes or escaped backslashes:

```ini
# Both work on Windows
SNOWFLAKE_PRIVATE_KEY_PATH=config/rsa_key.p8
SNOWFLAKE_PRIVATE_KEY_PATH=config\\rsa_key.p8
```

### macOS/Linux

Use forward slashes:

```ini
SNOWFLAKE_PRIVATE_KEY_PATH=config/rsa_key.p8
```

### Absolute Paths (All Platforms)

Python handles both styles:

```ini
# Windows
SNOWFLAKE_PRIVATE_KEY_PATH=C:/Users/username/keys/rsa_key.p8

# macOS/Linux
SNOWFLAKE_PRIVATE_KEY_PATH=/home/username/keys/rsa_key.p8
```

## Testing Your Setup

Run this command on any platform to verify everything works:

```bash
python -m python.cli.check
```

Expected output:
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
  ✓ Configuration file exists: config/.env
  ✓ SNOWFLAKE_ACCOUNT configured
  ✓ SNOWFLAKE_USER configured
  ✓ SNOWFLAKE_PRIVATE_KEY_PATH configured

Checking JWT private key...
  ✓ Private key file exists: config/rsa_key.p8

============================================================================
✓ All prerequisites satisfied!
============================================================================
```

## Getting Help

If you encounter platform-specific issues:

1. Check this guide first
2. Verify Python and Snowflake CLI are installed: 
   ```bash
   python --version
   snow --version
   ```
3. Try the universal Python command format
4. Check the project's GitHub Issues page

## Contributing

When contributing code:

- ✅ Test on Windows, macOS, and Linux if possible
- ✅ Use Python scripts for cross-platform logic
- ✅ Provide both `.sh` and `.bat` wrappers for convenience
- ✅ Use `pathlib.Path` for file paths in Python
- ✅ Document any platform-specific requirements

