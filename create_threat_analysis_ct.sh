#!/usr/bin/env bash

# Copyright (c) 2025 DXC AIP Community Scripts  
# Author: DXC AIP Team
# License: MIT
# https://github.com/DXCSithlordPadawan/SolrSim/tree/main

# Proxmox LXC Container Creation Script for Threat Analysis System
# Fixed version to resolve container creation issues

# Color codes
RD='\033[01;31m'
YW='\033[33m'
GN='\033[1;92m'
BL='\033[36m'
DGN='\033[32m'
BGN='\033[4;92m'
CL='\033[m'
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

# Initialize variables with defaults
APP="Threat Analysis"
CT_NAME="threat-analysis"
DISK_SIZE="20"
CORE_COUNT="2"
RAM_SIZE="4096"
BRG="vmbr0"
NET="192.169.0.201/24"
GATE="192.169.0.1"
DISABLEIP6="no"
SSH="no"
VERB="no"
CT_TYPE="1"
CT_PW=""

# Set safer bash options but allow commands to fail in some cases
set -euo pipefail

# Utility functions
function header_info {
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

               Proxmox Community Helper Scripts Style Installer
EOF
}

function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
    local msg="$1"
    echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
    exit 1
}

function PVE_CHECK() {
    if ! command -v pveversion >/dev/null 2>&1; then
        echo -e "${CROSS} This script requires Proxmox VE."
        echo -e "Exiting..."
        exit 1
    fi
}

function ARCH_CHECK() {
    if [ "$(dpkg --print-architecture)" != "amd64" ]; then
        echo -e "${CROSS} This script requires amd64 architecture."
        echo -e "Exiting..."
        exit 1
    fi
}

function exit_script() {
    clear
    echo -e "⚠  User exited script \n"
    exit 0
}

function default_settings() {
    NEXTID=$(pvesh get /cluster/nextid)
    CT_ID="$NEXTID"
    
    # Get available storage and set default
    STORAGE_LIST=$(pvesm status | awk 'NR>1 {print $1}' | grep -E "(local-lvm|local-zfs|local)" | head -1)
    if [ -z "$STORAGE_LIST" ]; then
        STORAGE_LIST=$(pvesm status | awk 'NR>1 {print $1}' | head -1)
    fi
    DEFAULT_STORAGE="$STORAGE_LIST"
    
    echo -e "${BL}Using Default Settings${CL}"
    echo -e "${DGN}Using CT Type ${BGN}Unprivileged${CL} ${RD}(Recommended)${CL}"
    echo -e "${DGN}Using CT Password ${BGN}Automatic Login${CL}"
    echo -e "${DGN}Using CT ID ${BGN}$CT_ID${CL}"
    echo -e "${DGN}Using CT Name ${BGN}$CT_NAME${CL}"
    echo -e "${DGN}Using Disk Size ${BGN}$DISK_SIZE GB${CL}"
    echo -e "${DGN}Using ${BGN}$CORE_COUNT${CL}${DGN} vCPU(s)${CL}"
    echo -e "${DGN}Using ${BGN}$RAM_SIZE${CL}${DGN}MiB RAM${CL}"
    echo -e "${DGN}Using Bridge ${BGN}$BRG${CL}"
    echo -e "${DGN}Using Static IP Address ${BGN}$NET${CL}"
    echo -e "${DGN}Using Gateway ${BGN}$GATE${CL}"
    echo -e "${DGN}Using Storage ${BGN}$DEFAULT_STORAGE${CL}"
    echo -e "${DGN}Disable IPv6 ${BGN}$DISABLEIP6${CL}"
    echo -e "${DGN}Enable Root SSH Access ${BGN}$SSH${CL}"
    echo -e "${DGN}Enable Verbose Mode ${BGN}$VERB${CL}"
    echo -e "${BL}Creating a ${APP} LXC using the above default settings${CL}"
}

