# illiniRM OpenProject Deployment

Custom OpenProject deployment configuration with Docker Compose.

## Quick Start

1. Clone this repository
2. Copy `.env.prod.example` to `.env.prod` and customize
3. Run: `docker-compose -f docker-compose.simple.yml up -d`

## Files

- `docker-compose.simple.yml` - Main Docker Compose configuration
- `docker-compose.prod.yml` - Production overrides
- `.env.prod.example` - Environment template
- `backup.sh` - Backup script
- `health-check.sh` - Health monitoring
- `PRODUCTION_DEPLOYMENT.md` - Deployment guide



This guide documents how to deploy **OpenProject** behind a **Cloudflare Tunnel**, exposing it to a custom domain (e.g., `app.irm-project.uk`).


## 📦 Prerequisites

- **Cloudflare account** with a registered domain (e.g., `irm-project.uk`)
- **Cloudflared** installed on the host  
  ```bash
  curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
  chmod +x /usr/local/bin/cloudflared
  ```
* **Docker + Docker Compose (v2)** installed


## ⚙️ Step 1 — Create Cloudflare Tunnel

1. Authenticate cloudflared:

   ```bash
   cloudflared tunnel login
   ```

2. Create a named tunnel:

   ```bash
   cloudflared tunnel create illinirm_proj_management
   ```

3. Route your domain to the tunnel:

   ```bash
   cloudflared tunnel route dns illinirm_proj_management app.irm-project.uk
   ```

---

## ⚙️ Step 2 — Configure cloudflared

Create `/etc/cloudflared/config.yml`:

```yaml
tunnel: illinirm_proj_management
credentials-file: /etc/cloudflared/<TUNNEL_ID>.json
protocol: http2

ingress:
  - hostname: app.irm-project.uk
    service: http://localhost:3000
  - service: http_status:404
```

Install as a systemd service:

```bash
sudo cloudflared service install
sudo systemctl enable --now cloudflared
```

Check status:

```bash
cloudflared tunnel info illinirm_proj_management
# Should show >=1 active CONNECTIONS
```

---

## ⚙️ Step 3 — Configure OpenProject (Docker Compose)

Your `docker-compose.yml` should define services: `db`, `cache`, `proxy`, `web`, `worker`, `cron`, `seeder`.

### `.env` file (same directory as `docker-compose.yml`):

```dotenv
TAG=16-slim
PORT=3000

# Domain + HTTPS
OPENPROJECT_HOST__NAME=app.irm-project.uk
OPENPROJECT_HTTPS=true
OPENPROJECT_HSTS=true

POSTGRES_PASSWORD=p4ssw0rd
```

### Key modifications in `docker-compose.yml`:

```yaml
services:
  proxy:
    ports:
      - "${PORT}:80"

  web:
    image: openproject/openproject:${TAG}
    environment:
      OPENPROJECT_HTTPS: "${OPENPROJECT_HTTPS}"
      OPENPROJECT_HOST__NAME: "${OPENPROJECT_HOST__NAME}"
      OPENPROJECT_HSTS: "${OPENPROJECT_HSTS}"
    # ... other config unchanged

  worker:
    image: openproject/openproject:${TAG}
    environment:
      OPENPROJECT_HTTPS: "${OPENPROJECT_HTTPS}"
      OPENPROJECT_HOST__NAME: "${OPENPROJECT_HOST__NAME}"
      OPENPROJECT_HSTS: "${OPENPROJECT_HSTS}"

  cron:
    image: openproject/openproject:${TAG}
    environment:
      OPENPROJECT_HTTPS: "${OPENPROJECT_HTTPS}"
      OPENPROJECT_HOST__NAME: "${OPENPROJECT_HOST__NAME}"
      OPENPROJECT_HSTS: "${OPENPROJECT_HSTS}"

  seeder:
    image: openproject/openproject:${TAG}
    environment:
      OPENPROJECT_HTTPS: "${OPENPROJECT_HTTPS}"
      OPENPROJECT_HOST__NAME: "${OPENPROJECT_HOST__NAME}"
      OPENPROJECT_HSTS: "${OPENPROJECT_HSTS}"
```

Bring up the stack:

```bash
docker compose up -d --build
```

---

## ✅ Step 4 — Verify Deployment

Check container status:

```bash
docker compose ps
```

Check environment variables inside container:

```bash
docker exec -it $(docker compose ps -q web) env | grep OPENPROJECT
```

Verify local backend:

```bash
curl -I -H 'Host: app.irm-project.uk' http://127.0.0.1:3000
# Expected 200/302
```

Verify public access (through Cloudflare Tunnel):

```bash
curl -I https://app.irm-project.uk
# Expected 200/302
```

---

## 🔧 Troubleshooting

* **400 Bad Request (Via: Caddy)**
  → Ensure `OPENPROJECT_HOST__NAME` is set to your domain (`app.irm-project.uk`).
  → Rebuild all containers (`web`, `worker`, `cron`, `seeder`).

* **Tunnel not active**
  → Check with `cloudflared tunnel info illinirm_proj_management`.
  → Restart service:

  ```bash
  sudo systemctl restart cloudflared
  ```

* **DNS not resolving**
  → Ensure `app.irm-project.uk` has a **CNAME** pointing to your tunnel in Cloudflare DNS.

---

## 🎉 Result

Your OpenProject instance should now be accessible at:

👉 [https://app.irm-project.uk](https://app.irm-project.uk)

Behind Cloudflare Tunnel, with HTTPS automatically handled.

```

