#!/bin/bash

# Docker Swarm Firewall Configuration for macOS
# This script configures macOS firewall for Docker Swarm Worker Node

set -e

echo "Configuring firewall for Docker Swarm on macOS (Worker Node)..."

# Check if running as root/sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo"
   exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Enable the built-in macOS firewall (Application Layer Firewall)
echo "Enabling macOS Application Layer Firewall..."
/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Set firewall to allow signed applications
/usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on

# Allow Docker Desktop through the firewall
if [ -d "/Applications/Docker.app" ]; then
    echo "Allowing Docker Desktop through Application Layer Firewall..."
    /usr/libexec/ApplicationFirewall/socketfilterfw --add "/Applications/Docker.app"
    /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "/Applications/Docker.app"
fi

# For additional port-based firewall control, we'll use pfctl (Packet Filter)
# Create a temporary pf configuration file
PF_CONF="/tmp/docker_swarm_pf.conf"

cat > "$PF_CONF" << 'EOF'
# Docker Swarm firewall rules for macOS
# Allow Docker Swarm ports

# Define Docker Swarm ports
docker_swarm_tcp = "{ 7946 }"
docker_swarm_udp = "{ 7946, 4789 }"
manager_port = "2377"

# Allow inbound Docker Swarm traffic
pass in proto tcp from any to any port $docker_swarm_tcp
pass in proto udp from any to any port $docker_swarm_udp

# Allow outbound connections to manager node
pass out proto tcp from any to any port $manager_port

# Allow all Docker bridge traffic (docker0 interface)
pass on docker0 all

# Allow established connections
pass in proto tcp from any to any flags S/SA modulate state
pass in proto udp from any to any keep state
EOF

# Backup existing pf configuration
if [ -f "/etc/pf.conf" ]; then
    echo "Backing up existing pf.conf..."
    cp /etc/pf.conf "/etc/pf.conf.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Load the new pf configuration
echo "Loading packet filter rules..."
pfctl -f "$PF_CONF" 2>/dev/null || true

# Enable pfctl
pfctl -e 2>/dev/null || true

# Clean up temporary file
rm -f "$PF_CONF"

# Alternative approach using pfctl with inline rules (more persistent)
echo "Adding persistent firewall rules..."

# Allow Docker Swarm ports
pfctl -a "com.apple/docker_swarm" -f - <<EOF 2>/dev/null || true
pass in proto tcp from any to any port 7946
pass in proto udp from any to any port 7946
pass in proto udp from any to any port 4789
pass out proto tcp from any to any port 2377
EOF

echo "✓ Firewall configuration completed for Docker Swarm Worker node"
echo ""
echo "Configured access for:"
echo "  - 7946/tcp: Container network discovery (inbound)"
echo "  - 7946/udp: Container network discovery (inbound)"
echo "  - 4789/udp: Overlay network traffic (inbound)"
echo "  - 2377/tcp: Manager communication (outbound)"
echo ""
echo "Application Layer Firewall status:"
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
echo ""
echo "To check pfctl status: sudo pfctl -sa"
echo "To test connectivity to manager: nc -zv linux.kumanet 2377"

# Create a script to disable the rules if needed
cat > "/usr/local/bin/disable_docker_swarm_firewall.sh" << 'EOF'
#!/bin/bash
echo "Disabling Docker Swarm firewall rules..."
sudo pfctl -a "com.apple/docker_swarm" -F all 2>/dev/null || true
echo "Docker Swarm firewall rules disabled"
EOF

chmod +x "/usr/local/bin/disable_docker_swarm_firewall.sh"
echo "Created disable script at: /usr/local/bin/disable_docker_swarm_firewall.sh"