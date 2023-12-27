#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo -e "\e[1m\e[31mThis script must be run as root\e[0m"
   exit 1
fi

# Variables:
PLL="power-led-loop.service"
PLOFF="power-led-off.service"
PLON="power-led-on.service"
SH_PLL="power-led-loop.sh"
SH_PLON="power-led-on.sh"
ECT_DIR="/usr/local/bin/ectool"
SETUP_DIR="$(pwd)"
required_files=(
    "$PLL"
    "$PLOFF"
    "$PLON"
    "$SH_PLL"
    "$SH_PLON"  
)

# Function to ask yes/no question
ask_yes_or_no() {
    local green=$(tput setaf 2)
    local blue=$(tput setaf 4)
    local bold=$(tput bold)
    local reset=$(tput sgr0)
    
    while true; do
        read -p "${bold}${green}$1 ${blue}(Y/n)${green}:${reset} " choice
        case "$choice" in
            [Yy]*|"" ) return 0;;  # Default to "Y" if Enter is pressed
            [Nn]* ) return 1;;
            * ) echo -e "\e[1m\e[31mPlease answer yes or no.\e[0m";;
        esac
    done
}


# Function to ask for laptop generation
ask_laptop_generation() {
    while true; do
        echo -e "\e[1m\e[32mPlease specify your Framework Laptop generation:\e[0m"
        echo -e "\e[1m\e[32m1. 11th Generation\e[0m"
        echo -e "\e[1m\e[32m2. 12th Generation\e[0m"
        read -p "Enter your choice (1/2): " gen_choice
        case "$gen_choice" in
            1 ) BOARD="hx20"; break;; # 11th Generation
            2 ) BOARD="hx30"; break;; # 12th Generation
            * ) echo -e "\e[1m\e[31mInvalid choice. Please enter 1 for 11th Generation or 2 for 12th Generation.\e[0m";;
        esac
    done
}

determine_laptop_generation() {
    cpu_info=$(grep -m 1 'model name' /proc/cpuinfo)
    echo -e "\e[1m\e[34mDetected CPU: \e[34m$cpu_info\e[0m"

    if [[ $cpu_info == *"11th Gen"* ]]; then
        BOARD="hx20" # 11th Generation
        echo -e "\e[1m\e[34mDetected 11th Generation Intel Processor. Setting BOARD to hx20.\e[0m"
    elif [[ $cpu_info == *"12th Gen"* ]]; then
        BOARD="hx30" # 12th Generation
        echo -e "\e[1m\e[34mDetected 12th Generation Intel Processor. Setting BOARD to hx30.\e[0m"
    else
        echo -e "\e[1m\e[31mUnable to automatically determine the Framework Laptop generation.\e[0m"
        echo -e "\e[1m\e[34mFalling back to manual selection.\e[0m"
        ask_laptop_generation # Fallback to manual selection if automatic detection fails
    fi
}

# Function to detect Linux distribution and install packages
install_packages() {
    echo -e "\e[1m\e[32mChecking for installed dependencies...\e[0m"

    # Distributions typically using dnf or yum
    if grep -qEi "(fedora|red hat|rhel|centos|oracle|scientific|cern|berry|elastix|clearos|frameos|fermi|turbolinux)" /etc/os-release; then
        echo -e "\e[1m\e[32mDetected a Fedora, Red Hat, or similar distribution.\e[0m"
        packages=(arm-none-eabi-gcc arm-none-eabi-newlib libftdi-devel make pkgconfig)
        for pkg in "${packages[@]}"; do
            if ! dnf list installed "$pkg" &> /dev/null; then
                echo -e "\e[1m\e[32mInstalling \e[34m$pkg\e[0m"
                sudo dnf install -y "$pkg" || {
                    echo -e "\e[1m\e[31mFailed to install \e[34m$pkg\e[31m. Please check your package manager and repositories.\e[0m"
                    return 1
                }
            else
                echo -e "\e[1m\e[32m$pkg is already installed.\e[0m"
            fi
        done

    # Distributions typically using apt-get/apt
    elif grep -qEi "(debian|ubuntu|lubuntu|xubuntu|kubuntu|linux mint|knoppix|deepin|peppermint|bodhi linux)" /etc/os-release; then
        echo -e "\e[1m\e[32mDetected Debian, Ubuntu, or a similar distribution.\e[0m"
        packages=(gcc-arm-none-eabi libftdi1-dev build-essential pkg-config)
        for pkg in "${packages[@]}"; do
            if ! dpkg -l "$pkg" &> /dev/null; then
                echo -e "\e[1m\e[32mInstalling \e[34m$pkg\e[0m"
                sudo apt install -y "$pkg" || {
                    echo -e "\e[1m\e[31mFailed to install \e[34m$pkg\e[31m. Please check your package manager and repositories.\e[0m"
                    return 1
                }
            else
                echo -e "\e[1m\e[32m$pkg is already installed.\e[0m"
            fi
        done

    # Distributions typically using zypper
    elif grep -qEi "(suse|opensuse|mageia|pclinuxos)" /etc/os-release; then
        echo -e "\e[1m\e[32mDetected SUSE, OpenSUSE, Mageia, or PCLinuxOS.\e[0m"
        packages=(arm-none-eabi-gcc arm-none-eabi-newlib libftdi-devel make pkg-config)
        for pkg in "${packages[@]}"; do
            if ! zypper se --installed-only "$pkg" &> /dev/null; then
                echo -e "\e[1m\e[32mInstalling \e[34m$pkg\e[0m"
                sudo zypper install -y "$pkg" || {
                    echo -e "\e[1m\e[31mFailed to install \e[34m$pkg\e[31m. Please check your package manager and repositories.\e[0m"
                    return 1
                }
            else
                echo -e "\e[1m\e[32m$pkg is already installed.\e[0m"
            fi
        done

    # Arch Linux and derivatives
    elif grep -qEi "(arch|archbang|archex|archman|arch linux 32|arch linux arm|archstrike|arcolinux|artix|blackarch|bluestar|chimeraos|ctlos|crystal|endeavouros|garuda|hyperbola|instantos|kaos|manjaro|msys2|obarun|parabola|puppyrus-a|rebornos|snal|steamos|systemrescue|tearch|ubos)" /etc/os-release; then
        echo -e "\e[1m\e[32mDetected Arch Linux or an Arch-based distribution.\e[0m"
        packages=(arm-none-eabi-gcc arm-none-eabi-newlib libftdi make pkg-config)
        for pkg in "${packages[@]}"; do
            if ! pacman -Qi "$pkg" &> /dev/null; then
                echo -e "\e[1m\e[32mInstalling \e[34m$pkg\e[0m"
                sudo pacman -S --noconfirm "$pkg" || {
                    echo -e "\e[1m\e[31mFailed to install \e[34m$pkg\e[31m. Please check your package manager and repositories.\e[0m"
                    return 1
                }
            else
                echo -e "\e[1m\e[32m$pkg is already installed.\e[0m"
            fi
        done

    else
        echo -e "\e[1m\e[31mUnsupported distribution. Please manually install the required packages.\e[0m"
        echo -e "\e[1m\e[34mPackages required: \e[32mgcc-arm-none-eabi libftdi1-dev build-essential pkg-config\e[34m\e[0m"
        return 1
    fi
    return 0
}




