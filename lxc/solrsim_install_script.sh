# Function to configure firewall
configure_firewall() {
    log_info "Configuring firewall and security..."
    
    pct exec "$CONTAINER_ID" -- bash -c "
        # Configure UFW firewall
        ufw --force enable
        ufw default deny incoming
        ufw default allow outgoing
        
        # Allow SSH (if needed)
        ufw allow ssh
        
        # Allow HTTP and HTTPS
        ufw allow $NGINX_HTTP_PORT/tcp
        ufw allow $NGINX_HTTPS_PORT/tcp
        
        # Allow application port (for direct access if needed)
        ufw allow $FLASK_PORT/tcp
        
        # Allow monitoring ports (restrict to local network if needed)
        ufw allow $PROMETHEUS_PORT/tcp
        ufw allow $GRAFANA_PORT/tcp
        ufw allow $NODE_EXPORTER_PORT/tcp
        ufw allow 8000/tcp  # Prometheus metrics from app
        
        # Configure Fail2Ban
        cat > /etc/fail2ban/jail.local << 'FAIL2BAN_EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
FAIL2BAN_EOF
        
        systemctl enable fail2ban
        systemctl start fail2ban
    "
    
    log_success "Firewall and security configuration completed"
}

# Function to setup monitoring
setup_monitoring() {
    log_info "Setting up monitoring infrastructure..."
    
    pct exec "$CONTAINER_ID" -- bash -c "
        # Create monitoring directory
        mkdir -p $MONITORING_DIR/{prometheus,grafana,scripts}
        
        # Configure Prometheus
        cat > /etc/prometheus/prometheus.yml << 'PROMETHEUS_EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:$PROMETHEUS_PORT']
  
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:$NODE_EXPORTER_PORT']
  
  - job_name: 'solrsim-app'
    static_configs:
      - targets: ['localhost:8000']
    metrics_path: '/metrics'
    scrape_interval: 5s
  
  - job_name: 'nginx'
    static_configs:
      - targets: ['localhost:$NGINX_HTTP_PORT']
PROMETHEUS_EOF
        
        # Configure Grafana
        mkdir -p /etc/grafana/provisioning/{datasources,dashboards}
        
        cat > /etc/grafana/provisioning/datasources/prometheus.yml << 'GRAFANA_DS_EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:$PROMETHEUS_PORT
    isDefault: true
GRAFANA_DS_EOF
        
        cat > /etc/grafana/provisioning/dashboards/dashboard.yml << 'GRAFANA_DB_EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
GRAFANA_DB_EOF
        
        # Create SolrSim dashboard
        mkdir -p /var/lib/grafana/dashboards
        cat > /var/lib/grafana/dashboards/solrsim-dashboard.json << 'DASHBOARD_EOF'
{
  \"dashboard\": {
    \"id\": null,
    \"title\": \"SolrSim Monitoring Dashboard\",
    \"tags\": [\"solrsim\", \"security\"],
    \"timezone\": \"browser\",
    \"panels\": [
      {
        \"id\": 1,
        \"title\": \"Request Rate\",
        \"type\": \"graph\",
        \"targets\": [
          {
            \"expr\": \"rate(solrsim_requests_total[5m])\",
            \"refId\": \"A\"
          }
        ],
        \"gridPos\": {\"h\": 8, \"w\": 12, \"x\": 0, \"y\": 0}
      },
      {
        \"id\": 2,
        \"title\": \"Response Time\",
        \"type\": \"graph\",
        \"targets\": [
          {
            \"expr\": \"histogram_quantile(0.95, rate(solrsim_request_duration_seconds_bucket[5m]))\",
            \"refId\": \"A\"
          }
        ],
        \"gridPos\": {\"h\": 8, \"w\": 12, \"x\": 12, \"y\": 0}
      },
      {
        \"id\": 3,
        \"title\": \"System Resources\",
        \"type\": \"graph\",
        \"targets\": [
          {
            \"expr\": \"solrsim_cpu_usage_percent\",
            \"refId\": \"CPU\"
          },
          {
            \"expr\": \"solrsim_memory_usage_percent\",
            \"refId\": \"Memory\"
          }
        ],
        \"gridPos\": {\"h\": 8, \"w\": 24, \"x\": 0, \"y\": 8}
      }
    ],
    \"time\": {
      \"from\": \"now-1h\",
      \"to\": \"now\"
    },
    \"refresh\": \"5s\"
  }
}
DASHBOARD_EOF
        
        # Create health check script
        cat > $MONITORING_DIR/scripts/health_check.sh << 'HEALTH_EOF'
#!/bin/bash

# Health check script for SolrSim
APP_URL=\"http://localhost:$FLASK_PORT/health\"
LOG_FILE=\"/var/log/solrsim/health.log\"

mkdir -p /var/log/solrsim

check_health() {
    local timestamp=\$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check application health
    if curl -f -s \$APP_URL > /dev/null 2>&1; then
        echo \"[\$timestamp] HEALTHY: Application is responding\" >> \$LOG_FILE
        return 0
    else
        echo \"[\$timestamp] UNHEALTHY: Application is not responding\" >> \$LOG_FILE
        
        # Try to restart service
        systemctl restart solrsim.service
        sleep 5
        
        if curl -f -s \$APP_URL > /dev/null 2>&1; then
            echo \"[\$timestamp] RECOVERED: Service restarted successfully\" >> \$LOG_FILE
        else
            echo \"[\$timestamp] CRITICAL: Service restart failed\" >> \$LOG_FILE
        fi
        return 1
    fi
}

check_health
HEALTH_EOF
        
        chmod +x $MONITORING_DIR/scripts/health_check.sh
        
        # Create log rotation configuration
        cat > /etc/logrotate.d/solrsim << 'LOGROTATE_EOF'
