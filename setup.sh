#!/bin/bash


if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Variables:
PLL="power-led-loop.service"
PLOFF="power-led-off.service"
PLON="power-led-on.service"
CSF="create-shutdown-flag.service"
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
    "$CSF"  
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

determine_laptop_generation() {
    cpu_info=$(grep -m 1 'model name' /proc/cpuinfo)
    echo "Detected CPU: $cpu_info"

    if [[ $cpu_info == *"11th Gen"* ]]; then
        BOARD="hx20" # 11th Generation
        echo "Detected 11th Generation Intel Processor. Setting BOARD to hx20."
    elif [[ $cpu_info == *"12th Gen"* ]]; then
        BOARD="hx30" # 12th Generation
        echo "Detected 12th Generation Intel Processor. Setting BOARD to hx30."
    else
        echo "Unable to automatically determine the Framework Laptop generation."
        echo "Falling back to manual selection."
        ask_laptop_generation # Fallback to manual selection if automatic detection fails
    fi
}



# Function to detect Linux distribution and install packages
install_packages() {
    echo "Checking for installed dependencies..."

    # Distributions typically using dnf or yum
    if grep -qEi "(fedora|red hat|rhel|centos|oracle|scientific|cern|berry|elastix|clearos|frameos|fermi|turbolinux)" /etc/os-release; then
        echo "Detected a Fedora, Red Hat, or similar distribution."
         packages=(arm-none-eabi-gcc arm-none-eabi-newlib libftdi-devel make pkgconfig)
         for pkg in "${packages[@]}"; do
             if ! dnf list installed "$pkg" &> /dev/null; then
                 echo "Installing $pkg"
                 sudo dnf install -y "$pkg" || {
                     echo "Failed to install $pkg. Please check your package manager and repositories."
                     return 1
                 }
             else
                 echo "$pkg is already installed."
             fi
         done


    # Distributions typically using apt-get/apt
   elif grep -qEi "(debian|ubuntu|lubuntu|xubuntu|kubuntu|linux mint|knoppix|deepin|peppermint|bodhi linux)" /etc/os-release; then
         echo "Detected Debian, Ubuntu, or a similar distribution."
         packages=(gcc-arm-none-eabi libftdi1-dev build-essential pkg-config)
         for pkg in "${packages[@]}"; do
             if ! dpkg -l "$pkg" &> /dev/null; then
                 echo "Installing $pkg"
                 sudo apt install -y "$pkg" || {
                     echo "Failed to install $pkg. Please check your package manager and repositories."
                     return 1
                 }
             else
                 echo "$pkg is already installed."
             fi
         done



    # Distributions typically using zypper
    elif grep -qEi "(suse|opensuse|mageia|pclinuxos)" /etc/os-release; then
        echo "Detected SUSE, OpenSUSE, Mageia, or PCLinuxOS."
        packages=(arm-none-eabi-gcc arm-none-eabi-newlib libftdi-devel make pkg-config)
         for pkg in "${packages[@]}"; do
             if ! zypper se --installed-only "$pkg" &> /dev/null; then
                 echo "Installing $pkg"
                 sudo zypper install -y "$pkg" || {
                     echo "Failed to install $pkg. Please check your package manager and repositories."
                     return 1
                 }
             else
                 echo "$pkg is already installed."
             fi
         done



    # Arch Linux and derivatives
   elif grep -qEi "(arch|archbang|archex|archman|arch linux 32|arch linux arm|archstrike|arcolinux|artix|blackarch|bluestar|chimeraos|ctlos|crystal|endeavouros|garuda|hyperbola|instantos|kaos|manjaro|msys2|obarun|parabola|puppyrus-a|rebornos|snal|steamos|systemrescue|tearch|ubos)" /etc/os-release; then
      echo "Detected Arch Linux or an Arch-based distribution."
      packages=(arm-none-eabi-gcc arm-none-eabi-newlib libftdi make pkg-config)
        for pkg in "${packages[@]}"; do
            if ! pacman -Qi "$pkg" &> /dev/null; then
                echo "Installing $pkg"
                sudo pacman -S --noconfirm "$pkg" || {
                    echo "Failed to install $pkg. Please check your package manager and repositories."
                    return 1
                }
            else
                echo "$pkg is already installed."
            fi
        done



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
        determine_laptop_generation

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
mv $CSF /etc/systemd/system/

echo "enabling $PLOFF"
restorecon -v /etc/systemd/system/$PLOFF
systemctl enable --now $PLOFF

echo "enabling $PLL"
restorecon -v /etc/systemd/system/$PLL
systemctl enable --now $PLL

echo "enabling $PLON"
restorecon -v /etc/systemd/system/$PLON
systemctl enable --now $PLON

echo "enabling $CSF"
restorecon -v /etc/systemd/system/$CSF
systemctl enable --now $CSF
