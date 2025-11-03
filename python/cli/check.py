"""
Cross-platform prerequisites checker.

Verifies that all required tools and configurations are in place before
running the RFID Badge Tracking demo.
"""

import os
import sys
import subprocess
import re
from pathlib import Path
from typing import Tuple, List, Optional
import argparse


class Colors:
    """ANSI color codes for terminal output (works on Windows 10+, macOS, Linux)."""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color
    
    @classmethod
    def disable(cls):
        """Disable colors for Windows systems that don't support ANSI."""
        cls.RED = cls.GREEN = cls.YELLOW = cls.BLUE = cls.NC = ''


# Enable ANSI colors on Windows 10+
if sys.platform == 'win32':
    import platform
    if int(platform.version().split('.')[0]) >= 10:
        os.system('')  # Enable ANSI escape sequences
    else:
        Colors.disable()


class PrerequisitesChecker:
    """Check and validate all prerequisites for the project."""
    
    def __init__(self, auto_update: bool = False):
        self.auto_update = auto_update
        self.issues_found = 0
        self.warnings_found = 0
        self.project_root = Path(__file__).parent.parent.parent
        
    def print_header(self):
        """Print header."""
        print(f"{Colors.BLUE}{'=' * 76}{Colors.NC}")
        print(f"{Colors.BLUE}RFID Badge Tracking: Prerequisites Check{Colors.NC}")
        print(f"{Colors.BLUE}{'=' * 76}{Colors.NC}")
        print()
    
    def check_virtual_environment(self) -> bool:
        """Check if running in a virtual environment and guide user if not."""
        print(f"{Colors.YELLOW}Checking Python environment...{Colors.NC}")
        
        # Check if in virtual environment
        in_venv = hasattr(sys, 'real_prefix') or (
            hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix
        )
        
        # Detect conda environment from environment variables
        conda_env_var = os.environ.get('CONDA_DEFAULT_ENV', '')
        
        # Check if actually running from a project venv (check sys.prefix path)
        venv_path = self.project_root / 'streaming-ingest-example'
        alt_venv_path = self.project_root / 'venv'
        
        # Determine which venv path to use
        if venv_path.exists():
            primary_venv = venv_path
        elif alt_venv_path.exists():
            primary_venv = alt_venv_path
        else:
            primary_venv = None
        
        venv_exists = primary_venv is not None
        
        # Check if sys.prefix points to our project venv (most reliable check)
        running_from_project_venv = False
        if venv_exists and in_venv:
            # Resolve both paths to compare properly
            try:
                sys_prefix_resolved = Path(sys.prefix).resolve()
                project_venv_resolved = primary_venv.resolve()
                running_from_project_venv = sys_prefix_resolved == project_venv_resolved
            except Exception:
                running_from_project_venv = False
        
        # Priority: Check if running from project venv first (overrides conda detection)
        if running_from_project_venv:
            # Running in proper project venv
            print(f"  {Colors.GREEN}✓{Colors.NC} Running in project virtual environment: {primary_venv.name}")
            print()
            return True
        
        elif in_venv and not running_from_project_venv:
            # Running in some other venv (not project venv)
            print(f"  {Colors.YELLOW}⚠{Colors.NC} Running in virtual environment: {sys.prefix}")
            print(f"    This is not the project venv. Recommended: use project venv")
            if venv_exists:
                print(f"    Project venv exists at: {primary_venv}")
            self.warnings_found += 1
            print()
            return True
        
        elif conda_env_var and conda_env_var != 'base':
            # In a conda environment (not base) - acceptable but not preferred
            print(f"  {Colors.YELLOW}⚠{Colors.NC} Running in conda environment: {conda_env_var}")
            print(f"    Recommended: Use project-specific venv for better isolation")
            self.warnings_found += 1
            print()
            return True
        
        else:
            # Not in venv or in conda base - needs fixing
            if conda_env_var == 'base':
                print(f"  {Colors.RED}✗{Colors.NC} Running in conda base environment")
                print(f"    This violates project standards - dependencies should be isolated")
            else:
                print(f"  {Colors.RED}✗{Colors.NC} Not running in a virtual environment")
            
            print()
            print(f"  {Colors.YELLOW}{'─' * 72}{Colors.NC}")
            print(f"  {Colors.YELLOW}Required Action: Create and activate a virtual environment{Colors.NC}")
            print(f"  {Colors.YELLOW}{'─' * 72}{Colors.NC}")
            print()
            
            if venv_exists:
                print(f"  {Colors.GREEN}✓{Colors.NC} Virtual environment already exists at: {primary_venv}")
                print(f"    You just need to activate it")
                print()
            else:
                print(f"  {Colors.BLUE}Automated Setup Available!{Colors.NC}")
                print(f"    Run the setup script to create environment automatically:")
                print()
                if sys.platform == 'win32':
                    print(f"    tools\\setup-env.bat")
                else:
                    print(f"    sh tools/setup-env.sh")
                print()
                print(f"  {Colors.BLUE}Or create manually:{Colors.NC}")
                print(f"    cd {self.project_root}")
                print(f"    python -m venv streaming-ingest-example")
                print()
            
            if venv_exists:
                print(f"  {Colors.BLUE}Manual Activation:{Colors.NC}")
                if sys.platform == 'win32':
                    venv_name = primary_venv.name
                    print(f"    {venv_name}\\Scripts\\activate.bat")
                else:
                    venv_name = primary_venv.name
                    print(f"    source {venv_name}/bin/activate")
                print()
                print(f"  {Colors.BLUE}Or use automated setup:{Colors.NC}")
                if sys.platform == 'win32':
                    print(f"    tools\\setup-env.bat")
                else:
                    print(f"    sh tools/setup-env.sh")
            else:
                print(f"  {Colors.BLUE}After activation:{Colors.NC}")
                print(f"    pip install -r python/requirements.txt")
                if sys.platform == 'win32':
                    print(f"    tools\\check.bat")
                else:
                    print(f"    sh tools/check.sh")
            
            print()
            print(f"  {Colors.YELLOW}Your prompt should change to show: (venv){Colors.NC}")
            print()
            
            self.issues_found += 1
            return False
    
    def check_command_exists(self, command: str) -> bool:
        """Check if a command exists in PATH."""
        try:
            result = subprocess.run(
                [command, '--version'],
                capture_output=True,
                text=True,
                timeout=5
            )
            return result.returncode == 0
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return False
    
    def get_version(self, command: str, pattern: str = r'(\d+\.\d+\.\d+)') -> Optional[str]:
        """Get version of a command."""
        try:
            result = subprocess.run(
                [command, '--version'],
                capture_output=True,
                text=True,
                timeout=5
            )
            match = re.search(pattern, result.stdout + result.stderr)
            return match.group(1) if match else None
        except Exception:
            return None
    
    def version_compare(self, ver1: str, ver2: str) -> int:
        """
        Compare two semantic versions.
        Returns: 1 if ver1 > ver2, -1 if ver1 < ver2, 0 if equal
        """
        v1_parts = [int(x) for x in ver1.split('.')]
        v2_parts = [int(x) for x in ver2.split('.')]
        
        for i in range(max(len(v1_parts), len(v2_parts))):
            v1 = v1_parts[i] if i < len(v1_parts) else 0
            v2 = v2_parts[i] if i < len(v2_parts) else 0
            
            if v1 > v2:
                return 1
            elif v1 < v2:
                return -1
        
        return 0
    
    def check_snowflake_cli(self) -> bool:
        """Check Snowflake CLI installation and version."""
        print(f"{Colors.YELLOW}Checking Snowflake CLI...{Colors.NC}")
        
        if not self.check_command_exists('snow'):
            print(f"  {Colors.RED}✗{Colors.NC} Snowflake CLI not found")
            print(f"    Install from: {Colors.BLUE}https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/installation/installation{Colors.NC}")
            self.issues_found += 1
            return False
        
        version = self.get_version('snow')
        print(f"  {Colors.GREEN}✓{Colors.NC} Snowflake CLI installed: v{version}")
        
        # Check for updates
        print("  Checking for updates...")
        
        if self.auto_update:
            try:
                print("  Running: snow update")
                result = subprocess.run(
                    ['snow', 'update'],
                    capture_output=True,
                    text=True,
                    timeout=60
                )
                
                new_version = self.get_version('snow')
                if new_version and new_version != version:
                    print(f"  {Colors.GREEN}✓{Colors.NC} Updated to v{new_version}")
                else:
                    print(f"  {Colors.GREEN}✓{Colors.NC} Already on latest version")
            except Exception as e:
                print(f"  {Colors.YELLOW}⚠{Colors.NC} Update command failed: {e}")
        else:
            print(f"  {Colors.YELLOW}ℹ{Colors.NC} To update, run: {Colors.BLUE}snow update{Colors.NC}")
            print(f"  {Colors.YELLOW}ℹ{Colors.NC} Or re-run with: {Colors.BLUE}python -m python.cli.check --auto-update{Colors.NC}")
        
        print()
        return True
    
    def check_python(self) -> bool:
        """Check Python version."""
        print(f"{Colors.YELLOW}Checking Python...{Colors.NC}")
        
        version = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
        print(f"  {Colors.GREEN}✓{Colors.NC} Python installed: v{version}")
        
        # Check minimum version (3.8+)
        if self.version_compare(version, "3.8.0") < 0:
            print(f"  {Colors.RED}✗{Colors.NC} Python version too old (requires 3.8+)")
            self.issues_found += 1
            print()
            return False
        
        print()
        return True
    
    def check_python_packages(self) -> bool:
        """Check required Python packages."""
        print(f"{Colors.YELLOW}Checking Python dependencies...{Colors.NC}")
        
        # Map package names to their import names (when they differ)
        required_packages = {
            'pydantic': 'pydantic',
            'python-dotenv': 'dotenv',  # python-dotenv imports as 'dotenv'
            'cryptography': 'cryptography',
            'requests': 'requests'
        }
        
        missing_packages = []
        
        for package_name, import_name in required_packages.items():
            try:
                __import__(import_name)
                print(f"  {Colors.GREEN}✓{Colors.NC} {package_name} installed")
            except ImportError:
                print(f"  {Colors.RED}✗{Colors.NC} {package_name} not found")
                missing_packages.append(package_name)
        
        if missing_packages:
            print()
            print(f"  {Colors.YELLOW}ℹ{Colors.NC} To install missing packages, run:")
            print(f"    {Colors.BLUE}pip install -r python/requirements.txt{Colors.NC}")
            self.issues_found += 1
        
        print()
        return len(missing_packages) == 0
    
    def check_configuration(self) -> bool:
        """Check configuration file."""
        print(f"{Colors.YELLOW}Checking configuration...{Colors.NC}")
        
        config_file = self.project_root / 'config' / '.env'
        
        if not config_file.exists():
            print(f"  {Colors.RED}✗{Colors.NC} Configuration file not found: config/.env")
            print(f"    Copy template: {Colors.BLUE}cp config/.env.example config/.env{Colors.NC}")
            print(f"    Then edit config/.env with your Snowflake credentials")
            self.issues_found += 1
            print()
            return False
        
        print(f"  {Colors.GREEN}✓{Colors.NC} Configuration file exists: config/.env")
        
        # Check for required keys
        required_vars = [
            'SNOWFLAKE_ACCOUNT',
            'SNOWFLAKE_USER',
            'SNOWFLAKE_PRIVATE_KEY_PATH'
        ]
        
        missing_vars = []
        
        with open(config_file, 'r') as f:
            content = f.read()
            
        for var in required_vars:
            # Check if variable is set and not empty
            pattern = rf'^{var}=(.+)$'
            match = re.search(pattern, content, re.MULTILINE)
            
            if match and match.group(1).strip():
                print(f"  {Colors.GREEN}✓{Colors.NC} {var} configured")
            else:
                print(f"  {Colors.YELLOW}⚠{Colors.NC} {var} not set or empty")
                missing_vars.append(var)
        
        if missing_vars:
            print()
            print(f"  {Colors.YELLOW}ℹ{Colors.NC} Please configure missing variables in: {Colors.BLUE}config/.env{Colors.NC}")
            self.issues_found += 1
        
        print()
        return len(missing_vars) == 0
    
    def check_private_key(self) -> bool:
        """Check JWT private key."""
        print(f"{Colors.YELLOW}Checking JWT private key...{Colors.NC}")
        
        config_file = self.project_root / 'config' / '.env'
        
        if not config_file.exists():
            print(f"  {Colors.YELLOW}⚠{Colors.NC} Skipping (config file not found)")
            print()
            return False
        
        # Read key path from config
        with open(config_file, 'r') as f:
            for line in f:
                if line.startswith('SNOWFLAKE_PRIVATE_KEY_PATH='):
                    key_path_str = line.split('=', 1)[1].strip()
                    
                    if not key_path_str:
                        print(f"  {Colors.YELLOW}⚠{Colors.NC} Private key path not configured")
                        print(f"    Generate key pair with: {Colors.BLUE}tools/setup-auth{Colors.NC} (coming soon)")
                        self.issues_found += 1
                        print()
                        return False
                    
                    # Resolve path relative to project root if needed
                    key_path = Path(key_path_str)
                    if not key_path.is_absolute():
                        key_path = self.project_root / key_path
                    
                    if key_path.exists():
                        print(f"  {Colors.GREEN}✓{Colors.NC} Private key file exists: {key_path}")
                        print()
                        return True
                    else:
                        print(f"  {Colors.RED}✗{Colors.NC} Private key file not found: {key_path}")
                        print(f"    Generate key pair with: {Colors.BLUE}tools/setup-auth{Colors.NC} (coming soon)")
                        self.issues_found += 1
                        print()
                        return False
        
        print(f"  {Colors.YELLOW}⚠{Colors.NC} Private key path not configured")
        print()
        return False
    
    def print_summary(self):
        """Print summary."""
        print(f"{Colors.BLUE}{'=' * 76}{Colors.NC}")
        
        if self.issues_found == 0 and self.warnings_found == 0:
            print(f"{Colors.GREEN}✓ All prerequisites satisfied!{Colors.NC}")
            print()
            print("Next steps:")
            if sys.platform == 'win32':
                print(f"  1. Deploy SQL: {Colors.BLUE}tools\\deploy.bat{Colors.NC}")
                print(f"  2. Start simulator: {Colors.BLUE}tools\\simulate.bat{Colors.NC}")
                print(f"  3. Validate pipeline: {Colors.BLUE}tools\\validate.bat{Colors.NC}")
            else:
                print(f"  1. Deploy SQL: {Colors.BLUE}sh tools/deploy.sh{Colors.NC}")
                print(f"  2. Start simulator: {Colors.BLUE}sh tools/simulate.sh{Colors.NC}")
                print(f"  3. Validate pipeline: {Colors.BLUE}sh tools/validate.sh{Colors.NC}")
        elif self.issues_found == 0 and self.warnings_found > 0:
            print(f"{Colors.GREEN}✓ All prerequisites satisfied{Colors.NC} {Colors.YELLOW}({self.warnings_found} warning(s)){Colors.NC}")
            print()
            print("You can proceed, but consider addressing the warnings above.")
        else:
            print(f"{Colors.YELLOW}⚠ Found {self.issues_found} issue(s) that need attention{Colors.NC}")
            print()
            print("Please resolve the issues above before proceeding.")
        
        print(f"{Colors.BLUE}{'=' * 76}{Colors.NC}")
        print()
        
        return self.issues_found == 0
    
    def run(self) -> bool:
        """Run all checks."""
        self.print_header()
        
        # Check virtual environment FIRST - most critical
        venv_ok = self.check_virtual_environment()
        
        # If not in venv, stop here and guide user
        if not venv_ok:
            print(f"{Colors.BLUE}{'=' * 76}{Colors.NC}")
            print(f"{Colors.YELLOW}⚠ Virtual environment required{Colors.NC}")
            print()
            print("Please activate your virtual environment and re-run this check.")
            print(f"{Colors.BLUE}{'=' * 76}{Colors.NC}")
            print()
            return False
        
        # Continue with other checks
        self.check_snowflake_cli()
        self.check_python()
        self.check_python_packages()
        self.check_configuration()
        self.check_private_key()
        
        return self.print_summary()


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Check prerequisites for RFID Badge Tracking demo"
    )
    
    parser.add_argument(
        '--auto-update',
        action='store_true',
        help='Automatically update Snowflake CLI if outdated'
    )
    
    args = parser.parse_args()
    
    checker = PrerequisitesChecker(auto_update=args.auto_update)
    success = checker.run()
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

