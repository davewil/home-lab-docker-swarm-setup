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

# Update package database
echo "Updating package database..."
pacman -Sy

# Install Docker
echo "Installing Docker..."
pacman -S --noconfirm docker docker-compose

# Enable and start Docker service
echo "Enabling and starting Docker service..."
systemctl enable docker
systemctl start docker

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
cat > /etc/docker/daemon.json << 'EOF'
{
  "hosts": ["unix:///var/run/docker.sock"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "userland-proxy": false,
  "experimental": false
}
EOF

# Restart Docker to apply configuration
echo "Restarting Docker to apply configuration..."
systemctl restart docker

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