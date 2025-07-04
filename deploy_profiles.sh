#!/bin/bash

# Define the base directory for profiles
BASE_DIR="/home/$USER/dotfiles-ng"

# List profiles and allow user to select one or more.
# Profiles are stored in the 'profiles/' directory. Each subdirectory is a profile.
echo "Finding available profiles..."
profiles=()
# Use find to get profile directories and store their names in an array
while IFS= read -r -d '' profile; do
    # Strip 'profiles/' prefix for a cleaner name
    profiles+=("$(basename "$profile")")
done < <(find "$BASE_DIR/profiles/" -mindepth 1 -maxdepth 1 -type d -print0)

if [ ${#profiles[@]} -eq 0 ]; then
    echo "No profiles found in the '$BASE_DIR/profiles/' directory."
    exit 1
fi

echo
echo "Please select one or more profiles to apply:"
# Display a numbered list of available profiles
for i in "${!profiles[@]}"; do
    printf "%d) %s\n" "$((i+1))" "${profiles[$i]}"
done
echo

# Prompt user for input
read -p "Enter the numbers of the profiles (e.g., 1 3 4): " selection

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
            echo "Warning: Invalid selection '$index' ignored."
        fi
    else
        # Ignore non-numeric input, but warn if it's not just empty space
        if [[ -n "$index" ]]; then
            echo "Warning: Invalid input '$index' ignored."
        fi
    fi
done

# Proceed if at least one valid profile was selected
if [ ${#selected_profiles[@]} -gt 0 ]; then
    echo
    echo "You have selected the following profiles:"
    for profile in "${selected_profiles[@]}"; do
        echo " - $profile"
    done
    
    echo
    read -p "Do you want to apply these profiles? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo "Applying selected profiles..."
        
        # First, make sure we run apt update
        echo "Updating package lists..."
        sudo apt-get update
        if [ $? -ne 0 ]; then
            echo "Failed to update package lists. Please check your internet connection or package manager."
            exit 1
        fi


        for profile in "${selected_profiles[@]}"; do
            echo "--- Applying profile: $profile ---"
            profile_dir="$BASE_DIR/profiles/$profile"
            # For each *.packages file in profile/selected_profile/packages, install the packages
            if [ -d "$profile_dir" ]; then
                echo "Profile '$profile' found. Running init scripts..."
                # Check if there is an init script for the profile
                if [ -f "$profile_dir/init-scripts/$profile-init.sh" ]; then
                    echo "Running init script for profile '$profile'..."
                    # Run the init script
                    bash "$profile_dir/init-scripts/$profile-init.sh"
                    if [ $? -ne 0 ]; then
                        echo "Error: Failed to run init script for profile '$profile'."
                        continue
                    fi
                else
                    echo "No init script found for profile '$profile'. Skipping."
                fi

                echo "Installing packages for profile '$profile'..."
                for package_file in "$profile_dir/packages/"*.packages; do
                    if [ -f "$package_file" ]; then
                        echo "Installing packages from $package_file..."
                        while IFS= read -r package; do
                            # Skip empty lines and comments
                            if [[ -n "$package" && ! "$package" =~ ^# ]]; then
                                # Install the package using the appropriate command
                                sudo apt-get install -y "$package" || { echo "Failed to install $package"; }
                            fi
                        done < "$package_file"
                    fi
                done
            
                # Now run remaining scripts in the profile/scripts directory
                echo "Running scripts for profile '$profile'..."
                for script in "$profile_dir/post-scripts/"*.sh; do
                    if [ -f "$script" ]; then
                        echo "Running script: $script"
                        # Make the script executable if it is not already
                        chmod +x "$script"
                        # Execute the script
                        bash "$script"
                        if [ $? -ne 0 ]; then
                            echo "Error: Failed to run script '$script'."
                            continue            
                        fi
                    fi
                done


                # If there is a bin folder in the profile, link all scripts in it to ~/.local/bin
                if [ -d "$profile_dir/bin" ]; then
                    echo "Linking scripts from $profile_dir/bin to ~/.local/bin..."
                    mkdir -p ~/.local/bin
                    for script in "$profile_dir/bin/"*; do
                        if [ -f "$script" ]; then
                            script_name=$(basename "$script")
                            # Create a symlink in ~/.local/bin
                            ln -sf "$(realpath "$script")" ~/.local/bin/"$script_name"
                            echo "Linked $script_name to ~/.local/bin"
                        fi
                    done
                fi

            fi
        done
        echo "All selected profiles have been applied."
    else
        echo "Operation cancelled."
    fi
else
    echo "No valid profiles were selected."
fi
