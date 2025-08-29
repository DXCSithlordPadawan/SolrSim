# Threat Analysis System - Deployment Guide

A comprehensive containerized threat analysis web application with Traefik reverse proxy, SSL certificates, and Tailscale integration.

## 🚀 Quick Start

```bash
# Deploy the complete system
make deploy

# Check status
make status

# View logs
make logs
```

## 📋 Prerequisites

- SSH access to target server (192.169.0.201)
- Docker and Docker Compose installed locally
- Tailscale account (for secure access)
- Access to cert-server.aip.dxc.com (192.168.0.22)

## 🏗️ Architecture

```
Internet → Tailscale → Traefik (443/80) → Threat Analysis App (5000)
                   ↓
            cert-server.aip.dxc.com (SSL Certs)
```

## 🔧 Configuration Files

### Modified Application (`threat_analysis_app.py`)
- External JSON configuration for valid areas
- RESTful API endpoints
- Health check endpoint
- Persistent data storage

### External Configuration (`config/areas.json`)
```json
{
  "valid_areas": ["OP1", "OP2", "OP3", "OP4", "OP5", "OP6", "OP7", "OP8"],
  "description": "Valid operational areas for threat analysis",
  "version": "1.0"
}
```

### Docker Configuration
- **Dockerfile**: Multi-stage build with security best practices
- **docker-compose.yml**: Complete service orchestration
- **requirements.txt**: Python dependencies

### Traefik Configuration
- **Reverse proxy** with automatic HTTPS
- **SSL certificates** from cert-server.aip.dxc.com
- **Security headers** and middleware
- **Dashboard** access at traefik.aip.dxc.com:8080

## 🚀 Deployment Process

### Automated Deployment
```bash
# Full deployment with all setup
./deploy.sh
```

### Manual Steps
```bash
# 1. Check prerequisites
make check-prereqs

# 2. Deploy application
make deploy

# 3. Configure Tailscale (on target server)
sudo tailscale up

# 4. Verify deployment
make health-check
```

## 📊 Management Commands

### Service Management
```bash
make start          # Start all services
make stop           # Stop all services  
make restart        # Restart all services
make status         # Check service status
make logs           # View application logs
make traefik-logs   # View Traefik logs
```

### Application Management
```bash
make update         # Update application
make config-reload  # Reload configuration
make backup         # Create backup
make restore BACKUP_FILE=filename  # Restore from backup
make scale REPLICAS=3  # Scale application
```

### Monitoring & Troubleshooting
```bash
make monitor        # Real-time monitoring
make health-check   # Comprehensive health check
make troubleshoot   # Run diagnostics
make ssl-status     # Check SSL certificates
make network-test   # Test connectivity
```

### Development
```bash
make dev-setup      # Setup local development
make build          # Build Docker images
make test-local     # Test locally
make lint           # Code linting
```

## 🔐 Security Features

### SSL/TLS
- **Automatic certificate generation** from cert-server.aip.dxc.com
- **TLS 1.2/1.3** with strong cipher suites
- **HSTS** and security headers
- **Certificate auto-renewal**

### Network Security
- **Tailscale VPN** for secure access
- **Firewall configuration** (UFW)
- **Docker network isolation**
- **Rate limiting** and DDoS protection

### Application Security
- **Non-root container execution**
- **Input validation** and sanitization
- **CSRF protection**
- **Secure session management**

## 📁 Directory Structure

```
/opt/threat-analysis/
├── config/
│   └── areas.json          # Valid areas configuration
├── data/
│   └── threats.json        # Persistent threat data
└── logs/                   # Application logs

/opt/traefik/
├── data/
│   └── acme.json          # SSL certificates
└── logs/                  # Traefik logs

/opt/deployment/
├── docker-compose.yml     # Service definitions
├── Dockerfile            # Container definition
├── deploy.sh            # Deployment script
├── backup.sh            # Backup script
└── monitor.sh           # Monitoring script

/opt/backups/             # Automated backups
```

