#!/usr/bin/env bash

# Copyright (c) 2025 DXC AIP Community Scripts  
# Author: DXC AIP Team
# License: MIT
# https://github.com/DXCSithlordPadawan/SolrSim/tree/main

# Proxmox LXC Container Creation Script for Threat Analysis System
# This script creates and configures a Proxmox LXC container specifically for the Threat Analysis application

# Color codes
RD='\033[01;31m'
YW='\033[33m'
GN='\033[1;92m'
CL='\033[m'
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

# Set error handling
set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    if [[ ${1-} =~ ^[0-9]+$ ]]; then
        exit $1
    fi
}

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
}

function PVE_CHECK() {
    if [ $(pveversion | grep -c "pve-manager/7\|pve-manager/8") -ne 1 ]; then
        echo -e "${CROSS} This script requires Proxmox VE 7.0 or later."
        echo -e "Exiting..."
        exit 1
    fi
}

function ARCH_CHECK() {
    if [ "$(dpkg --print-architecture)" != "amd64" ]; then
        echo -e "${CROSS} This script will not work with PiMOS! \n"
        echo -e "Exiting..."
        exit 1
    fi
}

function default_settings() {
    CT_TYPE="1"
    PW=""
    CT_ID="$NEXTID"
    CT_NAME="threat-analysis"
    DISK_SIZE="20"
    CORE_COUNT="2"
    RAM_SIZE="4096"
    BRG="vmbr0"
    NET="dhcp"
    GATE=""
    APT_CACHER=""
    APT_CACHER_IP=""
    DISABLEIP6="no"
    MTU=""
    SD=""
    NS=""
    MAC=""
    VLAN=""
    SSH="no"
    VERB="no"
    echo_default
}

function echo_default() {
    echo -e "${BL}Using Default Settings${CL}"
    echo -e "${DGN}Using CT Type ${BGN}Unprivileged${CL} ${RD}NO DEVICE PASSTHROUGH${CL}"
    echo -e "${DGN}Using CT Password ${BGN}Automatic Login${CL}"
    echo -e "${DGN}Using CT ID ${BGN}$NEXTID${CL}"
    echo -e "${DGN}Using CT Name ${BGN}$CT_NAME${CL}"
    echo -e "${DGN}Using Disk Size ${BGN}$DISK_SIZE GB${CL}"
    echo -e "${DGN}Using ${BGN}$CORE_COUNT${CL}${DGN} vCPU(s)${CL}"
    echo -e "${DGN}Using ${BGN}$RAM_SIZE${CL}${DGN}MiB RAM${CL}"
    echo -e "${DGN}Using Bridge ${BGN}$BRG${CL}"
    echo -e "${DGN}Using Static IP Address ${BGN}192.169.0.201/24${CL}"
    echo -e "${DGN}Using Gateway ${BGN}192.169.0.1${CL}"
    echo -e "${DGN}Disable IPv6 ${BGN}$DISABLEIP6${CL}"
    echo -e "${DGN}Using Interface MTU Size ${BGN}Default${CL}"
    echo -e "${DGN}Using DNS Search Domain ${BGN}Host${CL}"
    echo -e "${DGN}Using DNS Server Address ${BGN}Host${CL}"
    echo -e "${DGN}Using MAC Address ${BGN}Default${CL}"
    echo -e "${DGN}Using VLAN Tag ${BGN}Default${CL}"
    echo -e "${DGN}Enable Root SSH Access ${BGN}$SSH${CL}"
    echo -e "${DGN}Enable Verbose Mode ${BGN}$VERB${CL}"
    echo -e "${BL}Creating a ${APP} LXC using the above default settings${CL}"
}

function exit-script() {
    clear
    echo -e "⚠  User exited script \n"
    exit
}

