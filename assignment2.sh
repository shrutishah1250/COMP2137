#!/bin/bash

set -e  # Stop on any error

echo "Starting the configuration script..."

# Update and upgrade the system
echo "Updating and upgrading the system..."
sudo apt-get update && sudo apt-get upgrade -y

# Function to configure network settings with netplan
configure_network() {
    echo "Checking and applying network configuration..."

    # Define network configuration
    NETWORK_CONFIG=$(cat <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      dhcp4: no
      addresses: [192.168.16.21/24]
      gateway4: 192.168.16.1
      nameservers:
        addresses: [192.168.16.1]
        search: [home.arpa, localdomain]
EOF
    )

    # Apply network configuration if not already applied
    if ! grep -q "192.168.16.21/24" /etc/netplan/01-netcfg.yaml; then
        echo "$NETWORK_CONFIG" | sudo tee /etc/netplan/01-netcfg.yaml
        sudo netplan apply
    else
        echo "Network already configured. Skipping..."
    fi
}

# Function to install necessary software
install_software() {
    echo "Installing necessary software..."

    # Check and install OpenSSH, Apache2, Squid
    for pkg in openssh-server apache2 squid; do
        if ! dpkg -l | grep -qw $pkg; then
            sudo apt-get install -y $pkg
        else
            echo "$pkg is already installed. Skipping..."
        fi
    done

    # Configure SSH to use key authentication
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo systemctl restart sshd
}

# Function to configure the firewall with UFW
configure_firewall() {
    echo "Configuring UFW firewall..."

    # Enable UFW if not already enabled
    sudo ufw status | grep -q inactive && sudo ufw enable

    # Set default rules
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Allow specific ports
    for port in 22 80 443 3128; do
        sudo ufw allow $port
    done
}

# Function to create and configure user accounts
configure_users() {
    echo "Creating and configuring user accounts..."

    # List of users
    users=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

    for user in "${users[@]}"; do
        # Create user if not exists
        if ! id "$user" &>/dev/null; then
            sudo adduser --disabled-password --gecos "" "$user"
            sudo mkdir -p /home/"$user"/.ssh
            sudo chown "$user":"$user" /home/"$user"/.ssh
            sudo chmod 700 /home/"$user"/.ssh

            # Generate SSH keys
            sudo -u "$user" ssh-keygen -t rsa -f /home/"$user"/.ssh/id_rsa -q -N ""
            sudo -u "$user" ssh-keygen -t ed25519 -f /home/"$user"/.ssh/id_ed25519 -q -N ""

            # Add public keys to authorized_keys
            cat /home/"$user"/.ssh/*.pub >> /home/"$user"/.ssh/authorized_keys
        fi
    done

    # Special configuration for 'dennis'
    if ! grep -q "AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS
