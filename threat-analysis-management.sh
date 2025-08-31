#!/usr/bin/env bash

# Copyright (c) 2025 DXC AIP Community Scripts
# Author: DXC AIP Team
# License: MIT
# Proxmox Management Script for Threat Analysis System

# Color codes
RD='\033[01;31m'
YW='\033[33m'
GN='\033[1;92m'
BL='\033[36m'
DGN='\033[32m'
CL='\033[m'
BGN='\033[4;92m'

# Default values
DEFAULT_CT_ID=""
DEFAULT_CT_NAME="threat-analysis"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper functions
header_info() {
clear
cat <<"EOF"
    _______ _                    _       _                _           _     
   |__   __| |                  | |     | |              | |         (_)    
      | |  | |__  _ __ ___  __ _| |_    / \   _ __   __ _| |_   _ ___ _ ___ 
      | |  | '_ \| '__/ _ \/ _` | __|   / _ \ | '_ \ / _` | | | | / __| / __|
      | |  | | | | | |  __/ (_| | |_   / ___ \| | | | (_| | | |_| \__ \ \__ \
      |_|  |_| |_|_|  \___|\__,_|\__| /_/   \_\_| |_|\__,_|_|\__, |___/_|___/
                                                              __/ |        
                                                             |___/         
                           PROXMOX MANAGEMENT SCRIPT
EOF
}

msg_info() {
    echo -e " ${YW}⏳ $1...${CL}"
}

msg_ok() {
    echo -e " ${GN}✅ $1${CL}"
}

msg_error() {
    echo -e " ${RD}❌ $1${CL}"
}

msg_warn() {
    echo -e " ${YW}⚠️  $1${CL}"
}

# Find Threat Analysis container
find_container() {
    # Try to find by name first
    CT_ID=$(pct list | grep -i threat-analysis | awk '{print $1}' | head -1)
    
    # If not found by name, try by tag
    if [ -z "$CT_ID" ]; then
        CT_ID=$(pct list | grep -E "threat|analysis" | awk '{print $1}' | head -1)
    fi
    
    # If still not found, list all containers and let user choose
    if [ -z "$CT_ID" ]; then
        echo -e "${YW}No Threat Analysis container found automatically.${CL}"
        echo -e "${BL}Available containers:${CL}"
        pct list
        echo ""
        read -p "Enter Container ID: " CT_ID
    fi
    
    # Validate container exists
    if ! pct status $CT_ID >/dev/null 2>&1; then
        msg_error "Container $CT_ID does not exist"
        exit 1
    fi
    
    CT_NAME=$(pct config $CT_ID | grep "^hostname:" | cut -d' ' -f2)
    msg_ok "Found container: $CT_ID ($CT_NAME)"
}

# Container operations
start_container() {
    msg_info "Starting container $CT_ID"
    pct start $CT_ID
    msg_ok "Container started"
    
    # Wait for container to be fully ready
    sleep 10
    
    # Start application services
    msg_info "Starting Threat Analysis services"
    pct exec $CT_ID -- threat-analysis start
    msg_ok "Services started"
}

stop_container() {
    msg_info "Stopping Threat Analysis services"
    pct exec $CT_ID -- threat-analysis stop 2>/dev/null || true
    
    msg_info "Stopping container $CT_ID"
    pct stop $CT_ID
    msg_ok "Container stopped"
}

restart_container() {
    msg_info "Restarting container $CT_ID"
    pct exec $CT_ID -- threat-analysis stop 2>/dev/null || true
    pct restart $CT_ID
    sleep 15
    pct exec $CT_ID -- threat-analysis start
    msg_ok "Container and services restarted"
}

container_status() {
    echo -e "${BL}Container Status:${CL}"
    pct status $CT_ID
    
    echo -e "\n${BL}Container Configuration:${CL}"
    pct config $CT_ID | grep -E "^(hostname|memory|cores|net0|rootfs):"
    
    echo -e "\n${BL}Service Status:${CL}"
    if pct status $CT_ID | grep -q "running"; then
        pct exec $CT_ID -- threat-analysis status 2>/dev/null || echo "Services not responding"
    else
        echo "Container is not running"
    fi
}

container_logs() {
    msg_info "Fetching container and application logs"
    
    echo -e "${BL}=== Container System Logs (last 50 lines) ===${CL}"
    pct exec $CT_ID -- journalctl --no-pager -n 50
    
    echo -e "\n${BL}=== Application Logs ===${CL}"
    pct exec $CT_ID -- threat-analysis logs --tail=100 2>/dev/null || echo "Application logs not available"
}

enter_container() {
    msg_info "Entering container $CT_ID"
    echo -e "${GN}Tip: Use 'threat-analysis' command for application management${CL}"
    pct enter $CT_ID
}

backup_container() {
    local backup_name="threat-analysis-$(date +%Y%m%d_%H%M%S)"
    msg_info "Creating container backup: $backup_name"
    
    # Create Proxmox backup
    vzdump $CT_ID --compress gzip --mode stop --storage local
    
    # Create application data backup inside container
    pct exec $CT_ID -- threat-analysis backup
    
    msg_ok "Backup completed: $backup_name"
}

restore_container() {
    echo -e "${YW}Available backups:${CL}"
    ls -la /var/lib/vz/dump/ | grep -E "vzdump-lxc-.*\.tar\.(gz|zst|lzo)"
    echo ""
    read -p "Enter backup filename: " backup_file
    
    if [ ! -f "/var/lib/vz/dump/$backup_file" ]; then
        msg_error "Backup file not found"
        exit 1
    fi
    
    msg_warn "This will destroy the current container $CT_ID"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        msg_info "Stopping and destroying current container"
        pct stop $CT_ID 2>/dev/null || true
        pct destroy $CT_ID
        
        msg_info "Restoring from backup: $backup_file"
        pct restore $CT_ID /var/lib/vz/dump/$backup_file
        
        msg_ok "Container restored successfully"
    else
        msg_info "Restore cancelled"
    fi
}

update_container() {
    msg_info "Updating container OS and applications"
    
    pct exec $CT_ID -- apt update
    pct exec $CT_ID -- apt upgrade -y
    
    msg_info "Updating Threat Analysis application"
    pct exec $CT_ID -- threat-analysis update
    
    msg_ok "Update completed"
}

container_shell() {
    echo -e "${BL}Opening shell in container $CT_ID${CL}"
    echo -e "${GN}Available commands:${CL}"
    echo -e "  threat-analysis start|stop|restart|status|logs|backup|update"
    echo -e "  docker ps"
    echo -e "  docker-compose -f /opt/deployment/docker-compose.yml logs"
    echo ""
    pct enter $CT_ID
}

# Network and connectivity
test_connectivity() {
    echo -e "${BL}Testing Threat Analysis System Connectivity${CL}\n"
    
    # Test container connectivity
    msg_info "Testing container network"
    if pct exec $CT_ID -- ping -c 3 8.8.8.8 >/dev/null 2>&1; then
        msg_ok "Container network connectivity"
    else
        msg_error "Container network connectivity failed"
    fi
    
    # Test application health
    msg_info "Testing application health"
    if pct exec $CT_ID -- curl -f http://localhost/health >/dev/null 2>&1; then
        msg_ok "Application health check passed"
    else
        msg_error "Application health check failed"
    fi
    
    # Test external access
    msg_info "Testing external access"
    if curl -f -k https://threat.aip.dxc.com/health >/dev/null 2>&1; then
        msg_ok "External access working"
    else
        msg_warn "External access failed (check DNS/certificates)"
    fi
    
    # Test Tailscale
    msg_info "Testing Tailscale connectivity"
    if pct exec $CT_ID -- tailscale status >/dev/null 2>&1; then
        msg_ok "Tailscale is connected"
    else
        msg_warn "Tailscale not connected (run: pct exec $CT_ID -- tailscale up)"
    fi
}

# Certificate management
manage_certificates() {
    echo -e "${BL}SSL Certificate Management${CL}\n"
    
    echo -e "${BL}Current certificates:${CL}"
    pct exec $CT_ID -- docker-compose -f /opt/deployment/docker-compose.yml exec traefik cat /letsencrypt/acme.json 2>/dev/null | jq '.dxc-cert-resolver.Certificates[] | {domains: .domain.main, notAfter: .certificate}' 2>/dev/null || echo "No certificates found"
    
    echo -e "\n${YW}Certificate operations:${CL}"
    echo "1. Force certificate renewal"
    echo "2. View certificate logs"  
    echo "3. Reset certificates"
    echo "4. Back to main menu"
    
    read -p "Select option (1-4): " cert_option
    
    case $cert_option in
        1)
            msg_info "Forcing certificate renewal"
            pct exec $CT_ID -- docker-compose -f /opt/deployment/docker-compose.yml restart traefik
            msg_ok "Certificate renewal initiated"
            ;;
        2)
            msg_info "Viewing certificate logs"
            pct exec $CT_ID -- docker-compose -f /opt/deployment/docker-compose.yml logs traefik | grep -i cert
            ;;
        3)
            msg_warn "This will delete all certificates"
            read -p "Are you sure? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                pct exec $CT_ID -- rm -f /opt/traefik/data/acme.json
                pct exec $CT_ID -- docker-compose -f /opt/deployment/docker-compose.yml restart traefik
                msg_ok "Certificates reset"
            fi
            ;;
        4)
            return
            ;;
    esac
}

