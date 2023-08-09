#!/bin/bash

# read public keys from file
KEYFILE="public_keys.txt"
PUBLIC_KEYS=()
export USER_NAME=han

read_public_keys() {
    while IFS= read -r line; do
        PUBLIC_KEYS+=("$line")
    done < "$KEYFILE"
}

PACMANS="pacman -S --needed --noconfirm"

# packages for installing
PACKAGES="base-devel git vim rsync curl wget openssh sudo gcc make"

# check if root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# update pacman db
pacman_db_update() {
    pacman -Syy
}

# initialize pacman keyring
pacman_keyring_init() {
    pacman-key --init
    pacman-key --populate
    pacman_db_update
    $PACMANS "archlinux-keyring"
}

# add archlinuxcn repository
add_archlinuxcn_repo() {
    echo "Server = https://mirrors.ocf.berkeley.edu/archlinuxcn/\$arch" > /etc/pacman.d/mirrorlist-archlinuxcn
    echo -e "\n[archlinuxcn]" >> /etc/pacman.conf
    echo "Include = /etc/pacman.d/mirrorlist-archlinuxcn" >> /etc/pacman.conf
    pacman_db_update
    $PACMANS "archlinuxcn-keyring"
    $PACMANS "paru"
}

# create user
create_user() {
    $PACMANS "sudo"
    if id -u $USER_NAME >/dev/null 2>&1; then
        echo "User $USER_NAME already exists."
    else
        useradd -mG wheel $USER_NAME
    fi
    echo "$USER_NAME ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER_NAME
    echo "$USER_NAME:$USER_NAME" | chpasswd
}

# set up sshd
set_sshd() {
    $PACMANS "openssh"
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
}

# set up public key
set_public_key() {
    mkdir -p /home/$USER_NAME/.ssh
    mkdir -p /root/.ssh

    for key in "${PUBLIC_KEYS[@]}"; do
        echo -e "\n$key" >> /home/$USER_NAME/.ssh/authorized_keys
        echo -e "\n$key" >> /root/.ssh/authorized_keys
    done
    chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh
}

# change bash prompt for ssh session
ssh_prompt(){
    echo "if [ -n\"$SSH_CLIENT\" ] || [ -n \"$SSH_TTY\" ]; then" >> /home/$USER_NAME/.bashrc
    echo "    export PS1=\"\[\033[0;32m\][\u@\h \w]$\[\033[0m\] \"" >> /home/$USER_NAME/.bashrc
    echo "fi" >> /home/$USER_NAME/.bashrc
}

# install packages
install_packages() {
    $PACMANS $PACKAGES
}

main() {
    read_public_keys
    pacman_keyring_init
    add_archlinuxcn_repo
    pacman_db_update
    create_user
    set_public_key
    set_sshd
    install_packages
    ssh_prompt
    $PACMANS "-u"
}

main

