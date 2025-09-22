#!/bin/bash

# Docker Swarm Setup Automation Script
# This script guides you through the complete setup process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo ""
    echo "=============================================="
    echo -e "${GREEN}$1${NC}"
    echo "=============================================="
    echo ""
}

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v pacman > /dev/null 2>&1; then
            echo "arch"
        elif command -v apt > /dev/null 2>&1; then
            echo "debian"
        elif command -v yum > /dev/null 2>&1; then
            echo "redhat"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Main setup function
main() {
    print_header "Docker Swarm Home Lab Setup"
    
    OS=$(detect_os)
    print_info "Detected OS: $OS"
    
    case "$OS" in
        "arch")
            print_info "Setting up Arch Linux as Manager Node"
            setup_arch_manager
            ;;
        "macos")
            print_info "Setting up macOS as Worker Node"
            setup_macos_worker
            ;;
        "windows")
            print_info "Setting up Windows as Worker Node"
            setup_windows_worker
            ;;
        *)
            print_error "Unsupported operating system: $OS"
            print_info "Please follow the manual setup instructions in README.md"
            exit 1
            ;;
    esac
}

setup_arch_manager() {
    print_header "Arch Linux Manager Setup"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root on Arch Linux"
        print_info "Please run: sudo $0"
        exit 1
    fi
    
    print_info "Step 1: Installing Docker..."
    if ./scripts/install-docker-arch.sh; then
        print_success "Docker installed successfully"
    else
        print_error "Docker installation failed"
        exit 1
    fi
    
    print_info "Step 2: Configuring firewall..."
    if ./scripts/firewall-arch-linux.sh; then
        print_success "Firewall configured successfully"
    else
        print_error "Firewall configuration failed"
        exit 1
    fi
    
    print_info "Step 3: Initializing Docker Swarm..."
    if ./scripts/init-swarm-manager.sh; then
        print_success "Docker Swarm initialized successfully"
    else
        print_error "Docker Swarm initialization failed"
        exit 1
    fi
    
    print_header "Manager Setup Complete"
    print_success "Arch Linux manager node is ready!"
    print_info "Next steps:"
    print_info "1. Copy the worker join tokens to other machines"
    print_info "2. Run this setup script on Windows and macOS machines"
    print_info "3. Use the join commands displayed above"
    print_info ""
    print_info "Management commands:"
    print_info "- Check swarm status: docker node ls"
    print_info "- Run health check: ./scripts/health-check.sh"
    print_info "- Manage services: ./scripts/manage-swarm.sh"
}

setup_macos_worker() {
    print_header "macOS Worker Setup"
    
    print_info "Step 1: Installing Docker Desktop..."
    print_warning "This will download and install Docker Desktop for macOS"
    read -p "Continue? (y/N): " continue_install
    
    if [[ "$continue_install" != "y" ]] && [[ "$continue_install" != "Y" ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
    
    if sudo ./scripts/install-docker-macos.sh; then
        print_success "Docker Desktop installation completed"
        print_warning "Please start Docker Desktop and complete the setup wizard"
        print_info "Press Enter after Docker Desktop is running..."
        read
    else
        print_error "Docker Desktop installation failed"
        exit 1
    fi
    
    print_info "Step 2: Configuring firewall..."
    if sudo ./scripts/firewall-macos.sh; then
        print_success "Firewall configured successfully"
    else
        print_error "Firewall configuration failed"
        exit 1
    fi
    
    print_header "macOS Worker Setup Complete"
    print_success "macOS worker node is ready to join the swarm!"
    print_info ""
    print_info "To join the swarm, run:"
    print_info "./scripts/join-swarm-worker-macos.sh <worker-token> <manager-ip>"
    print_info ""
    print_info "Get the worker token from the manager node:"
    print_info "docker swarm join-token worker"
}

setup_windows_worker() {
    print_header "Windows Worker Setup"
    print_warning "Windows setup requires PowerShell scripts to be run separately"
    print_info ""
    print_info "Please run these commands in PowerShell as Administrator:"
    print_info "1. .\\scripts\\install-docker-windows.ps1"
    print_info "2. .\\scripts\\firewall-windows.ps1"
    print_info "3. .\\scripts\\join-swarm-worker-windows.ps1 <worker-token> <manager-ip>"
    print_info ""
    print_info "Get the worker token from the manager node with:"
    print_info "docker swarm join-token worker"
}

# Check if script exists and make executable
check_scripts() {
    local script_dir="./scripts"
    if [[ ! -d "$script_dir" ]]; then
        print_error "Scripts directory not found. Please run this from the project root."
        exit 1
    fi
    
    # Make scripts executable
    chmod +x "$script_dir"/*.sh 2>/dev/null || true
}

# Pre-flight checks
preflight_checks() {
    print_info "Running pre-flight checks..."
    
    check_scripts
    
    # Check for required commands
    local required_commands=("docker")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" > /dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]] && [[ "$OS" != "arch" ]]; then
        print_warning "Missing commands: ${missing_commands[*]}"
        print_info "These will be installed during setup"
    fi
    
    print_success "Pre-flight checks completed"
}

# Help function
show_help() {
    echo "Docker Swarm Home Lab Setup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo "  --check       Run pre-flight checks only"
    echo ""
    echo "This script will:"
    echo "1. Detect your operating system"
    echo "2. Install Docker (if needed)"
    echo "3. Configure firewall rules"
    echo "4. Initialize Swarm (Arch Linux) or prepare for joining (other OS)"
    echo ""
    echo "Supported platforms:"
    echo "- Arch Linux (Manager node)"
    echo "- macOS (Worker node)"
    echo "- Windows (Worker node - requires manual PowerShell execution)"
    echo ""
    echo "For detailed instructions, see README.md"
}

# Parse command line arguments
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --check)
        preflight_checks
        exit 0
        ;;
    *)
        preflight_checks
        main
        ;;
esac