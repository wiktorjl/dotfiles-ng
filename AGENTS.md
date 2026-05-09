# AGENTS.md

This file provides guidance for agentic coding assistants working in the dotfiles-ng repository.

## Repository Overview

This is a profile-based Linux dotfiles management system that automates deployment of configuration files, system packages, and development tools. The codebase consists primarily of Bash scripts with some configuration files.

## Build/Lint/Test Commands

### Testing
```bash
./run_docker_test.sh                    # Build and run Docker container for testing
./deploy_all.sh                         # Full deployment test inside container
```

### Manual Testing
```bash
./deploy_profiles.sh <profile>          # Test single profile deployment
./deploy_dotfiles.sh                    # Test dotfile deployment only
./link_bin_scripts.sh <profile>         # Test bin script linking
```

### No Automated Linting
This repository does not use automated linting tools. When modifying scripts:
- Ensure scripts start with proper shebang (`#!/bin/bash` or `#!/usr/bin/env bash`)
- Test scripts manually before committing
- Follow existing code patterns in the file you're editing
- Use `set -euo pipefail` for critical scripts that should fail fast

## Code Style Guidelines

### Shebang and Strict Mode
- Use `#!/bin/bash` for scripts requiring bash-specific features
- Use `#!/usr/bin/env bash` for maximum portability
- For critical deployment scripts, add `set -euo pipefail` after shebang
- Example: `#!/usr/bin/env bash` followed by `set -euo pipefail`

### Color Output
Scripts that output to terminal should define color constants at the top:
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'  # No Color
```

### Logging and Output Functions
Use standard logging function patterns:
- `log_message()` - General logging with timestamp
- `log_error()` - Error logging (writes to error log file)
- `log_command()` - Execute and log commands with exit code tracking
- `print_success()` - Success messages with [OK] prefix
- `print_error()` - Error messages with [ERROR] prefix
- `print_warning()` - Warning messages with [WARN] prefix
- `print_info()` - Informational messages with [INFO] prefix
- `print_progress()` - Progress indicators with [PROG] prefix

Always include timestamps in log files: `[$(date '+%Y-%m-%d %H:%M:%S')]`

### Function Naming
- Use lowercase with underscores: `function_name()`
- Prefix with descriptive category: `print_`, `log_`, `check_`, `install_`, etc.
- Group related functions together with section headers

### Variable Naming
- UPPERCASE for constants: `RED`, `GREEN`, `LOG_DIR`, `BASE_DIR`
- Lowercase for local variables: `package`, `profile_name`, `exit_code`
- Use `local` keyword for function-local variables

### Error Handling
- Check exit codes after critical commands: `if [ $? -ne 0 ]`
- Use `||` for inline error handling when appropriate
- Log errors with `log_error()` before exiting
- Clean up temporary files/resources in error paths
- Return non-zero exit codes on failure

### Conditional Statements
- Use `[[ ]]` for string and pattern matching
- Use `[ ]` for simple tests (file existence, numeric comparison)
- Quote variables to prevent word splitting: `"$variable"`
- Use `if` blocks with proper indentation (2 or 4 spaces)

### Package Files (.packages)
- One package per line
- Comments start with `#`
- Empty lines and whitespace are ignored
- Scripts automatically de-duplicate packages

### Profile Structure
```
profiles/<name>/
├── README.md                    # Description (first line used for display)
├── packages/
│   ├── base.packages          # Core packages
│   └── category.packages       # Additional categories
├── init-scripts/
│   └── setup.sh               # Run before package installation
├── post-scripts/
│   └── config.sh              # Run after package installation
└── bin/
    └── utility.sh             # Scripts linked to ~/.local/bin
```

### Init Scripts vs Post Scripts
- **Init scripts**: Run before package installation. Used for:
  - Adding software repositories
  - Installing GPG keys
  - Setting up dependencies
  - Follow with `apt update` after adding repos
- **Post scripts**: Run after package installation. Used for:
  - Application-specific configuration
  - Downloading additional tools
  - Creating symlinks or aliases
  - System configuration

### Bin Scripts
- Scripts in `profiles/*/bin/` are automatically symlinked
- Linked to `~/.local/bin` during profile deployment
- Can also be linked to `/usr/local/bin` with `--system` flag
- Should be executable (`chmod +x`)

### Comments and Documentation
- Use `#` for single-line comments
- Add section headers before logical blocks: `# Function to...`
- Include usage examples in script headers for bin scripts
- Comment complex logic or non-obvious operations
- No inline comments for obvious operations

### Environment Variables
- Define at top of script or sourced from `config_vars`
- Use UPPERCASE: `DEBIAN_FRONTEND=noninteractive`
- Export only when necessary for child processes
- Never commit secret values; use encrypted `.age` files

### Non-Interactive Mode
Scripts should support non-interactive mode via pipe:
```bash
echo "y" | ./deploy_profiles.sh
```
Detect non-interactive mode: `if [ -t 0 ]; then`

### Docker Testing
Dockerfile builds Debian container with:
- User `bob` (password: `bob`) with sudo NOPASSWD
- All scripts made executable
- SSH server for remote testing
- Helper scripts in home directory for quick testing

### Logging
- Create log directory: `mkdir -p "$LOG_DIR"`
- Use timestamped log files: `$(date +%Y%m%d_%H%M%S)`
- Log to both stdout and file with `tee -a`
- Separate error logs for easier debugging
- Log commands before execution: `log_message "EXECUTING: $cmd"`

### Exit Codes
- Use `exit 0` for success
- Use `exit 1` for errors (or specific codes if meaningful)
- Use `return` in functions, `exit` in main script flow
- Capture and check exit codes of external commands
