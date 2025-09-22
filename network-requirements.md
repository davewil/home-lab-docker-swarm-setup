# Docker Swarm Network Requirements

## Required Ports

Docker Swarm requires the following ports to be open between all nodes:

### TCP Ports
- **2377**: Cluster management communications (manager nodes only)
- **7946**: Container network discovery (all nodes)

### UDP Ports
- **7946**: Container network discovery (all nodes)
- **4789**: Overlay network traffic (all nodes)

## Machine Network Configuration

### Machine 1 - Arch Linux (Manager Node)
- **Hostname**: linux.kumanet
- **Role**: Manager Node
- **Services**: DNS Server (dnsmasq), Docker
- **Required Ports**: 2377/tcp, 7946/tcp, 7946/udp, 4789/udp

### Machine 2 - Windows 11 Pro (Worker Node)
- **Hostname**: windows.kumanet
- **Role**: Worker Node
- **Services**: Docker
- **Required Ports**: 7946/tcp, 7946/udp, 4789/udp

### Machine 3 - macOS Tahoe (Worker Node)
- **Hostname**: mac.kumanet
- **Role**: Worker Node
- **Services**: Docker
- **Required Ports**: 7946/tcp, 7946/udp, 4789/udp

## Network Verification Commands

Test connectivity between nodes using these commands:

```bash
# Test TCP connectivity
nc -zv <hostname> 2377
nc -zv <hostname> 7946

# Test UDP connectivity (requires netcat with UDP support)
nc -uzv <hostname> 7946
nc -uzv <hostname> 4789
```

## DNS Configuration

Ensure all machines can resolve each other's hostnames:
- linux.kumanet
- windows.kumanet
- mac.kumanet

If using the DNS server on linux.kumanet, ensure all machines are configured to use it.