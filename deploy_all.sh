#!/bin/bash

# Main deployment orchestrator script
# This script runs the complete deployment process in the correct order

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Shared logging + TUI helpers (colors, print_*, log_message).
LOG_NAME=deploy_all
# shellcheck disable=SC1091
. "$BASE_DIR/lib/log.sh"
# shellcheck disable=SC1091
. "$BASE_DIR/lib/pkg.sh"

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
    read -r confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "Deployment cancelled by user."
        exit 0
    fi
}

# Check for required tools. lib/pkg.sh has already refused to load on
# non-Debian-likes, so apt-get is guaranteed available here.
check_required_tools() {
    local missing_tools=()
    command -v sudo >/dev/null 2>&1 || missing_tools+=("sudo")
    command -v curl >/dev/null 2>&1 || missing_tools+=("curl")

    if [ ${#missing_tools[@]} -eq 0 ]; then
        print_success "All required tools are available"
        return 0
    fi

    print_error "Missing required tools: ${missing_tools[*]}"
    echo
    print_info "These tools are required for the deployment process."
    echo -e "${BOLD}${YELLOW}Do you want to install the missing tools?${NC} ${CYAN}[y/N]:${NC}"
    echo -n "=> "

    if [ -t 0 ]; then
        read -r install_tools
    else
        install_tools="y"
        print_info "Non-interactive mode: Auto-accepting tool installation"
    fi

    if [[ "$install_tools" != "y" && "$install_tools" != "Y" ]]; then
        print_error "Required tools not available. Deployment cannot continue."
        exit 1
    fi

    print_progress "Installing missing tools..."
    # Bootstrap path: sudo itself may be missing, so we may need to run as root
    # directly. After sudo lands, pkg_install handles the rest.
    if [ "$(id -u)" -eq 0 ]; then
        apt-get update -qq && apt-get install -y -qq --no-install-recommends "${missing_tools[@]}"
    else
        pkg_update && pkg_install "${missing_tools[@]}"
    fi

    for tool in "${missing_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            print_success "$tool installed successfully"
        else
            print_error "Failed to install $tool"
            exit 1
        fi
    done
}

# Main deployment function
main() {
    clear
    print_banner
    log_message "Starting complete dotfiles deployment"

    # Check for required tools first
    check_required_tools

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
        "$BASE_DIR/deploy_profiles.sh"
        if [ $? -ne 0 ]; then
            print_error "Profile deployment failed"
            exit 1
        fi
    else
        # Non-interactive: install common profile only
        print_info "Installing common profile (non-interactive mode)..."
        "$BASE_DIR/deploy_profiles.sh" common
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
        "$BASE_DIR/deploy_dotfiles.sh" --no-banner
    else
        # Non-interactive mode: skip prompts that require a terminal
        "$BASE_DIR/deploy_dotfiles.sh" --no-banner --non-interactive
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
        read -r config_answer
        
        if [ "$config_answer" = "y" ]; then
            print_progress "Running post-deployment configuration..."
            "$BASE_DIR/post_deployment_config.sh"
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