/var/log/solrsim/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 solrsim solrsim
    postrotate
        systemctl reload solrsim.service > /dev/null 2>&1 || true
    endscript
}

/var/log/nginx/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}
LOGROTATE_EOF
        
        # Setup cron jobs for monitoring
        cat > /tmp/solrsim_cron << 'CRON_EOF'
# Health check every 5 minutes
*/5 * * * * /opt/monitoring/scripts/health_check.sh

# Cleanup old logs weekly
0 2 * * 0 find /var/log/solrsim -name \"*.log\" -mtime +30 -delete

# System metrics collection (backup)
*/1 * * * * echo \"\$(date '+%Y-%m-%d %H:%M:%S') CPU: \$(top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1) MEM: \$(free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}')%\" >> /var/log/solrsim/system.log
CRON_EOF#!/bin/bash

# SolrSim LXC Container One-Click Install Script
# This script automates the creation of an LXC container and deployment of SolrSim application
# Run this script on your Proxmox host

set -euo pipefail

# Configuration variables
CONTAINER_ID="${1:-170}"
CONTAINER_NAME="solrsim-app"
CONTAINER_HOSTNAME="solrsim-app"
CONTAINER_MEMORY="1024"
CONTAINER_SWAP="512"
CONTAINER_CORES="2"
CONTAINER_DISK_SIZE="8"
FLASK_PORT="5000"
NGINX_HTTP_PORT="80"
NGINX_HTTPS_PORT="443"
PROMETHEUS_PORT="9090"
GRAFANA_PORT="3000"
NODE_EXPORTER_PORT="9100"
TEMPLATE_NAME="ubuntu-22.04-standard"
STORAGE_LOCATION="local-lvm"
TEMPLATE_STORAGE="local"
NETWORK_BRIDGE="vmbr0"
REPO_URL="https://github.com/DXCSithlordPadawan/SolrSim.git"
APP_DIR="/opt/solrsim"
MONITORING_DIR="/opt/monitoring"
SSL_ENABLED="${SSL_ENABLED:-false}"
DOMAIN_NAME="${DOMAIN_NAME:-}"
EMAIL_ADDRESS="${EMAIL_ADDRESS:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running on Proxmox
check_proxmox() {
    if ! command -v pct &> /dev/null; then
        log_error "This script must be run on a Proxmox VE host"
        exit 1
    fi
    log_success "Running on Proxmox VE host"
}

# Function to check if container ID is available
check_container_id() {
    if pct status "$CONTAINER_ID" &> /dev/null; then
        log_error "Container ID $CONTAINER_ID already exists"
        exit 1
    fi
    log_success "Container ID $CONTAINER_ID is available"
}

# Function to download template if needed
download_template() {
    log_info "Checking for Ubuntu template..."
    
    # Update available templates
    pveam update
    
    # Check if template exists
    if ! pveam list "$TEMPLATE_STORAGE" | grep -q "$TEMPLATE_NAME"; then
        log_info "Downloading Ubuntu 22.04 template..."
        pveam download "$TEMPLATE_STORAGE" "${TEMPLATE_NAME}_22.04-1_amd64.tar.zst"
    else
        log_success "Ubuntu template already available"
    fi
}

# Function to create LXC container
create_container() {
    log_info "Creating LXC container with ID $CONTAINER_ID..."
    
    local template_file
    template_file=$(pveam list "$TEMPLATE_STORAGE" | grep "$TEMPLATE_NAME" | awk '{print $1}')
    
    pct create "$CONTAINER_ID" "${TEMPLATE_STORAGE}:vztmpl/${template_file}" \
        --hostname "$CONTAINER_HOSTNAME" \
        --memory "$CONTAINER_MEMORY" \
        --swap "$CONTAINER_SWAP" \
        --cores "$CONTAINER_CORES" \
        --rootfs "${STORAGE_LOCATION}:${CONTAINER_DISK_SIZE}" \
        --net0 "name=eth0,bridge=${NETWORK_BRIDGE},ip=dhcp" \
        --nameserver "8.8.8.8" \
        --features "nesting=1" \
        --unprivileged 1 \
        --onboot 1
    
    log_success "Container created successfully"
}

# Function to start container
start_container() {
    log_info "Starting container..."
    pct start "$CONTAINER_ID"
    
    # Wait for container to be ready
    sleep 10
    
    # Wait for network to be ready
    local retries=30
    while ! pct exec "$CONTAINER_ID" -- ping -c 1 8.8.8.8 &> /dev/null && [ $retries -gt 0 ]; do
        log_info "Waiting for network connectivity..."
        sleep 2
        ((retries--))
    done
    
    if [ $retries -eq 0 ]; then
        log_error "Network connectivity timeout"
        exit 1
    fi
    
    log_success "Container started and network is ready"
}

# Function to update container system
update_container_system() {
    log_info "Updating container system packages..."
    
    pct exec "$CONTAINER_ID" -- bash -c "
        export DEBIAN_FRONTEND=noninteractive
        apt update
        apt upgrade -y
        apt install -y python3 python3-pip python3-venv git curl systemd nano htop net-tools \
                       nginx certbot python3-certbot-nginx logrotate rsyslog cron \
                       prometheus prometheus-node-exporter grafana wget apt-transport-https \
                       software-properties-common gnupg lsb-release jq fail2ban ufw
    "
    
    log_success "System packages updated"
}

# Function to create application user
create_app_user() {
    log_info "Creating application user..."
    
    pct exec "$CONTAINER_ID" -- bash -c "
        useradd --system --create-home --shell /bin/bash solrsim
    "
    
    log_success "Application user created"
}