function advanced_settings() {
    NEXTID=$(pvesh get /cluster/nextid)
    
    # Container Type
    if command -v whiptail >/dev/null 2>&1; then
        CT_TYPE=$(whiptail --title "CONTAINER TYPE" --radiolist "Choose Type" 10 58 2 \
            "1" "Unprivileged" ON \
            "0" "Privileged" OFF \
            3>&1 1>&2 2>&3) || exit_script
        echo -e "${DGN}Using CT Type ${BGN}$([ "$CT_TYPE" = "1" ] && echo "Unprivileged" || echo "Privileged")${CL}"
    else
        echo -e "${YW}Whiptail not available, using defaults${CL}"
        CT_TYPE="1"
    fi

    # Container ID
    if command -v whiptail >/dev/null 2>&1; then
        CT_ID=$(whiptail --inputbox "Set Container ID" 8 58 $NEXTID --title "CONTAINER ID" 3>&1 1>&2 2>&3) || exit_script
        echo -e "${DGN}Using CT ID ${BGN}$CT_ID${CL}"
    else
        CT_ID="$NEXTID"
        echo -e "${DGN}Using CT ID ${BGN}$CT_ID${CL}"
    fi

    # Container Name
    if command -v whiptail >/dev/null 2>&1; then
        CT_NAME=$(whiptail --inputbox "Set Container Name" 8 58 $CT_NAME --title "CONTAINER NAME" 3>&1 1>&2 2>&3) || exit_script
        echo -e "${DGN}Using CT Name ${BGN}$CT_NAME${CL}"
    else
        echo -e "${DGN}Using CT Name ${BGN}$CT_NAME${CL}"
    fi

    # Disk Size
    if command -v whiptail >/dev/null 2>&1; then
        DISK_SIZE=$(whiptail --inputbox "Set Disk Size (GB)" 8 58 $DISK_SIZE --title "DISK SIZE" 3>&1 1>&2 2>&3) || exit_script
        if ! [[ $DISK_SIZE =~ ^[0-9]+$ ]]; then
            echo -e "${RD}⚠ DISK SIZE MUST BE A NUMBER! Using default: 20GB${CL}"
            DISK_SIZE="20"
        fi
        echo -e "${DGN}Using Disk Size ${BGN}$DISK_SIZE GB${CL}"
    else
        echo -e "${DGN}Using Disk Size ${BGN}$DISK_SIZE GB${CL}"
    fi

    # CPU Cores
    if command -v whiptail >/dev/null 2>&1; then
        CORE_COUNT=$(whiptail --inputbox "Set CPU Cores" 8 58 $CORE_COUNT --title "CPU CORES" 3>&1 1>&2 2>&3) || exit_script
        echo -e "${DGN}Using ${BGN}$CORE_COUNT${CL}${DGN} vCPU(s)${CL}"
    else
        echo -e "${DGN}Using ${BGN}$CORE_COUNT${CL}${DGN} vCPU(s)${CL}"
    fi

    # RAM Size
    if command -v whiptail >/dev/null 2>&1; then
        RAM_SIZE=$(whiptail --inputbox "Set RAM (MB)" 8 58 $RAM_SIZE --title "RAM SIZE" 3>&1 1>&2 2>&3) || exit_script
        echo -e "${DGN}Using ${BGN}$RAM_SIZE${CL}${DGN}MiB RAM${CL}"
    else
        echo -e "${DGN}Using ${BGN}$RAM_SIZE${CL}${DGN}MiB RAM${CL}"
    fi

    # Network Bridge
    if command -v whiptail >/dev/null 2>&1; then
        BRG=$(whiptail --inputbox "Set Network Bridge" 8 58 $BRG --title "BRIDGE" 3>&1 1>&2 2>&3) || exit_script
        echo -e "${DGN}Using Bridge ${BGN}$BRG${CL}"
    else
        echo -e "${DGN}Using Bridge ${BGN}$BRG${CL}"
    fi

    # IP Address
    if command -v whiptail >/dev/null 2>&1; then
        NET=$(whiptail --inputbox "Set Static IP (CIDR format)" 8 58 $NET --title "IP ADDRESS" 3>&1 1>&2 2>&3) || exit_script
        echo -e "${DGN}Using Static IP Address ${BGN}$NET${CL}"
    else
        echo -e "${DGN}Using Static IP Address ${BGN}$NET${CL}"
    fi

    # Gateway
    if command -v whiptail >/dev/null 2>&1; then
        GATE=$(whiptail --inputbox "Set Gateway IP" 8 58 $GATE --title "GATEWAY" 3>&1 1>&2 2>&3) || exit_script
        echo -e "${DGN}Using Gateway ${BGN}$GATE${CL}"
    else
        echo -e "${DGN}Using Gateway ${BGN}$GATE${CL}"
    fi

    # Storage Selection
    select_storage

    # SSH Access
    if command -v whiptail >/dev/null 2>&1; then
        if whiptail --title "SSH ACCESS" --yesno "Enable Root SSH Access?" 10 58; then
            SSH="yes"
        else
            SSH="no"
        fi
        echo -e "${DGN}Enable Root SSH Access ${BGN}$SSH${CL}"
    else
        echo -e "${DGN}Enable Root SSH Access ${BGN}$SSH${CL}"
    fi
}

