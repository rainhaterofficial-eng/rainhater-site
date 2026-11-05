#!/usr/bin/env bash
# One-time setup for the rainhater.com droplet (Ubuntu 24.04).
# Runs automatically on first boot (from the droplet's "user data"), or by hand as root.
# It: creates a non-root user, locks SSH to keys only, turns on the firewall and
# automatic security updates, installs nginx, publishes the site from GitHub,
# keeps the site in sync with GitHub every 5 minutes, and turns on HTTPS as soon
# as rainhater.com points at this server.
set -euo pipefail
exec > >(tee -a /var/log/rainhater-setup.log) 2>&1

REPO_URL="${REPO_URL:-https://github.com/rainhaterofficial-eng/rainhater-site.git}"
SITE_USER="rain"
WEB_ROOT="/var/www/rainhater"
EMAIL="rainhaterofficial@gmail.com"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export DEBIAN_FRONTEND=noninteractive

echo "==> $(date) starting rainhater setup"
apt-get -o DPkg::Lock::Timeout=900 update -y
apt-get -o DPkg::Lock::Timeout=900 -o Dpkg::Options::=--force-confold upgrade -y
apt-get -o DPkg::Lock::Timeout=900 install -y nginx git ufw unattended-upgrades certbot python3-certbot-nginx fail2ban

echo "==> Non-root user '$SITE_USER' (SSH key copied from root, sudo allowed)"
if ! id "$SITE_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$SITE_USER"
  usermod -aG sudo "$SITE_USER"
fi
install -d -m 700 -o "$SITE_USER" -g "$SITE_USER" "/home/$SITE_USER/.ssh"
if [ -s /root/.ssh/authorized_keys ]; then
  install -m 600 -o "$SITE_USER" -g "$SITE_USER" /root/.ssh/authorized_keys "/home/$SITE_USER/.ssh/authorized_keys"
fi
echo "$SITE_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$SITE_USER"
chmod 440 "/etc/sudoers.d/90-$SITE_USER"

echo "==> SSH: keys only, no root login"
cat > /etc/ssh/sshd_config.d/00-rainhater.conf <<'CONF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
CONF
mkdir -p /run/sshd   # Ubuntu 24.04 only creates this once ssh has started
sshd -t
systemctl try-reload-or-restart ssh.service 2>/dev/null || true   # 24.04 starts ssh on demand, so it may not be running

echo "==> Firewall: only SSH and web traffic"
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

echo "==> Automatic security updates"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'CONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
CONF
systemctl enable --now unattended-upgrades
systemctl enable --now fail2ban

echo "==> Site files from GitHub"
if [ ! -d "$WEB_ROOT/.git" ]; then
  rm -rf "$WEB_ROOT"
  git clone --depth 1 "$REPO_URL" "$WEB_ROOT"
fi
chown -R "$SITE_USER:www-data" "$WEB_ROOT"
chmod -R g+rX,o+rX "$WEB_ROOT"

echo "==> Keep the site in sync with GitHub (every 5 minutes)"
cat > /usr/local/bin/rainhater-update <<UPD
#!/usr/bin/env bash
set -e
cd "$WEB_ROOT"
git fetch --depth 1 origin main -q
if [ "\$(git rev-parse HEAD)" != "\$(git rev-parse origin/main)" ]; then
  git reset --hard origin/main -q
  echo "updated to \$(git rev-parse --short HEAD)"
fi
UPD
chmod 755 /usr/local/bin/rainhater-update
cat > /etc/systemd/system/rainhater-update.service <<UNIT
[Unit]
Description=Pull the latest rainhater.com site from GitHub
After=network-online.target
[Service]
Type=oneshot
User=$SITE_USER
ExecStart=/usr/local/bin/rainhater-update
UNIT
cat > /etc/systemd/system/rainhater-update.timer <<'UNIT'
[Unit]
Description=Check GitHub for site updates every 5 minutes
[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
UNIT

echo "==> nginx"
cp "$WEB_ROOT/deploy/nginx-rainhater.conf" /etc/nginx/sites-available/rainhater
ln -sf /etc/nginx/sites-available/rainhater /etc/nginx/sites-enabled/rainhater
rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/conf.d/rainhater-tuning.conf <<'CONF'
server_tokens off;
gzip_comp_level 5;
gzip_types text/css application/javascript image/svg+xml text/plain application/json;
CONF
nginx -t
systemctl enable --now nginx
systemctl reload nginx

echo "==> HTTPS: try every 10 minutes until rainhater.com points here, then stop"
cat > /usr/local/bin/rainhater-cert <<CERT
#!/usr/bin/env bash
set -e
if [ -d /etc/letsencrypt/live/rainhater.com ]; then
  systemctl disable --now rainhater-cert.timer; exit 0
fi
MYIP=\$(curl -s4 https://api.ipify.org || true)
for h in rainhater.com www.rainhater.com; do
  [ "\$(getent ahostsv4 \$h | awk '{print \$1; exit}')" = "\$MYIP" ] || { echo "\$h not pointing here yet"; exit 0; }
done
certbot --nginx -d rainhater.com -d www.rainhater.com --redirect -m $EMAIL --agree-tos -n
systemctl disable --now rainhater-cert.timer
CERT
chmod 755 /usr/local/bin/rainhater-cert
cat > /etc/systemd/system/rainhater-cert.service <<'UNIT'
[Unit]
Description=Get the HTTPS certificate for rainhater.com once DNS is ready
After=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/rainhater-cert
UNIT
cat > /etc/systemd/system/rainhater-cert.timer <<'UNIT'
[Unit]
Description=Retry HTTPS setup every 10 minutes until it works
[Timer]
OnBootSec=1min
OnUnitActiveSec=10min
[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now rainhater-update.timer rainhater-cert.timer
systemctl enable --now certbot.timer 2>/dev/null || true   # auto-renewal

echo "==> $(date) rainhater setup finished"
