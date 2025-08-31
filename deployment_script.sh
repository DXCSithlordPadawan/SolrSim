#!/bin/bash

# Comprehensive Deployment Script for Threat Analysis Application
# Target: 192.169.0.201 with Tailscale and Traefik reverse proxy
# Author: DXC AIP Team
# Version: 1.0

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEPLOY_USER="ubuntu"
DEPLOY_HOST="192.169.0.201"
CERT_SERVER="192.168.0.22"
APP_NAME="threat-analysis"
DOMAIN="threat.aip.dxc.com"
TRAEFIK_DOMAIN="traefik.aip.dxc.com"

# Directories
REMOTE_APP_DIR="/opt/${APP_NAME}"
REMOTE_TRAEFIK_DIR="/opt/traefik"
LOCAL_DEPLOY_DIR="./deployment"

# Log function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if required commands exist
    command -v ssh >/dev/null 2>&1 || error "ssh is required but not installed"
    command -v scp >/dev/null 2>&1 || error "scp is required but not installed"
    command -v docker >/dev/null 2>&1 || error "docker is required but not installed"
    
    # Check if deployment files exist
    [ -f "threat_analysis_app.py" ] || error "threat_analysis_app.py not found"
    [ -f "docker-compose.yml" ] || error "docker-compose.yml not found"
    [ -f "Dockerfile" ] || error "Dockerfile not found"
    [ -f "requirements.txt" ] || error "requirements.txt not found"
    
    log "Prerequisites check completed"
}

# Test connectivity
test_connectivity() {
    log "Testing connectivity to deployment target..."
    
    if ! ssh -o ConnectTimeout=10 "${DEPLOY_USER}@${DEPLOY_HOST}" "echo 'Connection test successful'" >/dev/null 2>&1; then
        error "Cannot connect to ${DEPLOY_HOST}. Please check SSH access and Tailscale connection."
    fi
    
    log "Connectivity test passed"
}

# Setup remote environment
setup_remote_environment() {
    log "Setting up remote environment..."
    
    ssh "${DEPLOY_USER}@${DEPLOY_HOST}" << 'EOF'
        set -e
        
        # Update system
        sudo apt-get update && sudo apt-get upgrade -y
        
        # Install required packages
        sudo apt-get install -y docker.io docker-compose-plugin curl htop unzip jq
        
        # Start and enable Docker
        sudo systemctl start docker
        sudo systemctl enable docker
        
        # Add user to docker group
        sudo usermod -aG docker $USER
        
        # Install Docker Compose (standalone)
        if ! command -v docker-compose >/dev/null 2>&1; then
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
        fi
        
        # Create directories
        sudo mkdir -p /opt/threat-analysis/{data,config,logs}
        sudo mkdir -p /opt/traefik/{data,logs}
        sudo mkdir -p /opt/deployment/traefik/dynamic
        
        # Set permissions
        sudo chown -R $USER:docker /opt/threat-analysis
        sudo chown -R $USER:docker /opt/traefik
        sudo chown -R $USER:docker /opt/deployment
        
        # Create Docker network
        docker network create traefik 2>/dev/null || echo "Network traefik already exists"
        
        echo "Remote environment setup completed"
EOF
    
    log "Remote environment setup completed"
}

# Install and configure Tailscale
setup_tailscale() {
    log "Setting up Tailscale..."
    
    ssh "${DEPLOY_USER}@${DEPLOY_HOST}" << 'EOF'
        set -e
        
        # Check if Tailscale is already installed
        if ! command -v tailscale >/dev/null 2>&1; then
            echo "Installing Tailscale..."
            curl -fsSL https://tailscale.com/install.sh | sh
        else
            echo "Tailscale already installed"
        fi
        
        # Check Tailscale status
        if ! sudo tailscale status >/dev/null 2>&1; then
            echo "Tailscale not authenticated. Please run: sudo tailscale up"
            echo "After deployment, authenticate Tailscale manually"
        else
            echo "Tailscale is already configured"
        fi
EOF
    
    info "Tailscale setup completed. If not authenticated, run 'sudo tailscale up' on the target server"
}

