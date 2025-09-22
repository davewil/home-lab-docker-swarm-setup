# Docker Installation Script for Windows 11
# This script downloads and installs Docker Desktop for Windows

# IMPORTANT: CUSTOM HOSTNAME CONFIGURATION
# ===========================================
# By default, Docker Desktop uses "docker-desktop" as the hostname when joining Docker Swarm.
# To use a custom hostname (e.g., "windows"), you need to configure Docker after installation:
#
# METHOD 1: Create/edit daemon.json file
# 1. Create file: %USERPROFILE%\.docker\daemon.json
# 2. Add content: { "hostname": "windows" }
# 3. Restart Docker Desktop
#
# METHOD 2: Docker Desktop Settings
# 1. Open Docker Desktop → Settings → Docker Engine
# 2. Add to JSON: "hostname": "windows"
# 3. Apply & Restart
#
# After changing hostname, leave and rejoin the swarm:
# docker swarm leave
# docker swarm join --token <token> <manager-ip>:2377

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

Write-Host "Installing Docker Desktop on Windows 11..." -ForegroundColor Green

# Check Windows version
$windowsVersion = (Get-WmiObject -Class Win32_OperatingSystem).Version
Write-Host "Windows version: $windowsVersion" -ForegroundColor Cyan

# Enable Windows features required for Docker Desktop
Write-Host "Enabling required Windows features..." -ForegroundColor Yellow

# Enable Hyper-V (required for Docker Desktop)
try {
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
    Write-Host "✓ Hyper-V enabled" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to enable Hyper-V: $($_.Exception.Message)"
}

# Enable WSL2 (Windows Subsystem for Linux)
try {
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
    Write-Host "✓ WSL2 features enabled" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to enable WSL2 features: $($_.Exception.Message)"
}

# Set WSL2 as default version
wsl --set-default-version 2

# Download Docker Desktop installer
$dockerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
$installerPath = "$env:TEMP\DockerDesktopInstaller.exe"

Write-Host "Downloading Docker Desktop installer..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $dockerUrl -OutFile $installerPath -UseBasicParsing
    Write-Host "✓ Docker Desktop installer downloaded" -ForegroundColor Green
}
catch {
    Write-Error "Failed to download Docker Desktop installer: $($_.Exception.Message)"
    exit 1
}

# Install Docker Desktop
Write-Host "Installing Docker Desktop..." -ForegroundColor Yellow
try {
    Start-Process -FilePath $installerPath -ArgumentList "install", "--quiet", "--accept-license" -Wait
    Write-Host "✓ Docker Desktop installed successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to install Docker Desktop: $($_.Exception.Message)"
    exit 1
}

# Clean up installer
Remove-Item $installerPath -Force

# Create Docker Desktop configuration for Swarm
$dockerConfigPath = "$env:APPDATA\Docker"
if (!(Test-Path $dockerConfigPath)) {
    New-Item -ItemType Directory -Path $dockerConfigPath -Force
}

$dockerSettings = @{
    "autoStart" = $true
    "exposeDockerAPIOnTCP2375" = $false
    "useWindowsContainers" = $false
    "enableExperimentalFeatures" = $false
    "swarmModeEnabled" = $true
} | ConvertTo-Json

$dockerSettings | Out-File -FilePath "$dockerConfigPath\settings.json" -Encoding UTF8

Write-Host "`n✓ Docker Desktop installation completed" -ForegroundColor Green
Write-Host "`nIMPORTANT: A system restart is required to complete the installation." -ForegroundColor Red
Write-Host "`nAfter restart:" -ForegroundColor White
Write-Host "1. Start Docker Desktop from Start Menu" -ForegroundColor Gray
Write-Host "2. Complete Docker Desktop setup wizard" -ForegroundColor Gray
Write-Host "3. Run firewall configuration: .\firewall-windows.ps1" -ForegroundColor Gray
Write-Host "4. Join Docker Swarm as worker node" -ForegroundColor Gray

Write-Host "`n=== IMPORTANT: CONFIGURE CUSTOM HOSTNAME ===" -ForegroundColor Red
Write-Host "After Docker Desktop starts, configure a custom hostname:" -ForegroundColor Yellow
Write-Host "1. Create file: %USERPROFILE%\.docker\daemon.json" -ForegroundColor White
Write-Host "2. Add content: { `"hostname`": `"windows`" }" -ForegroundColor White
Write-Host "3. Restart Docker Desktop" -ForegroundColor White
Write-Host "4. Leave existing swarm: docker swarm leave" -ForegroundColor White
Write-Host "5. Rejoin with: docker swarm join --token <token> <manager-ip>:2377" -ForegroundColor White

Write-Host "`nTo verify installation after restart:" -ForegroundColor White
Write-Host "docker --version" -ForegroundColor Gray
Write-Host "docker system info" -ForegroundColor Gray

$restart = Read-Host "`nRestart computer now? (y/N)"
if ($restart -eq 'y' -or $restart -eq 'Y') {
    Write-Host "Restarting computer..." -ForegroundColor Yellow
    Restart-Computer -Force
}