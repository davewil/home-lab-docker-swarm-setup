#!/bin/bash

# Docker Swarm Service Deployment and Management Script
# Run this script on the manager node (linux.kumanet)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if this is a manager node
check_manager() {
    if ! docker node ls > /dev/null 2>&1; then
        print_error "This script must be run on a Docker Swarm manager node"
        exit 1
    fi
}

# Show swarm status
show_swarm_status() {
    print_info "Docker Swarm Status:"
    echo "===================="
    docker node ls
    echo ""
    docker service ls
    echo ""
}

# Deploy a sample nginx service
deploy_nginx() {
    print_info "Deploying nginx service..."
    
    docker service create \
        --name nginx-web \
        --replicas 3 \
        --publish published=80,target=80 \
        --constraint 'node.role == worker' \
        nginx:alpine
    
    print_success "Nginx service deployed"
    print_info "Service details:"
    docker service ps nginx-web
}

# Deploy a sample whoami service for testing
deploy_whoami() {
    print_info "Deploying whoami service for testing..."
    
    docker service create \
        --name whoami-test \
        --replicas 2 \
        --publish published=8080,target=80 \
        --constraint 'node.role == worker' \
        traefik/whoami
    
    print_success "Whoami service deployed"
    print_info "Service details:"
    docker service ps whoami-test
    print_info "Test with: curl http://localhost:8080"
}

# Deploy a monitoring stack (Portainer)
deploy_portainer() {
    print_info "Deploying Portainer for Docker Swarm management..."
    
    # Create portainer data volume
    docker volume create portainer_data
    
    docker service create \
        --name portainer \
        --publish published=9000,target=9000 \
        --publish published=8000,target=8000 \
        --constraint 'node.role == manager' \
        --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
        --mount type=volume,src=portainer_data,dst=/data \
        portainer/portainer-ce:latest \
        -H unix:///var/run/docker.sock
    
    print_success "Portainer deployed"
    print_info "Access Portainer at: http://localhost:9000"
    print_info "Service details:"
    docker service ps portainer
}

# Scale a service
scale_service() {
    local service_name="$1"
    local replicas="$2"
    
    if [[ -z "$service_name" ]] || [[ -z "$replicas" ]]; then
        print_error "Usage: scale_service <service_name> <replicas>"
        return 1
    fi
    
    print_info "Scaling service $service_name to $replicas replicas..."
    docker service scale "$service_name=$replicas"
    print_success "Service $service_name scaled to $replicas replicas"
}

# Remove a service
remove_service() {
    local service_name="$1"
    
    if [[ -z "$service_name" ]]; then
        print_error "Usage: remove_service <service_name>"
        return 1
    fi
    
    print_warning "Removing service $service_name..."
    docker service rm "$service_name"
    print_success "Service $service_name removed"
}

# Update a service
update_service() {
    local service_name="$1"
    local new_image="$2"
    
    if [[ -z "$service_name" ]] || [[ -z "$new_image" ]]; then
        print_error "Usage: update_service <service_name> <new_image>"
        return 1
    fi
    
    print_info "Updating service $service_name to image $new_image..."
    docker service update --image "$new_image" "$service_name"
    print_success "Service $service_name updated"
}

# Create an overlay network
create_network() {
    local network_name="$1"
    
    if [[ -z "$network_name" ]]; then
        network_name="app-network"
    fi
    
    print_info "Creating overlay network: $network_name"
    docker network create --driver overlay --attachable "$network_name"
    print_success "Network $network_name created"
}

# Show service logs
show_logs() {
    local service_name="$1"
    local lines="${2:-50}"
    
    if [[ -z "$service_name" ]]; then
        print_error "Usage: show_logs <service_name> [lines]"
        return 1
    fi
    
    print_info "Showing last $lines lines of logs for service $service_name:"
    docker service logs --tail "$lines" --follow "$service_name"
}

# Main menu
show_menu() {
    echo ""
    echo "Docker Swarm Management Script"
    echo "=============================="
    echo "1. Show swarm status"
    echo "2. Deploy nginx service"
    echo "3. Deploy whoami test service"
    echo "4. Deploy Portainer management"
    echo "5. Scale service"
    echo "6. Update service"
    echo "7. Remove service"
    echo "8. Create overlay network"
    echo "9. Show service logs"
    echo "10. Exit"
    echo ""
}

# Main script
main() {
    check_manager
    
    if [[ $# -eq 0 ]]; then
        # Interactive mode
        while true; do
            show_menu
            read -p "Choose an option (1-10): " choice
            
            case $choice in
                1) show_swarm_status ;;
                2) deploy_nginx ;;
                3) deploy_whoami ;;
                4) deploy_portainer ;;
                5) 
                    read -p "Service name: " svc_name
                    read -p "Number of replicas: " replicas
                    scale_service "$svc_name" "$replicas"
                    ;;
                6)
                    read -p "Service name: " svc_name
                    read -p "New image: " new_image
                    update_service "$svc_name" "$new_image"
                    ;;
                7)
                    read -p "Service name to remove: " svc_name
                    remove_service "$svc_name"
                    ;;
                8)
                    read -p "Network name (default: app-network): " net_name
                    create_network "$net_name"
                    ;;
                9)
                    read -p "Service name: " svc_name
                    read -p "Number of log lines (default: 50): " lines
                    show_logs "$svc_name" "$lines"
                    ;;
                10) exit 0 ;;
                *) print_error "Invalid option" ;;
            esac
        done
    else
        # Command line mode
        case "$1" in
            status) show_swarm_status ;;
            deploy-nginx) deploy_nginx ;;
            deploy-whoami) deploy_whoami ;;
            deploy-portainer) deploy_portainer ;;
            scale) scale_service "$2" "$3" ;;
            update) update_service "$2" "$3" ;;
            remove) remove_service "$2" ;;
            network) create_network "$2" ;;
            logs) show_logs "$2" "$3" ;;
            *)
                echo "Usage: $0 [status|deploy-nginx|deploy-whoami|deploy-portainer|scale|update|remove|network|logs]"
                echo "Run without arguments for interactive mode"
                ;;
        esac
    fi
}

main "$@"