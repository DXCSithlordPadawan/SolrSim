```bash
# Installation with SSL
SSL_ENABLED=true DOMAIN_NAME=solrsim.example.com EMAIL_ADDRESS=admin@example.com ./solrsim_install.sh 170

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

This enhanced script transforms a simple Flask app deployment into a enterprise-grade, monitored, and secured application platform. 
The monitoring stack provides complete visibility into application performance and system health, while the SSL integration ensures secure communications. 

All components are configured to work together seamlessly with minimal manual intervention required.
