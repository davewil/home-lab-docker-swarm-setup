#!/bin/bash

# Docker Swarm Manager Initialization Script
# Run this script on the Arch Linux machine (linux.kumanet)

set -e

echo "Initializing Docker Swarm Manager Node..."

# Check if Docker is running
if ! docker system info > /dev/null 2>&1; then
    echo "Docker is not running. Please start Docker first."
    exit 1
fi

# Check if already part of a swarm
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo "inactive")

if [[ "$SWARM_STATUS" == "active" ]]; then
    echo "This node is already part of a Docker Swarm."
    echo "Current swarm status:"
    docker node ls
    echo ""
    echo "Manager join token:"
    docker swarm join-token manager
    echo ""
    echo "Worker join token:"
    docker swarm join-token worker
    exit 0
fi

# Get the primary IP address (you may need to adjust this based on your network)
# This tries to get the IP address of the default route interface
PRIMARY_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}' 2>/dev/null || hostname -I | awk '{print $1}')

if [[ -z "$PRIMARY_IP" ]]; then
    echo "Could not determine primary IP address. Please specify manually:"
    read -p "Enter the IP address for this manager node: " PRIMARY_IP
fi

echo "Using IP address: $PRIMARY_IP"

# Initialize Docker Swarm
echo "Initializing Docker Swarm with advertise address: $PRIMARY_IP"
docker swarm init --advertise-addr "$PRIMARY_IP"

if [[ $? -eq 0 ]]; then
    echo "✓ Docker Swarm manager node initialized successfully"
    # Promote this node to manager (redundant but explicit)
    docker node promote linux.kumanet
    # Add tags for this node
    docker node update --label-add tags=dns,web,db,monitoring linux.kumanet
    echo "✓ Node promoted to manager and tagged: dns,web,db,monitoring"

    # Automated verification
    echo "Verifying manager status and tags..."
    ROLE=$(docker node inspect linux.kumanet --format '{{ .Spec.Role }}')
    LABELS=$(docker node inspect linux.kumanet --format '{{ .Spec.Labels.tags }}')
    if [[ "$ROLE" == "manager" ]]; then
        echo "✓ Node is a manager"
    else
        echo "✗ Node is NOT a manager!"
        exit 1
    fi
    if [[ "$LABELS" == "dns,web,db,monitoring" ]]; then
        echo "✓ Node tags are correct: $LABELS"
    else
        echo "✗ Node tags are incorrect: $LABELS"
        exit 1
    fi
else
    echo "✗ Failed to initialize Docker Swarm"
    exit 1
fi

# Display swarm information
echo ""
echo "=== Docker Swarm Information ==="
docker node ls
echo ""

# Generate and save join tokens
echo "=== Join Tokens ==="
echo ""
echo "Manager join token (save this securely):"
MANAGER_TOKEN=$(docker swarm join-token manager -q)
echo "$MANAGER_TOKEN"
echo ""

echo "Worker join token (for worker nodes):"
WORKER_TOKEN=$(docker swarm join-token worker -q)
echo "$WORKER_TOKEN"
echo ""

# Save tokens to files for easy access
echo "$MANAGER_TOKEN" > /tmp/manager-join-token.txt
echo "$WORKER_TOKEN" > /tmp/worker-join-token.txt
echo "Join tokens saved to /tmp/manager-join-token.txt and /tmp/worker-join-token.txt"

# Create join command files for easy copying
echo "docker swarm join --token $MANAGER_TOKEN $PRIMARY_IP:2377" > /tmp/manager-join-command.txt
echo "docker swarm join --token $WORKER_TOKEN $PRIMARY_IP:2377" > /tmp/worker-join-command.txt

echo ""
echo "=== Commands for Worker Nodes ==="
echo ""
echo "For Windows machine (windows.kumanet):"
echo "docker swarm join --token $WORKER_TOKEN $PRIMARY_IP:2377"
echo ""
echo "For macOS machine (mac.kumanet):"
echo "docker swarm join --token $WORKER_TOKEN $PRIMARY_IP:2377"
echo ""

# Create a convenience script to show join commands
cat > /usr/local/bin/show-swarm-tokens << EOF
#!/bin/bash
echo "Docker Swarm Join Commands:"
echo ""
echo "Worker join command:"
docker swarm join-token worker
echo ""
echo "Manager join command:"
docker swarm join-token manager
EOF

chmod +x /usr/local/bin/show-swarm-tokens

echo "✓ Docker Swarm manager setup completed"
echo ""
echo "Next steps:"
echo "1. Copy the worker join command to windows.kumanet and mac.kumanet"
echo "2. Run the worker join scripts on those machines"
echo "3. Verify all nodes joined: docker node ls"
echo ""
echo "To show join tokens later: show-swarm-tokens"