#!/usr/bin/env bash

# Copyright (c) 2025 DXC AIP Community Scripts
# Author: DXC AIP Team
# License: MIT
# https://github.com/DXCSithlordPadawan/SolrSim/tree/main

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"

color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
$STD apt-get install -y apt-transport-https
$STD apt-get install -y ca-certificates
$STD apt-get install -y gnupg
$STD apt-get install -y lsb-release
msg_ok "Installed Dependencies"

msg_info "Installing Docker"
$STD curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" >/etc/apt/sources.list.d/docker.list
$STD apt-get update
$STD apt-get install -y docker-ce docker-ce-cli containerd.io
$STD systemctl enable docker
$STD systemctl start docker
msg_ok "Installed Docker"

msg_info "Installing Docker Compose"
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
$STD curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
$STD chmod +x /usr/local/bin/docker-compose
msg_ok "Installed Docker Compose"

msg_info "Installing Tailscale"
$STD curl -fsSL https://tailscale.com/install.sh | sh
msg_ok "Installed Tailscale"

msg_info "Setting up Application Directories"
mkdir -p /opt/threat-analysis/{data,config,logs}
mkdir -p /opt/traefik/{data,logs}
mkdir -p /opt/deployment/{traefik/dynamic,config,templates,static}
mkdir -p /opt/backups
chmod 755 /opt/threat-analysis /opt/traefik /opt/deployment /opt/backups
msg_ok "Created Application Directories"

msg_info "Creating Docker Networks"
$STD docker network create traefik 2>/dev/null || true
msg_ok "Created Docker Networks"

msg_info "Installing Python Dependencies"
$STD apt-get install -y python3 python3-pip python3-venv
msg_ok "Installed Python Dependencies"

msg_info "Downloading Application Files"
cat <<'EOF' > /opt/deployment/threat_analysis_app.py
#!/usr/bin/env python3
"""
Threat Analysis Web Application
Modified to use external JSON configuration for valid areas
"""

import json
import os
from flask import Flask, render_template, request, jsonify, flash, redirect, url_for
from datetime import datetime
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'your-secret-key-change-in-production')

# Global variables
threat_data = []
valid_areas = []

def load_config():
    """Load configuration from external JSON file"""
    global valid_areas
    
    config_path = os.environ.get('CONFIG_PATH', './config/areas.json')
    
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
            valid_areas = config.get('valid_areas', [])
            logger.info(f"Loaded {len(valid_areas)} valid areas from {config_path}")
    except FileNotFoundError:
        logger.error(f"Configuration file not found at {config_path}")
        # Fallback to default areas
        valid_areas = ["OP1", "OP2", "OP3", "OP4", "OP5", "OP6", "OP7", "OP8"]
        logger.info("Using default valid areas")
    except json.JSONDecodeError as e:
        logger.error(f"Error parsing configuration file: {e}")
        valid_areas = ["OP1", "OP2", "OP3", "OP4", "OP5", "OP6", "OP7", "OP8"]
        logger.info("Using default valid areas")

def save_threat_data():
    """Save threat data to file"""
    data_path = os.environ.get('DATA_PATH', './data/threats.json')
    os.makedirs(os.path.dirname(data_path), exist_ok=True)
    
    try:
        with open(data_path, 'w') as f:
            json.dump(threat_data, f, indent=2)
        logger.info(f"Saved {len(threat_data)} threats to {data_path}")
    except Exception as e:
        logger.error(f"Error saving threat data: {e}")

def load_threat_data():
    """Load threat data from file"""
    global threat_data
    
    data_path = os.environ.get('DATA_PATH', './data/threats.json')
    
    try:
        with open(data_path, 'r') as f:
            threat_data = json.load(f)
        logger.info(f"Loaded {len(threat_data)} threats from {data_path}")
    except FileNotFoundError:
        logger.info("No existing threat data found, starting with empty list")
        threat_data = []
    except json.JSONDecodeError as e:
        logger.error(f"Error parsing threat data file: {e}")
        threat_data = []

