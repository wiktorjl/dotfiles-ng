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
    # moved
}

install_docker() {
    # moved
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
    # moved
}

install_metastploit() {
}

install_burpsuite() {
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
}

install_linpeas() {

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
        age
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
        gnupg2
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
