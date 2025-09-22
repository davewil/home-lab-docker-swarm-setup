#!/bin/bash

# Docker Swarm Firewall Configuration for Arch Linux
# This script configures iptables for Docker Swarm Manager Node

set -e

echo "Configuring firewall for Docker Swarm on Arch Linux (Manager Node)..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Install iptables if not present
if ! command -v iptables &> /dev/null; then
    echo "Installing iptables..."
    pacman -S --noconfirm iptables
fi

# Allow Docker Swarm Manager ports
echo "Configuring iptables rules for Docker Swarm..."

# Allow cluster management communications (Manager only)
iptables -A INPUT -p tcp --dport 2377 -j ACCEPT
echo "✓ Allowed port 2377/tcp (cluster management)"

# Allow container network discovery
iptables -A INPUT -p tcp --dport 7946 -j ACCEPT
iptables -A INPUT -p udp --dport 7946 -j ACCEPT
echo "✓ Allowed port 7946/tcp and 7946/udp (container network discovery)"

# Allow overlay network traffic
iptables -A INPUT -p udp --dport 4789 -j ACCEPT
echo "✓ Allowed port 4789/udp (overlay network traffic)"

# Allow Docker daemon communication (optional, for remote Docker API)
# iptables -A INPUT -p tcp --dport 2375 -j ACCEPT
# iptables -A INPUT -p tcp --dport 2376 -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Save iptables rules
echo "Saving iptables rules..."
iptables-save > /etc/iptables/iptables.rules

# Enable and start iptables service
systemctl enable iptables
systemctl start iptables

echo "✓ Firewall configuration completed for Docker Swarm Manager node"
echo ""
echo "Configured ports:"
echo "  - 2377/tcp: Cluster management"
echo "  - 7946/tcp: Container network discovery"
echo "  - 7946/udp: Container network discovery" 
echo "  - 4789/udp: Overlay network traffic"
echo ""
echo "To check current rules: iptables -L"
echo "To check if ports are listening: ss -tlnp | grep -E '2377|7946|4789'"