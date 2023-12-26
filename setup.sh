#!/bin/bash


if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
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
    while true; do
        read -p "$1 (Y/N): " choice
        case "$choice" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Function to ask for laptop generation
ask_laptop_generation() {
    while true; do
        echo "Please specify your Framework Laptop generation:"
        echo "1. 11th Generation"
        echo "2. 12th Generation"
        read -p "Enter your choice (1/2): " gen_choice
        case "$gen_choice" in
            1 ) BOARD="hx20"; break;; # 11th Generation
            2 ) BOARD="hx30"; break;; # 12th Generation
            * ) echo "Invalid choice. Please enter 1 for 11th Generation or 2 for 12th Generation.";;
        esac
    done
}

# Function to detect Linux distribution and install packages
install_packages() {
    if ask_yes_or_no "Are the dependencies already installed?"; then
        echo "Skipping dependency installation."
        return 0
    fi

    if grep -qEi "(fedora|red hat|centos|rhel|nobara)" /etc/os-release; then
        echo "Detected Fedora, Red Hat, CentOS, or similar distribution."
        sudo dnf install arm-none-eabi-gcc arm-none-eabi-newlib libftdi-devel make pkgconfig
    elif grep -qEi "(debian|ubuntu|mint|elementary)" /etc/os-release; then
        echo "Detected Debian, Ubuntu, Mint, elementary OS, or similar distribution."
        sudo apt install gcc-arm-none-eabi libftdi1-dev build-essential pkg-config
    else
        echo "Unsupported distribution. Please manually install the required packages."
        echo "Packages required: gcc-arm-none-eabi libftdi1-dev build-essential pkg-config"
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
        echo "Required file not found: $file"
        echo "Please run this script in the direcotry where the script and service files are."
        echo "Current directory: $SETUP_DIR"
        exit 10
    fi
done

# Check if ectool exists
ectool_path=$(which ectool)
if [ -n "$ectool_path" ]; then
    echo "Found ectool at $ectool_path."
    if [ "$ectool_path" != "/usr/local/bin/ectool" ]; then
        echo "Moving ectool to /usr/local/bin."
        sudo mv "$ectool_path" "/usr/local/bin/ectool"
    fi
else
    # Ask if the user wants to proceed with the installation
    if ask_yes_or_no "ectool is not found. Would you like to install it?"; then
        echo "Starting the installation process..."

        # Clone the repository
        git clone https://github.com/FrameworkComputer/EmbeddedController.git /tmp/ectool_setup/
        cd /tmp/ectool_setup/

        # Install necessary packages based on distribution
        if ! install_packages; then
            echo "Failed to install necessary packages. Exiting."
            exit 1
        fi

        # Ask for laptop generation and set BOARD variable accordingly
        ask_laptop_generation

        # Execute make with the appropriate board
        make BOARD=$BOARD CROSS_COMPILE=arm-none-eabi-

        # Move the utility to the local bin
        sudo mv build/$BOARD/util/ectool /usr/local/bin/
        sudo restorecon -v /usr/local/bin/ectool

        # Clean up
        rm -rf /tmp/ectool_setup
        cd $SETUP_DIR

        echo " ectool installation complete."
    else
        echo "Installation aborted."
    fi
fi




echo "marking scripts as executable"
chmod +x $SH_PLON
chmod +x $SH_PLL
echo "moving scripts to new directory. (/usr/local/bin/)"
mv $SH_PLON /usr/local/bin/
mv $SH_PLL /usr/local/bin/

echo "moving service files to new directory."
echo "(/etc/systemd/system/)"
mv $PLL /etc/systemd/system/
mv $PLOFF /etc/systemd/system/
mv $PLON /etc/systemd/system/

echo "enabling power-led-on"
restorecon -v /etc/systemd/system/$PLON
systemctl enable --now $PLON

echo "enabling power-led-off"
restorecon -v /etc/systemd/system/$PLOFF
systemctl enable --now $PLOFF

echo "enabling power-led-loop"
restorecon -v /etc/systemd/system/$PLL
systemctl enable --now $PLL
