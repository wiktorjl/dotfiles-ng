# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a dotfiles management system for Linux environments that provides automated deployment of configuration files, system packages, and development tools. The system is profile-based, allowing selective installation of different software stacks.

## Key Commands

### Complete Deployment (Recommended)
```bash
./deploy_all.sh        # Complete deployment: packages + dotfiles + configuration
# Orchestrates the entire deployment process in correct order
```

### Individual Components
```bash
./deploy_profiles.sh   # Install software packages only (profiles: common, desktop, dev, docker, pentest)
./deploy_dotfiles.sh   # Deploy dotfiles only - backs up existing dotfiles and creates symlinks
```

### Post-Deployment Configuration
```bash
./post_deployment_config.sh   # Sets hostname, domain, and adds user to necessary groups
```

### Testing
```bash
./run_docker_test.sh   # Builds and runs a Docker container for testing dotfile deployment
# Inside container: ./deploy_all.sh to test full deployment
```

### File Encryption/Decryption
```bash
./lock_file.sh <file>           # Encrypt file with age
./lock_file.sh -d <file.age>    # Decrypt age-encrypted file
```

### Log Review
```bash
./review_logs.sh                # Show usage and list all log files
./review_logs.sh --errors       # Show only error logs
./review_logs.sh --latest       # Show latest deployment log
./review_logs.sh --summary      # Show deployment summary
./review_logs.sh --all          # Show all logs
```

## Architecture Overview

### Profile System
- **profiles/** - Contains modular software installation profiles
  - Each profile has subdirectories:
    - **packages/** - Text files listing packages to install (e.g., base.packages, net.packages)
    - **init-scripts/** - Scripts run during profile setup (e.g., adding repositories)
    - **post-scripts/** - Scripts run after package installation
    - **bin/** - Scripts that get symlinked to ~/.local/bin
  - Available profiles:
    - **common** - Base packages, networking, system monitoring, security tools
    - **desktop** - GUI applications (Brave, Spotify, Bashimu)
    - **dev** - Development tools (VS Code, languages: Python, Go, Rust, Ruby)
    - **docker** - Docker installation and configuration
    - **pentest** - Security testing tools (Metasploit, Burp, SecLists)

### Dotfiles Management
- **dotfiles/** - Contains actual configuration files to be symlinked
  - bashrc, aliases, tmux.conf, bash-sensible
  - .config/ subdirectory for application configs
- Deployment creates symlinks from home directory to these files
- Original files are backed up with .bak extension

### System Files
- **sysfiles-full/** - Complete system configuration files (e.g., /etc files)
- **sysfiles-partial/** - Partial system configuration snippets
- System files are symlinked to their proper locations with backup of originals

### Key Scripts
- **deploy_all.sh** - Main orchestrator, runs complete deployment in correct order
- **deploy_dotfiles.sh** - Handles dotfiles linking and system configuration only
- **deploy_profiles.sh** - Interactive profile selector, reads package lists, executes init/post scripts, and links bin scripts
- **link_bin_scripts.sh** - Links profile bin scripts to ~/.local/bin and optionally /usr/local/bin (called by deploy_profiles.sh)
- **lock_file.sh** - Helper script for file encryption/decryption using age
- **post_deployment_config.sh** - Sets hostname and adds user to groups (docker, libvirt, kvm, etc.)

### Configuration
- **config_vars** - Environment variable definitions
- **config_vars.secret.age** - Encrypted secrets (using age encryption)

## Development Workflow

1. Test changes using Docker: `./run_docker_test.sh`
2. Modify dotfiles in `dotfiles/` directory
3. Add new packages to appropriate `.packages` files in `profiles/*/packages/`
4. Create init/post scripts in profiles as needed for complex installations
5. Run deployment scripts to apply changes

## Profile Package Management

Package files in `profiles/*/packages/` contain one package per line. Comments starting with # are ignored.
- **base.packages** - Core system utilities
- **net.packages** - Networking tools
- **sysmon.packages** - System monitoring tools
- **syssec.packages** - Security tools
- **dev-*.packages** - Language-specific development tools

## Custom Scripts

The `profiles/common/bin/` directory contains utility scripts that are symlinked to `~/.local/bin`:
- **sysrod.sh** - System status monitoring script
- **check_ip.sh** - IP address checker
- **create_backup.sh** - Backup creation utility
- Various proxy, browser, and system management scripts

## Non-Interactive Installation

Scripts support non-interactive mode when run via pipe. For example:
```bash
echo "y" | ./deploy_dotfiles.sh   # Auto-confirms base package installation
```

## TODO Items

From README.md:
- bashimu installation
- bootstrap file
- key packs deployment (and bootstrap)
- media packs deployment