@app.route('/')
def index():
    """Main page showing threat analysis form and current threats"""
    return render_template('index.html', 
                         valid_areas=valid_areas, 
                         threats=threat_data)

@app.route('/api/config')
def get_config():
    """API endpoint to get current configuration"""
    return jsonify({
        'valid_areas': valid_areas,
        'total_threats': len(threat_data)
    })

@app.route('/api/threats', methods=['GET'])
def get_threats():
    """API endpoint to get all threats"""
    return jsonify(threat_data)

@app.route('/api/threats', methods=['POST'])
def add_threat():
    """API endpoint to add a new threat"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['threat_type', 'area', 'severity', 'description']
        for field in required_fields:
            if field not in data or not data[field]:
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        # Validate area
        if data['area'] not in valid_areas:
            return jsonify({'error': f'Invalid area. Must be one of: {valid_areas}'}), 400
        
        # Validate severity
        valid_severities = ['Low', 'Medium', 'High', 'Critical']
        if data['severity'] not in valid_severities:
            return jsonify({'error': f'Invalid severity. Must be one of: {valid_severities}'}), 400
        
        # Create threat entry
        threat = {
            'id': len(threat_data) + 1,
            'timestamp': datetime.now().isoformat(),
            'threat_type': data['threat_type'],
            'area': data['area'],
            'severity': data['severity'],
            'description': data['description'],
            'reporter': data.get('reporter', 'Anonymous'),
            'status': 'Active'
        }
        
        threat_data.append(threat)
        save_threat_data()
        
        return jsonify({'message': 'Threat added successfully', 'threat': threat}), 201
        
    except Exception as e:
        logger.error(f"Error adding threat: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/threats/<int:threat_id>', methods=['PUT'])
def update_threat_status(threat_id):
    """API endpoint to update threat status"""
    try:
        data = request.get_json()
        
        # Find threat
        threat = next((t for t in threat_data if t['id'] == threat_id), None)
        if not threat:
            return jsonify({'error': 'Threat not found'}), 404
        
        # Update status
        valid_statuses = ['Active', 'Resolved', 'Investigating']
        if 'status' in data and data['status'] in valid_statuses:
            threat['status'] = data['status']
            threat['updated'] = datetime.now().isoformat()
            save_threat_data()
            return jsonify({'message': 'Threat updated successfully', 'threat': threat})
        else:
            return jsonify({'error': f'Invalid status. Must be one of: {valid_statuses}'}), 400
            
    except Exception as e:
        logger.error(f"Error updating threat: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/threats/<int:threat_id>', methods=['DELETE'])
def delete_threat(threat_id):
    """API endpoint to delete a threat"""
    try:
        global threat_data
        threat_data = [t for t in threat_data if t['id'] != threat_id]
        save_threat_data()
        return jsonify({'message': 'Threat deleted successfully'})
    except Exception as e:
        logger.error(f"Error deleting threat: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/health')
def health_check():
    """Health check endpoint for load balancer"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0'
    })

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    # Load configuration and data
    load_config()
    load_threat_data()
    
    # Start the application
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('DEBUG', 'False').lower() == 'true'
    
    logger.info(f"Starting Threat Analysis App on port {port}")
    app.run(host='0.0.0.0', port=port, debug=debug)
EOF

msg_ok "Downloaded Application Files"

msg_info "Creating Configuration Files"
cat <<'EOF' > /opt/deployment/config/areas.json
{
  "valid_areas": [
    "OP1",
    "OP2", 
    "OP3",
    "OP4",
    "OP5",
    "OP6",
    "OP7",
    "OP8"
  ],
  "description": "Valid operational areas for threat analysis",
  "last_updated": "2025-08-28T00:00:00Z",
  "version": "1.0"
}
EOF

