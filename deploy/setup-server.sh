#!/usr/bin/env bash
# One-time setup for the rainhater.com droplet (Ubuntu 24.04).
# Run as root on the NEW droplet only:  bash setup-server.sh
# It: creates a non-root user, locks SSH to keys only, turns on the firewall,
# turns on automatic security updates, installs nginx + certbot, and creates a
# git repo on the server so "git push" publishes the site.
set -euo pipefail

SITE_USER="rain"
WEB_ROOT="/var/www/rainhater"
REPO="/home/$SITE_USER/rainhater.git"

export DEBIAN_FRONTEND=noninteractive

echo "==> Updating packages"
apt-get update -y
apt-get upgrade -y
apt-get install -y nginx git ufw unattended-upgrades certbot python3-certbot-nginx fail2ban

echo "==> Creating user $SITE_USER (sudo, SSH key copied from root)"
if ! id "$SITE_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$SITE_USER"
  usermod -aG sudo "$SITE_USER"
fi
install -d -m 700 -o "$SITE_USER" -g "$SITE_USER" "/home/$SITE_USER/.ssh"
install -m 600 -o "$SITE_USER" -g "$SITE_USER" /root/.ssh/authorized_keys "/home/$SITE_USER/.ssh/authorized_keys"
# sudo without a password (the account itself has no password; login is by SSH key only)
echo "$SITE_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$SITE_USER"
chmod 440 "/etc/sudoers.d/90-$SITE_USER"

echo "==> Locking down SSH: keys only, no root login"
cat > /etc/ssh/sshd_config.d/99-rainhater.conf <<'CONF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
CONF
sshd -t
systemctl reload ssh || systemctl reload sshd

echo "==> Firewall: allow only SSH and web traffic"
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

echo "==> Web folder and git repo (push to deploy)"
install -d -o "$SITE_USER" -g www-data -m 755 "$WEB_ROOT"
if [ ! -d "$REPO" ]; then
  sudo -u "$SITE_USER" git init --bare -b main "$REPO"
fi
cat > "$REPO/hooks/post-receive" <<HOOK
#!/usr/bin/env bash
# Publishes the main branch into the web folder on every push.
while read oldrev newrev ref; do
  if [ "\$ref" = "refs/heads/main" ]; then
    git --work-tree="$WEB_ROOT" --git-dir="$REPO" checkout -f main
    echo "rainhater.com updated to \$(git --git-dir="$REPO" rev-parse --short main)"
  fi
done
HOOK
chmod +x "$REPO/hooks/post-receive"
chown -R "$SITE_USER:$SITE_USER" "$REPO"

echo "==> nginx"
cp "$(dirname "$0")/nginx-rainhater.conf" /etc/nginx/sites-available/rainhater
ln -sf /etc/nginx/sites-available/rainhater /etc/nginx/sites-enabled/rainhater
rm -f /etc/nginx/sites-enabled/default
# a little tuning: compression and hide version
cat > /etc/nginx/conf.d/rainhater-tuning.conf <<'CONF'
server_tokens off;
gzip on;
gzip_comp_level 5;
gzip_types text/css application/javascript image/svg+xml text/plain application/json;
CONF
nginx -t
systemctl enable --now nginx
systemctl reload nginx

echo "==> fail2ban (blocks repeated SSH login attempts)"
systemctl enable --now fail2ban

echo
echo "Done. Next: push the site with git, point DNS at this server, then run:"
echo "  sudo certbot --nginx -d rainhater.com -d www.rainhater.com --redirect -m rainhaterofficial@gmail.com --agree-tos -n"
