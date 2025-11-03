#!/bin/bash
# Automated virtual environment setup for Streaming Ingest project
# Creates venv, activates it, installs dependencies, and runs checks

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VENV_NAME="streaming-ingest-example"
VENV_PATH="$PROJECT_ROOT/$VENV_NAME"

echo "============================================================================"
echo "Streaming Ingest: Automated Environment Setup"
echo "============================================================================"
echo

# Check if Python is available
if ! command -v python &> /dev/null && ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python not found"
    echo "   Please install Python 3.8+ from https://python.org"
    exit 1
fi

# Use python3 if available, otherwise python
PYTHON_CMD="python3"
if ! command -v python3 &> /dev/null; then
    PYTHON_CMD="python"
fi

echo "Step 1: Creating virtual environment '$VENV_NAME'..."
if [ -d "$VENV_PATH" ]; then
    echo "   ⚠️  Virtual environment already exists at: $VENV_PATH"
    read -p "   Remove and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "   Removing existing environment..."
        rm -rf "$VENV_PATH"
        echo "   Creating new environment..."
        $PYTHON_CMD -m venv "$VENV_PATH"
        echo "   ✓ Virtual environment created"
    else
        echo "   Using existing environment"
    fi
else
    $PYTHON_CMD -m venv "$VENV_PATH"
    echo "   ✓ Virtual environment created"
fi
echo

echo "Step 2: Activating virtual environment..."
source "$VENV_PATH/bin/activate"
echo "   ✓ Activated: $VIRTUAL_ENV"
echo

echo "Step 3: Upgrading pip..."
pip install --upgrade pip --quiet
echo "   ✓ pip upgraded"
echo

echo "Step 4: Installing project dependencies..."
pip install -r "$PROJECT_ROOT/python/requirements.txt" --quiet
echo "   ✓ Dependencies installed"
echo

echo "Step 5: Running prerequisites check..."
echo
"$VENV_PATH/bin/python" "$PROJECT_ROOT/python/cli/check.py"
CHECK_EXIT_CODE=$?
echo

if [ $CHECK_EXIT_CODE -eq 0 ]; then
    echo "============================================================================"
    echo "✅ Setup Complete!"
    echo "============================================================================"
    echo
    echo "Your environment is ready. To activate it in future sessions, run:"
    echo
    echo "    source $VENV_NAME/bin/activate"
    echo
    echo "Or use this script again: sh tools/setup-env.sh"
    echo
else
    echo "============================================================================"
    echo "⚠️  Setup completed with warnings"
    echo "============================================================================"
    echo
    echo "Please review the issues above and configure:"
    echo "  - Snowflake connection (config/.env)"
    echo "  - JWT private key"
    echo
    echo "Your virtual environment is active. To reactivate later:"
    echo
    echo "    source $VENV_NAME/bin/activate"
    echo
fi

