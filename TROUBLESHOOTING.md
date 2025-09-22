# Troubleshooting Guide

This guide covers common issues you might encounter during Docker Swarm setup and their solutions.

## Docker Installation Issues

### 1. Docker Service Fails to Start on Arch Linux

**Error**: 
```
Job for docker.service failed because the control process exited with error code.
```

**Common Causes and Solutions**:

#### A. Conflicting hosts directive
**Symptoms**: 
```
unable to configure the Docker daemon with file /etc/docker/daemon.json: the following directives are specified both as a flag and in the configuration file: hosts
```

**Solution**:
```bash
# Remove the "hosts" directive from daemon.json
sudo nano /etc/docker/daemon.json
# Remove the line: "hosts": ["unix:///var/run/docker.sock"],
sudo systemctl restart docker
```

#### B. Missing bridge netfilter module
**Symptoms**:
```
failed to start daemon: Error initializing network controller: error creating default "bridge" network: cannot restrict inter-container communication or run without the userland proxy: stat /proc/sys/net/bridge/bridge-nf-call-iptables: no such file or directory
```

**Solution**:
```bash
# Create systemd override
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/ignore-bridge-netfilter.conf << 'EOF'
[Service]
Environment="DOCKER_IGNORE_BR_NETFILTER_ERROR=1"
EOF

# Update daemon.json to enable userland-proxy
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "userland-proxy": true,
  "experimental": false
}
EOF

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 2. Docker Desktop Installation Issues on Windows/macOS

#### Windows: Hyper-V not available
**Error**: Docker Desktop requires Hyper-V

**Solution**:
```powershell
# Enable Hyper-V in PowerShell as Administrator
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

#### macOS: Permission denied
**Error**: Cannot install Docker Desktop due to permissions

**Solution**:
```bash
# Ensure you have admin privileges and run with sudo
sudo ./scripts/install-docker-macos.sh
```

## Network and Firewall Issues

### 1. Swarm Nodes Cannot Communicate

**Symptoms**:
- Workers fail to join the swarm
- `docker node ls` shows nodes as "Down"
- Connection timeouts

**Diagnostic Commands**:
```bash
# Test connectivity to manager node
nc -zv <manager-ip> 2377

# Test Swarm discovery ports
nc -zv <node-ip> 7946
nc -uzv <node-ip> 7946

# Test overlay network port
nc -uzv <node-ip> 4789
```

**Solutions**:

#### Check firewall rules
```bash
# On Arch Linux
sudo iptables -L | grep -E "2377|7946|4789"

# On Windows (PowerShell as Administrator)
Get-NetFirewallRule -DisplayName "*Docker Swarm*"

# On macOS
sudo pfctl -sa | grep -E "2377|7946|4789"
```

#### Re-run firewall scripts
```bash
# Arch Linux
sudo ./scripts/firewall-arch-linux.sh

# Windows (PowerShell as Administrator)
.\scripts\firewall-windows.ps1

# macOS
sudo ./scripts/firewall-macos.sh
```

### 2. DNS Resolution Issues

**Symptoms**:
- Cannot resolve hostnames (linux.kumanet, windows.kumanet, mac.kumanet)
- Services cannot communicate across nodes

**Solution**:
```bash
# Add entries to /etc/hosts (Linux/macOS) or C:\Windows\System32\drivers\etc\hosts (Windows)
192.168.1.100  linux.kumanet
192.168.1.101  windows.kumanet  
192.168.1.102  mac.kumanet

# Or configure your router/DNS server to resolve these hostnames
```

## Swarm Management Issues

### 1. Cannot Initialize Swarm

**Error**: 
```
Error response from daemon: could not choose an IP address to advertise since this system has multiple addresses
```

**Solution**:
```bash
# Specify the advertise address explicitly
docker swarm init --advertise-addr <specific-ip-address>
```

**Error**:
```
Error response from daemon: --live-restore daemon configuration is incompatible with swarm mode
```

**Solution**:
```bash
# Remove live-restore from daemon.json
sudo nano /etc/docker/daemon.json
# Remove the line: "live-restore": true,
sudo systemctl restart docker
```

