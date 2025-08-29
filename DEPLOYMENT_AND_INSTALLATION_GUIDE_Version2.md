# SolrSim Threat Analysis Application - Deployment & Installation Guide

## Overview

SolrSim is a Flask-based threat analysis dashboard for platform and product management. It validates operational areas, matches threats to platforms using JSON data, and provides a web interface with API endpoints for analysis, monitoring, and reporting.

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
- API endpoints: `/api/threat-check`, `/api/current-products`, etc.

### Production

- Use Gunicorn or uWSGI for production, optionally behind Nginx.
- Example Gunicorn command:
  ```bash
  gunicorn -w 4 -b 0.0.0.0:5000 threat_analysis_app:app
  ```
- See LXC and container guides for enterprise deployment.

### Containerized Deployment

- See `lxc/solrsim_lxc_setup.md` for Proxmox container steps.
- Example (inside container):
  ```bash
  python3 -m venv venv
  source venv/bin/activate
  pip install -r requirements.txt
  python threat_analysis_app.py
  ```

---

## Monitoring & Security

- Monitoring endpoints: `/metrics`, `/health`
- Use Prometheus & Grafana for dashboards.
- Harden security with UFW firewall, Fail2Ban, secure SSH (see included scripts).

---

## Emergency Procedures

```bash
# Restart services
systemctl restart solrsim nginx prometheus grafana-server
# Check logs
journalctl -u solrsim.service -n 50
```

---

## Daily Operations & Maintenance

- Change sensitive credentials after install.
- Update dependencies regularly:
  ```bash
  pip list --outdated
  pip install --upgrade <package>
  ```
- Backup data with Proxmox or manual file copy.
- Rotate logs and monitor SSL expiry.

---

## Security Enhancements

- Only open required ports.
- Disable root SSH and create admin users.
- Set strong passwords.
- Use rate limiting and security headers in Nginx.

---

## Example Enterprise Setup

```bash
DISABLE_ROOT_SSH=true CREATE_ADMIN_USER=true ADMIN_USERNAME=secadmin \
ADMIN_PASSWORD=MySecurePass123 SSL_ENABLED=true DOMAIN_NAME=solrsim.company.com \
CONTAINER_MEMORY=2048 CONTAINER_CORES=4 ./solrsim_install.sh 104
```

---

## Troubleshooting

- **App won’t start:** Check for missing data files, check Python version.
- **Permission denied:** Ensure `threat_analysis_app.py` is executable (`chmod +x threat_analysis_app.py`).
- **No web access:** Check firewall and port status (`ufw status`, `netstat -tuln`).
- **API errors:** Validate JSON data for correct structure and required fields.
- **Monitor logs:** `/var/log/solrsim/` and systemd/journalctl.

---

## Support

Open an issue on GitHub or consult included `lxc/solrsim_lxc_setup.md` and `lxc/deployoverview.md` for advanced and enterprise deployment details.
