#!/bin/bash

# Docker Installation Script for Arch Linux
# This script installs Docker and configures it for Docker Swarm

set -e

echo "Installing Docker on Arch Linux..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Check if Docker is already installed and running
if command -v docker > /dev/null 2>&1 && systemctl is-active --quiet docker; then
    echo "Docker is already installed and running"
    echo "Current Docker version: $(docker --version)"
    echo "Skipping installation, proceeding with configuration..."
else
    # Update package database
    echo "Updating package database..."
    pacman -Sy

    # Install Docker
    echo "Installing Docker..."
    pacman -S --noconfirm docker docker-compose
fi

# Enable and start Docker service
echo "Enabling and starting Docker service..."
systemctl enable docker

# Check if Docker is already running
if systemctl is-active --quiet docker; then
    echo "Docker is already running"
else
    systemctl start docker
    
    # Wait a moment for Docker to fully start
    sleep 3
    
    # Verify Docker started successfully
    if ! systemctl is-active --quiet docker; then
        echo "✗ Docker service failed to start"
        echo "Check logs with: journalctl -xeu docker.service"
        exit 1
    fi
fi

# Add current user to docker group (if script is run with sudo, add the original user)
if [ -n "$SUDO_USER" ]; then
    echo "Adding user $SUDO_USER to docker group..."
    usermod -aG docker "$SUDO_USER"
    echo "User $SUDO_USER added to docker group. Please log out and back in for changes to take effect."
fi

# Verify Docker installation
echo "Verifying Docker installation..."
if docker --version; then
    echo "✓ Docker installed successfully"
else
    echo "✗ Docker installation failed"
    exit 1
fi

# Test Docker with hello-world
echo "Testing Docker with hello-world container..."
if docker run --rm hello-world > /dev/null 2>&1; then
    echo "✓ Docker is working correctly"
else
    echo "⚠ Docker test failed - may need to restart or check permissions"
fi

# Configure Docker daemon for Swarm
echo "Configuring Docker daemon for Swarm..."
mkdir -p /etc/docker

# Create daemon.json with optimizations for Swarm
# Note: "hosts" directive is removed to avoid conflict with systemd
# Note: "live-restore" is removed as it's incompatible with Swarm mode
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "userland-proxy": true,
  "experimental": false
}
EOF

# Create systemd override for Docker service to handle bridge netfilter issues
echo "Configuring systemd override for Docker service..."
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/ignore-bridge-netfilter.conf << 'EOF'
[Service]
Environment="DOCKER_IGNORE_BR_NETFILTER_ERROR=1"
EOF

# Reload systemd to pick up the override
systemctl daemon-reload

# Restart Docker to apply configuration
echo "Restarting Docker to apply configuration..."
if systemctl restart docker; then
    # Wait for Docker to be ready
    sleep 3
    if systemctl is-active --quiet docker; then
        echo "✓ Docker restarted successfully"
    else
        echo "⚠ Docker restart may have failed, but continuing..."
    fi
else
    echo "⚠ Docker restart failed, but Docker may still be running"
fi

echo "✓ Docker installation and configuration completed"
echo ""
echo "Docker version:"
docker --version
echo ""
echo "Docker Compose version:"
docker-compose --version
echo ""
echo "Next steps:"
echo "1. Run firewall configuration: ./firewall-arch-linux.sh"
echo "2. Initialize Docker Swarm as manager node"
echo ""
echo "To verify Docker daemon is ready for Swarm:"
echo "docker system info | grep -i swarm"