#!/bin/bash
# ============================================================================
# Check Prerequisites and Update Snowflake CLI
# ============================================================================
# Purpose: Verify that required tools are installed and up-to-date before
#          running the RFID Badge Tracking streaming ingestion demo.
#
# Usage: ./scripts/check_prerequisites.sh [--auto-update]
#
# Options:
#   --auto-update    Automatically update Snowflake CLI if outdated
# ============================================================================

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

AUTO_UPDATE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-update)
            AUTO_UPDATE=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: $0 [--auto-update]"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}RFID Badge Tracking: Prerequisites Check${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""

# Function to check command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to compare versions (basic semver)
version_compare() {
    local ver1=$1
    local ver2=$2
    
    if [[ "$ver1" == "$ver2" ]]; then
        return 0
    fi
    
    local IFS=.
    local i ver1_arr=($ver1) ver2_arr=($ver2)
    
    for ((i=0; i<${#ver1_arr[@]} || i<${#ver2_arr[@]}; i++)); do
        if [[ -z ${ver2_arr[i]} ]]; then
            ver2_arr[i]=0
        fi
        if [[ -z ${ver1_arr[i]} ]]; then
            ver1_arr[i]=0
        fi
        if ((10#${ver1_arr[i]} > 10#${ver2_arr[i]})); then
            return 1
        fi
        if ((10#${ver1_arr[i]} < 10#${ver2_arr[i]})); then
            return 2
        fi
    done
    return 0
}

ISSUES_FOUND=0

# ============================================================================
# Check 1: Snowflake CLI
# ============================================================================
echo -e "${YELLOW}Checking Snowflake CLI...${NC}"

if command_exists snow; then
    CURRENT_VERSION=$(snow --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    echo -e "  ${GREEN}✓${NC} Snowflake CLI installed: v${CURRENT_VERSION}"
    
    # Check for updates
    echo "  Checking for updates..."
    
    if $AUTO_UPDATE; then
        echo "  Running: snow update"
        if snow update 2>&1; then
            NEW_VERSION=$(snow --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            if [[ "$NEW_VERSION" != "$CURRENT_VERSION" ]]; then
                echo -e "  ${GREEN}✓${NC} Updated to v${NEW_VERSION}"
            else
                echo -e "  ${GREEN}✓${NC} Already on latest version"
            fi
        else
            echo -e "  ${YELLOW}⚠${NC} Update command failed (may require manual update)"
        fi
    else
        echo -e "  ${YELLOW}ℹ${NC} To update, run: ${BLUE}snow update${NC}"
        echo -e "  ${YELLOW}ℹ${NC} Or re-run this script with: ${BLUE}./scripts/check_prerequisites.sh --auto-update${NC}"
    fi
else
    echo -e "  ${RED}✗${NC} Snowflake CLI not found"
    echo -e "    Install from: ${BLUE}https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/installation/installation${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo ""

# ============================================================================
# Check 2: Python
# ============================================================================
echo -e "${YELLOW}Checking Python...${NC}"

if command_exists python; then
    PYTHON_VERSION=$(python --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    echo -e "  ${GREEN}✓${NC} Python installed: v${PYTHON_VERSION}"
    
    # Check minimum version (3.8+)
    REQUIRED_VERSION="3.8.0"
    if version_compare "$PYTHON_VERSION" "$REQUIRED_VERSION"; then
        result=$?
        if [[ $result -eq 2 ]]; then
            echo -e "  ${RED}✗${NC} Python version too old (requires 3.8+)"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    fi
else
    echo -e "  ${RED}✗${NC} Python not found"
    echo -e "    Install from: ${BLUE}https://www.python.org/downloads/${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo ""

# ============================================================================
# Check 3: Python Dependencies
# ============================================================================
echo -e "${YELLOW}Checking Python dependencies...${NC}"

if command_exists python; then
    REQUIRED_PACKAGES=("pydantic" "python-dotenv" "cryptography" "requests")
    MISSING_PACKAGES=()
    
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if python -c "import ${package}" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} ${package} installed"
        else
            echo -e "  ${RED}✗${NC} ${package} not found"
            MISSING_PACKAGES+=("$package")
        fi
    done
    
    if [[ ${#MISSING_PACKAGES[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${YELLOW}ℹ${NC} To install missing packages, run:"
        echo -e "    ${BLUE}pip install -r python/requirements.txt${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Skipping (Python not found)"
fi

echo ""

# ============================================================================
# Check 4: Configuration
# ============================================================================
echo -e "${YELLOW}Checking configuration...${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/config/.env"

if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "  ${GREEN}✓${NC} Configuration file exists: config/.env"
    
    # Check for required keys
    REQUIRED_VARS=("SNOWFLAKE_ACCOUNT" "SNOWFLAKE_USER" "SNOWFLAKE_PRIVATE_KEY_PATH")
    MISSING_VARS=()
    
    for var in "${REQUIRED_VARS[@]}"; do
        if grep -q "^${var}=" "$CONFIG_FILE" && ! grep -q "^${var}=$" "$CONFIG_FILE"; then
            echo -e "  ${GREEN}✓${NC} ${var} configured"
        else
            echo -e "  ${YELLOW}⚠${NC} ${var} not set or empty"
            MISSING_VARS+=("$var")
        fi
    done
    
    if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${YELLOW}ℹ${NC} Please configure missing variables in: ${BLUE}config/.env${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
else
    echo -e "  ${RED}✗${NC} Configuration file not found: config/.env"
    echo -e "    Copy template: ${BLUE}cp config/.env.example config/.env${NC}"
    echo -e "    Then edit config/.env with your Snowflake credentials"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo ""

# ============================================================================
# Check 5: Private Key
# ============================================================================
echo -e "${YELLOW}Checking JWT private key...${NC}"

if [[ -f "$CONFIG_FILE" ]]; then
    KEY_PATH=$(grep "^SNOWFLAKE_PRIVATE_KEY_PATH=" "$CONFIG_FILE" | cut -d'=' -f2-)
    
    if [[ -n "$KEY_PATH" ]] && [[ -f "$KEY_PATH" ]]; then
        echo -e "  ${GREEN}✓${NC} Private key file exists: ${KEY_PATH}"
    elif [[ -n "$KEY_PATH" ]]; then
        echo -e "  ${RED}✗${NC} Private key file not found: ${KEY_PATH}"
        echo -e "    Generate key pair with: ${BLUE}./scripts/setup_auth.sh${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} Private key path not configured"
        echo -e "    Generate key pair with: ${BLUE}./scripts/setup_auth.sh${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Skipping (config file not found)"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo -e "${BLUE}============================================================================${NC}"

if [[ $ISSUES_FOUND -eq 0 ]]; then
    echo -e "${GREEN}✓ All prerequisites satisfied!${NC}"
    echo ""
    echo -e "Next steps:"
    echo -e "  1. Run setup: ${BLUE}./scripts/run_setup_sqls.sh${NC}"
    echo -e "  2. Start simulator: ${BLUE}python -m python.rfid_simulator.simulator${NC}"
    echo -e "  3. Validate pipeline: ${BLUE}./scripts/validate_pipeline.sh quick${NC}"
else
    echo -e "${YELLOW}⚠ Found ${ISSUES_FOUND} issue(s) that need attention${NC}"
    echo ""
    echo -e "Please resolve the issues above before proceeding."
    exit 1
fi

echo -e "${BLUE}============================================================================${NC}"
echo ""

