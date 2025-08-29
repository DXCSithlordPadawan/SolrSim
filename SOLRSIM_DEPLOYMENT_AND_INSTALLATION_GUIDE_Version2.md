# SolrSim Threat Analysis Application - Unified Deployment & Installation Guide

## Overview

SolrSim is a Flask-based threat analysis dashboard for platform and product management. It validates operational areas, matches threats to platforms using JSON data, and provides a web interface with RESTful API endpoints for analysis, monitoring, and reporting.

---

## Prerequisites

- **Python:** 3.7+ (recommended 3.8+)
- **System:** Linux/Windows/macOS
- **Memory:** Minimum 1GB (2GB+ for production)
- **Disk:** Minimum 1GB free
- **Network:** Internet access for package installation

---

## Dependency Installation

### Python Libraries

Install with `requirements.txt` (recommended):

```text
Flask==2.3.3
Werkzeug==2.3.7
Jinja2==3.1.2
MarkupSafe==2.1.3
itsdangerous==2.1.2
click==8.1.7
blinker==1.6.2
prometheus_client
psutil
```

Or directly:

```bash
pip install Flask==2.3.3 Werkzeug==2.3.7 Jinja2==3.1.2 MarkupSafe==2.1.3 itsdangerous==2.1.2 click==8.1.7 blinker==1.6.2 prometheus_client psutil
```

---

## Quick Setup

### 1. Clone the Repository

```bash
git clone https://github.com/DXCSithlordPadawan/SolrSim.git
cd SolrSim
```

### 2. Create and Activate Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Prepare Data Directory

```bash
mkdir -p data
# Place your productissues.json, currentproduct.json, productconcessions.json in data/
```

---

## Running the Application

### Development

```bash
python threat_analysis_app.py
```
- Access at: http://localhost:5000
- API endpoints: `/api/threat-check`, `/api/config`, `/api/threats`, etc.

### Production

- Use Gunicorn or uWSGI for production, optionally behind Nginx.
- Example Gunicorn command:
  ```bash
  gunicorn -w 4 -b 0.0.0.0:5000 threat_analysis_app:app
  ```

### Containerized Deployment

- See container guides for LXC or Docker/Proxmox.
- Example (inside container):
  ```bash
  python3 -m venv venv
  source venv/bin/activate
  pip install -r requirements.txt
  python threat_analysis_app.py
  ```

---

## Directory Structure

```
/opt/threat-analysis/
├── config/
│   └── areas.json          # Valid areas configuration
├── data/
│   └── threats.json        # Persistent threat data
└── logs/                   # Application logs

/opt/traefik/
├── data/
│   └── acme.json           # SSL certificates
└── logs/                   # Traefik logs

/opt/deployment/
├── docker-compose.yml      # Service definitions
├── Dockerfile              # Container definition
├── deploy.sh               # Deployment script
├── backup.sh               # Backup script
└── monitor.sh              # Monitoring script

/opt/backups/               # Automated backups
```

---

## Management Commands

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

---

## API Documentation

### Endpoints

- `GET /` - Web interface
- `GET /health` - Health check
- `GET /api/config` - Get configuration
- `GET /api/threats` - List all threats
- `POST /api/threats` - Create new threat
- `PUT /api/threats/{id}` - Update threat status
- `DELETE /api/threats/{id}` - Delete threat
- `POST /api/threat-check` - Check for threats

---

## Monitoring & Alerting

- **Health checks** every 30 seconds
- **Log rotation** daily (30-day retention)
- **Automated backups** at 2:00 AM daily
- **Disk space monitoring**

Log locations:
```bash
# Application logs
/opt/threat-analysis/logs/

# Docker logs
docker-compose logs -f

# System logs
/var/log/syslog
```

Backup strategy:
- **Daily automated backups** at 2:00 AM
- **7-day retention policy**
- **Includes:** application data, configuration, certificates
- **Location:** `/opt/backups/`

---

## Emergency Procedures

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

**SSL Certificate Issues**
```bash
make ssl-status
make ssl-renew
make traefik-logs
```

**Application Not Responding**
```bash
make status
make logs
make restart
make health-check
```

**Tailscale Connection Issues**
```bash
sudo tailscale status
sudo tailscale up --reset
```

---

## Updates & Maintenance

### Application Updates

```bash
make update
make prod-deploy
```

### System Maintenance

```bash
make clean
ssh ubuntu@<server> "sudo apt update && sudo apt upgrade -y"
ssh ubuntu@<server> "sudo reboot"
```

---

## Security Enhancements

- Change default Flask secret key for production.
- Use Docker and Traefik for reverse proxy and SSL.
- Ensure proper firewall and monitoring.
- Automated backups and log rotation.
- Environment variables and configuration files for secrets.

---

## Example Enterprise Setup

- Containerized deployment with Docker Compose and Traefik.
- Automated SSL certificate renewal.
- Monitoring and alerting with Prometheus.
- Daily backups and rollback scripts.
- Secure environment variables.

---

## Support

For issues and support:
1. Check logs: `make logs`
2. Run diagnostics: `make troubleshoot`
3. View monitoring: `make monitor`
4. Create backup before changes: `make backup`
5. Check GitHub issues: https://github.com/DXCSithlordPadawan/SolrSim/issues

---

## Version History

- **v1.0** - Initial deployment with Traefik and Tailscale integration
- External JSON configuration for valid areas
- Comprehensive monitoring and backup system
- SSL certificate automation