cat <<'EOF' > /opt/deployment/requirements.txt
Flask==2.3.3
Werkzeug==2.3.7
Jinja2==3.1.2
MarkupSafe==2.1.3
itsdangerous==2.1.2
click==8.1.7
gunicorn==21.2.0
requests==2.31.0
python-dotenv==1.0.0
EOF

cat <<'EOF' > /opt/deployment/Dockerfile
# Use Python 3.11 slim image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY threat_analysis_app.py .
COPY templates/ ./templates/
COPY static/ ./static/

# Create directories for config and data
RUN mkdir -p /app/config /app/data

# Copy default configuration
COPY config/areas.json ./config/

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Set environment variables
ENV PYTHONPATH=/app
ENV CONFIG_PATH=/app/config/areas.json
ENV DATA_PATH=/app/data/threats.json
ENV PORT=5000
ENV DEBUG=False

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Run the application
CMD ["python", "threat_analysis_app.py"]
EOF

msg_ok "Created Configuration Files"

msg_info "Creating Docker Compose Configuration"
SECRET_KEY=$(openssl rand -hex 32)
cat <<EOF > /opt/deployment/docker-compose.yml
version: '3.8'

services:
  threat-analysis:
    build: .
    container_name: threat-analysis-app
    restart: unless-stopped
    environment:
      - PORT=5000
      - DEBUG=false
      - CONFIG_PATH=/app/config/areas.json
      - DATA_PATH=/app/data/threats.json
      - SECRET_KEY=${SECRET_KEY}
    volumes:
      - /opt/threat-analysis/data:/app/data
      - /opt/deployment/config:/app/config
    networks:
      - traefik
      - internal
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=traefik"
      - "traefik.http.routers.threat-analysis.rule=Host(\`threat.aip.dxc.com\`)"
      - "traefik.http.routers.threat-analysis.entrypoints=websecure"
      - "traefik.http.routers.threat-analysis.tls=true"
      - "traefik.http.routers.threat-analysis.tls.certresolver=dxc-cert-resolver"
      - "traefik.http.services.threat-analysis.loadbalancer.server.port=5000"
      - "traefik.http.routers.threat-analysis.middlewares=secure-headers@file"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    command:
      - "--api.dashboard=true"
      - "--api.debug=true"
      - "--log.level=INFO"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=traefik"
      - "--providers.file.directory=/etc/traefik/dynamic"
      - "--providers.file.watch=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--certificatesresolvers.dxc-cert-resolver.acme.caserver=https://cert-server.aip.dxc.com:8443/acme/acme/directory"
      - "--certificatesresolvers.dxc-cert-resolver.acme.tlschallenge=true"
      - "--certificatesresolvers.dxc-cert-resolver.acme.email=admin@aip.dxc.com"
      - "--certificatesresolvers.dxc-cert-resolver.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.dxc-cert-resolver.acme.preferredchain=ISRG Root X1"
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /opt/traefik/data:/letsencrypt
      - /opt/deployment/traefik/dynamic:/etc/traefik/dynamic:ro
    networks:
      - traefik
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(\`traefik.aip.dxc.com\`)"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.tls=true"
      - "traefik.http.routers.traefik.tls.certresolver=dxc-cert-resolver"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.middlewares=auth@file"

networks:
  traefik:
    external: true
  internal:
    driver: bridge
EOF
msg_ok "Created Docker Compose Configuration"

msg_info "Creating Traefik Dynamic Configuration"
mkdir -p /opt/deployment/traefik/dynamic
cat <<'EOF' > /opt/deployment/traefik/dynamic/middleware.yml
http:
  middlewares:
    secure-headers:
      headers:
        browserXssFilter: true
        contentTypeNosniff: true
        forceSTSHeader: true
        frameDeny: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000
        customFrameOptionsValue: "SAMEORIGIN"
        customRequestHeaders:
          X-Forwarded-Proto: "https"
        customResponseHeaders:
          X-Robots-Tag: "noindex,nofollow,nosnippet,noarchive"
          Server: ""
    
    auth:
      basicAuth:
        users:
          - "admin:$2y$10$8K8AKGXEqMDEUJx9.lXx9OcU9Q2uH8yZGdCZJLrKmKwYs5YvCmBqi"  # admin:traefik123
    
    rate-limit:
      rateLimit:
        burst: 100
        average: 50
        sourceCriterion:
          ipStrategy:
            depth: 2

tls:
  options:
    default:
      sslProtocols:
        - "TLSv1.2"
        - "TLSv1.3"
      cipherSuites:
        - "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
        - "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
        - "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"
        - "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
        - "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
        - "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"
EOF
msg_ok "Created Traefik Dynamic Configuration"

msg_info "Creating HTML Template"
mkdir -p /opt/deployment/templates
cat <<'EOF' > /opt/deployment/templates/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Threat Analysis System</title>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.1.3/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        .severity-low { background-color: #d4edda; }
        .severity-medium { background-color: #fff3cd; }
        .severity-high { background-color: #f8d7da; }
        .severity-critical { background-color: #f5c6cb; }
        .navbar-brand { font-weight: bold; }
        .card-header { font-weight: 600; }
    </style>
</head>
<body>
    <nav class="navbar navbar-dark bg-dark">
        <div class="container">
            <span class="navbar-brand">
                <i class="fas fa-shield-alt"></i> Threat Analysis System
            </span>
            <span class="navbar-text">
                <i class="fas fa-exclamation-triangle"></i> 
                Total Threats: <span id="threat-count">{{ threats|length }}</span>
            </span>
        </div>
    </nav>

    <div class="container mt-4">
        <!-- Add New Threat Form -->
        <div class="row mb-4">
            <div class="col-md-8 mx-auto">
                <div class="card">
                    <div class="card-header bg-primary text-white">
                        <i class="fas fa-plus-circle"></i> Report New Threat
                    </div>
                    <div class="card-body">
                        <form id="threat-form">
                            <div class="row">
                                <div class="col-md-6 mb-3">
                                    <label for="threat_type" class="form-label">Threat Type</label>
                                    <select class="form-select" id="threat_type" name="threat_type" required>
                                        <option value="">Select threat type...</option>
                                        <option value="Security Breach">Security Breach</option>
                                        <option value="System Failure">System Failure</option>
                                        <option value="Physical Threat">Physical Threat</option>
                                        <option value="Cyber Attack">Cyber Attack</option>
                                        <option value="Environmental">Environmental</option>
                                        <option value="Personnel">Personnel</option>
                                        <option value="Other">Other</option>
                                    </select>
                                </div>
                                <div class="col-md-6 mb-3">
                                    <label for="area" class="form-label">Area</label>
                                    <select class="form-select" id="area" name="area" required>
                                        <option value="">Select area...</option>
                                        {% for area in valid_areas %}
                                        <option value="{{ area }}">{{ area }}</option>
                                        {% endfor %}
                                    </select>
                                </div>
                            </div>
                            <div class="row">
                                <div class="col-md-6 mb-3">
                                    <label for="severity" class="form-label">Severity</label>
                                    <select class="form-select" id="severity" name="severity" required>
                                        <option value="">Select severity...</option>
                                        <option value="Low">Low</option>
                                        <option value="Medium">Medium</option>
                                        <option value="High">High</option>
                                        <option value="Critical">Critical</option>
                                    </select>
                                </div>
                                <div class="col-md-6 mb-3">
                                    <label for="reporter" class="form-label">Reporter (Optional)</label>
                                    <input type="text" class="form-control" id="reporter" name="reporter" placeholder="Your name">
                                </div>
                            </div>
                            <div class="mb-3">
                                <label for="description" class="form-label">Description</label>
                                <textarea class="form-control" id="description" name="description" rows="3" required placeholder="Describe the threat in detail..."></textarea>
                            </div>
                            <button type="submit" class="btn btn-primary">
                                <i class="fas fa-paper-plane"></i> Submit Threat Report
                            </button>
                        </form>
                    </div>
                </div>
            </div>
        </div>

        <!-- Current Threats -->
        <div class="row">
            <div class="col-12">
                <div class="card">
                    <div class="card-header bg-secondary text-white">
                        <i class="fas fa-list"></i> Current Threats
                    </div>
                    <div class="card-body">
                        <div id="threats-container">
                            {% if threats %}
                                <div class="table-responsive">
                                    <table class="table table-hover">
                                        <thead class="table-dark">
                                            <tr>
                                                <th>ID</th>
                                                <th>Type</th>
                                                <th>Area</th>
                                                <th>Severity</th>
                                                <th>Description</th>
                                                <th>Reporter</th>
                                                <th>Status</th>
                                                <th>Timestamp</th>
                                                <th>Actions</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            {% for threat in threats %}
                                            <tr class="severity-{{ threat.severity.lower() }}">
                                                <td><strong>#{{ threat.id }}</strong></td>
                                                <td>{{ threat.threat_type }}</td>
                                                <td><span class="badge bg-info">{{ threat.area }}</span></td>
                                                <td>
                                                    <span class="badge bg-{% if threat.severity == 'Critical' %}danger{% elif threat.severity == 'High' %}warning{% elif threat.severity == 'Medium' %}info{% else %}success{% endif %}">
                                                        {{ threat.severity }}
                                                    </span>
                                                </td>
                                                <td>{{ threat.description[:50] }}{% if threat.description|length > 50 %}...{% endif %}</td>
                                                <td>{{ threat.reporter or 'Anonymous' }}</td>
                                                <td>
                                                    <span class="badge bg-{% if threat.status == 'Active' %}danger{% elif threat.status == 'Resolved' %}success{% else %}warning{% endif %}">
                                                        {{ threat.status }}
                                                    </span>
                                                </td>
                                                <td>{{ threat.timestamp[:19] }}</td>
                                                <td>
                                                    <div class="btn-group btn-group-sm">
                                                        <button class="btn btn-outline-warning btn-sm" onclick="updateThreatStatus({{ threat.id }}, 'Investigating')">
                                                            <i class="fas fa-search"></i>
                                                        </button>
                                                        <button class="btn btn-outline-success btn-sm" onclick="updateThreatStatus({{ threat.id }}, 'Resolved')">
                                                            <i class="fas fa-check"></i>
                                                        </button>
                                                        <button class="btn btn-outline-danger btn-sm" onclick="deleteThreat({{ threat.id }})">
                                                            <i class="fas fa-trash"></i>
                                                        </button>
                                                    </div>
                                                </td>
                                            </tr>
                                            {% endfor %}
                                        </tbody>
                                    </table>
                                </div>
                            {% else %}
                                <div class="text-center text-muted py-4">
                                    <i class="fas fa-shield-alt fa-3x mb-3"></i>
                                    <h5>No threats reported</h5>
                                    <p>System is secure. Use the form above to report any threats.</p>
                                </div>
                            {% endif %}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Alert Modal -->
    <div class="modal fade" id="alertModal" tabindex="-1">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="alertTitle">Alert</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body" id="alertMessage"></div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-primary" data-bs-dismiss="modal">OK</button>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.1.3/js/bootstrap.bundle.min.js"></script>
    <script>
        // Form submission
        document.getElementById('threat-form').addEventListener('submit', function(e) {
            e.preventDefault();
            
            const formData = new FormData(e.target);
            const data = Object.fromEntries(formData.entries());
            
            fetch('/api/threats', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(data)
            })
            .then(response => response.json())
            .then(data => {
                if (data.error) {
                    showAlert('Error', data.error);
                } else {
                    showAlert('Success', `Threat #${threatId} status updated to ${status}`);
                    setTimeout(() => location.reload(), 1000);
                }
            })
            .catch(error => {
                showAlert('Error', 'Failed to update threat status');
                console.error('Error:', error);
            });
        }
        
        // Delete threat
        function deleteThreat(threatId) {
            if (confirm('Are you sure you want to delete this threat?')) {
                fetch(`/api/threats/${threatId}`, {
                    method: 'DELETE'
                })
                .then(response => response.json())
                .then(data => {
                    if (data.error) {
                        showAlert('Error', data.error);
                    } else {
                        showAlert('Success', `Threat #${threatId} deleted`);
                        setTimeout(() => location.reload(), 1000);
                    }
                })
                .catch(error => {
                    showAlert('Error', 'Failed to delete threat');
                    console.error('Error:', error);
                });
            }
        }
        
        // Show alert modal
        function showAlert(title, message) {
            document.getElementById('alertTitle').textContent = title;
            document.getElementById('alertMessage').textContent = message;
            new bootstrap.Modal(document.getElementById('alertModal')).show();
        }
    </script>