function advanced_settings() {
    CT_TYPE=$(whiptail --title "CONTAINER TYPE" --radiolist "Choose Type" 10 58 2 \
        "1" "Unprivileged" ON \
        "0" "Privileged" OFF \
        3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        echo -e "${DGN}Using CT Type ${BGN}$CT_TYPE${CL}"
    else
        exit-script
    fi

    CT_PW1=$(whiptail --inputbox "Set Root Password (needed for root ssh access)" 8 58 --title "PASSWORD(leave blank for automatic login)" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ -z "$CT_PW1" ]; then
            CT_PW1="Automatic Login" 
            CT_PW=" "
        else
            CT_PW="-password $CT_PW1"
        fi
        echo -e "${DGN}Using CT Password ${BGN}$CT_PW1${CL}"
    else
        exit-script
    fi

    CT_ID=$(whiptail --inputbox "Set Container ID" 8 58 $NEXTID --title "CONTAINER ID" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        echo -e "${DGN}Using CT ID ${BGN}$CT_ID${CL}"
    else
        exit-script
    fi

    CT_NAME=$(whiptail --inputbox "Set Hostname" 8 58 $CT_NAME --title "HOSTNAME" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        echo -e "${DGN}Using CT Name ${BGN}$CT_NAME${CL}"
    else
        exit-script
    fi

    DISK_SIZE=$(whiptail --inputbox "Set Disk Size in GB" 8 58 $DISK_SIZE --title "DISK SIZE" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if ! [[ $DISK_SIZE =~ ^[0-9]+$ ]]; then
            echo -e "${RD}⚠ DISK SIZE MUST BE A INTEGER NUMBER!${CL}"
            advanced_settings
        fi
        echo -e "${DGN}Using Disk Size ${BGN}$DISK_SIZE GB${CL}"
    else
        exit-script
    fi

    CORE_COUNT=$(whiptail --inputbox "Allocate CPU Cores" 8 58 $CORE_COUNT --title "CORE COUNT" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        echo -e "${DGN}Using ${BGN}$CORE_COUNT${CL}${DGN} vCPU(s)${CL}"
    else
        exit-script
    fi

    RAM_SIZE=$(whiptail --inputbox "Allocate RAM in MiB" 8 58 $RAM_SIZE --title "RAM" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        echo -e "${DGN}Using ${BGN}$RAM_SIZE${CL}${DGN}MiB RAM${CL}"
    else
        exit-script
    fi

    BRG=$(whiptail --inputbox "Set a Bridge" 8 58 vmbr0 --title "BRIDGE" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        echo -e "${DGN}Using Bridge ${BGN}$BRG${CL}"
    else
        exit-script
    fi

    NET=$(whiptail --inputbox "Set a Static IPv4 CIDR Address(/24)" 8 58 192.169.0.201/24 --title "IP ADDRESS" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        echo -e "${DGN}Using Static IP Address ${BGN}$NET${CL}"
    else
        exit-script
    fi

    GATE1=$(whiptail --inputbox "Set a Gateway IP (mandatory if Static IP was used)" 8 58 192.169.0.1 --title "GATEWAY IP" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ -z $GATE1 ]; then
            GATE1="Default" GATE=""
        else
            GATE=",gw=$GATE1"
        fi
        echo -e "${DGN}Using Gateway IP Address ${BGN}$GATE1${CL}"
    else
        exit-script
    fi

    if (whiptail --defaultno --title "IPv6" --yesno "Disable IPv6?" 10 58); then
        DISABLEIP6="yes"
    else
        DISABLEIP6="no"
    fi
    echo -e "${DGN}Disable IPv6 ${BGN}$DISABLEIP6${CL}"

    MTU1=$(whiptail --inputbox "Set Interface MTU Size (leave blank for default)" 8 58 --title "MTU SIZE" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ -z $MTU1 ]; then
            MTU1="Default" MTU=""
        else
            MTU=",mtu=$MTU1"
        fi
        echo -e "${DGN}Using Interface MTU Size ${BGN}$MTU1${CL}"
    else
        exit-script
    fi

    SD=$(whiptail --inputbox "Set a DNS Search Domain (leave blank for HOST)" 8 58 --title "DNS Search Domain" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ -z $SD ]; then
            SX=Host
        else
            SX=$SD
        fi
        echo -e "${DGN}Using DNS Search Domain ${BGN}$SX${CL}"
    else
        exit-script
    fi

    NS=$(whiptail --inputbox "Set a DNS Server IP (leave blank for HOST)" 8 58 --title "DNS SERVER IP" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ -z $NS ]; then
            NX=Host
        else
            NX=$NS
        fi
        echo -e "${DGN}Using DNS Server IP Address ${BGN}$NX${CL}"
    else
        exit-script
    fi

    MAC1=$(whiptail --inputbox "Set a MAC Address(leave blank for default)" 8 58 --title "MAC ADDRESS" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ -z $MAC1 ]; then
            MAC1="Default" MAC=""
        else
            MAC=",hwaddr=$MAC1"
            echo -e "${DGN}Using MAC Address ${BGN}$MAC1${CL}"
        fi
    else
        exit-script
    fi

    VLAN1=$(whiptail --inputbox "Set a Vlan(leave blank for default)" 8 58 --title "VLAN" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ -z $VLAN1 ]; then
            VLAN1="Default" VLAN=""
        else
            VLAN=",tag=$VLAN1"
        fi
        echo -e "${DGN}Using Vlan Tag ${BGN}$VLAN1${CL}"
    else
        exit-script
    fi

    if (whiptail --defaultno --title "SSH ACCESS" --yesno "Enable Root SSH Access?" 10 58); then
        SSH="yes"
    else
        SSH="no"
    fi
    echo -e "${DGN}Enable Root SSH Access ${BGN}$SSH${CL}"

    if (whiptail --defaultno --title "VERBOSE MODE" --yesno "Enable Verbose Mode?" 10 58); then
        VERB="yes"
    else
        VERB="no"
    fi
    echo -e "${DGN}Enable Verbose Mode ${BGN}$VERB${CL}"

    if (whiptail --title "CONTINUE" --yesno "Ready to create ${APP} LXC?" --no-button Continue --yes-button Exit 10 58); then
        exit-script
    fi
}

function install_script() {
    ARCH_CHECK
    PVE_CHECK
    if (whiptail --title "${APP}" --yesno "This will create a New ${APP} LXC. Proceed?" 10 58); then
        NEXTID=$(pvesh get /cluster/nextid)
    else
        clear
        echo -e "⚠  User exited script \n"
        exit
    fi
    if (whiptail --title "SETTINGS" --yesno "Use Default Settings?" --no-button Advanced --yes-button Default 10 58); then
        default_settings
    else
        advanced_settings
    fi
}

function update_script() {
    header_info
    msg_info "Updating ${APP} LXC"
    apt-get update &>/dev/null
    apt-get -y upgrade &>/dev/null
    msg_ok "Updated ${APP} LXC"
    exit
}

# Variables
APP="Threat Analysis"
var_disk="20"
var_cpu="2"
var_ram="4096"
var_os="ubuntu"
var_version="22.04"
NSAPP=$(echo ${APP,,} | tr -d ' ')
var_install="${NSAPP}-install"
timezone=$(cat /etc/timezone)
INTEGER='^[0-9]+([.][0-9]+)?$'

# Color variables
CL=`echo "\033[m"`
RD=`echo "\033[01;31m"`
BL=`echo "\033[36m"`
GN=`echo "\033[1;92m"`
YW=`echo "\033[33m"`
DGN=`echo "\033[32m"`
BGN=`echo "\033[4;92m"`

# Main script execution
header_info

# Check if this is an update
if [[ "$1" == "update" ]]; then
    update_script
fi

# Install script
install_script

# Start the LXC creation process
start_routines() {
    local VMID="$CT_ID"
    local VMNAME="$CT_NAME"
    local DISK_SIZE="$DISK_SIZE"
    local CORE_COUNT="$CORE_COUNT"
    local RAM_SIZE="$RAM_SIZE"
    local BRG="$BRG"
    local NET="$NET"
    local GATE="$GATE"
    local APT_CACHER="$APT_CACHER"
    local APT_CACHER_IP="$APT_CACHER_IP"
    local DISABLEIP6="$DISABLEIP6"
    local MTU="$MTU"
    local SD="$SD"
    local NS="$NS"
    local MAC="$MAC"
    local VLAN="$VLAN"
    local SSH="$SSH"
    local VERB="$VERB"
    
    msg_info "Downloading LXC Template"
    local OSTYPE=linux
    local OSVERSION=${var_version}
    local TEMPLATE_STRING="local:vztmpl/ubuntu-${OSVERSION}-standard_${OSVERSION}-1_amd64.tar.zst"
    
    if ! pveam list local | grep -q ubuntu-${OSVERSION}-standard_${OSVERSION}-1_amd64.tar.zst; then
        pveam download local ubuntu-${OSVERSION}-standard_${OSVERSION}-1_amd64.tar.zst >/dev/null 2>&1
    fi
    msg_ok "Downloaded LXC Template"

    msg_info "Creating LXC Container"
    STORAGE_TYPE=$(pvesm status -storage $(pvesm status | awk 'NR>1 {print $1}' | head -1) | awk 'NR>1 {print $2}')
    case $STORAGE_TYPE in
        nfs|cifs)
            DISK_EXT=".raw"
            DISK_REF="$VMID/"
            ;;
        dir)
            DISK_EXT=".raw"
            DISK_REF="$VMID/"
            ;;
        zfspool)
            DISK_EXT=""
            DISK_REF="subvol-$VMID-disk-0"
            ;;
        btrfs)
            DISK_EXT=".raw"
            DISK_REF="$VMID/"
            ;;
        *)
            DISK_EXT=""
            DISK_REF="vm-$VMID-disk-0"
            ;;
    esac
    
    DISK_IMPORT="-rootfs $(pvesm status | awk 'NR>1 {print $1}' | head -1):${DISK_SIZE}$DISK_EXT"
    
    pvesm alloc $(pvesm status | awk 'NR>1 {print $1}' | head -1) $VMID $DISK_REF ${DISK_SIZE}G >/dev/null
    if [ "$VERB" == "yes" ]; then set -x; fi
    
    # Create the container with specific network configuration for 192.169.0.201
    pct create $VMID $TEMPLATE_STRING $DISK_IMPORT \
        -arch $(dpkg --print-architecture) \
        -cores $CORE_COUNT \
        -hostname $VMNAME \
        -memory $RAM_SIZE \
        -nameserver 8.8.8.8 \
        -net0 name=eth0,bridge=$BRG,firewall=1,gw=192.169.0.1,ip=192.169.0.201/24,type=veth$MAC$MTU$VLAN \
        -onboot 1 \
        -ostype $OSTYPE \
        -searchdomain aip.dxc.com \
        -startup order=3 \
        -storage $(pvesm status | awk 'NR>1 {print $1}' | head -1) \
        -tags threat-analysis \
        -timezone $timezone \
        -unprivileged $CT_TYPE $CT_PW >/dev/null
        
    if [ "$VERB" == "yes" ]; then set +x; fi
    msg_ok "Created LXC Container"

    msg_info "Configuring Container Network"
    # Ensure the container has the correct network configuration
    pct set $VMID -net0 name=eth0,bridge=$BRG,firewall=1,gw=192.169.0.1,ip=192.169.0.201/24,type=veth
    msg_ok "Configured Container Network"

    msg_info "Starting LXC Container"
    pct start $VMID
    sleep 5
    pct push $VMID /root/threat-analysis-install.sh /root/threat-analysis-install.sh -perms 755
    msg_ok "Started LXC Container"
}

# Function to create the installation script content
create_install_script() {
    cat <<'EOF' > /root/threat-analysis-install.sh
#!/usr/bin/env bash

# Copyright (c) 2025 DXC AIP Community Scripts
# Author: DXC AIP Team  
# License: MIT

# Color codes for output
RD='\033[01;31m'
YW='\033[33m'
GN='\033[1;92m'
CL='\033[m'
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
BL="\033[36m"
DGN="\033[32m"

# Functions
msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}

msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

msg_error() {
    local msg="$1"
    echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
    exit 1
}

# Set error handling
set -euo pipefail

# Function definitions from functions library
setting_up_container() {
    msg_info "Setting up Container OS"
    sed -i "/$LANG/ s/\(^# \)//" /etc/locale.gen
    locale-gen >/dev/null
    msg_ok "Set up Container OS"
}

network_check() {
    msg_info "Checking Network Connection"
    if ping -c 1 google.com &> /dev/null; then
        msg_ok "Network Connection Established"
    else
        msg_error "Network Connection Failed"
    fi
}

update_os() {
    msg_info "Updating Container OS"
    apt-get update &>/dev/null
    apt-get -o Dpkg::Options::="--force-confold" -y upgrade &>/dev/null
    msg_ok "Updated Container OS"
}

motd_ssh() {
    msg_info "Customizing Container"
    GETTY_OVERRIDE="/etc/systemd/system/container-getty@1.service.d/override.conf"
    mkdir -p $(dirname $GETTY_OVERRIDE)
    cat <<EOT >$GETTY_OVERRIDE
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud tty%i 115200,38400,9600 \$TERM
EOT
    systemctl daemon-reload
    systemctl restart $(basename $(dirname $GETTY_OVERRIDE) | sed 's/\.d//')
    msg_ok "Customized Container"
}

customize() {
    msg_info "Customizing Container"
    if [[ "$SSH" == "yes" ]]; then
        sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config
        systemctl enable ssh
        systemctl restart ssh
    fi
    msg_ok "Customized Container"
}

# Variables
STD=""
if [[ "$VERB" != "yes" ]]; then STD="silent"; fi
silent() { "$@" > /dev/null 2>&1; }
LANG=C.UTF-8

# Color setup  
color() {
    YW=$(echo "\033[33m")
    BL=$(echo "\033[36m")  
    RD=$(echo "\033[01;31m")
    BGN=$(echo "\033[4;92m")
    GN=$(echo "\033[1;92m")
    DGN=$(echo "\033[32m")
    CL=$(echo "\033[m")
    BFR="\\r\\033[K"
    HOLD=" "
    CM="${GN}✓${CL}"
    CROSS="${RD}✗${CL}"
    if [[ "$VERB" == "yes" ]]; then STD=""; fi
}

verb_ip6() {
    if [[ "$DISABLEIP6" == "yes" ]]; then
        echo "net.ipv6.conf.all.disable_ipv6 = 1" >>/etc/sysctl.conf
        $STD sysctl -p
    fi
}

catch_errors() {
    set -Eeuo pipefail
    trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
}

error_handler() {
    local exit_code=$?
    local line_number=$1
    local bash_lineno=$2
    echo -e "\n$CROSS ERROR occurred in script at line $line_number: Exit code $exit_code"  
    echo -e "Failing command: $bash_lineno"
    exit $exit_code
}

# Execute the installation with these settings
SSH="no"
VERB="no" 
DISABLEIP6="no"

# Source the main installation script content here
# [The rest of the installation script from threat-analysis-install.sh goes here]
EOF

    chmod +x /root/threat-analysis-install.sh
}

# Main execution
start_routines

msg_info "Installing Threat Analysis Application"
create_install_script

# Execute the installation inside the container
pct exec $CT_ID -- bash -c "
export FUNCTIONS_FILE_PATH='$(cat /root/threat-analysis-install.sh | base64 -w 0)'
wget -qO- https://raw.githubusercontent.com/DXCSithlordPadawan/SolrSim/main/threat-analysis-install.sh | bash
"

# Final configuration
msg_info "Completing Container Setup"
if [[ "$SSH" == "yes" ]]; then
    pct exec $CT_ID -- bash -c "
        sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
        systemctl enable ssh
        systemctl restart ssh
    "
fi

# Container customization  
pct exec $CT_ID -- bash -c "
    GETTY_OVERRIDE='/etc/systemd/system/container-getty@1.service.d/override.conf'
    mkdir -p \$(dirname \$GETTY_OVERRIDE)
    cat <<EOT >\$GETTY_OVERRIDE
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud tty%i 115200,38400,9600 \\\$TERM
EOT
    systemctl daemon-reload
    systemctl restart \$(basename \$(dirname \$GETTY_OVERRIDE) | sed 's/\.d//')
"

msg_ok "Completed Container Setup"

# Display completion message
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
echo -e "   🌐 IP Address: ${GN}192.169.0.201${CL}"
echo -e "   💾 Disk Size: ${GN}${DISK_SIZE}GB${CL}"
echo -e "   🧠 CPU Cores: ${GN}$CORE_COUNT${CL}"
echo -e "   🐏 RAM: ${GN}${RAM_SIZE}MB${CL}"

echo -e "\n${BL}🌐 Application Access:${CL}"
echo -e "   🔗 Web Interface: ${GN}https://threat.aip.dxc.com${CL}"
echo -e "   🔧 Traefik Dashboard: ${GN}https://traefik.aip.dxc.com:8080${CL}"
echo -e "   ❤️  Health Check: ${GN}https://threat.aip.dxc.com/health${CL}"

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
echo -e "   💾 Create Backup: ${GN}threat-analysis backup${CL}"

echo -e "\n${YW}⚠️  Next Steps:${CL}"
echo -e "   1️⃣  Enter container: ${GN}pct enter $CT_ID${CL}"
echo -e "   2️⃣  Configure Tailscale: ${GN}tailscale up${CL}"
echo -e "   3️⃣  Verify SSL certificates are obtained"
echo -e "   4️⃣  Update DNS entries for threat.aip.dxc.com"
echo -e "   5️⃣  Test application access"

echo -e "\n${BL}🔧 Configuration Files:${CL}"
echo -e "   📂 App Config: ${GN}/opt/threat-analysis/config/areas.json${CL}"
echo -e "   🐳 Docker Compose: ${GN}/opt/deployment/docker-compose.yml${CL}"
echo -e "   🌐 Traefik Config: ${GN}/opt/deployment/traefik/dynamic/middleware.yml${CL}"

echo -e "\n${GN}✅ Container is ready and application is running!${CL}"
echo -e "${YW}📝 Don't forget to configure Tailscale and DNS entries.${CL}\n"