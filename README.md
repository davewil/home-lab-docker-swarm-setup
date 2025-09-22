# Docker Swarm Setup for Home Lab

A complete setup guide for deploying Docker Swarm across three machines with different operating systems: Arch Linux (Manager), Windows 11 Pro, and macOS Tahoe.

## Overview

This setup creates a Docker Swarm cluster with:
- **Manager Node**: Arch Linux (linux.kumanet) - DNS Server, Docker Swarm Manager
- **Worker Node 1**: Windows 11 Pro (windows.kumanet) - Docker Swarm Worker  
- **Worker Node 2**: macOS Tahoe (mac.kumanet) - Docker Swarm Worker

## Quick Start

### 1. Prerequisites
- All machines connected to the same network
- DNS resolution working between machines (linux.kumanet, windows.kumanet, mac.kumanet)
- Root/Administrator access on all machines

### 2. Installation Order
Execute these steps in order:

```bash
# 1. Install Docker on all machines
# On Arch Linux:
sudo ./scripts/install-docker-arch.sh

# On Windows (PowerShell as Administrator):
.\scripts\install-docker-windows.ps1

# On macOS:
sudo ./scripts/install-docker-macos.sh
```

```bash
# 2. Configure firewalls
# On Arch Linux:
sudo ./scripts/firewall-arch-linux.sh

# On Windows (PowerShell as Administrator):
.\scripts\firewall-windows.ps1

# On macOS:
sudo ./scripts/firewall-macos.sh
```

```bash
# 3. Initialize Swarm (on Arch Linux only)
sudo ./scripts/init-swarm-manager.sh
```

```bash
# 4. Join workers (copy tokens from step 3)
# On Windows:
.\scripts\join-swarm-worker-windows.ps1 <worker-token> <manager-ip>

# On macOS:
./scripts/join-swarm-worker-macos.sh <worker-token> <manager-ip>
```

### 3. Verify Setup
```bash
# On manager node (Arch Linux):
docker node ls
./scripts/health-check.sh
```

## Detailed Setup Guide

### Network Requirements

All machines must be able to communicate on these ports:
- **2377/tcp**: Cluster management (Manager only)
- **7946/tcp & 7946/udp**: Container network discovery (All nodes)
- **4789/udp**: Overlay network traffic (All nodes)

See [network-requirements.md](network-requirements.md) for detailed information.

### Firewall Configuration

Firewall scripts are provided for each platform:
- **Arch Linux**: `scripts/firewall-arch-linux.sh` - Uses iptables
- **Windows 11**: `scripts/firewall-windows.ps1` - Uses Windows Defender Firewall
- **macOS**: `scripts/firewall-macos.sh` - Uses pfctl and Application Layer Firewall

### Docker Installation

Platform-specific installation scripts:
- **Arch Linux**: `scripts/install-docker-arch.sh` - Uses pacman
- **Windows 11**: `scripts/install-docker-windows.ps1` - Downloads Docker Desktop
- **macOS**: `scripts/install-docker-macos.sh` - Downloads Docker Desktop

### Swarm Management

Use the management script for common operations:
```bash
# Interactive menu
./scripts/manage-swarm.sh

# Command line usage
./scripts/manage-swarm.sh status
./scripts/manage-swarm.sh deploy-nginx
./scripts/manage-swarm.sh scale nginx-web 5
```

## Service Deployment

### Using Docker Compose Stack
Deploy the example stack:
```bash
docker stack deploy -c docker-compose.yml homelab
```

This deploys:
- Nginx web servers (3 replicas)
- Traefik load balancer
- PostgreSQL database
- Redis cache
- API backend (2 replicas)
- Monitoring stack (Prometheus, Grafana, Loki)

### Individual Services
```bash
# Deploy simple nginx service
docker service create --name web --replicas 3 --publish 80:80 nginx:alpine

# Scale service
docker service scale web=5

# Update service
docker service update --image nginx:latest web

# Remove service
docker service rm web
```

## Monitoring and Health Checks

### Health Check Script
Run comprehensive health checks:
```bash
./scripts/health-check.sh
```

This checks:
- Node status and connectivity
- Service health and replica counts
- Network and volume status
- System resources

### Monitoring Stack
Access monitoring services:
- **Grafana**: http://manager-ip:3000 (admin/admin)
- **Prometheus**: http://manager-ip:9090
- **Portainer**: http://manager-ip:9000

## Directory Structure