# Copy deployment files
copy_deployment_files() {
    log "Copying deployment files to remote server..."
    
    # Create local deployment directory structure
    mkdir -p "${LOCAL_DEPLOY_DIR}/traefik/dynamic"
    mkdir -p "${LOCAL_DEPLOY_DIR}/config"
    mkdir -p "${LOCAL_DEPLOY_DIR}/templates"
    mkdir -p "${LOCAL_DEPLOY_DIR}/static"
    
    # Copy all files to local deployment directory
    cp threat_analysis_app.py "${LOCAL_DEPLOY_DIR}/"
    cp docker-compose.yml "${LOCAL_DEPLOY_DIR}/"
    cp Dockerfile "${LOCAL_DEPLOY_DIR}/"
    cp requirements.txt "${LOCAL_DEPLOY_DIR}/"
    cp config/areas.json "${LOCAL_DEPLOY_DIR}/config/"
    cp traefik/dynamic/middleware.yml "${LOCAL_DEPLOY_DIR}/traefik/dynamic/"
    
    # Copy templates and static files if they exist
    [ -d "templates" ] && cp -r templates/* "${LOCAL_DEPLOY_DIR}/templates/" || warning "No templates directory found"
    [ -d "static" ] && cp -r static/* "${LOCAL_DEPLOY_DIR}/static/" || warning "No static directory found"
    
    # Copy entire deployment directory to remote server
    scp -r "${LOCAL_DEPLOY_DIR}" "${DEPLOY_USER}@${DEPLOY_HOST}:/opt/"
    
    # Copy config files to their final locations
    ssh "${DEPLOY_USER}@${DEPLOY_HOST}" << EOF
        set -e
        cp -r /opt/deployment/* /opt/
        cp /opt/deployment/config/areas.json /opt/threat-analysis/config/
        chmod +x /opt/deployment/deploy.sh 2>/dev/null || true
EOF
    
    log "Deployment files copied successfully"
}

# Generate environment file
generate_env_file() {
    log "Generating environment configuration..."
    
    # Generate random secret key
    SECRET_KEY=$(openssl rand -hex 32)
    
    ssh "${DEPLOY_USER}@${DEPLOY_HOST}" << EOF
        cat > /opt/deployment/.env << EOL
# Threat Analysis Application Environment Configuration
# Generated on $(date)

# Application Settings
SECRET_KEY=${SECRET_KEY}
DEBUG=false
PORT=5000

# Paths
CONFIG_PATH=/app/config/areas.json
DATA_PATH=/app/data/threats.json

# Domain Configuration
DOMAIN=${DOMAIN}
TRAEFIK_DOMAIN=${TRAEFIK_DOMAIN}

# Certificate Configuration
CERT_SERVER=${CERT_SERVER}
CERT_EMAIL=admin@aip.dxc.com

# Traefik Configuration
TRAEFIK_LOG_LEVEL=INFO
TRAEFIK_API_DASHBOARD=true
EOL
        
        echo "Environment file generated"
EOF
    
    log "Environment configuration generated"
}

# Configure firewall
configure_firewall() {
    log "Configuring firewall..."
    
    ssh "${DEPLOY_USER}@${DEPLOY_HOST}" << 'EOF'
        set -e
        
        # Enable UFW if not enabled
        sudo ufw --force enable
        
        # Allow SSH
        sudo ufw allow ssh
        
        # Allow HTTP and HTTPS
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        
        # Allow Traefik dashboard (restrict as needed)
        sudo ufw allow 8080/tcp
        
        # Allow Tailscale
        sudo ufw allow in on tailscale0
        
        # Reload firewall
        sudo ufw reload
        
        echo "Firewall configured"
EOF
    
    log "Firewall configuration completed"
}

# Deploy application
deploy_application() {
    log "Deploying Threat Analysis application..."
    
    ssh "${DEPLOY_USER}@${DEPLOY_HOST}" << 'EOF'
        set -e
        cd /opt/deployment
        
        # Load environment variables
        export $(grep -v '^#' .env | xargs)
        
        # Stop existing containers if running
        docker-compose down 2>/dev/null || true
        
        # Pull latest images and rebuild
        docker-compose pull 2>/dev/null || true
        docker-compose build --no-cache
        
        # Start services
        docker-compose up -d
        
        # Wait for services to be ready
        echo "Waiting for services to start..."
        sleep 30
        
        # Check service status
        docker-compose ps
        docker-compose logs --tail=50
        
        echo "Application deployment completed"
EOF
    
    log "Application deployed successfully"
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    ssh "${DEPLOY_USER}@${DEPLOY_HOST}" << EOF
        set -e
        
        # Check container status
        echo "Container Status:"
        docker-compose -f /opt/deployment/docker-compose.yml ps
        
        # Check application health
        echo "Checking application health..."
        sleep 10
        
        # Test local connectivity
        if curl -f http://localhost/health >/dev/null 2>&1; then
            echo "✓ Application health check passed"
        else
            echo "✗ Application health check failed"
        fi
        
        # Check Traefik dashboard
        if curl -f http://localhost:8080/api/version >/dev/null 2>&1; then
            echo "✓ Traefik API accessible"
        else
            echo "✗ Traefik API not accessible"
        fi
        
        echo "Deployment verification completed"
EOF
    
    log "Deployment verification completed"
}

# Setup monitoring and logging
setup_monitoring() {
    log "Setting up monitoring and logging..."
    
    ssh "${DEPLOY_USER}@${DEPLOY_HOST}" << 'EOF'
        set -e
        
        # Create logrotate configuration
        sudo tee /etc/logrotate.d/threat-analysis << EOL
/opt/threat-analysis/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOL
        
        # Create monitoring script
        tee /opt/deployment/monitor.sh << EOL
#!/bin/bash
# Monitoring script for Threat Analysis application

LOG_FILE="/opt/threat-analysis/logs/monitor.log"
DATE=\$(date '+%Y-%m-%d %H:%M:%S')

echo "[\$DATE] Starting health check..." >> \$LOG_FILE

# Check Docker containers
if ! docker-compose -f /opt/deployment/docker-compose.yml ps | grep -q "Up"; then
    echo "[\$DATE] ERROR: Some containers are not running" >> \$LOG_FILE
    docker-compose -f /opt/deployment/docker-compose.yml up -d
fi

# Check application health
if ! curl -f http://localhost/health >/dev/null 2>&1; then
    echo "[\$DATE] ERROR: Application health check failed" >> \$LOG_FILE
else
    echo "[\$DATE] INFO: Application health check passed" >> \$LOG_FILE
fi

# Check disk space
DISK_USAGE=\$(df /opt | tail -1 | awk '{print \$5}' | sed 's/%//')
if [ \$DISK_USAGE -gt 85 ]; then
    echo "[\$DATE] WARNING: Disk usage is \${DISK_USAGE}%" >> \$LOG_FILE
fi

echo "[\$DATE] Health check completed" >> \$LOG_FILE
EOL
        
        chmod +x /opt/deployment/monitor.sh
        
        # Add cron job for monitoring
        (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/deployment/monitor.sh") | crontab -
        
        echo "Monitoring and logging setup completed"
EOF
    
    log "Monitoring and logging setup completed"
}

# Create backup script
create_backup_script() {
    log "Creating backup script..."
    
    ssh "${DEPLOY_USER}@${DEPLOY_HOST}" << 'EOF'
        set -e
        
        # Create backup directory
        mkdir -p /opt/backups
        
        # Create backup script
        tee /opt/deployment/backup.sh << 'EOL'
#!/bin/bash
# Backup script for Threat Analysis application

set -e

BACKUP_DIR="/opt/backups"
DATE=$(date '+%Y%m%d_%H%M%S')
BACKUP_NAME="threat-analysis_${DATE}"

echo "Starting backup: ${BACKUP_NAME}"

# Create backup directory
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"

# Backup application data
cp -r /opt/threat-analysis/data "${BACKUP_DIR}/${BACKUP_NAME}/"
cp -r /opt/threat-analysis/config "${BACKUP_DIR}/${BACKUP_NAME}/"

# Backup configuration files
cp -r /opt/deployment "${BACKUP_DIR}/${BACKUP_NAME}/"

# Backup Traefik data
cp -r /opt/traefik "${BACKUP_DIR}/${BACKUP_NAME}/"

# Create archive
cd "${BACKUP_DIR}"
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
rm -rf "${BACKUP_NAME}"

# Keep only last 7 backups
ls -t "${BACKUP_DIR}"/*.tar.gz | tail -n +8 | xargs rm -f

echo "Backup completed: ${BACKUP_NAME}.tar.gz"
EOL
        
        chmod +x /opt/deployment/backup.sh
        
        # Add daily backup cron job
        (crontab -l 2>/dev/null; echo "0 2 * * * /opt/deployment/backup.sh") | crontab -
        
        echo "Backup script created"
EOF
    
    log "Backup script created"
}

# Generate SSL certificate configuration
setup_ssl_certificates() {
    log "Setting up SSL certificate configuration..."
    
    ssh "${DEPLOY_USER}@${DEPLOY_HOST}" << EOF
        set -e
        
        # Create certificate configuration
        tee /opt/traefik/cert-config.yml << EOL
# Certificate configuration for DXC cert-server
# Server: ${CERT_SERVER}

certificatesResolvers:
  dxc-cert-resolver:
    acme:
      email: admin@aip.dxc.com
      storage: /letsencrypt/acme.json
      caServer: https://cert-server.aip.dxc.com:8443/acme/acme/directory
      tlsChallenge: {}
      # Alternative HTTP challenge if TLS challenge doesn't work
      # httpChallenge:
      #   entryPoint: web
EOL
        
        # Set proper permissions for ACME storage
        touch /opt/traefik/data/acme.json
        chmod 600 /opt/traefik/data/acme.json
        
        echo "SSL certificate configuration completed"
EOF
    
    log "SSL certificate configuration completed"
}

# Display post-deployment information
show_deployment_info() {
    log "Deployment completed successfully!"
    
    cat << EOF

${GREEN}======================================${NC}
${GREEN}  THREAT ANALYSIS DEPLOYMENT COMPLETE${NC}
${GREEN}======================================${NC}

${BLUE}Application Details:${NC}
- Server: ${DEPLOY_HOST}
- Application URL: https://${DOMAIN}
- Traefik Dashboard: https://${TRAEFIK_DOMAIN}
- Local Health Check: http://${DEPLOY_HOST}/health

${BLUE}Services Status:${NC}
$(ssh "${DEPLOY_USER}@${DEPLOY_HOST}" "docker-compose -f /opt/deployment/docker-compose.yml ps")

${BLUE}SSL Certificates:${NC}
- Certificate Server: ${CERT_SERVER}
- Certificates will be automatically obtained from cert-server.aip.dxc.com

${BLUE}Management Commands:${NC}
- View logs: ssh ${DEPLOY_USER}@${DEPLOY_HOST} "docker-compose -f /opt/deployment/docker-compose.yml logs -f"
- Restart services: ssh ${DEPLOY_USER}@${DEPLOY_HOST} "docker-compose -f /opt/deployment/docker-compose.yml restart"
- Update application: ssh ${DEPLOY_USER}@${DEPLOY_HOST} "docker-compose -f /opt/deployment/docker-compose.yml pull && docker-compose -f /opt/deployment/docker-compose.yml up -d"

${BLUE}Monitoring:${NC}
- Health checks run every 5 minutes
- Daily backups at 2:00 AM
- Logs rotated daily, kept for 30 days

${YELLOW}Next Steps:${NC}
1. Ensure Tailscale is authenticated: ssh ${DEPLOY_USER}@${DEPLOY_HOST} "sudo tailscale up"
2. Verify SSL certificates are obtained automatically
3. Test application access via https://${DOMAIN}
4. Configure DNS entries for ${DOMAIN} and ${TRAEFIK_DOMAIN} if needed

${YELLOW}Troubleshooting:${NC}
- Check container logs: docker-compose -f /opt/deployment/docker-compose.yml logs
- Verify Traefik config: curl http://localhost:8080/api/http/routers
- Test certificate generation: Check /opt/traefik/data/acme.json

EOF
}

# Cleanup function
cleanup() {
    log "Cleaning up local deployment files..."
    rm -rf "${LOCAL_DEPLOY_DIR}" 2>/dev/null || true
}

# Main deployment function
main() {
    log "Starting Threat Analysis Application Deployment"
    log "Target: ${DEPLOY_HOST}"
    log "Domain: ${DOMAIN}"
    
    # Trap cleanup on exit
    trap cleanup EXIT
    
    check_prerequisites
    test_connectivity
    setup_remote_environment
    setup_tailscale
    copy_deployment_files
    generate_env_file
    configure_firewall
    setup_ssl_certificates
    deploy_application
    setup_monitoring
    create_backup_script
    verify_deployment
    show_deployment_info
    
    log "Deployment process completed successfully!"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi