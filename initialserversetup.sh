#!/usr/bin/env bash

# This basically just takes instructions from DigitalOcean's "Initial Server Setup with Ubuntu 16.04" and puts it into a script.

# Check root privileges.

    if [[ $(id -u) -ne 0 ]] ; then 
        echo "This script must be run as root."
        exit 1
    fi

# Get username from user, set as superuser.
    
    printf "\n\nSetup will need to create a user with root privileges.  What username do"
    printf "\nyou want to use?\n\n"
    read username

    printf "\nMake sure your password isn't lousy.  Press [Enter] now to continue setup.\n\n"
    read -p ""

    adduser --gecos "" $username
    usermod -aG sudo $username

# Disable ssh for the new user, so can only log in from DigitalOcean terminal.

    #echo "PermitRootLogin no" >> /etc/ssh/sshd_config
    #service ssh restart

# Turn firewall on.

    ufw allow OpenSSH
    ufw enable
