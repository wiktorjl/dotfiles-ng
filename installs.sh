#!/bin/bash

# --- Helper function to install packages ---
install_package_group() {
    local group_name="$1"
    shift
    local packages=("$@")

    if [ ${#packages[@]} -eq 0 ]; then
        echo "No packages to install for group: $group_name"
        return
    fi

    echo "Installing $group_name..."
    # sudo apt update # Done globally at the start, or can be done per group
    sudo apt install -y "${packages[@]}"
    if [ $? -ne 0 ]; then
        echo "Warning: Errors occurred during installation of $group_name. Please check the output."
    fi
    echo "Installing $group_name... done"
    echo # Newline for better readability
}


install_flatpak() {
    echo "-----------------------------------------------------"
    echo "Attempting to install Flatpak..."
    echo "-----------------------------------------------------"

    # Check if Flatpak is already installed
    if command -v flatpak &> /dev/null; then
        echo "Flatpak is already installed. Skipping installation."
        return
    fi

    sudo apt install -y flatpak

    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Flatpak."
        return 1
    fi

    # Add the Flathub repository
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    if [ $? -ne 0 ]; then
        echo "Error: Failed to add Flathub repository."
        return 1
    fi

    echo "Flatpak installation completed successfully."
}

install_brave_browser() {
    echo "-----------------------------------------------------"
    echo "Attempting to install Brave Browser..."
    echo "-----------------------------------------------------"

    # Check if Brave is already installed
    if command -v brave &> /dev/null; then
        echo "Brave Browser is already installed. Skipping installation."
        return
    fi

    # Install dependencies
    sudo apt install -y apt-transport-https curl

    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list

    sudo apt update

    sudo apt install -y brave-browser


    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Brave Browser."
        return 1
    fi

    echo "Brave Browser installation completed successfully."
}

install_docker() {
    echo "-----------------------------------------------------"
    echo "Attempting to install Docker..."
    echo "-----------------------------------------------------"

    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        echo "Docker is already installed. Skipping installation."
        return
    fi

    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Docker."
        return 1
    fi

    # Add the current user to the docker group
    sudo groupadd docker
    sudo usermod -aG docker $USER
    
    echo "Docker installation completed successfully."
}


install_pentest() {
    echo "-----------------------------------------------------"
    echo "Attempting to install Penetration Testing tools..."
    echo "-----------------------------------------------------"



    # List of penetration testing tools
    local pentest_tools=(
        sqlmap
        hashid
        hashcat
        hydra
        john
        ffuf
        gobuster
        whatweb
        python3-pip
	python3-virtualenv
        netcat-openbsd
        socat
        nmap
        net-tools
        hashid
        hashcat
    )

    # Install the tools using the helper function
    install_package_group "Penetration Testing Tools" "${pentest_tools[@]}"
}

# --- Function to install Visual Studio Code ---
install_vscode() {
    echo "-----------------------------------------------------"
    echo "Attempting to install Visual Studio Code (VS Code)..."
    echo "-----------------------------------------------------"

    # Ensure dependencies are met (curl and gpg should be installed by prior groups)
    if ! command -v curl &> /dev/null || ! command -v gpg &> /dev/null; then
        echo "Error: curl or gpg not found. Cannot install VS Code."
        echo "Please ensure 'curl' and 'gnupg2' are installed."
        return 1
    fi

    echo "1. Downloading Microsoft GPG key..."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o microsoft.gpg
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download or dearmor Microsoft GPG key."
        rm -f microsoft.gpg # Clean up
        return 1
    fi

    echo "2. Installing Microsoft GPG key..."
    sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/keyrings/microsoft-archive-keyring.gpg
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Microsoft GPG key."
        rm -f microsoft.gpg # Clean up
        return 1
    fi
    rm -f microsoft.gpg # Clean up the temporary gpg file

    echo "3. Adding VS Code repository..."
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    if [ $? -ne 0 ]; then
        echo "Error: Failed to add VS Code repository."
        # Consider removing the key and list file if repo add fails
        sudo rm -f /etc/apt/keyrings/microsoft-archive-keyring.gpg /etc/apt/sources.list.d/vscode.list
        return 1
    fi

    echo "4. Updating package lists (after adding VS Code repo)..."
    sudo apt update
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to update package lists after adding VS Code repo. Installation might fail."
        # Don't necessarily exit, let apt install try
    fi

    echo "5. Installing VS Code (package: code)..."
    sudo apt install -y code
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install VS Code (package: code)."
        echo "You might need to manually run: sudo apt update && sudo apt install code"
        return 1
    fi

    echo "Visual Studio Code installation completed successfully."
    echo "-----------------------------------------------------"
    echo
}

install_metastploit() {
    echo "-----------------------------------------------------"
    echo "Attempting to install Metasploit Framework..."
    echo "-----------------------------------------------------"

    # Check if Metasploit is already installed
    if command -v msfconsole &> /dev/null; then
        echo "Metasploit Framework is already installed. Skipping installation."
        return
    fi

    curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall && \
    chmod 755 msfinstall && \
    ./msfinstall && \
    rm msfinstall

    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Metasploit Framework."
        return 1
    fi

    echo "Metasploit Framework installation completed successfully."
}

install_burpsuite() {
    echo "-----------------------------------------------------"
    echo "Attempting to install Burp Suite..."
    echo "-----------------------------------------------------"

    # Check if Burp Suite is already installed
    if command -v burpsuite &> /dev/null; then
        echo "Burp Suite is already installed. Skipping installation."
        return
    fi

    # Download the latest version of Burp Suite
    mkdir -p $HOME/apps
    curl -L -o /home/$USER/apps/burpsuite.jar  https://portswigger-cdn.net/burp/releases/download?product=community&version=2025.5&type=Jar
    
    echo "Burp Suite downloaded to /home/$USER/apps/burpsuite.jar"

cat <<EOF > $HOME/apps/burpsuite.sh
#!/bin/bash
java -jar $HOME/apps/burpsuite.jar "\$@"
EOF

    chmod +x /home/$USER/apps/burpsuite.sh

    # Create a desktop entry for Burp Suite
    cat <<EOF > /home/$USER/.local/share/applications/burpsuite.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Burp Suite
Comment=Burp Suite Community Edition
Exec=java -jar /home/$USER/apps/burpsuite.jar
Icon=/home/$USER/.local/share/icons/burpsuite.png
Terminal=false
Categories=Development;Security;
StartupNotify=true
EOF

    # Get some other goodies
    rm -rf /tmp/burp.git
    git clone https://aur.archlinux.org/burpsuite.git /tmp/burp.git
    mkdir -p /home/$USER/.local/share/applications
    mkdir -p /home/$USER/.local/share/icons
    # cp -v /tmp/burp.git/burpsuite.desktop /home/$USER/.local/share/applications/burpsuite.desktop
    cp -v /tmp/burp.git/icon64.png /home/$USER/.local/share/icons/burpsuite.png

    echo "Burp Suite downloaded to /home/$USER/apps/burpsuite.jar"
}

install_jdk21oracle() {
    echo "-----------------------------------------------------"
    echo "Attempting to install Java JDK 21 (Oracle)..."
    echo "-----------------------------------------------------"

    # Check if Java is already installed
    if command -v java &> /dev/null; then
        echo "Java JDK 21 is already installed. Skipping installation."
        return
    fi

    # Download the latest version of Java JDK 21
    curl -L -o /tmp/jdk21.deb https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.deb

    # Install the downloaded package
    sudo dpkg -i /tmp/jdk21.deb

    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Java JDK 21."
        return 1
    fi

    echo "Java JDK 21 installation completed successfully."
    echo "Installing other java packages..."
    dev_lang_java=(
        gradle
        maven
    )
    install_package_group "Development - Java" "${dev_lang_java[@]}"
    echo "Other Java packages installed successfully."
}

install_seclists() {
    echo "-----------------------------------------------------"
    echo "Attempting to install SecLists..."
    echo "-----------------------------------------------------"

    # Check if SecLists is already installed
    if [ -d "$HOME/SecLists" ]; then
        echo "SecLists is already installed. Skipping installation."
        return
    fi

    # Clone the SecLists repository
    git clone --depth 1 https://github.com/danielmiessler/SecLists.git "$HOME/SecLists"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clone SecLists repository."
        return 1
    fi
    echo "SecLists installation completed successfully."
    echo "SecLists cloned to $HOME/SecLists"
    echo "-----------------------------------------------------"
    echo
}

install_linpeas() {
    echo "-----------------------------------------------------"
    echo "Attempting to install LinPEAS..."
    echo "-----------------------------------------------------"

    # Clone the LinPEAS repository
    echo "Downloading latest LinPEAS..."
    mkdir -p $HOME/apps
    curl -L https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh > $HOME/apps/linpeas.sh
    chmod +x $HOME/apps/linpeas.sh
    echo "LinPEAS downloaded to $HOME/apps/linpeas.sh"
}

# --- Package Groups ---

install_base() {
    # 1. Core System & Shell Utilities
    core_shell_utils=(
        bash
        bash-completion
        screen
        sudo
        tmux
        zsh
	    ssh-askpass-gnome
        keychain
        sakura
	    bat
        keychain
        gpg
        gpg-agent
        gpgconf
    )
    install_package_group "Core System & Shell Utilities" "${core_shell_utils[@]}"

    # 2. System Monitoring & Process Management
    system_monitoring=(
        atop
        btop
        htop
        nethogs
        psmisc
    )
    install_package_group "System Monitoring & Process Management" "${system_monitoring[@]}"

    # 3. File & Text Manipulation / Viewing
    file_text_utils=(
        ack
        bat
        bc
        hexedit
        jq
        mc
        ncdu
        neovim
        pv
        tealdeer
        tree
        vim
    )
    install_package_group "File & Text Manipulation / Viewing" "${file_text_utils[@]}"
}

install_networking() {
 
    # 4. Networking Utilities
    networking_utils=(
        arp-scan
        bind9-dnsutils
        curl            # Dependency for VS Code key download
        iputils-ping
        mtr
        netcat-openbsd
        net-tools
        ngrep
        nmap
        socat
        tcpdump
        traceroute
        wget
        wireguard
    )
    install_package_group "Networking Utilities" "${networking_utils[@]}"
}

install_development() {
    # 5. Development - General Build Tools, Compilers & Version Control
    dev_general=(
        build-essential
        clang
        cmake
        gdb
        git
        gnupg2          # Provides gpg, dependency for VS Code key import
        lldb
    )
    install_package_group "Development - General Build Tools, Compilers & Version Control" "${dev_general[@]}"

    # 6. Development - Language Specific
    dev_lang_python=(
        python3
        python3-pip
        python3-venv
    )
    install_package_group "Development - Python" "${dev_lang_python[@]}"


    dev_lang_golang=(
        golang
    )
    install_package_group "Development - Go" "${dev_lang_golang[@]}"

    dev_lang_rust=(
        cargo
        rustc
    )
    install_package_group "Development - Rust" "${dev_lang_rust[@]}"

    dev_lang_ruby=(
        ruby
        ruby-dev
    )
    install_package_group "Development - Ruby" "${dev_lang_ruby[@]}"
}

install_syssec() {
    # 7. System Administration & Security
    admin_security=(
        certbot
        fail2ban
    )
    install_package_group "System Administration & Security" "${admin_security[@]}"
}


prompt_install() {
    local prompt_message="$1"
    local install_function="$2"

    echo
    read -r -p "$prompt_message (y/N): " user_choice
    case "$user_choice" in
        [yY]|[yY][eE][sS])
            $install_function
            ;;
        *)
            echo "Skipping ${install_function//_/ } installation."
            echo
            ;;
    esac
}