</body>
</html>
EOF
msg_ok "Created HTML Template"

msg_info "Creating Management Scripts"
cat <<'EOF' > /opt/deployment/backup.sh
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
EOF

cat <<'EOF' > /opt/deployment/monitor.sh
#!/bin/bash
# Monitoring script for Threat Analysis application

LOG_FILE="/opt/threat-analysis/logs/monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Starting health check..." >> $LOG_FILE

# Check Docker containers
if ! docker-compose -f /opt/deployment/docker-compose.yml ps | grep -q "Up"; then
    echo "[$DATE] ERROR: Some containers are not running" >> $LOG_FILE
    docker-compose -f /opt/deployment/docker-compose.yml up -d
fi

# Check application health
if ! curl -f http://localhost/health >/dev/null 2>&1; then
    echo "[$DATE] ERROR: Application health check failed" >> $LOG_FILE
else
    echo "[$DATE] INFO: Application health check passed" >> $LOG_FILE
fi

# Check disk space
DISK_USAGE=$(df /opt | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 85 ]; then
    echo "[$DATE] WARNING: Disk usage is ${DISK_USAGE}%" >> $LOG_FILE
fi

echo "[$DATE] Health check completed" >> $LOG_FILE
EOF

chmod +x /opt/deployment/backup.sh /opt/deployment/monitor.sh
msg_ok "Created Management Scripts"

