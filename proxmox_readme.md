# Proxmox Threat Analysis System Deployment

This solution provides a complete Proxmox-style deployment for the Threat Analysis System, designed to work like the popular Proxmox Community Helper Scripts.

## 📋 Overview

**Target Environment**: Proxmox VE Host  
**Container Type**: LXC (Linux Container)  
**IP Address**: 192.169.0.201/24  
**Domain**: threat.aip.dxc.com  
**SSL**: cert-server.aip.dxc.com (192.168.0.22)  

## 🚀 Quick Deployment

### Method 1: Direct Download and Execute (Recommended)
```bash
# On your Proxmox host, run as root:
bash -c "$(wget -qLO - https://raw.githubusercontent.com/DXCSithlordPadawan/SolrSim/main/create_threat_analysis_ct.sh)"
```

### Method 2: Download and Run Manually
```bash
# Download the container creation script
wget https://raw.githubusercontent.com/DXCSithlordPadawan/SolrSim/main/create_threat_analysis_ct.sh

# Make executable
chmod +x create_threat_analysis_ct.sh

# Run the script
./create_threat_analysis_ct.sh
```

### Method 3: Clone Repository
```bash
git clone https://github.com/DXCSithlordPadawan/SolrSim.git
cd SolrSim
chmod +x create_threat_analysis_ct.sh threat-analysis-management.sh
./create_threat_analysis_ct.sh
```

## 🎛️ Interactive Interface

The deployment script provides a Proxmox Community Helper Scripts-style interface:

### Container Configuration Options
- **Container Type**: Unprivileged (recommended) or Privileged
- **Container ID**: Auto-assigned or custom
- **Hostname**: threat-analysis (customizable)
- **Resources**: 2 vCPU, 4GB RAM, 20GB Disk (adjustable)
- **Network**: Static IP 192.169.0.201/24
- **Bridge**: vmbr0 (customizable)

### Default Settings
```
Container Type: Unprivileged
Password: Automatic Login (no password)
Container ID: Next available ID
Hostname: threat-analysis
Disk Size: 20GB
CPU Cores: 2
RAM: 4096MB
IP Address: 192.169.0.201/24
Gateway: 192.169.0.1
Bridge: vmbr0
```

## 📁 File Structure

### Deployment Scripts
```
create_threat_analysis_ct.sh     # Main container creation script
threat-analysis-install.sh       # Application installation script  
threat-analysis-management.sh    # Container management interface
```

### Inside Container (`/opt/`)
```
/opt/threat-analysis/
├── config/
│   └── areas.json              # Valid areas configuration
├── data/
│   └── threats.json           # Persistent threat data
└── logs/                      # Application logs

/opt/deployment/
├── docker-compose.yml         # Service orchestration
├── Dockerfile                 # Container definition
├── threat_analysis_app.py     # Modified application
├── requirements.txt           # Python dependencies
├── templates/
│   └── index.html            # Web interface
└── traefik/
    └── dynamic/
        └── middleware.yml     # Traefik configuration

/opt/traefik/
├── data/
│   └── acme.json             # SSL certificates
└── logs/                     # Traefik logs
```

## 🛠️ Management Interface

After creation, use the management script:

```bash
# Run the management interface
./threat-analysis-management.sh

# Or with specific actions
./threat-analysis-management.sh --create    # Create new container
./threat-analysis-management.sh --find      # Find existing container
```

### Management Menu Options

**Container Operations:**
- Start/Stop/Restart container
- View container status and logs
- Enter container shell

**Application Management:**
- Test connectivity and health
- Manage SSL certificates
- Real-time system monitoring
- Configuration management
- Performance tuning

**Backup & Maintenance:**
- Create/restore backups
- Update system and applications
- Clean up resources

**Advanced Operations:**
- Recreate container from scratch
- Export container as template
- View detailed statistics

## 🔧 Container Management Commands

### Proxmox Host Commands
```bash
# Container lifecycle
pct start <CTID>              # Start container
pct stop <CTID>               # Stop container
pct restart <CTID>            # Restart container
pct enter <CTID>              # Enter container

# Container information
pct list                      # List all containers
pct status <CTID>            # Container status
pct config <CTID>            # Container configuration

# Management script
./threat-analysis-management.sh  # Interactive management
```

### Inside Container Commands
```bash
# Application management
threat-analysis start         # Start services
threat-analysis stop          # Stop services
threat-analysis restart       # Restart services
threat-analysis status        # Check status
threat-analysis logs          # View logs
threat-analysis backup        # Create backup
threat-analysis update        # Update application
threat-analysis health        # Health check

# Docker management
docker ps                     # List containers
docker-compose -f /opt/deployment/docker-compose.yml logs -f
```

## 🌐 Network Configuration

### Static IP Configuration
- **IP Address**: 192.169.0.201/24
- **Gateway**: 192.169.0.1
- **DNS**: 8.8.8.8 (primary)
- **Search Domain**: aip.dxc.com

### Firewall Rules (UFW)
```bash
# Automatically configured ports:
80/tcp    # HTTP (redirects to HTTPS)
443/tcp   # HTTPS
8080/tcp  # Traefik dashboard
22/tcp    # SSH (if enabled)
```

### Tailscale Integration
```bash
# Inside container, authenticate Tailscale:
tailscale up

# Check status:
tailscale status
```

## 🔐 Security Features

### SSL/TLS Configuration
- **Certificate Authority**: cert-server.aip.dxc.com:8443
- **Automatic Renewal**: Yes
- **Protocols**: TLS 1.2, TLS 1.3
- **HSTS**: Enabled
- **Security Headers**: Full suite

### Container Security
- **Unprivileged**: Default (recommended)
- **AppArmor**: Enabled
- **User Namespace**: Isolated
- **Root Access**: Disabled by default

