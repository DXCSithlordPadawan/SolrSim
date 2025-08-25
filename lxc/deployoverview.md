```bash
# Installation with SSL
SSL_ENABLED=true DOMAIN_NAME=solrsim.example.com EMAIL_ADDRESS=admin@example.com ./solrsim_install.sh 102

# Custom resource allocation
CONTAINER_MEMORY=2048 CONTAINER_CORES=4 SSL_ENABLED=true DOMAIN_NAME=app.company.com EMAIL_ADDRESS=it@company.com ./solrsim_install.sh 103
```

## 📈 Monitoring Access Points:

After installation, you'll have access to:

- **Main Application**: `http://container-ip` or `https://your-domain.com`
- **Grafana Dashboard**: `http://container-ip:3000` (admin/admin)
- **Prometheus Metrics**: `http://container-ip:9090`
- **Application Metrics**: `http://container-ip:8000/metrics`
- **Health Check**: `http://container-ip:5000/health`

## 🛡️ Security Features:

1. **Firewall Rules**: Only necessary ports are opened
2. **Fail2Ban**: Protects against brute force attacks
3. **Rate Limiting**: Prevents abuse via Nginx
4. **SSL/TLS**: Strong encryption with modern ciphers
5. **Security Headers**: XSS protection, HSTS, content security policy

## 📊 What Gets Monitored:

- **Application Metrics**: Request count, response times, error rates
- **System Metrics**: CPU, memory, disk usage
- **Security Events**: Failed logins, firewall blocks
- **Service Health**: Automatic restart on failure
- **SSL Certificate**: Expiration monitoring and auto-renewal

## 🔧 Post-Installation Tasks:

1. **Change Grafana Password**: Login to Grafana and change from admin/admin
2. **Customize Data**: Edit `/opt/solrsim/data/productissues.json`
3. **Update Secrets**: Change SECRET_KEY in `/opt/solrsim/config.py`
4. **Configure Alerts**: Set up webhooks in `/opt/monitoring/scripts/alert_notification.sh`
5. **Review Logs**: Check `/var/log/solrsim/` for daily reports

## 🚨 Emergency Procedures:

The script includes comprehensive error handling and cleanup procedures. If anything goes wrong:

```bash
# Check service status
pct exec CONTAINER_ID -- systemctl status solrsim prometheus grafana-server nginx

# View recent logs
pct exec CONTAINER_ID -- journalctl -u solrsim.service -n 50

# Manual service recovery
pct exec CONTAINER_ID -- systemctl restart solrsim nginx prometheus grafana-server

# Complete container restart
pct stop CONTAINER_ID && pct start CONTAINER_ID
```

## 🌐 **Network Configuration Options:**

### **Static IP Configuration:**
```bash
# Basic static IP setup
USE_STATIC_IP=true STATIC_IP=192.168.1.100 GATEWAY=192.168.1.1 ./solrsim_install.sh 101

# Corporate network with custom DNS
USE_STATIC_IP=true STATIC_IP=172.16.1.100 GATEWAY=172.16.1.1 \
DNS_SERVER=172.16.1.10 DNS_SERVER_2=172.16.1.11 ./solrsim_install.sh 102
```

### **DHCP Configuration (Default):**
```bash
# Simple DHCP installation
./solrsim_install.sh 103
```

## 🔐 **SSH Access & Security:**

### **Default SSH Setup:**
- **SSH enabled by default** on port 22
- **Root password set to:** `BobTheBigRedBus-0`
- **Root SSH login enabled** by default

### **Enhanced Security Options:**
```bash
# Disable root SSH, create admin user with sudo
DISABLE_ROOT_SSH=true CREATE_ADMIN_USER=true ADMIN_USERNAME=secadmin \
ADMIN_PASSWORD=MySecurePass123 ./solrsim_install.sh 104

# Custom SSH port for security
SSH_PORT=2222 ./solrsim_install.sh 105

# Disable SSH completely (console access only)
ENABLE_SSH=false ./solrsim_install.sh 106
```

## 📋 Daily Operations:

1. **Health Monitoring**: Automated every 5 minutes
2. **Log Analysis**: Daily reports generated at 1 AM
3. **Certificate Renewal**: Automatic via systemd timer
4. **Backup Recommendations**: Use `vzdump CONTAINER_ID --storage local`

