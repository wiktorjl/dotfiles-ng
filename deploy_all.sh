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
    echo -e "${YELLOW}2.${NC} Deploy dotfiles and system configuration"
    echo -e "${YELLOW}3.${NC} Post-deployment configuration"
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
    echo -e "${BOLD}${BLUE}Step 2: Deploying Dotfiles and Configuration${NC}"
    echo -e "${BLUE}=============================================${NC}"
    
    print_progress "Running dotfiles deployment script..."
    
    if [ -t 0 ]; then
        # Interactive mode: run deploy_dotfiles.sh with user interaction
        echo "y" | ./deploy_dotfiles.sh --no-banner
    else
        # Non-interactive mode: run deploy_dotfiles.sh with auto-confirmation
        echo "y" | ./deploy_dotfiles.sh --no-banner
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Dotfiles deployment completed successfully"
    else
        print_error "Dotfiles deployment failed"
        exit 1
    fi
    
    # Step 3: Post-deployment configuration
    echo
    echo -e "${BOLD}${BLUE}Step 3: Post-Deployment Configuration${NC}"
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
    echo -e "  ${GREEN}✓${NC} Dotfiles deployed and configuration applied"
    echo -e "  ${GREEN}✓${NC} System configuration files linked"
    
    echo
    print_info "You can review the deployment logs at: $LOG_FILE"
    print_info "Use './review_logs.sh --latest' to review the log"
    
    log_message "Complete dotfiles deployment finished successfully"
}

# Run main function
main "$@"