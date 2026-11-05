# How rainhater.com runs

- Code lives on GitHub: rainhaterofficial-eng/rainhater-site (public; the site is public anyway).
- The droplet copies the site from GitHub on first boot and checks for updates every 5 minutes,
  so publishing a change = pushing it to the `main` branch on GitHub.
- HTTPS turns itself on once rainhater.com and www.rainhater.com point at the droplet
  (checked every 10 minutes), and the certificate renews automatically.
- Setup log on the server: /var/log/rainhater-setup.log

## Creating the droplet (DigitalOcean)
1. Create → Droplets. Region: closest to you. Image: Ubuntu 24.04 (LTS) x64.
2. Size: Basic → Regular → $6/mo (1 GB / 1 CPU / 25 GB).
3. Authentication: SSH Key (pick your existing key, or add a new one).
4. Enable weekly backups.
5. Advanced options → Add Initialization scripts (user data) → paste the contents of deploy/user-data.sh.
6. Hostname: rainhater. Create.
