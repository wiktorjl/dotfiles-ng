# Dotfiles Management System

A comprehensive dotfiles and system configuration management solution for Linux environments. This system provides automated deployment of configuration files, system packages, and development tools using a profile-based approach.

## Features

- **Profile-based installation**: Modular software stacks (common, desktop, dev, docker, pentest)
- **Dotfiles management**: Automated symlinking with backup of existing files
- **System status monitoring**: Fast, cached system information display (sysrod)
- **Encryption support**: Built-in file encryption/decryption with age
- **Docker testing**: Test deployments in isolated containers
- **Git-aware**: Tracks dotfiles repository status

## First Time Setup

### Prerequisites

- Git
- Bash 4.0+
- Sudo privileges
- Internet connection

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url> ~/dotfiles-ng
   cd ~/dotfiles-ng
   ```

2. **Run complete deployment**
   ```bash
   ./deploy_all.sh
   ```

   This orchestrates the full deployment:
   - Installs packages from selected profiles
   - Deploys dotfiles (creates symlinks)
   - Runs post-deployment configuration
   - Links utility scripts to `~/.local/bin`

3. **Select profiles when prompted**

   Available profiles:
   - **common**: Base packages, networking, system monitoring, security tools (recommended)
   - **desktop**: GUI applications (Brave, Spotify, etc.)
   - **dev**: Development tools (VS Code, Python, Go, Rust, Ruby)
   - **docker**: Docker installation and configuration
   - **pentest**: Security testing tools (Metasploit, Burp, SecLists)

4. **Reload your shell**
   ```bash
   source ~/.bashrc
   ```

### What Gets Installed

- **Dotfiles**: Symlinked from `dotfiles/` to `~/`
  - `.bashrc`, `.bash_aliases`, `.tmux.conf`, etc.
  - `.config/` directory contents

- **System files**: Symlinked from `sysfiles-full/` and `sysfiles-partial/`

- **Utility scripts**: Linked to `~/.local/bin/`
  - `sysrod.sh`: System status display
  - `update_sysrod_cache.sh`: Cache updater for system status
  - `check_dotfiles_status.sh`: Git status checker
  - `lock_file.sh`: File encryption/decryption
  - Various VM and system management scripts

## Updating Your Installation

### Update Dotfiles and Scripts

When you pull new changes from the repository:

1. **Pull latest changes**
   ```bash
   cd ~/dotfiles-ng
   git pull
   ```

2. **Relink bin scripts** (if new scripts were added)
   ```bash
   ./link_bin_scripts.sh common
   # Repeat for other profiles if you use them:
   # ./link_bin_scripts.sh dev
   # ./link_bin_scripts.sh desktop
   ```

3. **Redeploy dotfiles** (if configuration files changed)
   ```bash
   ./deploy_dotfiles.sh
   ```

4. **Update packages** (if package lists changed)
   ```bash
   ./deploy_profiles.sh
   # Select the profiles you want to update
   ```

### Update System Status Cache

The system status display (sysrod) uses a cache for fast terminal startup. To manually refresh:

```bash
update_sysrod_cache.sh
```

The cache updates automatically every 15 minutes in the background.

## Key Commands

### Complete Deployment
```bash
./deploy_all.sh        # Complete deployment: packages + dotfiles + configuration
```

### Individual Components
```bash
./deploy_profiles.sh   # Install software packages only
./deploy_dotfiles.sh   # Deploy dotfiles only
./link_bin_scripts.sh <profile>  # Relink bin scripts from a profile
```

### Post-Deployment Configuration
```bash
./post_deployment_config.sh   # Set hostname, domain, add user to groups
```

### Testing
```bash
./run_docker_test.sh   # Test deployment in Docker container
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

## System Status Display (sysrod)

The system status is displayed automatically on every new terminal session. It shows:

- **System**: User@host, distribution, kernel version
- **Resources**: CPU load, memory usage, disk space
- **Process info**: Running processes, logged-in users
- **Status**: Uptime, virtualization type, dotfiles git status

### How It Works

- **Fast startup**: Reads from cache (~2-5ms), never blocks terminal
- **Auto-refresh**: Cache updates every 15 minutes in background
- **Offline support**: Shows last known status when offline
- **Status indicators**:
  - `[UPDATING...]`: First terminal, building cache
  - `[STALE - updating...]`: Cache older than 15 minutes, refreshing in background

### Manual Cache Update
```bash
update_sysrod_cache.sh
```

## Architecture

### Profile System
Located in `profiles/`, each profile contains:
- **packages/**: Text files listing packages (one per line)
- **init-scripts/**: Run before package installation (e.g., add repositories)
- **post-scripts/**: Run after package installation
- **bin/**: Scripts symlinked to `~/.local/bin`

### Dotfiles
Located in `dotfiles/`, these are symlinked to `~/`:
- Shell configuration (bashrc, aliases)
- Application configs (`.config/` directory)
- Tool configurations (tmux, git, etc.)

### System Files
- **sysfiles-full/**: Complete system files (replaces target)
- **sysfiles-partial/**: Partial configs (merged with existing)

### Configuration
- **config_vars**: Environment variables
- **config_vars.secret.age**: Encrypted secrets (age encryption)

## Development

### Adding New Packages

1. Edit the appropriate `.packages` file in `profiles/<profile>/packages/`
2. Run `./deploy_profiles.sh` and select the profile

### Adding New Scripts

1. Add script to `profiles/<profile>/bin/`
2. Make it executable: `chmod +x <script>`
3. Run `./link_bin_scripts.sh <profile>`

### Testing Changes

Use Docker for isolated testing:
```bash
./run_docker_test.sh
# Inside container:
./deploy_all.sh
```

## Troubleshooting

### Scripts not found after update
```bash
./link_bin_scripts.sh common
```

### Dotfiles not updating
```bash
./deploy_dotfiles.sh
```

### System status not showing
```bash
# Check cache
cat ~/.cache/sysrod/status.cache

# Rebuild cache
rm -rf ~/.cache/sysrod
update_sysrod_cache.sh

# Check if sysrod.sh is sourced in bashrc
grep sysrod ~/.bashrc
```

### Package installation fails
Check logs:
```bash
./review_logs.sh --latest
```

## TODO List

- bashimu installation
- bootstrap file
- key packs deployment (and bootstrap)
- media packs deployment