### 2. Worker Fails to Join

**Error**:
```
Error response from daemon: rpc error: code = Unavailable desc = connection error
```

**Diagnostic Steps**:
```bash
# 1. Verify manager is accessible
nc -zv <manager-ip> 2377

# 2. Check if token is valid (run on manager)
docker swarm join-token worker

# 3. Verify no existing swarm membership
docker system info | grep -i swarm

# 4. Leave existing swarm if needed
docker swarm leave --force
```

### 3. Node Shows as "Down"

**Symptoms**:
- `docker node ls` shows nodes with status "Down"
- Services not scheduling on certain nodes

**Solutions**:
```bash
# Check node availability
docker node inspect <node-name> | grep -i availability

# Make node active if drained
docker node update --availability active <node-name>

# Check Docker daemon on the node
systemctl status docker  # Linux
# Or check Docker Desktop status on Windows/macOS
```

## Service Deployment Issues

### 1. Service Fails to Start

**Common Issues**:

#### Insufficient resources
```bash
# Check node resources
docker node ls
docker system df
```

#### Image pull failures
```bash
# Check service events
docker service ps <service-name>

# Check if image exists and is accessible
docker pull <image-name>
```

#### Port conflicts
```bash
# Check what's using the port
sudo netstat -tlnp | grep <port>
sudo ss -tlnp | grep <port>
```

### 2. Services Not Accessible

**Symptoms**:
- Cannot connect to published ports
- Services running but not responding

**Solutions**:
```bash
# Check service status
docker service ps <service-name>

# Check service logs
docker service logs <service-name>

# Verify port publishing
docker service inspect <service-name> | grep -A 10 Ports

# Check if service is on worker nodes only
docker service inspect <service-name> | grep -A 5 Placement
```

## Performance Issues

### 1. Slow Container Startup

**Causes**:
- Large images
- Network latency
- Resource constraints

**Solutions**:
```bash
# Use smaller base images
# Enable Docker BuildKit
export DOCKER_BUILDKIT=1

# Check resource usage
docker system df
docker stats

# Clean up unused resources
docker system prune -f
```

### 2. High Memory Usage

**Solutions**:
```bash
# Limit container memory
docker service update --limit-memory 512m <service-name>

# Check memory usage per service
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Clean up logs
docker system prune --volumes
```

## Diagnostic Commands Reference

### System Information
```bash
# Docker system info
docker system info

# Swarm status
docker info | grep -i swarm

# Node information
docker node ls
docker node inspect <node-name>
```

### Service Information
```bash
# List services
docker service ls

# Service details
docker service ps <service-name>
docker service inspect <service-name>

# Service logs
docker service logs --tail 100 <service-name>
```

### Network Information
```bash
# List networks
docker network ls

# Network details
docker network inspect <network-name>

# Container networking
docker exec <container> ip addr show
```

### Resource Usage
```bash
# System resource usage
docker system df

# Container resource usage
docker stats

# Cleanup commands
docker system prune -f
docker volume prune -f
docker network prune -f
```

## Getting Help

1. **Run the health check script**:
   ```bash
   ./scripts/health-check.sh
   ```

2. **Check logs**:
   ```bash
   # Docker daemon logs (Linux)
   journalctl -u docker.service
   
   # Windows: Check Docker Desktop logs
   # macOS: Check Docker Desktop logs in Console app
   ```

3. **Enable debug logging**:
   ```bash
   # Add to daemon.json
   {
     "debug": true,
     "log-level": "debug"
   }
   ```

4. **Community Resources**:
   - [Docker Documentation](https://docs.docker.com/)
   - [Docker Community Forums](https://forums.docker.com/)
   - [Stack Overflow](https://stackoverflow.com/questions/tagged/docker)

## Report Issues

If you encounter issues not covered in this guide:

1. Run the health check script: `./scripts/health-check.sh`
2. Gather system information: `docker system info`
3. Check logs for error messages
4. Open an issue in the GitHub repository with:
   - Operating system and version
   - Docker version
   - Error messages or logs
   - Steps to reproduce
   - Output from health check script