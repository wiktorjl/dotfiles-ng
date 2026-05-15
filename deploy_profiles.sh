#!/bin/bash
set -o pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Shared logging + TUI helpers (colors, print_*, log_*).
LOG_NAME=deploy_profiles
# shellcheck disable=SC1091
. "$BASE_DIR/lib/log.sh"
# Package-manager abstraction; sets DEBIAN_FRONTEND=noninteractive.
# shellcheck disable=SC1091
. "$BASE_DIR/lib/pkg.sh"

# Package verification functions
collect_all_packages() {
    local profiles=("$@")
    local all_requested_packages=()
    declare -A seen_packages
    
    for profile in "${profiles[@]}"; do
        local profile_dir="$BASE_DIR/profiles/$profile"
        if [ -d "$profile_dir/packages" ]; then
            for package_file in "$profile_dir/packages/"*.packages; do
                if [ -f "$package_file" ]; then
                    while IFS= read -r package; do
                        # Skip empty lines and comments
                        if [[ -n "$package" && ! "$package" =~ ^# ]]; then
                            # Trim whitespace
                            package=$(echo "$package" | xargs)
                            # Check for duplicates
                            if [[ -z "${seen_packages[$package]}" ]]; then
                                all_requested_packages+=("$package")
                                seen_packages["$package"]=1
                            fi
                        fi
                    done < "$package_file"
                fi
            done
        fi
    done
    
    printf '%s\n' "${all_requested_packages[@]}"
}

verify_package_installation() {
    local packages=("$@")
    local installed_packages=()
    local failed_packages=()

    for package in "${packages[@]}"; do
        if pkg_installed "$package"; then
            installed_packages+=("$package")
        else
            failed_packages+=("$package")
        fi
    done

    # Return results via global arrays (bash limitation workaround)
    INSTALLED_PACKAGES=("${installed_packages[@]}")
    FAILED_PACKAGES=("${failed_packages[@]}")
}

print_header() {
    echo -e "${CYAN}+==============================================================+${NC}"
    echo -e "${CYAN}|${BOLD}                    PROFILE DEPLOYMENT MANAGER                ${NC}${CYAN}|${NC}"
    echo -e "${CYAN}+==============================================================+${NC}"
    echo
}

# List profiles and allow user to select one or more.
# Profiles are stored in the 'profiles/' directory. Each subdirectory is a profile.
print_header
print_info "Scanning for available profiles..."

# Read profile order from profiles/order file
profile_order=()
if [ -f "$BASE_DIR/profiles/order" ]; then
    print_info "Reading profile order from profiles/order file..."
    while read -r line; do
        # Skip empty lines and comments
        if [[ -n "$line" && ! "$line" =~ ^# ]]; then
            # Split space-separated profiles on this line
            read -ra line_profiles <<< "$line"
            for profile_name in "${line_profiles[@]}"; do
                if [[ -n "$profile_name" ]]; then
                    profile_order+=("$profile_name")
                fi
            done
        fi
    done < "$BASE_DIR/profiles/order"
    print_info "Profile order: ${profile_order[*]}"
else
    print_warning "No profiles/order file found, using default order"
    profile_order=("common" "desktop" "dev" "docker" "pentest")
fi

# Get all available profile directories
available_profiles=()
while IFS= read -r -d '' profile; do
    # Strip 'profiles/' prefix for a cleaner name
    available_profiles+=("$(basename "$profile")")
done < <(find "$BASE_DIR/profiles/" -mindepth 1 -maxdepth 1 -type d -print0)

# Build ordered profiles list: first ordered profiles, then any not in order file
profiles=()
# Add profiles in order
for ordered_profile in "${profile_order[@]}"; do
    for available_profile in "${available_profiles[@]}"; do
        if [[ "$ordered_profile" == "$available_profile" ]]; then
            profiles+=("$ordered_profile")
            break
        fi
    done
done

# Add any profiles not in the order file
for available_profile in "${available_profiles[@]}"; do
    found=false
    for profile in "${profiles[@]}"; do
        if [[ "$available_profile" == "$profile" ]]; then
            found=true
            break
        fi
    done
    if [[ "$found" == false ]]; then
        profiles+=("$available_profile")
    fi
done

if [ ${#profiles[@]} -eq 0 ]; then
    print_error "No profiles found in the '$BASE_DIR/profiles/' directory."
    exit 1
fi

# Check if profiles were passed as command-line arguments
if [ $# -gt 0 ]; then
    # Non-interactive mode: use command-line arguments
    selected_profiles=()
    for arg in "$@"; do
        # Check if the profile exists
        if [[ " ${profiles[*]} " =~ " ${arg} " ]]; then
            selected_profiles+=("$arg")
        else
            print_warning "Profile '$arg' not found, skipping."
        fi
    done
    
    if [ ${#selected_profiles[@]} -eq 0 ]; then
        print_error "None of the specified profiles exist."
        exit 1
    fi
    
    print_info "Using command-line specified profiles:"
    for profile in "${selected_profiles[@]}"; do
        echo -e "  ${GREEN}* ${NC} $profile"
    done
    confirm="y"  # Auto-confirm in non-interactive mode
else
    # Interactive mode: show menu
    echo
    echo -e "${BOLD}${WHITE}Please select one or more profiles to apply:${NC}"
    echo -e "${CYAN}+================================================================+${NC}"
    # Display a numbered list of available profiles with descriptions
    for i in "${!profiles[@]}"; do
        profile="${profiles[$i]}"
        # Get profile description from directory
        description=""
        if [ -f "$BASE_DIR/profiles/$profile/README.md" ]; then
            description=$(head -n1 "$BASE_DIR/profiles/$profile/README.md" 2>/dev/null | sed 's/^# //' || echo "")
        fi
        if [ -z "$description" ]; then
            case "$profile" in
                "common") description="Base packages, networking, security tools" ;;
                "desktop") description="GUI applications (Brave, Spotify, etc.)" ;;
                "dev") description="Development tools (VS Code, languages)" ;;
                "docker") description="Docker installation and configuration" ;;
                "pentest") description="Security testing tools" ;;
                *) description="Custom profile" ;;
            esac
        fi
        printf "${CYAN}|${NC} ${YELLOW}%2d${NC}) ${BOLD}%-10s${NC} ${CYAN}|${NC} %-45s ${CYAN}|${NC}\n" "$((i+1))" "$profile" "$description"
    done
    echo -e "${CYAN}+================================================================+${NC}"
    echo

    # Prompt user for input
    echo -e "${BOLD}Enter the numbers of the profiles${NC} ${CYAN}(e.g., 1 3 4 or 1,3,4):${NC}"
    echo -n "=> "
    read -r selection

    # Replace commas with spaces to handle both space and comma-separated input
    selection=${selection//,/ }
    read -ra selected_indices <<< "$selection"

    selected_profiles=()
    for index in "${selected_indices[@]}"; do
        # Validate that input is a number
        if [[ "$index" =~ ^[0-9]+$ ]]; then
            profile_index=$((index - 1))
            # Validate that the number corresponds to a profile in the list
            if [[ "$profile_index" -ge 0 && "$profile_index" -lt "${#profiles[@]}" ]]; then
                # Check for duplicates before adding to the selection
                if ! [[ " ${selected_profiles[*]} " =~ " ${profiles[$profile_index]} " ]]; then
                    selected_profiles+=("${profiles[$profile_index]}")
                fi
            else
                print_warning "Invalid selection '$index' ignored."
            fi
        else
            # Ignore non-numeric input, but warn if it's not just empty space
            if [[ -n "$index" ]]; then
                print_warning "Invalid input '$index' ignored."
            fi
        fi
    done

    # Proceed if at least one valid profile was selected
    if [ ${#selected_profiles[@]} -gt 0 ]; then
        echo
        echo -e "${BOLD}${GREEN}Selected profiles:${NC}"
        echo -e "${GREEN}+==========================+${NC}"
        for profile in "${selected_profiles[@]}"; do
            printf "${GREEN}|${NC} ${BOLD}*${NC} %-22s ${GREEN}|${NC}\n" "$profile"
        done
        echo -e "${GREEN}+==========================+${NC}"
        
        echo
        echo -e "${BOLD}${YELLOW}Do you want to apply these profiles?${NC} ${CYAN}[y/N]:${NC}"
        echo -n "=> "
        read -r confirm
    else
        print_error "No valid profiles were selected."
        exit 1
    fi
fi

# Proceed if we have selected profiles (from either command-line or interactive)
if [ ${#selected_profiles[@]} -gt 0 ]; then
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo
        print_progress "Applying selected profiles..."

        print_info "Updating package lists..."
        if log_command "Updating package lists" pkg_update; then
            print_success "Package lists updated successfully"
        else
            print_error "Failed to update package lists. Please check your internet connection or package manager."
            exit 1
        fi


        # Sort selected_profiles into install order by filtering the already-
        # ordered `profiles` list (which combines profiles/order + any custom
        # profile dirs found on disk). The user may click profiles in any
        # order, but install order must respect profiles/order so deps land
        # before dependents.
        ordered_profiles=()
        for p in "${profiles[@]}"; do
            case " ${selected_profiles[*]} " in
                *" $p "*) ordered_profiles+=("$p") ;;
            esac
        done

        print_info "Installing profiles in dependency order: ${ordered_profiles[*]}"
        echo

        # Track non-package failures (scripts, link step) across all profiles so
        # we can still finish what we can and exit non-zero at the end.
        FAILED_STEPS=()

        for profile in "${ordered_profiles[@]}"; do
            echo
            echo -e "${BOLD}${BLUE}+== Applying profile: ${WHITE}$profile${BLUE} ===============================================+${NC}"
            profile_dir="$BASE_DIR/profiles/$profile"
            # For each *.packages file in profile/selected_profile/packages, install the packages
            if [ -d "$profile_dir" ]; then
                print_success "Profile '$profile' found. Checking for init scripts..."
                # Run all init scripts for the profile
                if [ -d "$profile_dir/init-scripts" ]; then
                    init_script_count=0
                    for init_script in "$profile_dir/init-scripts/"*.sh; do
                        if [ -f "$init_script" ]; then
                            init_script_count=$((init_script_count + 1))
                            print_progress "Running init script: $(basename "$init_script")"
                            # Make the script executable if it is not already
                            chmod +x "$init_script"
                            # Run the init script
                            if log_command "Running init script $(basename "$init_script")" bash "$init_script"; then
                                print_success "Init script '$(basename "$init_script")' completed successfully"
                            else
                                print_error "Failed to run init script '$(basename "$init_script")'."
                                FAILED_STEPS+=("$profile/init-scripts/$(basename "$init_script")")
                            fi
                        fi
                    done
                    if [ $init_script_count -eq 0 ]; then
                        print_info "No init scripts found for profile '$profile'. Skipping."
                    else
                        print_success "Completed $init_script_count init scripts for profile '$profile'"
                        # Refresh package lists so newly-added repos (from init-scripts) are visible.
                        print_info "Updating package lists after init scripts..."
                        if ! log_command "Post-init scripts package list update" pkg_update; then
                            # Stale package lists would poison the upcoming install,
                            # so skip the rest of this profile but keep going on the others.
                            print_error "Failed to update package lists after init scripts; skipping packages and post-scripts for '$profile'."
                            FAILED_STEPS+=("$profile/apt-update-after-init")
                            echo -e "${BLUE}+=====================================================================+${NC}"
                            continue
                        fi
                    fi
                else
                    print_info "No init-scripts directory found for profile '$profile'. Skipping."
                fi

                print_progress "Installing packages for profile '$profile'..."
                
                # Collect all packages from all .packages files for this profile
                all_packages=()
                declare -A seen_packages  # Track duplicates
                for package_file in "$profile_dir/packages/"*.packages; do
                    if [ -f "$package_file" ]; then
                        print_info "Reading packages from $(basename "$package_file")..."
                        while IFS= read -r package; do
                            # Skip empty lines and comments
                            if [[ -n "$package" && ! "$package" =~ ^# ]]; then
                                # Trim whitespace
                                package=$(echo "$package" | xargs)
                                # Check for duplicates
                                if [[ -z "${seen_packages[$package]}" ]]; then
                                    all_packages+=("$package")
                                    seen_packages["$package"]=1
                                else
                                    print_warning "Duplicate package '$package' found in $(basename "$package_file"), skipping"
                                fi
                            fi
                        done < "$package_file"
                    fi
                done
                
                # Validate packages before installation. The pre-check filters out
                # packages that aren't in any configured repo, so the batch install
                # doesn't fail wholesale when one package has been renamed/removed.
                if [ ${#all_packages[@]} -eq 0 ]; then
                    print_info "No packages found for profile '$profile'"
                else
                    print_info "Validating ${#all_packages[@]} packages..."
                    pkg_partition_available "${all_packages[@]}"

                    if [ ${#PKG_UNAVAILABLE[@]} -gt 0 ]; then
                        print_warning "${#PKG_UNAVAILABLE[@]} packages unavailable: ${PKG_UNAVAILABLE[*]}"
                    fi

                    if [ ${#PKG_AVAILABLE[@]} -eq 0 ]; then
                        print_warning "No packages available for installation in profile '$profile'"
                    else
                        print_info "Installing ${#PKG_AVAILABLE[@]} available packages in batch..."
                        echo -e "  ${CYAN}Packages: ${PKG_AVAILABLE[*]}${NC}"
                        if log_command "Installing ${#PKG_AVAILABLE[@]} packages in batch" pkg_install "${PKG_AVAILABLE[@]}"; then
                            print_success "All available packages installed successfully"
                        else
                            # Per-package failures are reported in the verification
                            # summary at the end; keep going so other packages still
                            # get a chance.
                            print_warning "Batch installation failed. Falling back to individual package installation..."
                            for package in "${PKG_AVAILABLE[@]}"; do
                                print_progress "Installing $package individually..."
                                if log_command "Installing $package individually" pkg_install_one "$package"; then
                                    print_success "$package installed"
                                else
                                    print_error "Failed to install $package"
                                fi
                            done
                        fi
                    fi
                fi
            
                # Now run remaining scripts in the profile/scripts directory
                print_progress "Running post-installation scripts for profile '$profile'..."
                script_count=0
                for script in "$profile_dir/post-scripts/"*.sh; do
                    if [ -f "$script" ]; then
                        script_count=$((script_count + 1))
                        print_info "Running script: $(basename "$script")"
                        # Make the script executable if it is not already
                        chmod +x "$script"
                        # Execute the script
                        if log_command "Running post-script $(basename "$script")" bash "$script"; then
                            print_success "Script '$(basename "$script")' completed"
                        else
                            print_error "Failed to run script '$(basename "$script")'."
                            FAILED_STEPS+=("$profile/post-scripts/$(basename "$script")")
                        fi
                    fi
                done
                if [ $script_count -eq 0 ]; then
                    print_info "No post-installation scripts found for profile '$profile'"
                fi


                # If there is a bin folder in the profile, link all scripts in it to ~/.local/bin and /usr/local/bin
                if [ -d "$profile_dir/bin" ]; then
                    print_progress "Linking scripts from profile bin directory..."

                    # Use link_bin_scripts.sh for consistent linking behavior
                    # Links to both ~/.local/bin and /usr/local/bin (requires sudo)
                    if [ -f "$BASE_DIR/link_bin_scripts.sh" ]; then
                        if ! bash "$BASE_DIR/link_bin_scripts.sh" "$profile" --non-interactive --system; then
                            print_error "Failed to link scripts for profile '$profile'."
                            FAILED_STEPS+=("$profile/link-bin-scripts")
                        fi
                    else
                        print_error "link_bin_scripts.sh not found!"
                        FAILED_STEPS+=("$profile/link-bin-scripts-missing")
                    fi
                fi

            fi
            echo -e "${BLUE}+=====================================================================+${NC}"
        done
        echo
        print_success "All selected profiles have been applied successfully!"
        
        # Package verification summary
        echo
        echo -e "${BOLD}${CYAN}+== PACKAGE INSTALLATION VERIFICATION =======================================+${NC}"
        print_info "Collecting all requested packages from selected profiles..."
        
        # Collect all packages that were requested across all selected profiles
        mapfile -t all_requested_packages < <(collect_all_packages "${ordered_profiles[@]}")
        
        if [ ${#all_requested_packages[@]} -gt 0 ]; then
            print_info "Verifying installation status of ${#all_requested_packages[@]} requested packages..."
            
            # Verify installation status
            verify_package_installation "${all_requested_packages[@]}"
            
            # Log and display results
            total_requested=${#all_requested_packages[@]}
            total_installed=${#INSTALLED_PACKAGES[@]}
            total_failed=${#FAILED_PACKAGES[@]}
            
            # Calculate success rate with division by zero protection
            if [ $total_requested -gt 0 ]; then
                success_rate=$((total_installed * 100 / total_requested))
            else
                success_rate=0
            fi
            
            echo
            print_info "PACKAGE INSTALLATION SUMMARY:"
            print_info "=============================="
            log_message "PACKAGE VERIFICATION: Total requested: $total_requested, Installed: $total_installed, Failed: $total_failed, Success rate: ${success_rate}%"
            
            if [ $total_installed -gt 0 ]; then
                print_success "Successfully installed packages ($total_installed/$total_requested - ${success_rate}%):"
                echo -e "  ${GREEN}${INSTALLED_PACKAGES[*]}${NC}"
                log_message "INSTALLED PACKAGES: ${INSTALLED_PACKAGES[*]}"
            fi
            
            if [ $total_failed -gt 0 ]; then
                print_warning "Failed to install packages ($total_failed/$total_requested):"
                echo -e "  ${RED}${FAILED_PACKAGES[*]}${NC}"
                log_message "FAILED PACKAGES: ${FAILED_PACKAGES[*]}"
            fi
            
            echo
            if [ $total_failed -eq 0 ]; then
                print_success "🎉 All requested packages were installed successfully!"
                log_message "SUCCESS: All requested packages were installed successfully"
            else
                print_warning "⚠️  Some packages failed to install. Check logs above for details."
                log_message "WARNING: $total_failed packages failed to install"
            fi
        else
            print_info "No packages were requested for installation."
            log_message "INFO: No packages were requested for installation"
        fi
        echo -e "${CYAN}+=========================================================================+${NC}"

        if [ ${#FAILED_STEPS[@]} -gt 0 ]; then
            echo
            print_warning "⚠️  ${#FAILED_STEPS[@]} non-package step(s) failed:"
            for step in "${FAILED_STEPS[@]}"; do
                echo -e "  ${RED}- ${step}${NC}"
            done
            log_message "FAILED STEPS: ${FAILED_STEPS[*]}"
        fi

        if [ "${total_failed:-0}" -gt 0 ] || [ ${#FAILED_STEPS[@]} -gt 0 ]; then
            exit 1
        fi
    else
        print_info "Operation cancelled by user."
    fi
else
    print_error "No valid profiles were selected."
fi
