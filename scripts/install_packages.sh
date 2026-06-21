#!/bin/bash


install_packages() {
    echo ""
    echo "Detecting Operating system"
    OS=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    echo "Operating system: $OS"

    # Debian / Ubuntu
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        echo "Installing for Ubuntu/Debian..."
        sudo apt update
		sudo apt install -y p7zip-full lz4 liblz4-1 liblz4-dev libzstd1 libzstd-dev build-essential android-sdk-libsparse-utils f2fs-tools fuse2fs fuse e2fsprogs python3 python3-pip zipalign unzip openjdk-21-jdk jq perl xxd file kmod erofs-utils
		sudo apt autoremove -y

    # Arch Linux
    elif [ "$OS" = "arch" ]; then
        echo "Installing for Arch Linux..."
        pacman -Syu --noconfirm p7zip lz4 zstd base-devel android-tools f2fs-tools fuse2 fuse3 e2fsprogs python python-pip zip unzip jdk21-openjdk jq perl xxd file kmod erofs-utils

    # Fedora
    elif [ "$OS" = "fedora" ]; then
        echo "Installing for Fedora..."
        sudo dnf upgrade -y
		sudo dnf install -y p7zip p7zip-plugins lz4 lz4-devel zstd zstd-devel gcc gcc-c++ make android-tools f2fs-tools fuse fuse-libs e2fsprogs python3 python3-pip zip unzip java-21-openjdk-devel jq perl vim-common file kmod erofs-utils
    else
        echo "Unsupported OS: $OS"
        return 1
    fi

    echo "Installation complete"
}