# System monitoring
system_monitor() {
    echo -e "${BL}Threat Analysis System Monitor${CL}\n"
    
    while true; do
        clear
        echo -e "${BL}=== System Status - $(date) ===${CL}"
        
        # Container status
        echo -e "\n${GN}Container Status:${CL}"
        pct status $CT_ID
        
        # Resource usage
        echo -e "\n${GN}Resource Usage:${CL}"
        pct exec $CT_ID -- df -h /opt | tail -1
        pct exec $CT_ID -- free -h | head -2
        
        # Service status
        echo -e "\n${GN}Service Status:${CL}"
        pct exec $CT_ID -- docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        # Application health
        echo -e "\n${GN}Application Health:${CL}"
        pct exec $CT_ID -- curl -s http://localhost/health 2>/dev/null | jq '.' || echo "Health check failed"
        
        # Recent logs
        echo -e "\n${GN}Recent Events:${CL}"
        pct exec $CT_ID -- docker-compose -f /opt/deployment/docker-compose.yml logs --tail=5 2>/dev/null | tail -10
        
        echo -e "\n${YW}Press Ctrl+C to exit, or wait 30 seconds for refresh...${CL}"
        sleep 30
    done
}

# Configuration management
manage_config() {
    echo -e "${BL}Configuration Management${CL}\n"
    
    echo "1. Edit valid areas (areas.json)"
    echo "2. View current configuration"
    echo "3. Restart application with new config"
    echo "4. Backup configuration"
    echo "5. Back to main menu"
    
    read -p "Select option (1-5): " config_option
    
    case $config_option in
        1)
            msg_info "Opening areas configuration for editing"
            pct exec $CT_ID -- nano /opt/threat-analysis/config/areas.json
            msg_info "Reloading configuration"
            pct exec $CT_ID -- threat-analysis restart
            msg_ok "Configuration updated"
            ;;
        2)
            echo -e "\n${GN}Current Configuration:${CL}"
            pct exec $CT_ID -- cat /opt/threat-analysis/config/areas.json
            echo ""
            ;;
        3)
            msg_info "Restarting application with new configuration"
            pct exec $CT_ID -- threat-analysis restart
            msg_ok "Application restarted"
            ;;
        4)
            msg_info "Creating configuration backup"
            pct exec $CT_ID -- cp /opt/threat-analysis/config/areas.json /opt/backups/areas-$(date +%Y%m%d_%H%M%S).json
            msg_ok "Configuration backed up"
            ;;
        5)
            return
            ;;
    esac
}