# Function to clone and setup application
setup_application() {
    log_info "Setting up SolrSim application..."
    
    pct exec "$CONTAINER_ID" -- bash -c "
        # Create application directory
        mkdir -p $APP_DIR
        cd $APP_DIR
        
        # Clone repository
        git clone $REPO_URL .
        
        # Create Python virtual environment
        python3 -m venv venv
        source venv/bin/activate
        
        # Create requirements.txt
        cat > requirements.txt << 'EOF'
Flask==2.3.3
Werkzeug==2.3.7
Jinja2==3.1.2
MarkupSafe==2.1.3
itsdangerous==2.1.2
click==8.1.7
blinker==1.6.2
EOF
        
        # Install requirements
        pip install -r requirements.txt
        
        # Install monitoring dependencies
        pip install prometheus_client psutil
        
        # Create data directory if it doesn't exist
        mkdir -p data
        
        # Create sample data file if it doesn't exist
        if [ ! -f data/productissues.json ]; then
            cat > data/productissues.json << 'EOF'
{
  \"products\": [
    {
      \"area\": \"OP1\",
      \"platforms\": [
        {
          \"name\": \"Platform-Alpha\",
          \"threats\": [\"malware\", \"ddos\", \"injection\"]
        },
        {
          \"name\": \"Platform-Beta\",
          \"threats\": [\"phishing\", \"ransomware\"]
        }
      ]
    },
    {
      \"area\": \"OP2\",
      \"platforms\": [
        {
          \"name\": \"Platform-Gamma\",
          \"threats\": [\"backdoor\", \"trojan\"]
        }
      ]
    }
  ]
}
EOF
        fi
    "
    
    log_success "Application setup completed"
}

