#!/bin/bash

# Docker Swarm Health Check Script
# Run this script on the manager node to check swarm health

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

# Health check results
HEALTH_CHECKS=()

# Add health check result
add_check() {
    local status="$1"
    local message="$2"
    HEALTH_CHECKS+=("$status|$message")
}

# Check if this is a manager node
check_manager_node() {
    print_info "Checking manager node status..."
    if docker node ls > /dev/null 2>&1; then
        add_check "✓" "Manager node accessible"
        print_success "Manager node accessible"
    else
        add_check "✗" "Not a manager node or Docker Swarm not initialized"
        print_error "Not a manager node or Docker Swarm not initialized"
        return 1
    fi
}

# Check swarm nodes
check_swarm_nodes() {
    print_info "Checking swarm nodes..."
    
    local nodes_output=$(docker node ls --format "table {{.Hostname}}\t{{.Status}}\t{{.Availability}}\t{{.ManagerStatus}}")
    echo "$nodes_output"
    
    local total_nodes=$(docker node ls --format "{{.ID}}" | wc -l)
    local ready_nodes=$(docker node ls --filter "status=ready" --format "{{.ID}}" | wc -l)
    local active_nodes=$(docker node ls --filter "availability=active" --format "{{.ID}}" | wc -l)
    
    print_info "Node summary: $ready_nodes/$total_nodes ready, $active_nodes/$total_nodes active"
    
    if [[ $ready_nodes -eq $total_nodes ]] && [[ $active_nodes -eq $total_nodes ]]; then
        add_check "✓" "All nodes ($total_nodes) are ready and active"
        print_success "All nodes are healthy"
    else
        add_check "⚠" "$ready_nodes/$total_nodes nodes ready, $active_nodes/$total_nodes active"
        print_warning "Some nodes may have issues"
    fi
}

# Check services
check_services() {
    print_info "Checking services..."
    
    local services=$(docker service ls --format "table {{.Name}}\t{{.Mode}}\t{{.Replicas}}\t{{.Image}}")
    if [[ -n "$services" ]]; then
        echo "$services"
        
        local total_services=$(docker service ls --format "{{.ID}}" | wc -l)
        local converged_services=0
        
        while IFS= read -r service_id; do
            local service_name=$(docker service inspect --format "{{.Spec.Name}}" "$service_id")
            local desired=$(docker service inspect --format "{{.Spec.Mode.Replicated.Replicas}}" "$service_id" 2>/dev/null || echo "1")
            local running=$(docker service ps "$service_id" --filter "desired-state=running" --format "{{.DesiredState}}" | wc -l)
            
            if [[ "$running" -eq "$desired" ]]; then
                ((converged_services++))
            else
                print_warning "Service $service_name: $running/$desired replicas running"
            fi
        done < <(docker service ls --format "{{.ID}}")
        
        if [[ $converged_services -eq $total_services ]]; then
            add_check "✓" "All services ($total_services) are converged"
            print_success "All services are healthy"
        else
            add_check "⚠" "$converged_services/$total_services services converged"
            print_warning "Some services may have issues"
        fi
    else
        add_check "ℹ" "No services deployed"
        print_info "No services deployed"
    fi
}

# Check networks
check_networks() {
    print_info "Checking overlay networks..."
    
    local overlay_networks=$(docker network ls --filter "driver=overlay" --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}")
    if [[ -n "$overlay_networks" ]]; then
        echo "$overlay_networks"
        local network_count=$(docker network ls --filter "driver=overlay" --format "{{.ID}}" | wc -l)
        add_check "✓" "$network_count overlay networks available"
    else
        add_check "ℹ" "No overlay networks found"
        print_info "No overlay networks found"
    fi
}

# Check volumes
check_volumes() {
    print_info "Checking volumes..."
    
    local volumes=$(docker volume ls --format "table {{.Name}}\t{{.Driver}}")
    if [[ -n "$volumes" ]]; then
        echo "$volumes"
        local volume_count=$(docker volume ls --format "{{.Name}}" | wc -l)
        add_check "✓" "$volume_count volumes available"
    else
        add_check "ℹ" "No volumes found"
        print_info "No volumes found"
    fi
}

# Check system resources
check_system_resources() {
    print_info "Checking system resources..."
    
    # Docker system info
    local docker_info=$(docker system info --format "json" 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        local containers_running=$(echo "$docker_info" | jq -r '.ContainersRunning // 0')
        local containers_total=$(echo "$docker_info" | jq -r '.Containers // 0')
        local images_count=$(echo "$docker_info" | jq -r '.Images // 0')
        
        print_info "Containers: $containers_running running / $containers_total total"
        print_info "Images: $images_count"
        
        add_check "✓" "System resources accessible"
    else
        add_check "⚠" "Could not retrieve system information"
        print_warning "Could not retrieve system information"
    fi
}

# Check connectivity between nodes
check_node_connectivity() {
    print_info "Checking node connectivity..."
    
    local failed_connections=0
    
    while IFS= read -r node_info; do
        local hostname=$(echo "$node_info" | awk '{print $1}')
        local status=$(echo "$node_info" | awk '{print $2}')
        
        if [[ "$hostname" != "HOSTNAME" ]] && [[ "$status" == "Ready" ]]; then
            # Test Docker Swarm ports
            if nc -z "$hostname" 2377 2>/dev/null; then
                print_success "Connectivity to $hostname:2377 ✓"
            else
                print_error "Cannot connect to $hostname:2377"
                ((failed_connections++))
            fi
        fi
    done < <(docker node ls --format "{{.Hostname}} {{.Status}}")
    
    if [[ $failed_connections -eq 0 ]]; then
        add_check "✓" "All nodes are reachable"
    else
        add_check "✗" "$failed_connections nodes unreachable"
    fi
}

# Generate health report
generate_report() {
    echo ""
    print_info "=== Docker Swarm Health Report ==="
    echo "Generated: $(date)"
    echo ""
    
    for check in "${HEALTH_CHECKS[@]}"; do
        local status=$(echo "$check" | cut -d'|' -f1)
        local message=$(echo "$check" | cut -d'|' -f2)
        echo -e "$status $message"
    done
    
    echo ""
    
    # Count status types
    local success_count=$(printf '%s\n' "${HEALTH_CHECKS[@]}" | grep -c "✓" || echo "0")
    local warning_count=$(printf '%s\n' "${HEALTH_CHECKS[@]}" | grep -c "⚠" || echo "0")
    local error_count=$(printf '%s\n' "${HEALTH_CHECKS[@]}" | grep -c "✗" || echo "0")
    local info_count=$(printf '%s\n' "${HEALTH_CHECKS[@]}" | grep -c "ℹ" || echo "0")
    
    print_info "Summary: $success_count passed, $warning_count warnings, $error_count errors, $info_count info"
    
    if [[ $error_count -gt 0 ]]; then
        print_error "Swarm has critical issues that need attention"
        return 1
    elif [[ $warning_count -gt 0 ]]; then
        print_warning "Swarm has minor issues to investigate"
        return 2
    else
        print_success "Swarm is healthy"
        return 0
    fi
}

# Main execution
main() {
    echo "Docker Swarm Health Check"
    echo "========================"
    echo ""
    
    check_manager_node || exit 1
    check_swarm_nodes
    check_services
    check_networks
    check_volumes
    check_system_resources
    check_node_connectivity
    
    generate_report
}

# Run main function
main "$@"