### Application Security
- **Non-root execution**: Yes
- **Input validation**: Complete
- **Rate limiting**: Configured
- **CSRF protection**: Enabled

## 📊 Monitoring & Logging

### Automated Monitoring
```bash
# Health checks every 5 minutes
*/5 * * * * /opt/deployment/monitor.sh

# Daily backups at 2:00 AM
0 2 * * * /opt/deployment/backup.sh
```

### Log Management
- **Application logs**: `/opt/threat-analysis/logs/`
- **Container logs**: `journalctl`
- **Docker logs**: `docker-compose logs`
- **Traefik logs**: `/opt/traefik/logs/`
- **Rotation**: Daily, 30-day retention

### Health Monitoring
```bash
# Health check endpoints:
curl http://localhost/health           # Local check
curl https://threat.aip.dxc.com/health # External check

# Container health:
pct status <CTID>

# Service health:
threat-analysis health
```

## 🔄 Backup & Recovery

### Backup Strategy
1. **Container Backup**: Full Proxmox vzdump backup
2. **Application Data**: JSON files and configurations  
3. **SSL Certificates**: Traefik ACME data
4. **Frequency**: Daily automated, on-demand manual

### Backup Commands
```bash
# Proxmox container backup
vzdump <CTID> --compress gzip --storage local

# Application data backup (inside container)
threat-analysis backup

# Manual backup with management script
./threat-analysis-management.sh  # Option 12
```

### Recovery Process
```bash
# Restore container from backup
pct restore <CTID> /var/lib/vz/dump/backup-file.tar.gz

# Restore application data (inside container)
cd /opt/backups
tar -xzf threat-analysis_YYYYMMDD_HHMMSS.tar.gz
cp -r threat-analysis_*/* /opt/
docker-compose -f /opt/deployment/docker-compose.yml restart
```

## 🔧 Customization

### Modify Valid Areas
```bash
# Enter container
pct enter <CTID>

# Edit configuration
nano /opt/threat-analysis/config/areas.json

# Restart application
threat-analysis restart
```

### Resource Scaling
```bash
# Adjust container resources (on Proxmox host)
pct set <CTID> -memory 8192        # 8GB RAM
pct set <CTID> -cores 4             # 4 CPU cores
pct restart <CTID>

# Scale application containers (inside container)
docker-compose -f /opt/deployment/docker-compose.yml up -d --scale threat-analysis=3
```

### Custom Domains
```bash
# Edit Docker Compose file
nano /opt/deployment/docker-compose.yml

# Update Traefik labels:
traefik.http.routers.threat-analysis.rule=Host(`your-domain.com`)

# Restart services
threat-analysis restart
```

## 🆘 Troubleshooting

### Common Issues

#### Container Won't Start
```bash
# Check container status
pct status <CTID>

# Check container logs
pct exec <CTID> -- journalctl -f

# Check Proxmox host logs
tail -f /var/log/pve/lxc/<CTID>.log
```

#### Application Not Accessible
```bash
# Check service status
pct exec <CTID> -- threat-analysis status

# Check container network
pct exec <CTID> -- ip addr show

# Test local connectivity
pct exec <CTID> -- curl http://localhost/health

# Check firewall
pct exec <CTID> -- ufw status
```

#### SSL Certificate Issues
```bash
# Check certificate status
pct exec <CTID> -- docker-compose -f /opt/deployment/docker-compose.yml logs traefik

# Force certificate renewal
pct exec <CTID> -- docker-compose -f /opt/deployment/docker-compose.yml restart traefik

# Reset certificates
pct exec <CTID> -- rm /opt/traefik/data/acme.json
pct exec <CTID> -- threat-analysis restart
```

#### Tailscale Connection Issues
```bash
# Check Tailscale status
pct exec <CTID> -- tailscale status

# Re-authenticate
pct exec <CTID> -- tailscale up --reset

# Check network configuration
pct exec <CTID> -- ip route show
```

### Diagnostic Commands
```bash
# System resources
pct exec <CTID> -- df -h
pct exec <CTID> -- free -h
pct exec <CTID> -- top

# Network diagnosis
pct exec <CTID> -- ss -tlnp
pct exec <CTID> -- netstat -rn
pct exec <CTID> -- nslookup threat.aip.dxc.com

# Application diagnosis
pct exec <CTID> -- docker ps
pct exec <CTID> -- docker-compose -f /opt/deployment/docker-compose.yml ps
```

## 📞 Support & Maintenance

### Regular Maintenance Tasks
1. **Weekly**: Check application logs and health
2. **Monthly**: Update container OS and applications
3. **Quarterly**: Review and test backup procedures
4. **Annually**: Review security configurations

### Support Resources
- **Documentation**: This README and inline help
- **Management Interface**: `./threat-analysis-management.sh`
- **Health Checks**: Built-in monitoring and alerting
- **Backup System**: Automated daily backups

### Version Updates
```bash
# Update management scripts
wget -O threat-analysis-management.sh \
  https://raw.githubusercontent.com/DXCSithlordPadawan/SolrSim/main/threat-analysis-management.sh

# Update container
./threat-analysis-management.sh  # Option 14
```

---

## 🎯 Summary

This Proxmox deployment solution provides:

✅ **Proxmox Community Helper Scripts interface**  
✅ **One-command deployment**  
✅ **Complete container lifecycle management**  
✅ **Automated SSL certificate management**  
✅ **Tailscale VPN integration**  
✅ **Comprehensive monitoring and backup**  
✅ **Interactive management interface**  
✅ **Production-ready security**  

The solution follows Proxmox best practices and provides enterprise-grade deployment with minimal manual intervention.