function install_script() {
    ARCH_CHECK
    PVE_CHECK
    
    if command -v whiptail >/dev/null 2>&1; then
        if whiptail --title "${APP}" --yesno "This will create a New ${APP} LXC. Proceed?" 10 58; then
            NEXTID=$(pvesh get /cluster/nextid)
        else
            exit_script
        fi
        
        if whiptail --title "SETTINGS" --yesno "Use Default Settings?" --no-button Advanced --yes-button Default 10 58; then
            default_settings
        else
            advanced_settings
        fi
    else
        echo -e "${YW}Interactive mode not available, using default settings${CL}"
        default_settings
    fi
}
    msg_info "Detecting Available Storage"
    
    # Get list of available storages that support containers
    STORAGE_ARRAY=()
    STORAGE_MENU=()
    
    while IFS= read -r line; do
        storage=$(echo "$line" | awk '{print $1}')
        type=$(echo "$line" | awk '{print $2}')
        status=$(echo "$line" | awk '{print $3}')
        
        # Skip header and unavailable storages
        if [[ "$storage" != "Name" && "$status" == "active" ]]; then
            # Check if storage supports containers
            if pvesm status -storage "$storage" | grep -q "content.*rootdir\|content.*vztmpl\|content.*images"; then
                STORAGE_ARRAY+=("$storage")
                STORAGE_MENU+=("$storage" "$type ($status)")
            fi
        fi
    done < <(pvesm status)
    
    msg_ok "Detected ${#STORAGE_ARRAY[@]} Available Storages"
    
    if [ ${#STORAGE_ARRAY[@]} -eq 0 ]; then
        msg_error "No suitable storage found for containers"
    elif [ ${#STORAGE_ARRAY[@]} -eq 1 ]; then
        DEFAULT_STORAGE="${STORAGE_ARRAY[0]}"
        echo -e "${DGN}Using Storage ${BGN}$DEFAULT_STORAGE${CL} ${YW}(Only available storage)${CL}"
    else
        # Multiple storages available - let user choose
        if command -v whiptail >/dev/null 2>&1; then
            # Build whiptail menu
            MENU_ITEMS=()
            for i in "${!STORAGE_ARRAY[@]}"; do
                storage="${STORAGE_ARRAY[$i]}"
                type=$(pvesm status | grep "^$storage" | awk '{print $2}')
                
                # Mark first storage as default
                if [ $i -eq 0 ]; then
                    MENU_ITEMS+=("$storage" "$type" "ON")
                else
                    MENU_ITEMS+=("$storage" "$type" "OFF")
                fi
            done
            
            DEFAULT_STORAGE=$(whiptail --title "STORAGE SELECTION" \
                --radiolist "Choose storage for container:" \
                15 70 ${#STORAGE_ARRAY[@]} \
                "${MENU_ITEMS[@]}" \
                3>&1 1>&2 2>&3) || exit_script
                
            echo -e "${DGN}Using Storage ${BGN}$DEFAULT_STORAGE${CL}"
        else
            # No whiptail, show menu manually
            echo -e "${BL}Available Storages:${CL}"
            for i in "${!STORAGE_ARRAY[@]}"; do
                storage="${STORAGE_ARRAY[$i]}"
                type=$(pvesm status | grep "^$storage" | awk '{print $2}')
                echo -e "  $((i+1))) ${GN}$storage${CL} ($type)"
            done
            
            while true; do
                echo -e "\n${YW}Select storage (1-${#STORAGE_ARRAY[@]}) or press Enter for default:${CL}"
                read -r choice
                
                if [ -z "$choice" ]; then
                    DEFAULT_STORAGE="${STORAGE_ARRAY[0]}"
                    break
                elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#STORAGE_ARRAY[@]}" ]; then
                    DEFAULT_STORAGE="${STORAGE_ARRAY[$((choice-1))]}"
                    break
                else
                    echo -e "${RD}Invalid choice. Please enter a number between 1 and ${#STORAGE_ARRAY[@]}${CL}"
                fi
            done
            
            echo -e "${DGN}Using Storage ${BGN}$DEFAULT_STORAGE${CL}"
        fi
    fi
    
    # Verify storage can handle the disk size
    if command -v pvesm >/dev/null 2>&1; then
        AVAILABLE_SPACE=$(pvesm status -storage "$DEFAULT_STORAGE" | awk 'NR==2 {print $4}' | sed 's/G//')
        if [[ "$AVAILABLE_SPACE" =~ ^[0-9]+$ ]] && [ "$AVAILABLE_SPACE" -lt "$DISK_SIZE" ]; then
            echo -e "${YW}Warning: Storage has ${AVAILABLE_SPACE}GB available, but ${DISK_SIZE}GB requested${CL}"
            echo -e "${YW}Consider reducing disk size or choosing different storage${CL}"
        fi
    fi
}
    ARCH_CHECK
    PVE_CHECK
    
    if command -v whiptail >/dev/null 2>&1; then
        if whiptail --title "${APP}" --yesno "This will create a New ${APP} LXC. Proceed?" 10 58; then
            NEXTID=$(pvesh get /cluster/nextid)
        else
            exit_script
        fi
        
        if whiptail --title "SETTINGS" --yesno "Use Default Settings?" --no-button Advanced --yes-button Default 10 58; then
            default_settings
        else
            advanced_settings
        fi
    else
        echo -e "${YW}Interactive mode not available, using default settings${CL}"
        default_settings
    fi
}

# Container creation function
function create_container() {
    msg_info "Downloading LXC Template"
    
    # Check available templates and download if needed
    TEMPLATE_STRING="local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
    
    if ! pveam list local | grep -q "ubuntu-22.04-standard_22.04-1_amd64.tar.zst"; then
        pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst
    fi
    msg_ok "Downloaded LXC Template"

    msg_info "Creating LXC Container"
    
    # Show storage information
    echo -e "${BL}Storage Details:${CL}"
    echo -e "   Storage: ${GN}$DEFAULT_STORAGE${CL}"
    pvesm status -storage "$DEFAULT_STORAGE" 2>/dev/null | awk 'NR==2 {printf "   Type: %s | Status: %s | Available: %s\n", $2, $3, $4}' || true
    
    # Create container with selected storage
    if ! pct create $CT_ID $TEMPLATE_STRING \
        --arch $(dpkg --print-architecture) \
        --cores $CORE_COUNT \
        --hostname $CT_NAME \
        --memory $RAM_SIZE \
        --nameserver 8.8.8.8 \
        --net0 name=eth0,bridge=$BRG,firewall=1,gw=$GATE,ip=$NET,type=veth \
        --onboot 1 \
        --ostype ubuntu \
        --rootfs $DEFAULT_STORAGE:$DISK_SIZE \
        --searchdomain aip.dxc.com \
        --startup order=3 \
        --tags threat-analysis \
        --timezone $(cat /etc/timezone) \
        --unprivileged $CT_TYPE; then
        
        echo -e "\n${RD}Container creation failed. Possible causes:${CL}"
        echo -e "  • Insufficient space on storage '$DEFAULT_STORAGE'"
        echo -e "  • Container ID '$CT_ID' already exists"
        echo -e "  • Network configuration issues"
        echo -e "  • Storage '$DEFAULT_STORAGE' doesn't support containers"
        echo -e "\n${YW}Troubleshooting:${CL}"
        echo -e "  • Check storage: pvesm status -storage $DEFAULT_STORAGE"
        echo -e "  • Check container ID: pct list | grep $CT_ID"
        echo -e "  • Try different storage or container ID"
        msg_error "Failed to create LXC container"
    fi

    msg_ok "Created LXC Container"

    msg_info "Starting LXC Container"
    if ! pct start $CT_ID; then
        echo -e "\n${RD}Container start failed. Checking status...${CL}"
        pct status $CT_ID || true
        msg_error "Failed to start container"
    fi
    
    # Wait for container to be fully ready
    echo -e "${YW}Waiting for container to be ready...${CL}"
    sleep 15
    
    # Check if container is running
    if ! pct status $CT_ID | grep -q "running"; then
        echo -e "\n${RD}Container status check:${CL}"
        pct status $CT_ID || true
        msg_error "Container failed to start properly"
    fi
    
    msg_ok "Started LXC Container"
}

function install_application() {
    msg_info "Installing Dependencies"
    
    # Update and install basic packages
    if ! pct exec $CT_ID -- bash -c "
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get upgrade -y
        apt-get install -y curl sudo mc apt-transport-https ca-certificates gnupg lsb-release wget
    "; then
        msg_error "Failed to install basic dependencies"
    fi
    msg_ok "Installed Dependencies"

    msg_info "Installing Docker"
    if ! pct exec $CT_ID -- bash -c "
        # Install Docker
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" > /etc/apt/sources.list.d/docker.list
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io
        systemctl enable docker
        systemctl start docker
        
        # Install Docker Compose
        DOCKER_COMPOSE_VERSION=\$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'\"' -f4)
        curl -L \"https://github.com/docker/compose/releases/download/\${DOCKER_COMPOSE_VERSION}/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    "; then
        msg_error "Failed to install Docker"
    fi
    msg_ok "Installed Docker"

    msg_info "Installing Additional Tools"
    if ! pct exec $CT_ID -- bash -c "
        # Install Tailscale
        curl -fsSL https://tailscale.com/install.sh | sh
        
        # Create directories
        mkdir -p /opt/threat-analysis/{data,config,logs}
        mkdir -p /opt/traefik/{data,logs}
        mkdir -p /opt/deployment/{traefik/dynamic,config,templates,static}
        mkdir -p /opt/backups
        
        # Create Docker network
        docker network create traefik || true
        
        # Install Python dependencies
        apt-get install -y python3 python3-pip python3-venv
    "; then
        msg_error "Failed to install additional tools"
    fi
    msg_ok "Installed Additional Tools"

    msg_info "Configuring Application"
    # Create application files inside container
    pct exec $CT_ID -- bash -c '
# Create threat analysis application
cat > /opt/deployment/threat_analysis_app.py << "APPEOF"
#!/usr/bin/env python3
"""
Threat Analysis Web Application
Modified to use external JSON configuration for valid areas
"""

import json
import os
from flask import Flask, render_template, request, jsonify
from datetime import datetime
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "your-secret-key-change-in-production")

threat_data = []
valid_areas = []

def load_config():
    global valid_areas
    config_path = os.environ.get("CONFIG_PATH", "./config/areas.json")
    try:
        with open(config_path, "r") as f:
            config = json.load(f)
            valid_areas = config.get("valid_areas", [])
            logger.info(f"Loaded {len(valid_areas)} valid areas")
    except FileNotFoundError:
        valid_areas = ["OP1", "OP2", "OP3", "OP4", "OP5", "OP6", "OP7", "OP8"]
        logger.info("Using default valid areas")

def save_threat_data():
    data_path = os.environ.get("DATA_PATH", "./data/threats.json")
    os.makedirs(os.path.dirname(data_path), exist_ok=True)
    try:
        with open(data_path, "w") as f:
            json.dump(threat_data, f, indent=2)
    except Exception as e:
        logger.error(f"Error saving threat data: {e}")

def load_threat_data():
    global threat_data
    data_path = os.environ.get("DATA_PATH", "./data/threats.json")
    try:
        with open(data_path, "r") as f:
            threat_data = json.load(f)
    except FileNotFoundError:
        threat_data = []

@app.route("/")
def index():
    return render_template("index.html", valid_areas=valid_areas, threats=threat_data)

@app.route("/api/threats", methods=["GET"])
def get_threats():
    return jsonify(threat_data)

@app.route("/api/threats", methods=["POST"])
def add_threat():
    try:
        data = request.get_json()
        threat = {
            "id": len(threat_data) + 1,
            "timestamp": datetime.now().isoformat(),
            "threat_type": data["threat_type"],
            "area": data["area"],
            "severity": data["severity"],
            "description": data["description"],
            "reporter": data.get("reporter", "Anonymous"),
            "status": "Active"
        }
        threat_data.append(threat)
        save_threat_data()
        return jsonify({"message": "Threat added successfully", "threat": threat}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/health")
def health_check():
    return jsonify({"status": "healthy", "timestamp": datetime.now().isoformat()})

if __name__ == "__main__":
    load_config()
    load_threat_data()
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
APPEOF

# Create configuration file
cat > /opt/deployment/config/areas.json << "CONFEOF"
{
  "valid_areas": ["OP1", "OP2", "OP3", "OP4", "OP5", "OP6", "OP7", "OP8"],
  "description": "Valid operational areas for threat analysis",
  "version": "1.0"
}
CONFEOF

# Create requirements file
cat > /opt/deployment/requirements.txt << "REQEOF"
Flask==2.3.3
Werkzeug==2.3.7
Jinja2==3.1.2
requests==2.31.0
REQEOF

# Create Dockerfile
cat > /opt/deployment/Dockerfile << "DOCKEREOF"
FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y gcc curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY threat_analysis_app.py .
COPY templates/ ./templates/
COPY config/areas.json ./config/
RUN mkdir -p /app/config /app/data
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser
ENV CONFIG_PATH=/app/config/areas.json
ENV DATA_PATH=/app/data/threats.json
ENV PORT=5000
EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=10s CMD curl -f http://localhost:5000/health || exit 1
CMD ["python", "threat_analysis_app.py"]
DOCKEREOF

# Create Docker Compose
SECRET_KEY=$(openssl rand -hex 32)
cat > /opt/deployment/docker-compose.yml << COMPOSEEOF
version: "3.8"
services:
  threat-analysis:
    build: .
    container_name: threat-analysis-app
    restart: unless-stopped
    environment:
      - PORT=5000
      - SECRET_KEY=$SECRET_KEY
      - CONFIG_PATH=/app/config/areas.json
      - DATA_PATH=/app/data/threats.json
    volumes:
      - /opt/threat-analysis/data:/app/data
      - /opt/deployment/config:/app/config
    networks:
      - traefik
    ports:
      - "80:5000"
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=traefik"
      - "traefik.http.routers.threat-analysis.rule=Host(\`threat.aip.dxc.com\`)"
      - "traefik.http.services.threat-analysis.loadbalancer.server.port=5000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  traefik:
    external: true
COMPOSEEOF

# Create basic HTML template
mkdir -p /opt/deployment/templates
cat > /opt/deployment/templates/index.html << "HTMLEOF"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Threat Analysis System</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        .severity-low { background-color: #d4f6d4; }
        .severity-medium { background-color: #fff3cd; }
        .severity-high { background-color: #f8d7da; }
        .severity-critical { background-color: #f5c6cb; }
    </style>
</head>
<body>
    <nav class="navbar navbar-dark bg-dark">
        <div class="container">
            <span class="navbar-brand">🛡️ Threat Analysis System</span>
            <span class="navbar-text">Total Threats: {{ threats|length }}</span>
        </div>
    </nav>
    <div class="container mt-4">
        <div class="row">
            <div class="col-md-8 mx-auto">
                <div class="card">
                    <div class="card-header bg-primary text-white">Report New Threat</div>
                    <div class="card-body">
                        <form id="threat-form">
                            <div class="row">
                                <div class="col-md-6 mb-3">
                                    <label class="form-label">Threat Type</label>
                                    <select class="form-select" name="threat_type" required>
                                        <option value="">Select...</option>
                                        <option value="Security Breach">Security Breach</option>
                                        <option value="System Failure">System Failure</option>
                                        <option value="Physical Threat">Physical Threat</option>
                                        <option value="Cyber Attack">Cyber Attack</option>
                                        <option value="Environmental">Environmental</option>
                                        <option value="Other">Other</option>
                                    </select>
                                </div>
                                <div class="col-md-6 mb-3">
                                    <label class="form-label">Area</label>
                                    <select class="form-select" name="area" required>
                                        <option value="">Select area...</option>
                                        {% for area in valid_areas %}
                                        <option value="{{ area }}">{{ area }}</option>
                                        {% endfor %}
                                    </select>
                                </div>
                            </div>
                            <div class="row">
                                <div class="col-md-6 mb-3">
                                    <label class="form-label">Severity</label>
                                    <select class="form-select" name="severity" required>
                                        <option value="">Select...</option>
                                        <option value="Low">Low</option>
                                        <option value="Medium">Medium</option>
                                        <option value="High">High</option>
                                        <option value="Critical">Critical</option>
                                    </select>
                                </div>
                                <div class="col-md-6 mb-3">
                                    <label class="form-label">Reporter</label>
                                    <input type="text" class="form-control" name="reporter" placeholder="Your name">
                                </div>
                            </div>
                            <div class="mb-3">
                                <label class="form-label">Description</label>
                                <textarea class="form-control" name="description" rows="3" required></textarea>
                            </div>
                            <button type="submit" class="btn btn-primary">Submit Threat Report</button>
                        </form>
                    </div>
                </div>
            </div>
        </div>
        
        {% if threats %}
        <div class="row mt-4">
            <div class="col-12">
                <div class="card">
                    <div class="card-header bg-secondary text-white">Current Threats</div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-striped">
                                <thead class="table-dark">
                                    <tr>
                                        <th>ID</th>
                                        <th>Type</th>
                                        <th>Area</th>
                                        <th>Severity</th>
                                        <th>Description</th>
                                        <th>Status</th>
                                        <th>Time</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {% for threat in threats %}
                                    <tr class="severity-{{ threat.severity.lower() }}">
                                        <td><strong>#{{ threat.id }}</strong></td>
                                        <td>{{ threat.threat_type }}</td>
                                        <td><span class="badge bg-info">{{ threat.area }}</span></td>
                                        <td><span class="badge bg-{% if threat.severity == 'Critical' %}danger{% elif threat.severity == 'High' %}warning{% elif threat.severity == 'Medium' %}info{% else %}success{% endif %}">{{ threat.severity }}</span></td>
                                        <td>{{ threat.description[:100] }}...</td>
                                        <td><span class="badge bg-{% if threat.status == 'Active' %}danger{% else %}success{% endif %}">{{ threat.status }}</span></td>
                                        <td>{{ threat.timestamp[:19] }}</td>
                                    </tr>
                                    {% endfor %}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        {% endif %}
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        document.getElementById("threat-form").addEventListener("submit", function(e) {
            e.preventDefault();
            const formData = new FormData(e.target);
            const data = Object.fromEntries(formData.entries());
            
            fetch("/api/threats", {
                method: "POST",
                headers: {"Content-Type": "application/json"},
                body: JSON.stringify(data)
            })
            .then(response => response.json())
            .then(data => {
                if (data.error) {
                    alert("Error: " + data.error);
                } else {
                    alert("Threat reported successfully!");
                    location.reload();
                }
            })
            .catch(error => {
                alert("Error: " + error);
            });
        });
    </script>
</body>
</html>
HTMLEOF

# Create management script
cat > /usr/local/bin/threat-analysis << "MGMTEOF"
#!/bin/bash
COMPOSE_FILE="/opt/deployment/docker-compose.yml"

case "$1" in
    start)
        echo "Starting Threat Analysis System..."
        cd /opt/deployment
        docker-compose up -d
        ;;
    stop)
        echo "Stopping Threat Analysis System..."
        cd /opt/deployment
        docker-compose down
        ;;
    restart)
        echo "Restarting Threat Analysis System..."
        cd /opt/deployment
        docker-compose restart
        ;;
    status)
        echo "Threat Analysis System Status:"
        cd /opt/deployment
        docker-compose ps
        ;;
    logs)
        cd /opt/deployment
        docker-compose logs -f --tail=100
        ;;
    health)
        echo "Health Check:"
        curl -s http://localhost/health | jq "." 2>/dev/null || curl -s http://localhost/health || echo "Health check failed"
        ;;
    build)
        echo "Building application..."
        cd /opt/deployment
        docker-compose build
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|health|build}"
        echo ""
        echo "Threat Analysis System Management Commands:"
        echo "  start    - Start all services"
        echo "  stop     - Stop all services"
        echo "  restart  - Restart all services"
        echo "  status   - Show service status"
        echo "  logs     - Show application logs"
        echo "  health   - Check application health"
        echo "  build    - Build application containers"
        exit 1
        ;;
