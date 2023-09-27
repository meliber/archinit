#!/bin/bash

pacmans="pacman -Sy --needed --noconfirm"

# packages for installing
# paru is in archlinuxcn repository
packages="base-devel git which vim rsync curl wget openssh sudo gcc make paru"

log='archinit.log'
myname=han

# read public keys from file
if [ -f "public_keys.txt" ]; then
    keyfile="public_keys.txt"
else
    echo "public_keys.txt does not exist"
    exit 1
fi
public_keys=()

# check if the current user is root
if [ $EUID -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

read_public_keys() {
    while IFS= read -r line; do
        public_keys+=("$line")
    done < "$keyfile"
    if [ -z "$public_keys" ]; then
        echo "public_keys.txt is empty"
        exit 1
    fi
}

update() {
    pacman -Syyu --noconfirm
}

# update pacman db
pacman_db_update() {
    pacman -Syy
}

# get user name
get_user_name() {
    if [ -z $myname ]; then

        echo -n "Enter a user name: "
        read user_name
    else
        user_name=$myname
    fi
}

# initialize pacman keyring
pacman_keyring_init() {
    pacman-key --init
    pacman-key --populate
    pacman_db_update
    $pacmans "archlinux-keyring"
}

# add archlinuxcn repository
add_archlinuxcn_repo() {
    echo "Server = https://mirrors.ocf.berkeley.edu/archlinuxcn/\$arch" > /etc/pacman.d/mirrorlist-archlinuxcn
    echo -e "\n[archlinuxcn]" >> /etc/pacman.conf
    echo "Include = /etc/pacman.d/mirrorlist-archlinuxcn" >> /etc/pacman.conf
    pacman_db_update
    $pacmans "archlinuxcn-keyring"
}

# create user
create_user() {
    $pacmans "sudo"
    if id -u $user_name >/dev/null 2>&1; then
        echo "User $user_name already exists."
    else
        useradd -mG wheel $user_name
    fi
    echo "$user_name ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/$user_name
    echo "$user_name:$user_name" | chpasswd
}

# set up sshd
set_sshd() {
    $pacmans "openssh"
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl enable sshd
}

# set up public key
set_public_key() {
    mkdir -p /home/$user_name/.ssh
    mkdir -p /root/.ssh

    for key in "${public_keys[@]}"; do
        echo -e "\n$key" >> /home/$user_name/.ssh/authorized_keys
        echo -e "\n$key" >> /root/.ssh/authorized_keys
    done
    chown -R $user_name:$user_name /home/$user_name/.ssh
}

# change bash prompt for ssh session
ssh_prompt(){
    echo 'if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then' >> /home/$user_name/.bashrc
    echo "    export PS1=\"\[\033[0;32m\][\u@\h \w]$\[\033[0m\] \"" >> /home/$user_name/.bashrc
    echo "fi" >> /home/$user_name/.bashrc
}

# install packages
install_packages() {
    $pacmans $packages
}

echo_and_reboot() {
    echo "user name is $user_name"
    echo "All Done!"
    echo "Rebooting in 5 seconds..."
    sleep 5
    reboot
}

main() {
    read_public_keys
    get_user_name
    pacman_keyring_init
    add_archlinuxcn_repo
    update
    create_user
    set_public_key
    set_sshd
    install_packages
    ssh_prompt
    update
    echo_and_reboot
}

main 2>&1 | tee $log