```
home_lab_docker_swarm_setup/
├── home_lab_machines.md          # Machine specifications
├── network-requirements.md        # Network configuration details
├── docker-compose.yml            # Example multi-service stack
├── README.md                     # This file
├── scripts/
│   ├── install-docker-arch.sh    # Docker installation for Arch Linux
│   ├── install-docker-windows.ps1 # Docker installation for Windows
│   ├── install-docker-macos.sh   # Docker installation for macOS
│   ├── firewall-arch-linux.sh    # Firewall setup for Arch Linux
│   ├── firewall-windows.ps1      # Firewall setup for Windows
│   ├── firewall-macos.sh         # Firewall setup for macOS
│   ├── init-swarm-manager.sh     # Initialize Swarm manager
│   ├── join-swarm-worker-windows.ps1 # Join Windows worker
│   ├── join-swarm-worker-macos.sh # Join macOS worker
│   ├── manage-swarm.sh           # Swarm management utilities
│   └── health-check.sh           # Health monitoring script
└── monitoring/
    ├── prometheus.yml            # Prometheus configuration
    └── promtail.yml             # Promtail log shipping config
```

## Common Commands

### Swarm Management
```bash
# View nodes
docker node ls

# View services
docker service ls

# View service details
docker service ps <service-name>

# View service logs
docker service logs <service-name>

# Get join tokens
docker swarm join-token worker
docker swarm join-token manager
```

### Node Management
```bash
# Drain node for maintenance
docker node update --availability drain <node-name>

# Activate node after maintenance
docker node update --availability active <node-name>

# Remove node from swarm
docker node rm <node-name>

# Promote worker to manager
docker node promote <node-name>

# Demote manager to worker
docker node demote <node-name>
```

### Stack Management
```bash
# Deploy stack
docker stack deploy -c docker-compose.yml <stack-name>

# List stacks
docker stack ls

# List stack services
docker stack services <stack-name>

# Remove stack
docker stack rm <stack-name>
```

## Troubleshooting

### Common Issues

1. **Nodes not joining**
   - Check firewall rules
   - Verify network connectivity: `nc -zv <manager-ip> 2377`
   - Check Docker daemon is running
   - Verify join token is correct

2. **Services not starting**
   - Check node constraints
   - Verify image availability
   - Check resource requirements
   - Review service logs: `docker service logs <service>`

3. **Network connectivity issues**
   - Verify overlay networks: `docker network ls`
   - Check DNS resolution between containers
   - Validate firewall rules for ports 7946 and 4789

4. **Performance issues**
   - Monitor resource usage: `docker system df`
   - Check node resource constraints
   - Review service placement and distribution

### Diagnostic Commands
```bash
# System information
docker system info

# Node resource usage
docker system df

# Swarm state
docker info | grep -i swarm

# Network inspection
docker network inspect <network-name>

# Service inspection
docker service inspect <service-name>
```

### Log Files
- **Arch Linux**: `/var/log/docker/` or `journalctl -u docker`
- **Windows**: Docker Desktop logs in `%APPDATA%\Docker\log`
- **macOS**: Docker Desktop logs in `~/Library/Containers/com.docker.docker/Data/log`

## Security Considerations

1. **TLS Encryption**: Docker Swarm automatically encrypts all management and data plane communications
2. **Secrets Management**: Use Docker secrets for sensitive data
3. **Access Control**: Implement proper RBAC if needed
4. **Network Segmentation**: Use overlay networks to isolate services
5. **Regular Updates**: Keep Docker and system packages updated

## Backup and Recovery

### Backup Swarm State
```bash
# On manager node, backup swarm state
sudo cp -r /var/lib/docker/swarm /backup/swarm-$(date +%Y%m%d)
```

### Backup Volumes
```bash
# Create volume backup
docker run --rm -v <volume-name>:/data -v $(pwd):/backup alpine tar czf /backup/volume-backup.tar.gz -C /data .
```

### Disaster Recovery
1. Maintain multiple manager nodes for high availability
2. Regular backups of critical data volumes
3. Document restoration procedures
4. Test recovery procedures regularly

## Maintenance

### Regular Tasks
- Run health checks: `./scripts/health-check.sh`
- Update services: `docker service update --image <new-image> <service>`
- Clean up unused resources: `docker system prune`
- Monitor resource usage and performance
- Review logs for errors or security issues

### Updating Docker
Follow platform-specific update procedures and test in non-production environment first.

## Contributing

To extend this setup:
1. Add new services to `docker-compose.yml`
2. Update firewall scripts if new ports are needed
3. Enhance monitoring configuration
4. Add new management scripts as needed

## Support

For issues:
1. Check the troubleshooting section
2. Review Docker Swarm documentation
3. Run health check script for detailed diagnostics
4. Check system logs for specific error messages