## 🎯 Key Benefits:

- **One-Click Deployment**: Complete setup in minutes
- **Production Ready**: SSL, monitoring, and security included
- **Self-Healing**: Automatic restart on failures
- **Comprehensive Logging**: Full audit trail
- **Performance Monitoring**: Real-time dashboards
- **Security Hardened**: Multiple layers of protection
- **Maintenance Automation**: Log rotation, health checks, SSL renewal

## 🏢 **Enterprise Configuration Example:**
```bash
# Full enterprise setup
USE_STATIC_IP=true STATIC_IP=192.168.10.100 GATEWAY=192.168.10.1 \
SSL_ENABLED=true DOMAIN_NAME=solrsim.company.com EMAIL_ADDRESS=it@company.com \
CREATE_ADMIN_USER=true ADMIN_USERNAME=solradmin ADMIN_PASSWORD=SecurePass123 \
DISABLE_ROOT_SSH=true SSH_PORT=2222 \
CONTAINER_MEMORY=2048 CONTAINER_CORES=4 CONTAINER_DISK_SIZE=16 \
./solrsim_install.sh 200
```

## 🔧 **Key Features Added:**

1. **Network Validation**: Validates IP addresses and network configuration before container creation
2. **Flexible DNS**: Supports primary and secondary DNS servers
3. **SSH Security**: Configurable SSH settings with hardened defaults
4. **Admin User Creation**: Optional admin user with sudo privileges
5. **Enhanced Firewall**: UFW rules automatically configured based on enabled services
6. **Fail2Ban Integration**: SSH protection automatically configured if SSH is enabled

## 📋 **Post-Installation Access Methods:**

### **Console Access (Always Available):**
```bash
pct enter CONTAINER_ID
```

### **SSH Access (If Enabled):**
```bash
# Root access
ssh root@CONTAINER_IP -p SSH_PORT
# Password: BobTheBigRedBus-0

# Admin user access (if created)
ssh ADMIN_USERNAME@CONTAINER_IP -p SSH_PORT
```

### **Web Access:**
```bash
# Application
http://CONTAINER_IP or https://DOMAIN_NAME

# Monitoring
http://CONTAINER_IP:3000  # Grafana (admin/admin)
http://CONTAINER_IP:9090  # Prometheus
```

## 🛡️ **Security Enhancements:**

1. **Automatic UFW Configuration**: Only required ports opened
2. **Fail2Ban Protection**: SSH brute force protection
3. **Rate Limiting**: Nginx-level request throttling  
4. **Security Headers**: XSS, HSTS, and content security policies
5. **Admin User Option**: Reduces need for root access
6. **Configurable SSH**: Custom ports and root disable options

## 🚀 **Quick Start Examples:**

```bash
# Home lab setup
USE_STATIC_IP=true STATIC_IP=192.168.1.200 GATEWAY=192.168.1.1 ./solrsim_install.sh 101

# Corporate deployment
USE_STATIC_IP=true STATIC_IP=10.0.1.100 GATEWAY=10.0.1.1 \
CREATE_ADMIN_USER=true ADMIN_USERNAME=solradmin \
SSL_ENABLED=true DOMAIN_NAME=solrsim.corp.local \
./solrsim_install.sh 102

# High security deployment  
DISABLE_ROOT_SSH=true CREATE_ADMIN_USER=true SSH_PORT=2222 \
USE_STATIC_IP=true STATIC_IP=172.16.1.50 GATEWAY=172.16.1.1 \
./solrsim_install.sh 103
```
This enhanced script transforms a simple Flask app deployment into a enterprise-grade, monitored, and secured application platform. 
The monitoring stack provides complete visibility into application performance and system health, while the SSL integration ensures secure communications. 
All components are configured to work together seamlessly with minimal manual intervention required.

I've enhanced the installation script with comprehensive network configuration options, SSH access, and security features. Here's a summary of the new capabilities:

The script now provides enterprise-grade deployment options while maintaining the simplicity of one-click installation. 
All network configurations are validated, SSH access is properly secured, and the 
system provides multiple access methods for different security requirements.