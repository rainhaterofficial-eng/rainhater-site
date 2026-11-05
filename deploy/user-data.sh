#!/bin/bash
# Paste this into DigitalOcean's "User data" box when creating the droplet.
git clone --depth 1 https://github.com/rainhaterofficial-eng/rainhater-site.git /root/rainhater-setup && bash /root/rainhater-setup/deploy/setup-server.sh
