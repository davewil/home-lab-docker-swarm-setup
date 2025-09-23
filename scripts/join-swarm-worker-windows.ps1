# Docker Swarm Worker Join Script for Windows 11
# Run this script on the Windows machine (windows.kumanet)

# IMPORTANT: CONFIGURE CUSTOM HOSTNAME FIRST!
# ===========================================
# Before running this script, configure a custom hostname for Docker:
# 1. Create file: %USERPROFILE%\.docker\daemon.json
# 2. Add content: { "hostname": "windows" }
# 3. Restart Docker Desktop
# This will make your node appear as "windows" instead of "docker-desktop" in swarm listings.

param(
    [Parameter(Mandatory=$true)]
    [string]$WorkerToken,
    
    [Parameter(Mandatory=$true)]
    [string]$ManagerIP
)

Write-Host "Joining Docker Swarm as Worker Node (Windows 11)..." -ForegroundColor Green

# Check if Docker is running
try {
    docker system info | Out-Null
    Write-Host "✓ Docker is running" -ForegroundColor Green
}
catch {
    Write-Error "Docker is not running. Please start Docker Desktop first."
    exit 1
}

# Check if already part of a swarm
try {
    $swarmInfo = docker info --format '{{.Swarm.LocalNodeState}}' 2>$null
    if ($swarmInfo -eq "active") {
        Write-Host "This node is already part of a Docker Swarm." -ForegroundColor Yellow
        docker info --format 'Swarm: {{.Swarm.LocalNodeState}}'
        exit 0
    }
}
catch {
    # Not in swarm, continue
}

# Validate inputs
if (-not $WorkerToken.StartsWith("SWMTKN-1-")) {
    Write-Error "Invalid worker token format. Token should start with 'SWMTKN-1-'"
    exit 1
}

Write-Host "Worker Token: $($WorkerToken.Substring(0,20))..." -ForegroundColor Cyan
Write-Host "Manager IP: $ManagerIP" -ForegroundColor Cyan

# Test connectivity to manager node
Write-Host "Testing connectivity to manager node at ${ManagerIP}:2377..." -ForegroundColor Yellow
try {
    $connection = Test-NetConnection -ComputerName $ManagerIP -Port 2377 -WarningAction SilentlyContinue
    if ($connection.TcpTestSucceeded) {
        Write-Host "✓ Manager node is reachable" -ForegroundColor Green
    }
    else {
        Write-Error "Cannot reach manager node at ${ManagerIP}:2377"
        Write-Host "Please check:" -ForegroundColor Red
        Write-Host "1. Manager node is running and Docker Swarm is initialized" -ForegroundColor Gray
        Write-Host "2. Firewall allows port 2377" -ForegroundColor Gray
        Write-Host "3. Network connectivity between machines" -ForegroundColor Gray
        exit 1
    }
}
catch {
    Write-Warning "Could not test connectivity: $($_.Exception.Message)"
}

# Join the swarm
Write-Host "Joining Docker Swarm..." -ForegroundColor Yellow
try {
    $joinCommand = "docker swarm join --token $WorkerToken ${ManagerIP}:2377"
    Invoke-Expression $joinCommand
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Successfully joined Docker Swarm as worker node" -ForegroundColor Green
        # Promote this node to manager
        Write-Host "Promoting this node to manager..." -ForegroundColor Yellow
        docker node promote $env:COMPUTERNAME
        # Add tags for this node
        Write-Host "Tagging this node with: web,db,ai,webrtc,monitoring" -ForegroundColor Yellow
        docker node update --label-add tags=web,db,ai,webrtc,monitoring $env:COMPUTERNAME
        Write-Host "✓ Node promoted to manager and tagged" -ForegroundColor Green
        # Automated verification
        Write-Host "Verifying manager status and tags..." -ForegroundColor Yellow
        $role = docker node inspect $env:COMPUTERNAME --format '{{ .Spec.Role }}'
        $labels = docker node inspect $env:COMPUTERNAME --format '{{ .Spec.Labels.tags }}'
        if ($role -eq 'manager') {
            Write-Host "✓ Node is a manager" -ForegroundColor Green
        } else {
            Write-Error "✗ Node is NOT a manager!"
            exit 1
        }
        if ($labels -eq 'web,db,ai,webrtc,monitoring') {
            Write-Host "✓ Node tags are correct: $labels" -ForegroundColor Green
        } else {
            Write-Error "✗ Node tags are incorrect: $labels"
            exit 1
        }
    }
    else {
        Write-Error "Failed to join Docker Swarm (exit code: $LASTEXITCODE)"
        exit 1
    }
}
catch {
    Write-Error "Failed to join Docker Swarm: $($_.Exception.Message)"
    exit 1
}

# Verify swarm membership
Write-Host "`n=== Swarm Information ===" -ForegroundColor White
try {
    $localNodeState = docker info --format '{{.Swarm.LocalNodeState}}'
    $nodeId = docker info --format '{{.Swarm.NodeID}}'
    $managerAddresses = docker info --format '{{.Swarm.RemoteManagers}}'
    
    Write-Host "Swarm: $localNodeState" -ForegroundColor Cyan
    Write-Host "NodeID: $nodeId" -ForegroundColor Cyan
    Write-Host "Manager Addresses: $managerAddresses" -ForegroundColor Cyan
}
catch {
    Write-Warning "Could not retrieve swarm information: $($_.Exception.Message)"
}

Write-Host "`n✓ Windows worker node successfully joined the Docker Swarm" -ForegroundColor Green
Write-Host "`nVerify on manager node with: docker node ls" -ForegroundColor White

# Create a helper script for leaving the swarm if needed
$leaveSwarmScript = @'
# Script to leave Docker Swarm
Write-Host "Leaving Docker Swarm..." -ForegroundColor Yellow
docker swarm leave
Write-Host "Left Docker Swarm" -ForegroundColor Green
'@

$leaveSwarmScript | Out-File -FilePath "$env:TEMP\leave-swarm.ps1" -Encoding UTF8
Write-Host "`nHelper script created: $env:TEMP\leave-swarm.ps1" -ForegroundColor Gray
Write-Host "Use this script to leave the swarm if needed" -ForegroundColor Gray