# Function to create configuration files
create_config_files() {
    log_info "Creating configuration files..."
    
    # Create application configuration
    pct exec "$CONTAINER_ID" -- bash -c "
        cat > $APP_DIR/config.py << 'EOF'
import os

class Config:
    # Flask configuration
    HOST = '0.0.0.0'
    PORT = int(os.environ.get('FLASK_PORT', $FLASK_PORT))
    DEBUG = False
    
    # Security
    SECRET_KEY = os.environ.get('SECRET_KEY', 'solrsim-secret-key-change-in-production')
    
    # Application settings
    DATA_FILE = os.path.join(os.path.dirname(__file__), 'data', 'productissues.json')
EOF
    "
    
    # Create application wrapper
    pct exec "$CONTAINER_ID" -- bash -c "
        cat > $APP_DIR/run_app.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
import time
sys.path.insert(0, os.path.dirname(__file__))

# Add Prometheus monitoring
from prometheus_client import Counter, Histogram, Gauge, start_http_server
import psutil

# Metrics
REQUEST_COUNT = Counter('solrsim_requests_total', 'Total requests', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('solrsim_request_duration_seconds', 'Request latency')
ACTIVE_CONNECTIONS = Gauge('solrsim_active_connections', 'Active connections')
SYSTEM_CPU_USAGE = Gauge('solrsim_cpu_usage_percent', 'CPU usage percentage')
SYSTEM_MEMORY_USAGE = Gauge('solrsim_memory_usage_percent', 'Memory usage percentage')
SYSTEM_DISK_USAGE = Gauge('solrsim_disk_usage_percent', 'Disk usage percentage')

def update_system_metrics():
    \"\"\"Update system metrics\"\"\"
    try:
        SYSTEM_CPU_USAGE.set(psutil.cpu_percent())
        SYSTEM_MEMORY_USAGE.set(psutil.virtual_memory().percent)
        SYSTEM_DISK_USAGE.set(psutil.disk_usage('/').percent)
    except Exception as e:
        print(f\"Error updating system metrics: {e}\")

try:
    from threat_analysis_app import app
    from config import Config
    
    # Start Prometheus metrics server
    start_http_server(8000)
    
    # Add request monitoring
    from flask import request, g
    import threading
    import time
    
    @app.before_request
    def before_request():
        g.start_time = time.time()
        REQUEST_COUNT.labels(method=request.method, endpoint=request.endpoint or 'unknown').inc()
    
    @app.after_request
    def after_request(response):
        if hasattr(g, 'start_time'):
            REQUEST_LATENCY.observe(time.time() - g.start_time)
        return response
    
    # Update system metrics periodically
    def metrics_updater():
        while True:
            update_system_metrics()
            time.sleep(30)
    
    metrics_thread = threading.Thread(target=metrics_updater, daemon=True)
    metrics_thread.start()
    
    if __name__ == '__main__':
        app.run(
            host=Config.HOST,
            port=Config.PORT,
            debug=Config.DEBUG
        )
        
except ImportError as e:
    # Fallback if threat_analysis_app doesn't exist
    from flask import Flask, render_template_string, request, jsonify, g
    import json
    from datetime import datetime
    from config import Config
    import threading
    import time
    
    app = Flask(__name__)
    app.config.from_object(Config)
    
    # Start Prometheus metrics server
    start_http_server(8000)
    
    # Add request monitoring
    @app.before_request
    def before_request():
        g.start_time = time.time()
        REQUEST_COUNT.labels(method=request.method, endpoint=request.endpoint or 'unknown').inc()
    
    @app.after_request
    def after_request(response):
        if hasattr(g, 'start_time'):
            REQUEST_LATENCY.observe(time.time() - g.start_time)
        return response
    
    @app.route('/health')
    def health_check():
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'version': '1.0.0'
        })
    
    @app.route('/metrics')
    def metrics():
        return \"Prometheus metrics available on port 8000\"
    
    @app.route('/')
    def index():
        return render_template_string('''
        <!DOCTYPE html>
        <html>
        <head>
            <title>SolrSim Threat Analysis</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }
                .container { max-width: 800px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                .header { text-align: center; margin-bottom: 30px; }
                .form-group { margin-bottom: 15px; }
                label { display: block; margin-bottom: 5px; font-weight: bold; }
                select, input { width: 100%; padding: 12px; margin-bottom: 10px; border: 1px solid #ddd; border-radius: 4px; box-sizing: border-box; }
                button { background-color: #007bff; color: white; padding: 12px 24px; border: none; cursor: pointer; border-radius: 4px; font-size: 16px; }
                button:hover { background-color: #0056b3; }
                .results { margin-top: 20px; padding: 20px; background-color: #f8f9fa; border-radius: 5px; }
                .status-bar { background-color: #28a745; color: white; padding: 10px; text-align: center; margin-bottom: 20px; border-radius: 4px; }
                .health-link { position: absolute; top: 20px; right: 20px; color: #28a745; text-decoration: none; }
            </style>
        </head>
        <body>
            <a href=\"/health\" class=\"health-link\">Health Check</a>
            <div class=\"container\">
                <div class=\"header\">
                    <h1>🛡️ SolrSim Threat Analysis</h1>
                    <div class=\"status-bar\">System Operational - SSL Secured</div>
                </div>
                <form method=\"POST\" action=\"/analyze\">
                    <div class=\"form-group\">
                        <label for=\"area\">🎯 Operational Area:</label>
                        <select id=\"area\" name=\"area\" required>
                            <option value=\"\">Select Area</option>
                            <option value=\"OP1\">OP1 - Donetsk Operations</option>
                            <option value=\"OP2\">OP2 - Dnipropetrovsk Operations</option>
                            <option value=\"OP3\">OP3 - Zaporizhzhia Operations</option>
                            <option value=\"OP4\">OP4 - Kyiv Operations</option>
                            <option value=\"OP5\">OP5 - Kirovohrad Operations</option>
                            <option value=\"OP6\">OP6 - Mykolaiv Operations</option>
                            <option value=\"OP7\">OP7 - Odessa Operations</option>
                            <option value=\"OP8\">OP8 - Sumy Operations</option>
                        </select>
                    </div>
                    <div class=\"form-group\">
                        <label for=\"threat\">⚠️ Threat Identifier:</label>
                        <input type=\"text\" id=\"threat\" name=\"threat\" placeholder=\"e.g., malware, ddos, phishing\" required>
                    </div>
                    <button type=\"submit\">🔍 Analyze Threat</button>
                </form>
            </div>
        </body>
        </html>
        ''')
    
    @app.route('/analyze', methods=['POST'])
    def analyze():
        area = request.form.get('area')
        threat = request.form.get('threat')
        
        if not area or not threat:
            return \"Area and Threat are required\", 400
        
        try:
            with open(Config.DATA_FILE, 'r') as f:
                data = json.load(f)
        except FileNotFoundError:
            return \"Data file not found\", 500
        
        results = []
        for product in data.get('products', []):
            if product.get('area') == area:
                for platform in product.get('platforms', []):
                    if threat.lower() in [t.lower() for t in platform.get('threats', [])]:
                        results.append({
                            'platform': platform.get('name'),
                            'message': f\"{platform.get('name')} Threat Active - No Action Possible\",
                            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                            'severity': 'HIGH',
                            'area': area,
                            'threat_type': threat
                        })
        
        return render_template_string('''
        <!DOCTYPE html>
        <html>
        <head>
            <title>Analysis Results - SolrSim</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }
                .container { max-width: 800px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                .header { text-align: center; margin-bottom: 30px; }
                .result-item { padding: 20px; margin: 15px 0; background-color: #f8f9fa; border-radius: 8px; border-left: 4px solid #dc3545; }
                .result-item.safe { border-left-color: #28a745; background-color: #d4edda; }
                .back-link { display: inline-block; margin-top: 20px; color: #007bff; text-decoration: none; padding: 10px 20px; border: 1px solid #007bff; border-radius: 4px; }
                .back-link:hover { background-color: #007bff; color: white; }
                .severity-high { color: #dc3545; font-weight: bold; }
                .timestamp { color: #6c757d; font-size: 0.9em; }
                .no-results { text-align: center; color: #28a745; font-size: 1.2em; }
            </style>
        </head>
        <body>
            <div class=\"container\">
                <div class=\"header\">
                    <h1>🔍 Threat Analysis Results</h1>
                    <h3>📍 Area: {{ area }} | ⚠️ Threat: {{ threat }}</h3>
                </div>
                {% if results %}
                    {% for result in results %}
                    <div class=\"result-item\">
                        <div class=\"severity-high\">🚨 {{ result.message }}</div>
                        <div style=\"margin-top: 10px;\">
                            <strong>Platform:</strong> {{ result.platform }}<br>
                            <strong>Severity:</strong> <span class=\"severity-high\">{{ result.severity }}</span><br>
                            <strong>Area:</strong> {{ result.area }}<br>
                            <strong>Threat Type:</strong> {{ result.threat_type }}
                        </div>
                        <div class=\"timestamp\">{{ result.timestamp }}</div>
                    </div>
                    {% endfor %}
                {% else %}
                    <div class=\"result-item safe\">
                        <div class=\"no-results\">✅ No active threats detected for the specified area and threat combination.</div>
                    </div>
                {% endif %}
                <a href=\"/\" class=\"back-link\">⬅️ Back to Search</a>
            </div>
        </body>
        </html>
        ''', results=results, area=area, threat=threat)
    
    # Update system metrics periodically
    def metrics_updater():
        while True:
            update_system_metrics()
            time.sleep(30)
    
    metrics_thread = threading.Thread(target=metrics_updater, daemon=True)
    metrics_thread.start()
    
    if __name__ == '__main__':
        app.run(
            host=Config.HOST,
            port=Config.PORT,
            debug=Config.DEBUG
        )
EOF
        
        chmod +x $APP_DIR/run_app.py
    "
    
    log_success "Configuration files created"
}