# Performance tuning
performance_tune() {
    echo -e "${BL}Performance Tuning${CL}\n"
    
    echo "1. Scale application containers"
    echo "2. Adjust container resources"
    echo "3. View performance metrics"
    echo "4. Optimize Docker"
    echo "5. Back to main menu"
    
    read -p "Select option (1-5): " perf_option
    
    case $perf_option in
        1)
            read -p "Number of application replicas (current: 1): " replicas
            msg_info "Scaling application to $replicas replicas"
            pct exec $CT_ID -- docker-compose -f /opt/deployment/docker-compose.yml up -d --scale threat-analysis=$replicas
            msg_ok "Application scaled"
            ;;
        2)
            echo -e "${GN}Current container resources:${CL}"
            pct config $CT_ID | grep -E "^(memory|cores):"
            echo ""
            read -p "New memory size (MB): " new_memory
            read -p "New CPU cores: " new_cores
            
            if [ ! -z "$new_memory" ]; then
                pct set $CT_ID -memory $new_memory
            fi
            if [ ! -z "$new_cores" ]; then
                pct set $CT_ID -cores $new_cores
            fi
            
            msg_info "Restarting container to apply changes"
            pct restart $CT_ID
            sleep 15
            pct exec $CT_ID -- threat-analysis start
            msg_ok "Resources updated"
            ;;
        3)
            echo -e "${GN}Performance Metrics:${CL}"
            pct exec $CT_ID -- docker stats --no-stream
            echo -e "\n${GN}System Load:${CL}"
            pct exec $CT_ID -- uptime
            echo -e "\n${GN}Disk I/O:${CL}"
            pct exec $CT_ID -- iostat 1 1
            ;;
        4)
            msg_info "Optimizing Docker"
            pct exec $CT_ID -- docker system prune -f
            pct exec $CT_ID -- docker volume prune -f
            msg_ok "Docker optimized"
            ;;
        5)
            return
            ;;
    esac
}