## 🌐 Access URLs

- **Application**: https://threat.aip.dxc.com
- **Traefik Dashboard**: https://traefik.aip.dxc.com:8080
- **Health Check**: https://threat.aip.dxc.com/health
- **API Endpoints**: https://threat.aip.dxc.com/api/*

## 🔧 Configuration Management

### Update Valid Areas
```bash
# Edit config/areas.json locally
vim config/areas.json

# Deploy updated configuration
make config-reload
```

### Environment Variables
```bash
# View current environment
ssh ubuntu@192.169.0.201 "cat /opt/deployment/.env"

# Update environment
ssh ubuntu@192.169.0.201 "vi /opt/deployment/.env"
make restart
```

## 📊 Monitoring & Alerting

### Built-in Monitoring
- **Health checks** every 30 seconds
- **Log rotation** daily (30-day retention)
- **Automated backups** at 2:00 AM daily
- **Disk space monitoring**

### Log Locations
```bash
# Application logs
/opt/threat-analysis/logs/

# Docker logs
docker-compose logs -f

# System logs
/var/log/syslog
```

### Backup Strategy
- **Daily automated backups** at 2:00 AM
- **7-day retention policy**
- **Includes**: application data, configuration, certificates
- **Location**: `/opt/backups/`

## 🆘 Emergency Procedures

### Emergency Stop
```bash
make emergency-stop    # Stop all services immediately
```

### Emergency Restore
```bash
make emergency-restore # Restore from latest backup
```

### Rollback Deployment
```bash
make rollback         # Rollback to previous version
```

### Troubleshooting Common Issues

#### SSL Certificate Issues
```bash
# Check certificate status
make ssl-status

# Force certificate renewal
make ssl-renew

# View Traefik logs
make traefik-logs
```

#### Application Not Responding
```bash
# Check container status
make status

# View application logs
make logs

# Restart services
make restart

# Run health check
make health-check
```

#### Tailscale Connection Issues
```bash
# On target server
sudo tailscale status
sudo tailscale up --reset
```

## 🔄 Updates & Maintenance

### Application Updates
```bash
# Update application code
make update

# Update with downtime notification
make prod-deploy
```

### System Maintenance
```bash
# Clean Docker resources
make clean

# Update system packages (on target server)
ssh ubuntu@192.169.0.201 "sudo apt update && sudo apt upgrade -y"

# Restart system (if required)
ssh ubuntu@192.169.0.201 "sudo reboot"
```

## 📝 API Documentation

### Endpoints
- `GET /` - Web interface
- `GET /health` - Health check
- `GET /api/config` - Get configuration
- `GET /api/threats` - List all threats
- `POST /api/threats` - Create new threat
- `PUT /api/threats/{id}` - Update threat status
- `DELETE /api/threats/{id}` - Delete threat

### Example API Usage
```bash
# Get all threats
curl https://threat.aip.dxc.com/api/threats

# Create new threat
curl -X POST https://threat.aip.dxc.com/api/threats \
  -H "Content-Type: application/json" \
  -d '{"threat_type":"Security Breach","area":"OP1","severity":"High","description":"Unauthorized access detected"}'

# Update threat status
curl -X PUT https://threat.aip.dxc.com/api/threats/1 \
  -H "Content-Type: application/json" \
  -d '{"status":"Resolved"}'
```

## 🤝 Contributing

1. Make changes to source files
2. Test locally: `make test-local`
3. Deploy to staging: `make deploy`
4. Run health checks: `make health-check`
5. Deploy to production: `make prod-deploy`

## 📞 Support

For issues and support:
1. Check logs: `make logs`
2. Run diagnostics: `make troubleshoot`
3. View monitoring: `make monitor`
4. Create backup before changes: `make backup`

## 🔖 Version History

- **v1.0** - Initial deployment with Traefik and Tailscale integration
- External JSON configuration for valid areas
- Comprehensive monitoring and backup system
- SSL certificate automation with cert-server.aip.dxc.com