# Function to set proper permissions
set_permissions() {
    log_info "Setting proper permissions..."
    
    pct exec "$CONTAINER_ID" -- bash -c "
        chown -R solrsim:solrsim $APP_DIR
        chmod -R 755 $APP_DIR
        chmod +x $APP_DIR/run_app.py
    "
    
    log_success "Permissions set"
}

# Function to create systemd service
create_systemd_service() {
    log_info "Creating systemd service..."
    
    pct exec "$CONTAINER_ID" -- bash -c "
        cat > /etc/systemd/system/solrsim.service << 'EOF'
[Unit]
Description=SolrSim Threat Analysis Application
After=network.target
Wants=network.target

[Service]
Type=simple
User=solrsim
Group=solrsim
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
Environment=PYTHONPATH=$APP_DIR
Environment=FLASK_PORT=$FLASK_PORT
ExecStart=$APP_DIR/venv/bin/python run_app.py
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=solrsim

# Security settings
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$APP_DIR
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes

[Install]
WantedBy=multi-user.target
EOF
    "
    
    log_success "Systemd service created"
}

# Function to enable and start service
start_service() {
    log_info "Starting SolrSim service..."
    
    pct exec "$CONTAINER_ID" -- bash -c "
        systemctl daemon-reload
        systemctl enable solrsim.service
        systemctl start solrsim.service
    "
    
    # Wait a moment for service to start
    sleep 5
    
    # Check service status
    if pct exec "$CONTAINER_ID" -- systemctl is-active --quiet solrsim.service; then
        log_success "SolrSim service started successfully"
    else
        log_error "Failed to start SolrSim service"
        pct exec "$CONTAINER_ID" -- systemctl status solrsim.service
        pct exec "$CONTAINER_ID" -- journalctl -u solrsim.service -n 20
        exit 1
    fi
}

        
        crontab -u solrsim /tmp/solrsim_cron
        rm /tmp/solrsim_cron
        
        # Start monitoring services
        systemctl enable prometheus
        systemctl start prometheus
        
        systemctl enable prometheus-node-exporter
        systemctl start prometheus-node-exporter
        
        systemctl enable grafana-server
        systemctl start grafana-server
        
        # Set proper permissions
        chown -R solrsim:solrsim $MONITORING_DIR
        chown -R grafana:grafana /var/lib/grafana/dashboards
    "
    
    log_success "Monitoring infrastructure setup completed"
}

# Function to setup SSL with Let's Encrypt
setup_ssl() {
    if [[ "$SSL_ENABLED" == "true" && -n "$DOMAIN_NAME" && -n "$EMAIL_ADDRESS" ]]; then
        log_info "Setting up SSL certificate with Let's Encrypt..."
        
        pct exec "$CONTAINER_ID" -- bash -c "
            # Configure Nginx for SSL
            cat > /etc/nginx/sites-available/solrsim-ssl << 'NGINX_SSL_EOF'
# HTTP redirect to HTTPS
server {
    listen $NGINX_HTTP_PORT;
    server_name $DOMAIN_NAME;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS configuration
server {
    listen $NGINX_HTTPS_PORT ssl http2;
    server_name $DOMAIN_NAME;
    
    # SSL Configuration will be added by Certbot
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection \"1; mode=block\";
    add_header Strict-Transport-Security \"max-age=63072000; includeSubDomains; preload\";
    add_header Content-Security-Policy \"default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';\";
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=app:10m rate=10r/m;
    
    location / {
        limit_req zone=app burst=20 nodelay;
        
        proxy_pass http://127.0.0.1:$FLASK_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Proxy timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:$FLASK_PORT/health;
        access_log off;
    }
    
    # Monitoring endpoints (restrict access)
    location /metrics {
        allow 127.0.0.1;
        allow 10.0.0.0/8;
        allow 172.16.0.0/12;
        allow 192.168.0.0/16;
        deny all;
        
        proxy_pass http://127.0.0.1:8000/;
    }
    
    # Static files with caching
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control \"public, immutable\";
    }
    
    # Deny access to sensitive files
    location ~ /\. {
        deny all;
    }
    
    location ~ \.(env|log|ini)$ {
        deny all;
    }
}
NGINX_SSL_EOF
            
            # Remove default site and enable SSL site
            rm -f /etc/nginx/sites-enabled/default
            ln -sf /etc/nginx/sites-available/solrsim-ssl /etc/nginx/sites-enabled/
            
            # Test nginx configuration
            nginx -t
            
            # Reload nginx
            systemctl reload nginx
            
            # Get SSL certificate
            certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --email $EMAIL_ADDRESS --redirect
            
            # Setup auto-renewal
            systemctl enable certbot.timer
            systemctl start certbot.timer
            
            # Test renewal
            certbot renew --dry-run
        "
        
        log_success "SSL certificate configured for $DOMAIN_NAME"
    else
        log_info "Setting up Nginx reverse proxy without SSL..."
        
        pct exec "$CONTAINER_ID" -- bash -c "
            cat > /etc/nginx/sites-available/solrsim << 'NGINX_EOF'
server {
    listen $NGINX_HTTP_PORT;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection \"1; mode=block\";
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=app:10m rate=10r/m;
    
    location / {
        limit_req zone=app burst=20 nodelay;
        
        proxy_pass http://127.0.0.1:$FLASK_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /health {
        proxy_pass http://127.0.0.1:$FLASK_PORT/health;
        access_log off;
    }
    
    location /metrics {
        allow 127.0.0.1;
        allow 10.0.0.0/8;
        allow 172.16.0.0/12;
        allow 192.168.0.0/16;
        deny all;
        
        proxy_pass http://127.0.0.1:8000/;
    }
}

# Monitoring interfaces
server {
    listen $PROMETHEUS_PORT;
    server_name _;
    
    location / {
        allow 127.0.0.1;
        allow 10.0.0.0/8;
        allow 172.16.0.0/12;
        allow 192.168.0.0/16;
        deny all;
        
        proxy_pass http://127.0.0.1:$PROMETHEUS_PORT;
    }
}

server {
    listen $GRAFANA_PORT;
    server_name _;
    
    location / {
        allow 127.0.0.1;
        allow 10.0.0.0/8;
        allow 172.16.0.0/12;  
        allow 192.168.0.0/16;
        deny all;
        
        proxy_pass http://127.0.0.1:$GRAFANA_PORT;
    }
}
NGINX_EOF
            
            rm -f /etc/nginx/sites-enabled/default
            ln -sf /etc/nginx/sites-available/solrsim /etc/nginx/sites-enabled/
            
            nginx -t
            systemctl reload nginx
        "
        
        log_success "Nginx reverse proxy configured"
    fi
}