# --- Update package lists once at the beginning ---
echo "Updating package lists..."
sudo apt update
echo "Updating package lists... done"
echo

# Map module names to install functions
declare -A MODULES=(
    [base]=install_base
    [networking]=install_networking
    [java]=install_jdk21oracle
    [development]=install_development
    [syssec]=install_syssec
    [vscode]=install_vscode
    [pentest]=install_pentest
    [docker]=install_docker
    [brave]=install_brave_browser
    [flatpak]=install_flatpak
    [metasploit]=install_metastploit
    [burpsuite]=install_burpsuite
    [seclists]=install_seclists
    [linpeas]=install_linpeas
)

if [ $# -gt 0 ]; then
    # If arguments are provided, only run those modules
    for arg in "$@"; do
        func="${MODULES[$arg]}"
        if [ -n "$func" ]; then
            $func
        else
            echo "Unknown module: $arg"
        fi
    done
    exit 0
fi


prompt_install "Do you want to install Base?" install_base
prompt_install "Do you want to install Networking?" install_networking
prompt_install "Do you want to install Development - Java?" install_jdk21oracle
prompt_install "Do you want to install Development?" install_development
prompt_install "Do you want to install System Administration & Security?" install_syssec
prompt_install "Do you want to install Visual Studio Code (VS Code)?" install_vscode
prompt_install "Do you want to install Penetration Testing tools?" install_pentest
prompt_install "Do you want to install Docker?" install_docker
prompt_install "Do you want to install Brave Browser?" install_brave_browser
prompt_install "Do you want to install Flatpak?" install_flatpak
prompt_install "Do you want to install Metasploit Framework?" install_metastploit
prompt_install "Do you want to install Burp Suite?" install_burpsuite
prompt_install "Do you want to install SecLists?" install_seclists
prompt_install "Do you want to install LinPEAS?" install_linpeas

# TODO:
# - Pull OSCP repo
# - Install DBeaver community edition
