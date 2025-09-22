# Docker Swarm Firewall Configuration for Windows 11
# This script configures Windows Defender Firewall for Docker Swarm Worker Node

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

Write-Host "Configuring Windows Defender Firewall for Docker Swarm Worker Node..." -ForegroundColor Green

# Function to create firewall rule
function New-DockerSwarmRule {
    param(
        [string]$DisplayName,
        [string]$Direction,
        [string]$Protocol,
        [string]$LocalPort,
        [string]$Action = "Allow"
    )
    
    try {
        New-NetFirewallRule -DisplayName $DisplayName -Direction $Direction -Protocol $Protocol -LocalPort $LocalPort -Action $Action -Profile Any
        Write-Host "✓ Created rule: $DisplayName" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to create rule: $DisplayName - $($_.Exception.Message)"
    }
}

# Remove existing Docker Swarm rules if they exist
Write-Host "Removing existing Docker Swarm firewall rules..." -ForegroundColor Yellow
Get-NetFirewallRule -DisplayName "*Docker Swarm*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule

# Create inbound rules for Docker Swarm Worker Node
Write-Host "Creating inbound firewall rules..." -ForegroundColor Cyan

# Container network discovery (TCP)
New-DockerSwarmRule -DisplayName "Docker Swarm - Container Network Discovery (TCP-In)" -Direction Inbound -Protocol TCP -LocalPort 7946

# Container network discovery (UDP)
New-DockerSwarmRule -DisplayName "Docker Swarm - Container Network Discovery (UDP-In)" -Direction Inbound -Protocol UDP -LocalPort 7946

# Overlay network traffic (UDP)
New-DockerSwarmRule -DisplayName "Docker Swarm - Overlay Network Traffic (UDP-In)" -Direction Inbound -Protocol UDP -LocalPort 4789

# Create outbound rules for Docker Swarm Worker Node
Write-Host "Creating outbound firewall rules..." -ForegroundColor Cyan

# Container network discovery (TCP)
New-DockerSwarmRule -DisplayName "Docker Swarm - Container Network Discovery (TCP-Out)" -Direction Outbound -Protocol TCP -LocalPort 7946

# Container network discovery (UDP)
New-DockerSwarmRule -DisplayName "Docker Swarm - Container Network Discovery (UDP-Out)" -Direction Outbound -Protocol UDP -LocalPort 7946

# Overlay network traffic (UDP)
New-DockerSwarmRule -DisplayName "Docker Swarm - Overlay Network Traffic (UDP-Out)" -Direction Outbound -Protocol UDP -LocalPort 4789

# Allow outbound connections to manager node (port 2377)
New-NetFirewallRule -DisplayName "Docker Swarm - Manager Communication (TCP-Out)" -Direction Outbound -Protocol TCP -RemotePort 2377 -Action Allow -Profile Any
Write-Host "✓ Created rule: Docker Swarm - Manager Communication (TCP-Out)" -ForegroundColor Green

Write-Host "`n✓ Firewall configuration completed for Docker Swarm Worker node" -ForegroundColor Green
Write-Host "`nConfigured ports:" -ForegroundColor White
Write-Host "  - 7946/tcp: Container network discovery" -ForegroundColor Gray
Write-Host "  - 7946/udp: Container network discovery" -ForegroundColor Gray
Write-Host "  - 4789/udp: Overlay network traffic" -ForegroundColor Gray
Write-Host "  - 2377/tcp: Outbound to manager node" -ForegroundColor Gray

Write-Host "`nTo view created rules:" -ForegroundColor White
Write-Host "Get-NetFirewallRule -DisplayName '*Docker Swarm*'" -ForegroundColor Gray

Write-Host "`nTo test connectivity to manager node:" -ForegroundColor White
Write-Host "Test-NetConnection -ComputerName linux.kumanet -Port 2377" -ForegroundColor Gray