# Function to create monitoring alerts
setup_alerts() {
    log_info "Setting up monitoring alerts..."
    
    pct exec "$CONTAINER_ID" -- bash -c "
        # Create alerting rules for Prometheus
        mkdir -p /etc/prometheus/rules
        
        cat > /etc/prometheus/rules/solrsim.yml << 'RULES_EOF'
groups:
  - name: solrsim
    rules:
      - alert: SolrSimDown
        expr: up{job=\"solrsim-app\"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: \"SolrSim application is down\"
          description: \"SolrSim application has been down for more than 1 minute\"
      
      - alert: HighResponseTime
        expr: histogram_quantile(0.95, rate(solrsim_request_duration_seconds_bucket[5m])) > 2
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: \"High response time detected\"
          description: \"95th percentile response time is above 2 seconds\"
      
      - alert: HighCPUUsage
        expr: solrsim_cpu_usage_percent > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: \"High CPU usage\"
          description: \"CPU usage is above 80% for more than 5 minutes\"
      
      - alert: HighMemoryUsage
        expr: solrsim_memory_usage_percent > 90
        for: 3m
        labels:
          severity: critical
        annotations:
          summary: \"High memory usage\"
          description: \"Memory usage is above 90% for more than 3 minutes\"
      
      - alert: DiskSpaceLow
        expr: solrsim_disk_usage_percent > 85
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: \"Disk space running low\"
          description: \"Disk usage is above 85%\"
RULES_EOF
        
        # Update Prometheus configuration to include rules
        cat >> /etc/prometheus/prometheus.yml << 'RULES_CONFIG_EOF'

rule_files:
  - \"/etc/prometheus/rules/*.yml\"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # Add Alertmanager targets here if needed
RULES_CONFIG_EOF
        
        # Create notification script
        cat > $MONITORING_DIR/scripts/alert_notification.sh << 'ALERT_EOF'
#!/bin/bash

# Simple alert notification script
ALERT_TYPE=\$1
ALERT_MESSAGE=\$2
LOG_FILE=\"/var/log/solrsim/alerts.log\"

mkdir -p /var/log/solrsim

timestamp=\$(date '+%Y-%m-%d %H:%M:%S')
echo \"[\$timestamp] ALERT: \$ALERT_TYPE - \$ALERT_MESSAGE\" >> \$LOG_FILE

# Add webhook or email notification here
# Example: curl -X POST -H 'Content-type: application/json' --data '{\"text\":\"\$ALERT_MESSAGE\"}' YOUR_WEBHOOK_URL
ALERT_EOF
        
        chmod +x $MONITORING_DIR/scripts/alert_notification.sh
        
        # Restart Prometheus to load new rules
        systemctl restart prometheus
    "
    
    log_success "Monitoring alerts configured"
}

# Function to setup log aggregation
setup_logging() {
    log_info "Setting up centralized logging..."
    
    pct exec "$CONTAINER_ID" -- bash -c "
        # Configure rsyslog for application logging
        cat > /etc/rsyslog.d/30-solrsim.conf << 'RSYSLOG_EOF'
# SolrSim application logging
\$template SolrSimFormat,\"%timestamp% %hostname% solrsim[%procid%]: %msg%\n\"
if \$programname == 'solrsim' then /var/log/solrsim/application.log;SolrSimFormat
& stop
RSYSLOG_EOF
        
        # Create log directories
        mkdir -p /var/log/solrsim
        mkdir -p /var/log/nginx
        
        # Set proper permissions
        chown -R solrsim:solrsim /var/log/solrsim
        chown -R www-data:www-data /var/log/nginx
        
        # Configure log rotation for all logs
        cat > /etc/logrotate.d/solrsim-complete << 'LOGROTATE_COMPLETE_EOF'
/var/log/solrsim/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 solrsim solrsim
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}

/var/log/nginx/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    sharedscripts
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}

