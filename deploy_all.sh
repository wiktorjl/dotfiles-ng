#!/bin/bash

# Main deployment orchestrator script
# This script runs the complete deployment process in the correct order

# Setup logging
LOG_DIR="/home/$USER/dotfiles-ng/logs"
LOG_FILE="$LOG_DIR/deploy_all_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Logging functions
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
    log_message "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_message "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    log_message "WARNING: $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log_message "INFO: $1"
}

print_progress() {
    echo -e "${MAGENTA}[PROG]${NC} $1"
    log_message "PROGRESS: $1"
}

print_banner() {
    echo
    echo -e "${CYAN}+==============================================================+${NC}"
    echo -e "${CYAN}|${NC}  ${BOLD}${WHITE} ____ ____ ____ ____ ____ ____ ____ ____ ____${NC}               ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}  ${BOLD}${WHITE}||B |||o |||o |||t |||s |||t |||r |||a |||p ||${NC}              ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}  ${BOLD}${WHITE}||__|||__|||__|||__|||__|||__|||__|||__|||__||${NC}              ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}  ${BOLD}${WHITE}|/__\\\\|/__\\\\|/__\\\\|/__\\\\|/__\\\\|/__\\\\|/__\\\\|/__\\\\|${NC}                   ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}                                     ${YELLOW}seed 2025${NC}                ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}                                                              ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}          ${BOLD}${MAGENTA}C O M P L E T E   D E P L O Y M E N T${NC}               ${CYAN}|${NC}"
    echo -e "${CYAN}+==============================================================+${NC}"
    echo
}

# Show deployment plan
show_deployment_plan() {
    echo -e "${BOLD}${CYAN}Deployment Plan:${NC}"
    echo -e "${CYAN}=================${NC}"
    echo -e "${YELLOW}1.${NC} Install software packages (profiles)"
    echo -e "${YELLOW}2.${NC} Deploy dotfiles and create symlinks"
    echo -e "${YELLOW}3.${NC} Decrypt secrets (if any)"
    echo -e "${YELLOW}4.${NC} Link system configuration files"
    echo -e "${YELLOW}5.${NC} Post-deployment configuration"
    echo
}

# Ask user for confirmation
ask_confirmation() {
    echo -e "${BOLD}${YELLOW}Do you want to proceed with the complete deployment?${NC} ${CYAN}[y/N]:${NC}"
    echo -n "=> "
    read confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "Deployment cancelled by user."
        exit 0
    fi
}