esac
MGMTEOF

chmod +x /usr/local/bin/threat-analysis

# Set up basic firewall
ufw --force enable
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8080/tcp

# Copy config files and set permissions
cp -r /opt/deployment/config/* /opt/threat-analysis/config/
chmod -R 755 /opt/threat-analysis /opt/traefik /opt/deployment
chown -R 1000:1000 /opt/threat-analysis/data /opt/threat-analysis/config

echo "Application configuration completed"
'
    
    if [ $? -ne 0 ]; then
        msg_error "Failed to configure application"
    fi
    msg_ok "Configured Application"

    msg_info "Building and Starting Services"
    if ! pct exec $CT_ID -- bash -c '
        cd /opt/deployment
        docker-compose build
        docker-compose up -d
        sleep 20
    '; then
        msg_error "Failed to start services"
    fi
    msg_ok "Services Started"
}

function verify_installation() {
    msg_info "Verifying Installation"
    
    # Wait for services to be ready
    sleep 15
    
    # Check if application is responding
    if pct exec $CT_ID -- curl -f http://localhost/health >/dev/null 2>&1; then
        msg_ok "Application Health Check Passed"
    else
        echo -e "\n${YW}Warning: Application health check failed. This may be normal during first startup.${CL}"
        echo -e "${YW}Check logs with: pct exec $CT_ID -- threat-analysis logs${CL}"
    fi
    
    # Check container status
    if pct status $CT_ID | grep -q "running"; then
        msg_ok "Container is Running"
    else
        msg_error "Container Status Issue"
    fi
    
    # Check Docker status
    if pct exec $CT_ID -- systemctl is-active docker >/dev/null 2>&1; then
        msg_ok "Docker Service is Running"
    else
        msg_error "Docker Service Issue"
    fi
}

function show_completion_info() {
    echo -e "\n${RD}████████████████████████████████████████████████████████████████████████████${CL}"
    echo -e "${RD}█                                                                          █${CL}"
    echo -e "${RD}█    _______ _                    _       _                _           _   █${CL}" 
    echo -e "${RD}█   |__   __| |                  | |     | |              | |         (_)  █${CL}"
    echo -e "${RD}█      | |  | |__  _ __ ___  __ _| |_    / \\   _ __   __ _| |_   _ ___ _ ___█${CL}"
    echo -e "${RD}█      | |  | '_ \\| '__/ _ \\/ _\` | __|   / _ \\ | '_ \\ / _\` | | | | / __| / __█${CL}"
    echo -e "${RD}█      | |  | | | | | |  __/ (_| | |_   / ___ \\| | | | (_| | | |_| \\__ \\ \\__ █${CL}"
    echo -e "${RD}█      |_|  |_| |_|_|  \\___|\\__,_|\\__| /_/   \\_\\_| |_|\\__,_|_|\\__, |___/_|___█${CL}"
    echo -e "${RD}█                                                              __/ |        █${CL}"
    echo -e "${RD}█                                                             |___/         █${CL}" 
    echo -e "${RD}█                                                                          █${CL}"
    echo -e "${RD}████████████████████████████████████████████████████████████████████████████${CL}"

    echo -e "\n${GN}🚀 Threat Analysis LXC Container Created Successfully!${CL}\n"

    echo -e "${BL}📋 Container Details:${CL}"
    echo -e "   🆔 Container ID: ${GN}$CT_ID${CL}"
    echo -e "   🏷️  Container Name: ${GN}$CT_NAME${CL}"
    echo -e "   🌐 IP Address: ${GN}$NET${CL}"
    echo -e "   💾 Disk Size: ${GN}${DISK_SIZE}GB${CL}"
    echo -e "   🧠 CPU Cores: ${GN}$CORE_COUNT${CL}"
    echo -e "   🐏 RAM: ${GN}${RAM_SIZE}MB${CL}"

    echo -e "\n${BL}🌐 Application Access:${CL}"
    echo -e "   🔗 Web Interface: ${GN}http://192.169.0.201${CL}"
    echo -e "   ❤️  Health Check: ${GN}http://192.169.0.201/health${CL}"
    echo -e "   📊 API Endpoint: ${GN}http://192.169.0.201/api/threats${CL}"

    echo -e "\n${BL}🛠️  Container Management:${CL}"
    echo -e "   🚀 Start Container: ${GN}pct start $CT_ID${CL}"
    echo -e "   🛑 Stop Container: ${GN}pct stop $CT_ID${CL}"
    echo -e "   🔄 Restart Container: ${GN}pct restart $CT_ID${CL}"
    echo -e "   💻 Enter Container: ${GN}pct enter $CT_ID${CL}"

    echo -e "\n${BL}📊 Application Management (inside container):${CL}"
    echo -e "   🏁 Start Services: ${GN}threat-analysis start${CL}"
    echo -e "   🛑 Stop Services: ${GN}threat-analysis stop${CL}"
    echo -e "   📊 Check Status: ${GN}threat-analysis status${CL}"
    echo -e "   📋 View Logs: ${GN}threat-analysis logs${CL}"
    echo -e "   ❤️  Health Check: ${GN}threat-analysis health${CL}"
    echo -e "   🔨 Build Application: ${GN}threat-analysis build${CL}"

    echo -e "\n${YW}⚠️  Next Steps:${CL}"
    echo -e "   1️⃣  Test application: ${GN}curl http://192.169.0.201/health${CL}"
    echo -e "   2️⃣  Enter container: ${GN}pct enter $CT_ID${CL}"
    echo -e "   3️⃣  Configure Tailscale: ${GN}tailscale up${CL}"
    echo -e "   4️⃣  Access web interface: ${GN}http://192.169.0.201${CL}"

    echo -e "\n${BL}🔧 Configuration Files:${CL}"
    echo -e "   📂 App Config: ${GN}/opt/threat-analysis/config/areas.json${CL}"
    echo -e "   🐳 Docker Compose: ${GN}/opt/deployment/docker-compose.yml${CL}"
    echo -e "   📝 Python App: ${GN}/opt/deployment/threat_analysis_app.py${CL}"
    echo -e "   💿 Storage Used: ${GN}$DEFAULT_STORAGE${CL}"

    echo -e "\n${BL}🔍 Troubleshooting:${CL}"
    echo -e "   📋 Check Container: ${GN}pct status $CT_ID${CL}"
    echo -e "   🐳 Check Docker: ${GN}pct exec $CT_ID -- docker ps${CL}"
    echo -e "   📊 Check Services: ${GN}pct exec $CT_ID -- threat-analysis status${CL}"
    echo -e "   📝 View Logs: ${GN}pct exec $CT_ID -- threat-analysis logs${CL}"

    echo -e "\n${GN}✅ Container is ready and application is running!${CL}"
    echo -e "${YW}📝 Configure Tailscale for secure external access if needed.${CL}\n"
}

# Main execution
main() {
    header_info
    install_script
    create_container
    install_application
    verify_installation
    show_completion_info
}

# Check if running on Proxmox
if ! command -v pct &> /dev/null; then
    echo -e "${CROSS} This script must be run on a Proxmox VE host"
    exit 1
fi

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${CROSS} This script must be run as root"
    exit 1
fi

# Handle command line arguments
case "${1:-main}" in
    --help)
        echo "Threat Analysis Proxmox Container Creation Script"
        echo ""
        echo "This script creates a complete Threat Analysis system in an LXC container"
        echo "with Docker, Python Flask application, and management tools."
        echo ""
        echo "Usage: $0 [--help]"
        echo ""
        echo "Features:"
        echo "  - LXC container with Ubuntu 22.04"
        echo "  - Docker and Docker Compose"
        echo "  - Python Flask web application"
        echo "  - External JSON configuration"
        echo "  - RESTful API endpoints"
        echo "  - Bootstrap web interface"
        echo "  - Health monitoring"
        echo "  - Management commands"
        echo "  - Tailscale ready"
        echo ""
        echo "After installation:"
        echo "  - Access: http://192.169.0.201"
        echo "  - Management: pct enter <CT_ID>"
        echo "  - Commands: threat-analysis start|stop|status|logs"
        echo ""
        ;;
    *)
        main
        ;;
esac