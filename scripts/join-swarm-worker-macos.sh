#!/bin/bash

# Docker Swarm Worker Join Script for macOS
# Run this script on the macOS machine (mac.kumanet)

# IMPORTANT: CONFIGURE CUSTOM HOSTNAME FIRST!
# ===========================================
# Before running this script, configure a custom hostname for Docker:
# 1. Create file: ~/.docker/daemon.json
# 2. Add content: { "hostname": "mac" }
# 3. Restart Docker Desktop
# This will make your node appear as "mac" instead of "docker-desktop" in swarm listings.

set -e

echo "Joining Docker Swarm as Worker Node (macOS)..."

# Check if Docker is running
if ! docker system info > /dev/null 2>&1; then
    echo "Docker is not running. Please start Docker Desktop first."
    echo "You can start it with: open -a Docker"
    exit 1
fi

# Check if already part of a swarm
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo "inactive")

if [[ "$SWARM_STATUS" == "active" ]]; then
    echo "This node is already part of a Docker Swarm."
    docker info --format 'Swarm: {{.Swarm.LocalNodeState}}'
    exit 0
fi

# Get join token and manager IP from user
echo "To join this worker node to the Docker Swarm, you need:"
echo "1. Worker join token from the manager node"
echo "2. Manager node IP address (linux.kumanet)"
echo ""

if [[ -z "$1" ]] || [[ -z "$2" ]]; then
    echo "Usage: $0 <worker-token> <manager-ip>"
    echo ""
    echo "Get the worker token from the manager node by running:"
    echo "  docker swarm join-token worker"
    echo ""
    echo "Example:"
    echo "  $0 SWMTKN-1-xxxxx... 192.168.1.100"
    exit 1
fi

WORKER_TOKEN="$1"
MANAGER_IP="$2"

# Validate inputs
if [[ ! "$WORKER_TOKEN" =~ ^SWMTKN-1- ]]; then
    echo "Invalid worker token format. Token should start with 'SWMTKN-1-'"
    exit 1
fi

# Test connectivity to manager node
echo "Testing connectivity to manager node at $MANAGER_IP:2377..."
if nc -z "$MANAGER_IP" 2377 2>/dev/null; then
    echo "✓ Manager node is reachable"
else
    echo "✗ Cannot reach manager node at $MANAGER_IP:2377"
    echo "Please check:"
    echo "1. Manager node is running and Docker Swarm is initialized"
    echo "2. Firewall allows port 2377"
    echo "3. Network connectivity between machines"
    exit 1
fi

# Join the swarm
echo "Joining Docker Swarm..."
docker swarm join --token "$WORKER_TOKEN" "$MANAGER_IP:2377"

if [[ $? -eq 0 ]]; then
    echo "✓ Successfully joined Docker Swarm as worker node"
    # Promote this node to manager
    echo "Promoting this node to manager..."
    docker node promote mac.kumanet
    # Add tags for this node
    echo "Tagging this node with: web,db"
    docker node update --label-add tags=web,db mac.kumanet
    echo "✓ Node promoted to manager and tagged"

    # Automated verification
    echo "Verifying manager status and tags..."
    ROLE=$(docker node inspect mac.kumanet --format '{{ .Spec.Role }}')
    LABELS=$(docker node inspect mac.kumanet --format '{{ .Spec.Labels.tags }}')
    if [[ "$ROLE" == "manager" ]]; then
        echo "✓ Node is a manager"
    else
        echo "✗ Node is NOT a manager!"
        exit 1
    fi
    if [[ "$LABELS" == "web,db" ]]; then
        echo "✓ Node tags are correct: $LABELS"
    else
        echo "✗ Node tags are incorrect: $LABELS"
        exit 1
    fi
else
    echo "✗ Failed to join Docker Swarm"
    exit 1
fi

# Verify swarm membership
echo ""
echo "=== Swarm Information ==="
docker info --format 'Swarm: {{.Swarm.LocalNodeState}}'
docker info --format 'NodeID: {{.Swarm.NodeID}}'
docker info --format 'Manager Addresses: {{.Swarm.RemoteManagers}}'

echo ""
echo "✓ macOS worker node successfully joined the Docker Swarm"
echo ""
echo "Verify on manager node with: docker node ls"