# Main menu
show_menu() {
    echo -e "\n${BL}📋 Threat Analysis Management Menu${CL}"
    echo -e "${DGN}Container: $CT_ID ($CT_NAME)${CL}"
    echo ""
    echo "━━━ Container Operations ━━━"
    echo " 1. Start container"
    echo " 2. Stop container"  
    echo " 3. Restart container"
    echo " 4. Container status"
    echo " 5. View logs"
    echo " 6. Enter container shell"
    echo ""
    echo "━━━ Application Management ━━━"
    echo " 7. Test connectivity"
    echo " 8. Manage certificates"
    echo " 9. System monitor"
    echo "10. Manage configuration"
    echo "11. Performance tuning"
    echo ""
    echo "━━━ Backup & Maintenance ━━━"
    echo "12. Create backup"
    echo "13. Restore from backup"
    echo "14. Update system"
    echo "15. Clean up resources"
    echo ""
    echo "━━━ Advanced ━━━"
    echo "16. Recreate container"
    echo "17. Export container"
    echo "18. Container statistics"
    echo ""
    echo " 0. Exit"
    echo ""
}

# Advanced operations
recreate_container() {
    msg_warn "This will recreate the container from scratch"
    echo -e "${YW}Current container will be backed up first${CL}"
    
    read -p "Continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        return
    fi
    
    # Backup first
    backup_container
    
    msg_info "Stopping current container"
    pct stop $CT_ID
    
    msg_info "Destroying container (backup was created)"
    pct destroy $CT_ID
    
    msg_info "Recreating container"
    bash "$SCRIPT_DIR/create_threat_analysis_ct.sh"
    
    msg_ok "Container recreated successfully"
}

export_container() {
    local export_name="threat-analysis-export-$(date +%Y%m%d_%H%M%S)"
    msg_info "Exporting container as template: $export_name"
    
    # Create template
    vzdump $CT_ID --compress gzip --mode suspend --storage local
    
    msg_ok "Container exported successfully"
    echo -e "${GN}Export location: /var/lib/vz/dump/${CL}"
    ls -la /var/lib/vz/dump/ | tail -1
}

container_stats() {
    echo -e "${BL}Container Statistics${CL}\n"
    
    # Basic info
    echo -e "${GN}Container Information:${CL}"
    pct config $CT_ID
    
    echo -e "\n${GN}Resource Usage:${CL}"
    pct exec $CT_ID -- cat /proc/meminfo | head -5
    pct exec $CT_ID -- cat /proc/loadavg
    
    echo -e "\n${GN}Network Statistics:${CL}"
    pct exec $CT_ID -- cat /proc/net/dev | grep eth0
    
    echo -e "\n${GN}Disk Usage:${CL}"
    pct exec $CT_ID -- df -h
    
    echo -e "\n${GN}Process Count:${CL}"
    pct exec $CT_ID -- ps aux | wc -l
}

clean_resources() {
    msg_info "Cleaning up system resources"
    
    # Clean Docker
    pct exec $CT_ID -- docker system prune -f
    pct exec $CT_ID -- docker volume prune -f
    
    # Clean package cache
    pct exec $CT_ID -- apt autoremove -y
    pct exec $CT_ID -- apt autoclean
    
    # Clean logs
    pct exec $CT_ID -- journalctl --vacuum-time=7d
    
    # Clean old backups (keep last 5)
    pct exec $CT_ID -- bash -c "cd /opt/backups && ls -t *.tar.gz | tail -n +6 | xargs rm -f"
    
    msg_ok "Resources cleaned up"
}

# Main execution
main() {
    header_info
    
    # Find the container
    find_container
    
    while true; do
        show_menu
        read -p "Select option (0-18): " choice
        
        case $choice in
            1) start_container ;;
            2) stop_container ;;
            3) restart_container ;;
            4) container_status ;;
            5) container_logs ;;
            6) container_shell ;;
            7) test_connectivity ;;
            8) manage_certificates ;;
            9) system_monitor ;;
            10) manage_config ;;
            11) performance_tune ;;
            12) backup_container ;;
            13) restore_container ;;
            14) update_container ;;
            15) clean_resources ;;
            16) recreate_container ;;
            17) export_container ;;
            18) container_stats ;;
            0) 
                echo -e "${GN}Goodbye!${CL}"
                exit 0
                ;;
            *)
                msg_error "Invalid option. Please try again."
                sleep 2
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Check if running on Proxmox
if ! command -v pct &> /dev/null; then
    msg_error "This script must be run on a Proxmox VE host"
    exit 1
fi

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    msg_error "This script must be run as root"
    exit 1
fi

# Handle command line arguments
case "${1:-}" in
    --create)
        bash "$SCRIPT_DIR/create_threat_analysis_ct.sh"
        ;;
    --find)
        find_container
        echo "Container ID: $CT_ID"
        echo "Container Name: $CT_NAME"
        ;;
    --help)
        echo "Threat Analysis Proxmox Management Script"
        echo ""
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  --create    Create new Threat Analysis container"
        echo "  --find      Find existing Threat Analysis container"
        echo "  --help      Show this help message"
        echo ""
        echo "Without options, starts interactive management interface"
        ;;
    *)
        main
        ;;
esac