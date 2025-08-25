# SolrSim LXC Container Setup Guide for Proxmox

This guide will help you create an LXC container on Proxmox and deploy the SolrSim threat analysis application as a system service.

## Prerequisites

- Proxmox VE server with LXC support
- Access to Proxmox web interface or SSH access
- Basic understanding of Linux containers and systemd services

## Step 1: Create LXC Container

### Using Proxmox Web Interface

1. **Create Container**:
   - Navigate to your Proxmox node → Create CT
   - **General**: 
     - CT ID: Choose available ID (e.g., 170)
     - Hostname: `solrsim-app`
     - Resource Pool: (optional)
   - **Template**:
     - Storage: local
     - Template: `ubuntu-22.04-standard` (recommended)
   - **Root Disk**:
     - Disk size: 8 GB (minimum)
     - Storage: local-lvm
   - **CPU**:
     - Cores: 2
   - **Memory**:
     - Memory: 1024 MB
     - Swap: 512 MB
   - **Network**:
     - Bridge: vmbr0
     - IPv4: DHCP (or static if preferred)
   - **DNS**:
     - Use host settings: Yes

2. **Start the Container**:
   ```bash
   pct start 170
   ```

### Using CLI (Alternative)

```bash
# Download Ubuntu template if not available
pveam update
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst

# Create container
pct create 100 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname solrsim-app \
  --memory 1024 \
  --swap 512 \
  --cores 2 \
  --rootfs local-lvm:8 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --nameserver 8.8.8.8 \
  --features nesting=1

# Start container
pct start 100
```

## Step 2: Container Initial Setup

### Enter the Container

```bash
# From Proxmox host
pct enter 170

# Or via console in web interface
```

### Update System and Install Dependencies

```bash
# Update package lists
apt update && apt upgrade -y

# Install required packages
apt install -y python3 python3-pip python3-venv git curl systemd

# Install additional tools
apt install -y nano htop net-tools
```

## Step 3: Deploy SolrSim Application

### Clone Repository and Setup

```bash
# Create application directory
mkdir -p /opt/solrsim
cd /opt/solrsim

# Clone the repository
git clone https://github.com/DXCSithlordPadawan/SolrSim.git .

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Flask and dependencies
pip install Flask

# Create requirements.txt if not present
cat > requirements.txt << EOF
Flask==2.3.3
Werkzeug==2.3.7
Jinja2==3.1.2
MarkupSafe==2.1.3
itsdangerous==2.1.2
click==8.1.7
blinker==1.6.2
EOF

# Install from requirements
pip install -r requirements.txt

# Make sure the app file has proper permissions
chmod +x threat_analysis_app.py
```

### Create Application User

```bash
# Create dedicated user for the service
useradd --system --create-home --shell /bin/bash solrsim

# Change ownership of application directory
chown -R solrsim:solrsim /opt/solrsim

# Set proper permissions
chmod -R 755 /opt/solrsim
```

## Step 4: Create Systemd Service

### Create Service Configuration

```bash
# Create systemd service file
cat > /etc/systemd/system/solrsim.service << 'EOF'
[Unit]
Description=SolrSim Threat Analysis Application
After=network.target
Wants=network.target

[Service]
Type=simple
User=solrsim
Group=solrsim
WorkingDirectory=/opt/solrsim
Environment=PATH=/opt/solrsim/venv/bin
Environment=FLASK_APP=threat_analysis_app.py
Environment=FLASK_ENV=production
ExecStart=/opt/solrsim/venv/bin/python threat_analysis_app.py
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=solrsim

# Security settings
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/opt/solrsim
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes

[Install]
WantedBy=multi-user.target
EOF
```

### Configure Application for Production

```bash
# Create a production configuration file
cat > /opt/solrsim/config.py << 'EOF'
import os

class Config:
    # Flask configuration
    HOST = '0.0.0.0'
    PORT = int(os.environ.get('FLASK_PORT', 5000))
    DEBUG = False
    
    # Security
    SECRET_KEY = os.environ.get('SECRET_KEY', 'change-this-in-production')
    
    # Application settings
    DATA_FILE = os.path.join(os.path.dirname(__file__), 'data', 'productissues.json')
EOF

# Ensure data directory exists
mkdir -p /opt/solrsim/data

# Update ownership after creating config
chown -R solrsim:solrsim /opt/solrsim
```

### Modify the Application for Service Mode

Create a wrapper script to ensure the app runs properly as a service:

```bash
cat > /opt/solrsim/run_app.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from threat_analysis_app import app
from config import Config

if __name__ == '__main__':
    app.run(
        host=Config.HOST,
        port=Config.PORT,
        debug=Config.DEBUG
    )
EOF

chmod +x /opt/solrsim/run_app.py
chown solrsim:solrsim /opt/solrsim/run_app.py
```

### Update Service File to Use Wrapper