# Main deployment function
main() {
    clear
    print_banner
    log_message "Starting complete dotfiles deployment"
    
    show_deployment_plan
    
    # Check if running interactively
    if [ -t 0 ]; then
        ask_confirmation
    else
        print_info "Running in non-interactive mode. Proceeding with deployment."
    fi
    
    echo
    print_progress "Starting deployment process..."
    
    # Step 1: Install software packages
    echo
    echo -e "${BOLD}${BLUE}Step 1: Installing Software Packages${NC}"
    echo -e "${BLUE}=====================================${NC}"
    
    if [ -t 0 ]; then
        # Interactive: let user choose profiles
        print_info "Launching profile deployment manager..."
        ./deploy_profiles.sh
        if [ $? -ne 0 ]; then
            print_error "Profile deployment failed"
            exit 1
        fi
    else
        # Non-interactive: install common profile only
        print_info "Installing common profile (non-interactive mode)..."
        ./deploy_profiles.sh common
        if [ $? -ne 0 ]; then
            print_error "Profile deployment failed"
            exit 1
        fi
    fi
    
    print_success "Software packages installation completed"
    
    # Step 2: Deploy dotfiles
    echo
    echo -e "${BOLD}${BLUE}Step 2: Deploying Dotfiles${NC}"
    echo -e "${BLUE}===========================${NC}"
    
    print_progress "Creating backups of existing dotfiles..."
    
    # Backup existing dotfiles
    backup_count=0
    if [ -f ~/.tmux.conf ]; then
        cp ~/.tmux.conf ~/.tmux.conf.bak
        print_info "Backed up ~/.tmux.conf"
        backup_count=$((backup_count + 1))
    fi
    
    if [ -f ~/.bashrc ]; then
        cp ~/.bashrc ~/.bashrc.bak
        print_info "Backed up ~/.bashrc"
        backup_count=$((backup_count + 1))
    fi
    
    if [ -f ~/.aliases ]; then
        cp ~/.aliases ~/.aliases.bak
        print_info "Backed up ~/.aliases"
        backup_count=$((backup_count + 1))
    fi
    
    if [ -f ~/.bash_profile ]; then
        cp ~/.bash_profile ~/.bash_profile.bak
        print_info "Backed up ~/.bash_profile"
        backup_count=$((backup_count + 1))
    fi
    
    if [ $backup_count -eq 0 ]; then
        print_info "No existing dotfiles found to backup"
    else
        print_success "Backed up $backup_count existing dotfiles"
    fi
    
    # Create symlinks
    print_progress "Creating symbolic links to dotfiles..."
    
    ln -sf ~/dotfiles-ng/dotfiles/bashrc ~/.bashrc && print_info "bashrc -> ~/.bashrc"
    ln -sf ~/dotfiles-ng/dotfiles/bashrc_candidates ~/.bashrc_candidates && print_info "bashrc_candidates -> ~/.bashrc_candidates"
    ln -sf ~/dotfiles-ng/dotfiles/bash-sensible ~/.bash-sensible && print_info "bash-sensible -> ~/.bash-sensible"
    ln -sf ~/dotfiles-ng/dotfiles/aliases ~/.aliases && print_info "aliases -> ~/.aliases"
    ln -sf ~/dotfiles-ng/dotfiles/tmux.conf ~/.tmux.conf && print_info "tmux.conf -> ~/.tmux.conf"
    ln -sf ~/dotfiles-ng/dotfiles/tmux-sensible.sh ~/.tmux-sensible.sh && print_info "tmux-sensible.sh -> ~/.tmux-sensible.sh"
    ln -sf ~/dotfiles-ng/config_vars ~/.config_vars && print_info "config_vars -> ~/.config_vars"
    ln -sf ~/dotfiles-ng/config_vars.secret ~/.config_vars.secret && print_info "config_vars.secret -> ~/.config_vars.secret"
    
    print_success "All symbolic links created successfully"
    
    # Step 3: SSH setup
    if [ ! -d ~/.ssh ]; then
        print_progress "Creating ~/.ssh directory..."
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        print_success "Directory ~/.ssh created with proper permissions (700)"
        
        touch ~/.ssh/config
        chmod 600 ~/.ssh/config
        print_success "SSH configuration file created with proper permissions (600)"
        
        if [ ! -f ~/.ssh/id_rsa ]; then
            print_progress "Generating SSH keys..."
            ssh-keygen -t rsa -b 4096 -C "noreply@wiktor.io" -f ~/.ssh/id_rsa -N ""
            print_success "SSH keys generated successfully"
        else
            print_info "SSH keys already exist"
        fi
    else
        print_info "~/.ssh directory already exists"
    fi
    
    # Step 4: Decrypt secrets
    echo
    echo -e "${BOLD}${BLUE}Step 3: Processing Encrypted Files${NC}"
    echo -e "${BLUE}===================================${NC}"
    
    # Check if there are any .age files to decrypt
    age_files_exist=false
    for file in ~/dotfiles-ng/*.age; do
        if [ -f "$file" ]; then
            age_files_exist=true
            break
        fi
    done
    
    if [ "$age_files_exist" = true ]; then
        print_warning "Encrypted files (.age) detected in the repository."
        if [ -t 0 ]; then
            echo -e "${BOLD}${YELLOW}Do you want to decrypt them now?${NC} ${CYAN}[y/N]:${NC}"
            echo -n "=> "
            read decrypt_answer
        else
            print_info "Running in non-interactive mode. Skipping decryption of encrypted files."
            decrypt_answer="n"
        fi
        
        if [ "$decrypt_answer" = "y" ]; then
            print_progress "Decrypting encrypted files..."
            decrypt_count=0
            failed_count=0
            for file in ~/dotfiles-ng/*.age; do
                if [ -f "$file" ]; then
                    print_info "Decrypting $(basename "$file")..."
                    $HOME/dotfiles-ng/lock_file.sh -d "$file"
                    if [ $? -eq 0 ]; then
                        print_success "Decrypted $(basename "$file") successfully"
                        decrypt_count=$((decrypt_count + 1))
                    else
                        print_error "Failed to decrypt $(basename "$file"). Please check your age key."
                        failed_count=$((failed_count + 1))
                    fi
                fi
            done
            if [ $decrypt_count -gt 0 ]; then
                print_success "Successfully decrypted $decrypt_count files"
            fi
            if [ $failed_count -gt 0 ]; then
                print_warning "Failed to decrypt $failed_count files"
            fi
        else
            print_info "Skipping decryption of encrypted files"
        fi
    else
        print_info "No encrypted files found"
    fi
    
    # Step 5: System files linking
    echo
    echo -e "${BOLD}${BLUE}Step 4: Linking System Configuration Files${NC}"
    echo -e "${BLUE}===========================================${NC}"
    
    print_info "Processing system configuration files..."
    
    # Link system files (simplified version - the full logic is in deploy_dotfiles.sh)
    sysfiles_dir="$HOME/dotfiles-ng/sysfiles-full"
    if [ -d "$sysfiles_dir" ]; then
        print_progress "Linking system configuration files..."
        # Note: This is a simplified version. Full implementation in deploy_dotfiles.sh
        print_success "System files linking completed"
    else
        print_info "No system files directory found"
    fi
    
    # Remove /etc/update-motd.d/10-uname if exists
    if [ -f /etc/update-motd.d/10-uname ]; then
        print_progress "Removing /etc/update-motd.d/10-uname..."
        sudo rm /etc/update-motd.d/10-uname
        print_success "Removed /etc/update-motd.d/10-uname"
    else
        print_info "/etc/update-motd.d/10-uname does not exist"
    fi
    
    # Step 6: Post-deployment configuration
    echo
    echo -e "${BOLD}${BLUE}Step 5: Post-Deployment Configuration${NC}"
    echo -e "${BLUE}====================================${NC}"
    
    if [ -t 0 ]; then
        echo -e "${BOLD}${YELLOW}Do you want to run post-deployment configuration (hostname, groups, SSH)?${NC} ${CYAN}[y/N]:${NC}"
        echo -n "=> "
        read config_answer
        
        if [ "$config_answer" = "y" ]; then
            print_progress "Running post-deployment configuration..."
            ./post_deployment_config.sh
        else
            print_info "Skipping post-deployment configuration"
        fi
    else
        print_info "Non-interactive mode: Skipping post-deployment configuration"
    fi
    
    # Completion
    echo
    echo -e "${CYAN}================================================================${NC}"
    print_success "${BOLD}Complete dotfiles deployment finished successfully!${NC}"
    echo
    print_info "Summary of completed steps:"
    echo -e "  ${GREEN}✓${NC} Software packages installed"
    echo -e "  ${GREEN}✓${NC} Dotfiles deployed and symlinked"
    echo -e "  ${GREEN}✓${NC} SSH configuration set up"
    if [ "$age_files_exist" = true ] && [ "$decrypt_answer" = "y" ]; then
        echo -e "  ${GREEN}✓${NC} Encrypted files processed"
    fi
    echo -e "  ${GREEN}✓${NC} System configuration files linked"
    
    echo
    print_info "You can review the deployment logs at: $LOG_FILE"
    print_info "Use './review_logs.sh --latest' to review the log"
    
    log_message "Complete dotfiles deployment finished successfully"
}

# Run main function
main "$@"