/var/log/prometheus/*.log {
    weekly
    missingok
    rotate 12
    compress
    delaycompress
    notifempty
    postrotate
        systemctl reload prometheus > /dev/null 2>&1 || true
    endscript
}
LOGROTATE_COMPLETE_EOF
        
        # Restart rsyslog
        systemctl restart rsyslog
        
        # Create log analysis script
        cat > $MONITORING_DIR/scripts/log_analysis.sh << 'LOG_ANALYSIS_EOF'
#!/bin/bash

# Log analysis script for SolrSim
LOG_DIR=\"/var/log/solrsim\"
REPORT_FILE=\"\$LOG_DIR/daily_report.txt\"

generate_report() {
    local date=\$(date '+%Y-%m-%d')
    
    echo \"SolrSim Daily Report - \$date\" > \$REPORT_FILE
    echo \"====================================\" >> \$REPORT_FILE
    echo \"\" >> \$REPORT_FILE
    
    # Application metrics
    if [ -f \"\$LOG_DIR/application.log\" ]; then
        echo \"Application Activity:\" >> \$REPORT_FILE
        echo \"- Total requests: \$(grep -c 'request' \$LOG_DIR/application.log)\" >> \$REPORT_FILE
        echo \"- Errors: \$(grep -c 'ERROR' \$LOG_DIR/application.log)\" >> \$REPORT_FILE
        echo \"\" >> \$REPORT_FILE
    fi
    
    # Health check status
    if [ -f \"\$LOG_DIR/health.log\" ]; then
        echo \"Health Check Status:\" >> \$REPORT_FILE
        echo \"- Healthy checks: \$(grep -c 'HEALTHY' \$LOG_DIR/health.log)\" >> \$REPORT_FILE
        echo \"- Unhealthy checks: \$(grep -c 'UNHEALTHY' \$LOG_DIR/health.log)\" >> \$REPORT_FILE
        echo \"- Service restarts: \$(grep -c 'RECOVERED' \$LOG_DIR/health.log)\" >> \$REPORT_FILE
        echo \"\" >> \$REPORT_FILE
    fi
    
    # System metrics summary
    if [ -f \"\$LOG_DIR/system.log\" ]; then
        echo \"System Performance:\" >> \$REPORT_FILE
        echo \"- Average CPU: \$(awk '{sum+=\$4} END {printf \"%.1f%%\", sum/NR}' \$LOG_DIR/system.log)\" >> \$REPORT_FILE
        echo \"- Average Memory: \$(awk '{gsub(/%/,\"\",\$6); sum+=\$6} END {printf \"%.1f%%\", sum/NR}' \$LOG_DIR/system.log)\" >> \$REPORT_FILE
        echo \"\" >> \$REPORT_FILE
    fi
    
    # Security events
    if [ -f \"/var/log/auth.log\" ]; then
        echo \"Security Events:\" >> \$REPORT_FILE
        echo \"- Failed login attempts: \$(grep -c 'Failed password' /var/log/auth.log)\" >> \$REPORT_FILE
        echo \"- Firewall blocks: \$(grep -c 'UFW BLOCK' /var/log/ufw.log 2>/dev/null || echo '0')\" >> \$REPORT_FILE
        echo \"\" >> \$REPORT_FILE
    fi
    
    echo \"Report generated at: \$(date)\" >> \$REPORT_FILE
}

generate_report
LOG_ANALYSIS_EOF
        
        chmod +x $MONITORING_DIR/scripts/log_analysis.sh
        
        # Add to cron for daily reports
        (crontab -l -u solrsim 2>/dev/null; echo \"0 1 * * * $MONITORING_DIR/scripts/log_analysis.sh\") | crontab -u solrsim -
    "
    
    log_success "Centralized logging configured"
}

# Function to get container info
get_container_info() {
    local container_ip
    container_ip=$(pct exec "$CONTAINER_ID" -- hostname -I | awk '{print $1}')
    
    log_success "Installation completed successfully!"
    echo
    echo "==============================================="
    echo "       SolrSim Installation Summary"
    echo "==============================================="
    echo "Container ID: $CONTAINER_ID"
    echo "Container Name: $CONTAINER_NAME"
    echo "Container IP: $container_ip"
    echo
    if [[ "$SSL_ENABLED" == "true" && -n "$DOMAIN_NAME" ]]; then
        echo "🔒 SSL Configuration:"
        echo "  Primary URL: https://$DOMAIN_NAME"
        echo "  HTTP Redirect: http://$DOMAIN_NAME -> https://$DOMAIN_NAME"
    else
        echo "🌐 Application Access:"
        echo "  Primary URL: http://$container_ip"
        echo "  Direct App: http://$container_ip:$FLASK_PORT"
    fi
    echo
    echo "📊 Monitoring Dashboards:"
    echo "  Grafana: http://$container_ip:$GRAFANA_PORT (admin/admin)"
    echo "  Prometheus: http://$container_ip:$PROMETHEUS_PORT"
    echo "  App Metrics: http://$container_ip:8000/metrics"
    echo "  Health Check: http://$container_ip:$FLASK_PORT/health"
    echo
    echo "🔧 Service Management Commands:"
    echo "  Start:   pct exec $CONTAINER_ID -- systemctl start solrsim.service"
    echo "  Stop:    pct exec $CONTAINER_ID -- systemctl stop solrsim.service"
    echo "  Restart: pct exec $CONTAINER_ID -- systemctl restart solrsim.service"
    echo "  Status:  pct exec $CONTAINER_ID -- systemctl status solrsim.service"
    echo "  Logs:    pct exec $CONTAINER_ID -- journalctl -u solrsim.service -f"
    echo
    echo "📈 Monitoring Commands:"
    echo "  Prometheus: pct exec $CONTAINER_ID -- systemctl status prometheus"
    echo "  Grafana:    pct exec $CONTAINER_ID -- systemctl status grafana-server"
    echo "  Node Exp:   pct exec $CONTAINER_ID -- systemctl status prometheus-node-exporter"
    echo "  View Logs:  pct exec $CONTAINER_ID -- tail -f /var/log/solrsim/*.log"
    echo
    echo "🛡️ Security & SSL:"
    if [[ "$SSL_ENABLED" == "true" ]]; then
        echo "  SSL Status: pct exec $CONTAINER_ID -- certbot certificates"
        echo "  Renew SSL:  pct exec $CONTAINER_ID -- certbot renew"
    else
        echo "  Firewall:   pct exec $CONTAINER_ID -- ufw status"
    fi
    echo "  Fail2Ban:   pct exec $CONTAINER_ID -- fail2ban-client status"
    echo "  Auth Logs:  pct exec $CONTAINER_ID -- tail -f /var/log/auth.log"
    echo
    echo "📂 Important File Locations:"
    echo "  App Directory: $APP_DIR"
    echo "  Config File: $APP_DIR/config.py"
    echo "  Data File: $APP_DIR/data/productissues.json"
    echo "  Nginx Config: /etc/nginx/sites-available/solrsim"
    if [[ "$SSL_ENABLED" == "true" ]]; then
        echo "  SSL Config: /etc/nginx/sites-available/solrsim-ssl"
    fi
    echo "  Monitoring: $MONITORING_DIR"
    echo "  App Logs: /var/log/solrsim/"
    echo "  Nginx Logs: /var/log/nginx/"
    echo
    echo "🔍 Daily Operations:"
    echo "  1. Check health: curl http://$container_ip:$FLASK_PORT/health"
    echo "  2. View metrics in Grafana dashboard"
    echo "  3. Review daily reports: /var/log/solrsim/daily_report.txt"
    echo "  4. Monitor alerts: /var/log/solrsim/alerts.log"
    echo
    echo "⚙️ Configuration Next Steps:"
    echo "  1. Change Grafana password (admin/admin)"
    echo "  2. Customize data file: $APP_DIR/data/productissues.json"
    echo "  3. Update SECRET_KEY: $APP_DIR/config.py"
    if [[ "$SSL_ENABLED" != "true" ]]; then
        echo "  4. Consider enabling SSL with: SSL_ENABLED=true DOMAIN_NAME=your.domain EMAIL_ADDRESS=your@email"
    fi
    echo "  5. Configure external alerting in $MONITORING_DIR/scripts/alert_notification.sh"
    echo
    echo "🚨 Emergency Procedures:"
    echo "  Container Management:"
    echo "    Enter: pct enter $CONTAINER_ID"
    echo "    Stop:  pct stop $CONTAINER_ID"
    echo "    Start: pct start $CONTAINER_ID"
    echo "  Service Recovery:"
    echo "    pct exec $CONTAINER_ID -- systemctl restart solrsim nginx prometheus grafana-server"
    echo "  Backup: vzdump $CONTAINER_ID --storage local"
    echo
    if [[ "$SSL_ENABLED" == "true" && -n "$DOMAIN_NAME" ]]; then
        echo "🎉 Installation Complete! Access your secure SolrSim at: https://$DOMAIN_NAME"
    else
        echo "🎉 Installation Complete! Access SolrSim at: http://$container_ip"
    fi
    echo "==============================================="
}

# Function to cleanup on error
cleanup_on_error() {
    log_error "Installation failed. Cleaning up..."
    if pct status "$CONTAINER_ID" &> /dev/null; then
        pct stop "$CONTAINER_ID" || true
        pct destroy "$CONTAINER_ID" || true
        log_info "Container $CONTAINER_ID removed"
    fi
    exit 1
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [CONTAINER_ID] [OPTIONS]"
    echo
    echo "This script creates an LXC container and installs SolrSim application with monitoring and SSL"
    echo
    echo "Arguments:"
    echo "  CONTAINER_ID  Container ID to use (default: 170)"
    echo
    echo "Environment Variables:"
    echo "  SSL_ENABLED    Enable SSL with Let's Encrypt (true/false, default: false)"
    echo "  DOMAIN_NAME    Domain name for SSL certificate (required if SSL_ENABLED=true)"
    echo "  EMAIL_ADDRESS  Email for Let's Encrypt notifications (required if SSL_ENABLED=true)"
    echo
    echo "Examples:"
    echo "  # Basic installation"
    echo "  $0 170"
    echo
    echo "  # Installation with SSL"
    echo "  SSL_ENABLED=true DOMAIN_NAME=solrsim.example.com EMAIL_ADDRESS=admin@example.com $0 102"
    echo
    echo "  # Installation with custom container settings"
    echo "  CONTAINER_MEMORY=2048 CONTAINER_CORES=4 $0 103"
    echo
    echo "Features included:"
    echo "  ✓ SolrSim Flask application"
    echo "  ✓ Nginx reverse proxy with rate limiting"
    echo "  ✓ SSL/TLS with Let's Encrypt (optional)"
    echo "  ✓ Prometheus monitoring with custom metrics"
    echo "  ✓ Grafana dashboards"
    echo "  ✓ Health checks and alerting"
    echo "  ✓ Log rotation and analysis"
    echo "  ✓ UFW firewall and Fail2Ban security"
    echo "  ✓ Automated backups and recovery scripts"
    echo
    echo "Post-installation access:"
    echo "  - Application: http://CONTAINER_IP (or https://DOMAIN_NAME if SSL enabled)"
    echo "  - Grafana: http://CONTAINER_IP:3000 (admin/admin)"
    echo "  - Prometheus: http://CONTAINER_IP:9090"
    echo
    echo "Make sure to run this script on a Proxmox VE host"
}

# Main installation function
main() {
    # Check for help argument
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    log_info "Starting SolrSim LXC installation..."
    log_info "Container ID: $CONTAINER_ID"
    
    # Set trap for cleanup on error
    trap cleanup_on_error ERR
    
    # Run installation steps
    check_proxmox
    check_container_id
    download_template
    create_container
    start_container
    update_container_system
    create_app_user
    setup_application
    create_config_files
    set_permissions
    create_systemd_service
    start_service
    setup_monitoring
    setup_ssl
    setup_alerts
    setup_logging
    configure_firewall
    get_container_info
}

# Run main function
main "$@"
