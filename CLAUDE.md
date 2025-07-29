# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a dotfiles management system for Linux environments that provides automated deployment of configuration files, system packages, and development tools. The system is profile-based, allowing selective installation of different software stacks.

## Key Commands

### Deploy Dotfiles
```bash
./deploy_dotfiles.sh   # Main deployment script - backs up existing dotfiles and creates symlinks
```

### Deploy Profiles (Software Packages)
```bash
./deploy_profiles.sh   # Interactive script to select and install profile-based packages
# Profiles available: common, desktop, dev, docker, pentest
# Can select multiple profiles at once (e.g., "1 3 4")
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

## Architecture Overview

### Profile System
- **profiles/** - Contains modular software installation profiles
  - Each profile has subdirectories:
    - **packages/** - Text files listing packages to install (e.g., base.packages, net.packages)
    - **init-scripts/** - Scripts run during profile setup (e.g., adding repositories)
    - **post-scripts/** - Scripts run after package installation
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

### Key Scripts
- **deploy_dotfiles.sh** - Main entry point, optionally installs base packages, then symlinks dotfiles
- **deploy_profiles.sh** - Interactive profile selector, reads package lists and executes init/post scripts
- **lock_file.sh** - Helper script for file locking during operations
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