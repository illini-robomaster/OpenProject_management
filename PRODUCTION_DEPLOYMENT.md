# OpenProject Production Deployment Guide

This guide will help you deploy OpenProject for production use.

## Current Status

✅ **Development deployment is complete and running on http://localhost:3000**

Default credentials:
- Username: `admin`
- Password: `admin`

⚠️ **Please change the admin password immediately after first login!**

## Quick Start (Already Done)

The following steps have already been completed for you:

1. ✅ OpenProject is running in development mode on port 3000
2. ✅ All containers are healthy and operational
3. ✅ Database is initialized with default admin user
4. ✅ All necessary Docker networks and volumes are created

## Production Deployment Preparation

### 1. Domain and DNS Setup

Before deploying to production, you need:

- A domain name (e.g., `openproject.yourdomain.com`)
- DNS A record pointing to your server's IP address
- SSL certificate (recommended: Let's Encrypt with Caddy auto-HTTPS)

### 2. Server Requirements

**Minimum Requirements:**
- 2 CPU cores
- 4 GB RAM
- 20 GB disk space
- Ubuntu 20.04+ or similar Linux distribution

**Recommended:**
- 4+ CPU cores
- 8+ GB RAM
- 50+ GB SSD storage

### 3. Security Setup

**Firewall Configuration:**
```bash
# Allow SSH, HTTP, and HTTPS
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
```

**Change Default Passwords:**
1. Change the OpenProject admin password (username: admin, password: admin)
2. Update the database password in production configuration

### 4. Production Configuration

**Step 1: Create production environment file**
```bash
cp .env.prod.example .env.prod
```

**Step 2: Edit .env.prod with your settings**
```bash
vim .env.prod
```

**Required changes:**
- Set `DOMAIN_NAME` to your actual domain
- Set a strong `POSTGRES_PASSWORD`
- Configure SMTP settings for email notifications
- Set appropriate resource limits

**Step 3: Update Caddy proxy for SSL (Recommended)**

Create a new Caddyfile for production with automatic HTTPS:

```bash
cat > proxy/Caddyfile.prod << EOF
{your-domain.com} {
    reverse_proxy * http://web:8080
    log
}
EOF
```

### 5. Deploy to Production

**Option A: Same server transition (Development → Production)**
```bash
# Stop development environment
docker-compose -f docker-compose.simple.yml down

# Start production environment
docker-compose -f docker-compose.simple.yml -f docker-compose.prod.yml --env-file .env.prod up -d
```

**Option B: Fresh production server**
```bash
# 1. Clone repository
git clone https://github.com/opf/openproject-docker-compose.git --depth=1 --branch=stable/16 openproject
cd openproject

# 2. Copy your production files
# (Copy .env.prod, docker-compose.simple.yml, docker-compose.prod.yml, etc.)

# 3. Create required directories
sudo mkdir -p /var/openproject/assets
sudo chown 1000:1000 -R /var/openproject/assets

# 4. Start production deployment
docker-compose -f docker-compose.simple.yml -f docker-compose.prod.yml --env-file .env.prod up -d
```

### 6. SSL/TLS Setup Options

**Option 1: Let Caddy handle SSL automatically (Recommended)**
- Update domain in configuration
- Ensure ports 80 and 443 are open
- Caddy will automatically obtain Let's Encrypt certificates

**Option 2: External reverse proxy (Nginx, Apache, CloudFlare)**
- Keep OpenProject on internal port (e.g., 3000)
- Configure your reverse proxy to handle SSL termination
- Set `OPENPROJECT_HTTPS=true` but proxy handles actual SSL

**Option 3: Manual SSL certificates**
- Obtain SSL certificates manually
- Mount certificates into the proxy container
- Configure Caddy or nginx to use your certificates

### 7. Monitoring and Maintenance

**Health Checks:**
```bash
# Check container status
docker-compose ps

# Check logs
docker-compose logs -f web
docker-compose logs -f worker
```

**Backup Commands:**
```bash
# Create backup
docker-compose -f docker-compose.yml -f docker-compose.control.yml run backup

# Restore backup (if needed)
# Follow the restore procedures in OpenProject documentation
```

**Updates:**
```bash
# Update OpenProject
git pull origin stable/16
docker-compose pull
docker-compose up -d --build
```

### 8. Post-Deployment Checklist

After production deployment:

- [ ] Change admin password from default (admin/admin)
- [ ] Configure SMTP settings for email notifications
- [ ] Set up regular backups
- [ ] Configure monitoring (optional)
- [ ] Test SSL certificate and security headers
- [ ] Create additional user accounts
- [ ] Configure project templates and workflows
- [ ] Set up integrations (if needed)

## Troubleshooting

**Port Conflicts:**
- Change the PORT variable in .env file
- Ensure no other services are using the same ports

**SSL Issues:**
- Verify DNS records point to your server
- Check firewall allows ports 80 and 443
- Review Caddy logs for certificate errors

**Performance Issues:**
- Increase `RAILS_MAX_THREADS` for high traffic
- Monitor database performance
- Consider scaling to multiple containers

**Database Issues:**
- Check PostgreSQL logs
- Verify database connectivity
- Ensure sufficient disk space

## Support Resources

- [Official Documentation](https://www.openproject.org/docs/)
- [Community Forum](https://community.openproject.org/)
- [GitHub Issues](https://github.com/opf/openproject/issues)
- [Installation Guide](https://www.openproject.org/docs/installation-and-operations/)

---

**⚠️ Security Notice:**
Never use the development configuration in production. Always use strong passwords, enable HTTPS, and keep the system updated.