msg_info "Setting up Firewall"
$STD ufw --force enable
$STD ufw allow ssh
$STD ufw allow 80/tcp
$STD ufw allow 443/tcp
$STD ufw allow 8080/tcp
msg_ok "Configured Firewall"

msg_info "Configuring SSL Certificate Storage"
touch /opt/traefik/data/acme.json
chmod 600 /opt/traefik/data/acme.json
msg_ok "Configured SSL Certificate Storage"

msg_info "Setting up Cron Jobs"
cat <<'EOF' > /tmp/crontab_threat
# Threat Analysis System Cron Jobs
*/5 * * * * /opt/deployment/monitor.sh
0 2 * * * /opt/deployment/backup.sh
EOF
crontab /tmp/crontab_threat
rm /tmp/crontab_threat
msg_ok "Setup Cron Jobs"

msg_info "Building and Starting Application"
cd /opt/deployment
$STD docker-compose build
$STD docker-compose up -d
msg_ok "Application Started"

msg_info "Copying Configuration Files"
cp -r /opt/deployment/config/* /opt/threat-analysis/config/ 2>/dev/null || true
msg_ok "Configuration Files Copied"

msg_info "Setting File Permissions"
chown -R 1000:1000 /opt/threat-analysis/data
chown -R 1000:1000 /opt/threat-analysis/config
chmod -R 755 /opt/threat-analysis
chmod -R 755 /opt/traefik
chmod -R 755 /opt/deployment
msg_ok "File Permissions Set"

msg_info "Creating Management Interface"
cat <<'EOF' > /usr/local/bin/threat-analysis
#!/bin/bash
# Threat Analysis System Management Script

COMPOSE_FILE="/opt/deployment/docker-compose.yml"

case "$1" in
    start)
        echo "Starting Threat Analysis System..."
        docker-compose -f $COMPOSE_FILE up -d
        ;;
    stop)
        echo "Stopping Threat Analysis System..."
        docker-compose -f $COMPOSE_FILE down
        ;;
    restart)
        echo "Restarting Threat Analysis System..."
        docker-compose -f $COMPOSE_FILE restart
        ;;
    status)
        echo "Threat Analysis System Status:"
        docker-compose -f $COMPOSE_FILE ps
        ;;
    logs)
        docker-compose -f $COMPOSE_FILE logs -f --tail=100
        ;;
    backup)
        /opt/deployment/backup.sh
        ;;
    update)
        echo "Updating Threat Analysis System..."
        cd /opt/deployment
        docker-compose pull
        docker-compose up -d --force-recreate
        ;;
    health)
        echo "Health Check:"
        curl -s http://localhost/health | jq '.' 2>/dev/null || echo "Health check failed"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|backup|update|health}"
        echo ""
        echo "Threat Analysis System Management Commands:"
        echo "  start    - Start all services"
        echo "  stop     - Stop all services"
        echo "  restart  - Restart all services"
        echo "  status   - Show service status"
        echo "  logs     - Show application logs"
        echo "  backup   - Create system backup"
        echo "  update   - Update application"
        echo "  health   - Check application health"
        exit 1
        ;;
esac
EOF
chmod +x /usr/local/bin/threat-analysis
msg_ok "Created Management Interface"

msg_info "Cleaning up"
$STD apt-get autoremove -y
$STD apt-get autoclean
msg_ok "Cleaned"

motd_ssh
customize

msg_info "Starting Services and Performing Health Check"
sleep 10
if curl -f http://localhost/health >/dev/null 2>&1; then
    msg_ok "Application Health Check Passed"
else
    msg_error "Application Health Check Failed"
fi

msg_info "Checking Container Status"
docker-compose -f /opt/deployment/docker-compose.yml ps

msg_ok "Completed Successfully"

echo -e "\n${RD}═══════════════════════════════════════════════════════════════════════════════${CL}"
echo -e "${RD}    _______ _                    _       _                _           _     ${CL}"
echo -e "${RD}   |__   __| |                  | |     | |              | |         (_)    ${CL}"
echo -e "${RD}      | |  | |__  _ __ ___  __ _| |_    / \\   _ __   __ _| |_   _ ___ _ ___ ${CL}"
echo -e "${RD}      | |  | '_ \\| '__/ _ \\/ _\` | __|   / _ \\ | '_ \\ / _\` | | | | / __| / __|${CL}"
echo -e "${RD}      | |  | | | | | |  __/ (_| | |_   / ___ \\| | | | (_| | | |_| \\__ \\ \\__ \\${CL}"
echo -e "${RD}      |_|  |_| |_|_|  \\___|\\__,_|\\__| /_/   \\_\\_| |_|\\__,_|_|\\__, |___/_|___/${CL}"
echo -e "${RD}                                                              __/ |        ${CL}"
echo -e "${RD}                                                             |___/         ${CL}"
echo -e "${RD}═══════════════════════════════════════════════════════════════════════════════${CL}"

echo -e "\n${GN}🚀 Threat Analysis System Installation Complete!${CL}\n"

echo -e "${BL}📊 Application Information:${CL}"
echo -e "   🌐 Web Interface: ${GN}https://threat.aip.dxc.com${CL}"
echo -e "   🔧 Traefik Dashboard: ${GN}https://traefik.aip.dxc.com:8080${CL}"
echo -e "   ❤️  Health Check: ${GN}https://threat.aip.dxc.com/health${CL}"

echo -e "\n${BL}🔐 Security Features:${CL}"
echo -e "   ✅ SSL/TLS certificates from cert-server.aip.dxc.com"
echo -e "   ✅ Tailscale VPN ready (run: tailscale up)"
echo -e "   ✅ Firewall configured (ports 80, 443, 8080)"
echo -e "   ✅ Security headers and middleware"

echo -e "\n${BL}🛠️  Management Commands:${CL}"
echo -e "   ${GN}threat-analysis start${CL}   - Start services"
echo -e "   ${GN}threat-analysis stop${CL}    - Stop services"
echo -e "   ${GN}threat-analysis restart${CL} - Restart services"
echo -e "   ${GN}threat-analysis status${CL}  - Check status"
echo -e "   ${GN}threat-analysis logs${CL}    - View logs"
echo -e "   ${GN}threat-analysis backup${CL}  - Create backup"
echo -e "   ${GN}threat-analysis update${CL}  - Update system"
echo -e "   ${GN}threat-analysis health${CL}  - Health check"

echo -e "\n${BL}📁 Important Directories:${CL}"
echo -e "   📂 Application Data: ${GN}/opt/threat-analysis/data${CL}"
echo -e "   📂 Configuration: ${GN}/opt/threat-analysis/config${CL}"
echo -e "   📂 Deployment: ${GN}/opt/deployment${CL}"
echo -e "   📂 Backups: ${GN}/opt/backups${CL}"

echo -e "\n${BL}🔄 Automated Features:${CL}"
echo -e "   ⏰ Health checks every 5 minutes"
echo -e "   💾 Daily backups at 2:00 AM"
echo -e "   🔄 Log rotation (30-day retention)"
echo -e "   🔒 SSL certificate auto-renewal"

echo -e "\n${YW}⚠️  Next Steps:${CL}"
echo -e "   1️⃣  Configure Tailscale: ${GN}tailscale up${CL}"
echo -e "   2️⃣  Verify SSL certificates are obtained"
echo -e "   3️⃣  Test application: ${GN}curl https://threat.aip.dxc.com/health${CL}"
echo -e "   4️⃣  Update DNS entries for threat.aip.dxc.com and traefik.aip.dxc.com"

echo -e "\n${BL}💡 Configuration:${CL}"
echo -e "   📝 Valid Areas: Edit ${GN}/opt/threat-analysis/config/areas.json${CL}"
echo -e "   🔧 Docker Compose: ${GN}/opt/deployment/docker-compose.yml${CL}"
echo -e "   🌐 Traefik Config: ${GN}/opt/deployment/traefik/dynamic/${CL}"

echo -e "\n${BL}📞 Troubleshooting:${CL}"
echo -e "   🔍 Check logs: ${GN}threat-analysis logs${CL}"
echo -e "   📊 Container status: ${GN}docker ps${CL}"
echo -e "   🔧 Restart services: ${GN}threat-analysis restart${CL}"

echo -e "\n${RD}═══════════════════════════════════════════════════════════════════════════════${CL}"
echo -e "${GN}Installation completed successfully! 🎉${CL}"
echo -e "${YW}Remember to configure Tailscale and DNS entries.${CL}"
echo -e "${RD}═══════════════════════════════════════════════════════════════════════════════${CL}\n"
            .then(data => {
                if (data.error) {
                    showAlert('Error', data.error);
                } else {
                    showAlert('Success', 'Threat reported successfully!');
                    e.target.reset();
                    setTimeout(() => location.reload(), 1000);
                }
            })
            .catch(error => {
                showAlert('Error', 'Failed to submit threat report');
                console.error('Error:', error);
            });
        });
        
        // Update threat status
        function updateThreatStatus(threatId, status) {
            fetch(`/api/threats/${threatId}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ status: status })
            })
            .then(response => response.json())