#!/usr/bin/env bash
docker-compose -f docker-compose.simple.yml down
docker-compose -f docker-compose.simple.yml up -d --build

set -euo pipefail

need_root() { if [ "$EUID" -ne 0 ]; then echo "Please run as root (sudo)"; exit 1; fi; }
need_root

echo "=== DuckDNS + Nginx reverse proxy to Cloudflare Tunnel ==="

# ---- Collect inputs (interactive with env var overrides) ----
DOMAIN="${DOMAIN:-}"
DUCK_SUB="${DUCK_SUB:-}"
DUCK_TOKEN="${DUCK_TOKEN:-}"
CF_TUNNEL_URL="${CF_TUNNEL_URL:-}"
EMAIL="${EMAIL:-}"

read -rp "DuckDNS full domain (e.g., irmproject-management.duckdns.org): " DOMAIN   < /dev/tty || true
DOMAIN="${DOMAIN:-${DOMAIN}}"

# derive subdomain part for updater if user didn’t provide
if [[ -z "${DUCK_SUB}" ]]; then
  DUCK_SUB="${DOMAIN%%.duckdns.org}"
fi

if [[ -z "${DUCK_TOKEN}" ]]; then
  read -rp "DuckDNS token: " DUCK_TOKEN < /dev/tty || true
fi

if [[ -z "${CF_TUNNEL_URL}" ]]; then
  echo "Cloudflare Tunnel URL (e.g., https://abc12345.trycloudflare.com)"
  read -rp "> " CF_TUNNEL_URL < /dev/tty || true
fi

if [[ -z "${EMAIL}" ]]; then
  read -rp "Email for Let’s Encrypt (important for renewal notices): " EMAIL < /dev/tty || true
fi

if [[ -z "${DOMAIN}" || -z "${DUCK_SUB}" || -z "${DUCK_TOKEN}" || -z "${CF_TUNNEL_URL}" || -z "${EMAIL}" ]]; then
  echo "Missing required inputs. Exiting."
  exit 1
fi

# strip possible trailing slash on CF url
CF_TUNNEL_URL="${CF_TUNNEL_URL%/}"

# hostname part for Host header
CF_HOST="$(echo "${CF_TUNNEL_URL}" | sed -E 's#https?://([^/]+).*#\1#')"

echo
echo "== Summary =="
echo " DuckDNS domain : ${DOMAIN}"
echo " DuckDNS sub    : ${DUCK_SUB}"
echo " Cloudflare URL : ${CF_TUNNEL_URL}"
echo " CF Hostname    : ${CF_HOST}"
echo " Email          : ${EMAIL}"
echo

# ---- Update system & install packages ----
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx certbot python3-certbot-nginx curl

# ---- DuckDNS updater (cron) ----
echo "Setting up DuckDNS updater (every 5 minutes)..."
mkdir -p /opt/duckdns
cat > /opt/duckdns/update.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
curl -fsS "https://www.duckdns.org/update?domains=${DUCK_SUB}&token=${DUCK_TOKEN}&ip=" | logger -t duckdns
EOF
chmod +x /opt/duckdns/update.sh

# add cron (idempotent)
( crontab -l 2>/dev/null | grep -v "/opt/duckdns/update.sh" ; echo "*/5 * * * * /opt/duckdns/update.sh" ) | crontab -

# run once now
/opt/duckdns/update.sh || true

# ---- Nginx site config ----
SITE_PATH="/etc/nginx/sites-available/${DOMAIN}"
ENABLED_LINK="/etc/nginx/sites-enabled/${DOMAIN}"
SNIPPET="/etc/nginx/snippets/cf_tunnel_proxy.conf"

echo "Creating Nginx snippet ${SNIPPET}..."
mkdir -p /etc/nginx/snippets
cat > "${SNIPPET}" <<EOF
# Proxy to Cloudflare Tunnel URL
proxy_set_header Host ${CF_HOST};
proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto https;
proxy_http_version 1.1;
proxy_set_header Upgrade \$http_upgrade;
proxy_set_header Connection "upgrade";
proxy_pass ${CF_TUNNEL_URL};
EOF

echo "Creating Nginx server for ${DOMAIN} (HTTP, will be auto-upgraded to HTTPS by certbot)..."
cat > "${SITE_PATH}" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        include ${SNIPPET};
    }
}
EOF

ln -sf "${SITE_PATH}" "${ENABLED_LINK}"
nginx -t
systemctl reload nginx

# ---- Let’s Encrypt (Certbot) ----
echo "Requesting Let’s Encrypt certificate..."
certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos -m "${EMAIL}" --redirect

echo "Enabling auto-renewal timer (default on most systems)..."
systemctl enable --now certbot.timer || true

# ---- Helper script to update CF tunnel URL later ----
UPDATER="/usr/local/bin/update-cf-tunnel-url"
cat > "${UPDATER}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ $# -ne 1 ]; then
  echo "Usage: update-cf-tunnel-url https://NEW.trycloudflare.com"
  exit 1
fi
NEW_URL="${1%/}"
NEW_HOST="$(echo "${NEW_URL}" | sed -E 's#https?://([^/]+).*#\1#')"
SNIPPET="/etc/nginx/snippets/cf_tunnel_proxy.conf"
tmp="$(mktemp)"
# rewrite proxy snippet atomically
cat > "$tmp" <<EOT
proxy_set_header Host ${NEW_HOST};
proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto https;
proxy_http_version 1.1;
proxy_set_header Upgrade \$http_upgrade;
proxy_set_header Connection "upgrade";
proxy_pass ${NEW_URL};
EOT
mv "$tmp" "$SNIPPET"
nginx -t && systemctl reload nginx
echo "Updated Cloudflare Tunnel target to: ${NEW_URL}"
EOF
chmod +x "${UPDATER}"

echo
echo "=== Done! ==="
echo "Your site should be live at: https://${DOMAIN}"
echo
echo "If your trycloudflare URL ever changes, run:"
echo "  sudo ${UPDATER} https://NEW.trycloudflare.com"
echo
echo "Tip: keep your tunnel running on your laptop:"
echo "  cloudflared tunnel --url http://localhost:3000"