# Function to check if a file exists
file_exists() {
    [[ -f "$1" ]]
}

# Check for all required files
for file in "${required_files[@]}"; do
    if ! file_exists "$file"; then
        echo -e "\e[1m\e[31mRequired file not found: \e[34m$file\e[31m\e[0m"
        echo -e "\e[34mPlease run this script in the directory where the script and service files are.\e[0m"
        echo -e "\e[34mCurrent directory: \e[32m$SETUP_DIR\e[34m.\e[0m"
        exit 1
    fi
done

# Check if ectool exists
ectool_path=$(which ectool)
if [ -n "$ectool_path" ]; then
    echo -e "\e[1m\e[32mFound ectool at \e[34m$ectool_path\e[32m.\e[0m"
    if [ "$ectool_path" != "/usr/local/bin/ectool" ]; then
        echo -e "\e[1m\e[32mMoving ectool to \e[34m/usr/local/bin\e[32m.\e[0m"
        sudo mv "$ectool_path" "/usr/local/bin/ectool"
    fi
else
    # Ask if the user wants to proceed with the installation
    if ask_yes_or_no "ectool is not found. Would you like to install it?"; then
        echo -e "\e[1m\e[32mStarting the installation process...\e[0m"

        # Clone the repository
        git clone https://github.com/FrameworkComputer/EmbeddedController.git /tmp/ectool_setup/
        cd /tmp/ectool_setup/

        # Install necessary packages based on distribution
        if ! install_packages; then
            echo -e "\e[1m\e[31mFailed to install necessary packages. Exiting.\e[0m"
            exit 1
        fi

        # Ask for laptop generation and set BOARD variable accordingly
        determine_laptop_generation

        # Execute make with the appropriate board
        make BOARD=$BOARD CROSS_COMPILE=arm-none-eabi-

        # Move the utility to the local bin
        sudo mv build/$BOARD/util/ectool /usr/local/bin/
        sudo restorecon -v /usr/local/bin/ectool

        # Clean up
        rm -rf /tmp/ectool_setup
        cd $SETUP_DIR

        echo -e "\e[1m\e[32mectool installation complete.\e[0m"
    else
        echo -e "\e[1m\e[31mInstallation aborted.\e[0m"
    fi
fi




echo -e "\e[1m\e[32mmarking scripts as executable\e[0m"
chmod +x $SH_PLON
chmod +x $SH_PLL
echo -e "\e[1m\e[32mmoving scripts to new directory. (/usr/local/bin/)\e[0m"
mv $SH_PLON /usr/local/bin/
mv $SH_PLL /usr/local/bin/

echo -e "\e[1m\e[32mmoving service files to new directory.\e[0m"
echo -e "\e[1m\e[32m(/etc/systemd/system/)\e[0m"
mv $PLL /etc/systemd/system/
mv $PLOFF /etc/systemd/system/
mv $PLON /etc/systemd/system/
mv $CSF /etc/systemd/system/

echo -e "\e[1m\e[32menabling $PLOFF\e[0m"
restorecon -v /etc/systemd/system/$PLOFF
systemctl enable --now $PLOFF

echo -e "\e[1m\e[32menabling $PLL\e[0m"
restorecon -v /etc/systemd/system/$PLL
systemctl enable --now $PLL

echo -e "\e[1m\e[32menabling $PLON\e[0m"
restorecon -v /etc/systemd/system/$PLON
systemctl enable --now $PLON
