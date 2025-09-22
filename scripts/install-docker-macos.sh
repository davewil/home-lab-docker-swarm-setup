#!/bin/bash

# Docker Installation Script for macOS
# This script downloads and installs Docker Desktop for macOS

set -e

echo "Installing Docker Desktop on macOS..."

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "This script is designed for macOS only"
    exit 1
fi

# Detect Mac architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    DOCKER_URL="https://desktop.docker.com/mac/main/arm64/Docker.dmg"
    echo "Detected Apple Silicon Mac (ARM64)"
elif [[ "$ARCH" == "x86_64" ]]; then
    DOCKER_URL="https://desktop.docker.com/mac/main/amd64/Docker.dmg"
    echo "Detected Intel Mac (x86_64)"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Check if Homebrew is installed (optional method)
if command -v brew &> /dev/null; then
    echo "Homebrew detected. You can also install Docker using: brew install --cask docker"
fi

# Download Docker Desktop
DMG_PATH="/tmp/Docker.dmg"
echo "Downloading Docker Desktop for macOS..."

if command -v curl &> /dev/null; then
    curl -L "$DOCKER_URL" -o "$DMG_PATH"
elif command -v wget &> /dev/null; then
    wget "$DOCKER_URL" -O "$DMG_PATH"
else
    echo "Neither curl nor wget found. Please install one of them or download Docker Desktop manually."
    echo "Download URL: $DOCKER_URL"
    exit 1
fi

echo "✓ Docker Desktop downloaded"

# Mount the DMG
echo "Mounting Docker Desktop installer..."
MOUNT_POINT=$(hdiutil attach "$DMG_PATH" | grep -E '/Volumes/Docker' | awk '{print $3}')

if [[ -z "$MOUNT_POINT" ]]; then
    echo "Failed to mount Docker Desktop installer"
    exit 1
fi

echo "✓ Installer mounted at: $MOUNT_POINT"

# Copy Docker to Applications
echo "Installing Docker Desktop to /Applications..."
if [[ -d "$MOUNT_POINT/Docker.app" ]]; then
    sudo cp -R "$MOUNT_POINT/Docker.app" /Applications/
    echo "✓ Docker Desktop installed to /Applications"
else
    echo "Docker.app not found in mounted volume"
    exit 1
fi

# Unmount the DMG
echo "Cleaning up..."
hdiutil detach "$MOUNT_POINT"
rm -f "$DMG_PATH"

# Set up Docker Desktop configuration
USER_HOME=$(eval echo ~$USER)
DOCKER_CONFIG_DIR="$USER_HOME/.docker"
mkdir -p "$DOCKER_CONFIG_DIR"

# Create Docker Desktop settings
cat > "$DOCKER_CONFIG_DIR/settings.json" << 'EOF'
{
  "autoStart": true,
  "enableExperimentalFeatures": false,
  "useResourceSaver": false,
  "useVirtualizationFramework": true,
  "useVirtualizationFrameworkVirtioFS": true,
  "swarmModeEnabled": true
}
EOF

# Create launch script
cat > "/usr/local/bin/start-docker-desktop" << 'EOF'
#!/bin/bash
echo "Starting Docker Desktop..."
open -a Docker
echo "Waiting for Docker to start..."
while ! docker system info > /dev/null 2>&1; do
    sleep 2
done
echo "✓ Docker Desktop is running"
EOF

chmod +x "/usr/local/bin/start-docker-desktop"

echo "✓ Docker Desktop installation completed"
echo ""
echo "Next steps:"
echo "1. Start Docker Desktop: open -a Docker"
echo "   Or use: start-docker-desktop"
echo "2. Complete Docker Desktop setup in the GUI"
echo "3. Run firewall configuration: sudo ./firewall-macos.sh"
echo "4. Join Docker Swarm as worker node"
echo ""
echo "To verify installation:"
echo "docker --version"
echo "docker system info"
echo ""
echo "Starting Docker Desktop now..."
open -a Docker

# Wait a bit and verify
sleep 5
echo "Waiting for Docker daemon to start..."
timeout=60
count=0
while ! docker system info > /dev/null 2>&1; do
    if [ $count -ge $timeout ]; then
        echo "⚠ Docker Desktop is taking longer than expected to start"
        echo "Please manually start Docker Desktop and verify it's working"
        break
    fi
    sleep 2
    count=$((count + 2))
done

if docker system info > /dev/null 2>&1; then
    echo "✓ Docker Desktop is running and ready"
    docker --version
else
    echo "⚠ Docker Desktop may still be starting up"
    echo "Please check Docker Desktop in your Applications folder"
fi