```bash
# Update the service file
cat > /etc/systemd/system/solrsim.service << 'EOF'
[Unit]
Description=SolrSim Threat Analysis Application
After=network.target
Wants=network.target

[Service]
Type=simple
User=solrsim
Group=solrsim
WorkingDirectory=/opt/solrsim
Environment=PATH=/opt/solrsim/venv/bin
Environment=PYTHONPATH=/opt/solrsim
ExecStart=/opt/solrsim/venv/bin/python run_app.py
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=solrsim

# Security settings
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/opt/solrsim
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes

[Install]
WantedBy=multi-user.target
EOF
```

## Step 5: Enable and Start the Service

```bash
# Reload systemd configuration
systemctl daemon-reload

# Enable service to start at boot
systemctl enable solrsim.service

# Start the service
systemctl start solrsim.service

# Check service status
systemctl status solrsim.service

# View logs
journalctl -u solrsim.service -f
```

## Step 6: Configure Networking and Firewall

### Open Firewall Port (if UFW is enabled)

```bash
# Check if UFW is active
ufw status

# If UFW is active, allow the Flask port
ufw allow 5000/tcp

# Or allow from specific networks only
# ufw allow from 192.168.1.0/24 to any port 5000
```

### Configure Proxmox Firewall (Optional)

1. In Proxmox web interface, go to: Datacenter → Firewall → Add
2. Create rule to allow port 5000:
   - Direction: `in`
   - Action: `ACCEPT`
   - Protocol: `tcp`
   - Dest. port: `5000`

## Step 7: Access and Test the Application

### Find Container IP Address

```bash
# From within container
ip addr show eth0

# From Proxmox host
pct exec 100 -- ip addr show eth0
```

### Test the Application

```bash
# Test from within container
curl http://localhost:5000

# Test from Proxmox host (replace IP)
curl http://[CONTAINER_IP]:5000

# Test from browser
http://[CONTAINER_IP]:5000
```

## Step 8: Additional Configuration

### Configure Reverse Proxy (Optional)

If you want to use a reverse proxy like Nginx:

```bash
# Install Nginx
apt install -y nginx

# Create site configuration
cat > /etc/nginx/sites-available/solrsim << 'EOF'
server {
    listen 80;
    server_name solrsim.local;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Enable site
ln -s /etc/nginx/sites-available/solrsim /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

# Test and restart Nginx
nginx -t
systemctl restart nginx
systemctl enable nginx
```

### Configure SSL (Optional)

```bash
# Install Certbot
apt install -y certbot python3-certbot-nginx

# Get SSL certificate (replace with your domain)
# certbot --nginx -d your-domain.com
```

## Monitoring and Maintenance

### Service Management Commands

```bash
# Check service status
systemctl status solrsim.service

# Stop service
systemctl stop solrsim.service

# Start service
systemctl start solrsim.service

# Restart service
systemctl restart solrsim.service

# View logs
journalctl -u solrsim.service -n 50

# Follow logs in real-time
journalctl -u solrsim.service -f
```

### Container Management from Proxmox Host

```bash
# Stop container
pct stop 170

# Start container
pct start 170

# Restart container
pct reboot 170

# Enter container
pct enter 170

# View container status
pct list
```

### Backup and Restore

```bash
# Create backup from Proxmox host
vzdump 170 --storage local

# Restore from backup
# Use Proxmox web interface: Restore → select backup file
```

## Troubleshooting

### Common Issues

1. **Service won't start**:
   ```bash
   # Check logs
   journalctl -u solrsim.service -n 50
   
   # Check file permissions
   ls -la /opt/solrsim/
   
   # Verify Python environment
   sudo -u solrsim /opt/solrsim/venv/bin/python -c "import flask; print('Flask OK')"
   ```

2. **Port already in use**:
   ```bash
   # Check what's using port 5000
   netstat -tulpn | grep :5000
   
   # Change port in config.py or stop conflicting service
   ```

3. **Permission errors**:
   ```bash
   # Fix ownership
   chown -R solrsim:solrsim /opt/solrsim
   
   # Fix permissions
   chmod -R 755 /opt/solrsim
   chmod +x /opt/solrsim/run_app.py
   ```

4. **Network connectivity issues**:
   ```bash
   # Check container network
   ip addr show
   
   # Test connectivity
   ping 8.8.8.8
   
   # Check firewall rules
   ufw status
   ```

## Security Considerations

1. **Change default secrets**: Update the SECRET_KEY in config.py
2. **Limit network access**: Configure firewall rules to restrict access
3. **Regular updates**: Keep the system and Python packages updated
4. **Monitor logs**: Regularly check application and system logs
5. **Backup regularly**: Create automated backups of the container

## Performance Optimization

1. **Resource allocation**: Adjust CPU cores and memory based on usage
2. **Python optimization**: Use production WSGI server like Gunicorn
3. **Caching**: Implement application-level caching if needed
4. **Database**: Consider moving to a proper database for large datasets

This setup provides a robust, production-ready deployment of your SolrSim application in an LXC container with proper service management and security configurations.
