#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Scalegj
# License: MIT | https://github.com/Scalegj/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/qdm12/gluetun | https://www.qbittorrent.org/ | https://prowlarr.com/ | https://sonarr.tv/ | https://radarr.video/ | https://lidarr.audio/ | https://github.com/FlareSolverr/FlareSolverr

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  openvpn \
  wireguard-tools \
  iptables \
  sqlite3
msg_ok "Installed Dependencies"

# =============================================================================
# GLUETUN VPN (mandatory) - routes ALL container traffic through VPN
# =============================================================================

msg_info "Configuring iptables"
$STD update-alternatives --set iptables /usr/sbin/iptables-legacy
$STD update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
ln -sf /usr/sbin/openvpn /usr/sbin/openvpn2.6
msg_ok "Configured iptables"

setup_go

fetch_and_deploy_gh_release "gluetun" "qdm12/gluetun" "tarball"

msg_info "Building Gluetun"
cd /opt/gluetun
$STD go mod download
CGO_ENABLED=0 $STD go build -trimpath -ldflags="-s -w" -o /usr/local/bin/gluetun ./cmd/gluetun/
msg_ok "Built Gluetun"

msg_info "Configuring Gluetun"
mkdir -p /opt/gluetun-data
ln -sf /opt/gluetun-data /gluetun
# Build .env — only write optional fields if they have values (empty strings crash Gluetun)
{
  cat <<'STATIC'
# Edit this file to configure the VPN, then run: systemctl restart gluetun
# =============================================================================

STATIC

  echo "# VPN provider: protonvpn / mullvad / nordvpn / custom"
  echo "VPN_SERVICE_PROVIDER=${ARRSUITE_VPN_PROVIDER:-protonvpn}"
  echo ""
  echo "# Protocol: wireguard / openvpn"
  echo "VPN_TYPE=${ARRSUITE_VPN_TYPE:-wireguard}"
  echo ""
  echo "# Server filter - optional, comma-separated. Examples: Netherlands, United States, Japan"
  [[ -n "${ARRSUITE_SERVER_COUNTRIES:-}" ]] && echo "SERVER_COUNTRIES=${ARRSUITE_SERVER_COUNTRIES}" || echo "#SERVER_COUNTRIES="
  echo ""
  echo "# WireGuard private key (ProtonVPN: account.proton.me > VPN > WireGuard > create config > PrivateKey)"
  echo "# No quotes. 44-character base64 string ending in ="
  [[ -n "${ARRSUITE_WG_PRIVATE_KEY:-}" ]] && echo "WIREGUARD_PRIVATE_KEY=${ARRSUITE_WG_PRIVATE_KEY}" || echo "#WIREGUARD_PRIVATE_KEY="
  echo ""
  echo "# OpenVPN credentials (only for VPN_TYPE=openvpn)"
  echo "# ProtonVPN: account.proton.me > VPN > OpenVPN/IKEv2 username"
  [[ -n "${ARRSUITE_OPENVPN_USER:-}" ]] && echo "OPENVPN_USER=${ARRSUITE_OPENVPN_USER}" || echo "#OPENVPN_USER="
  [[ -n "${ARRSUITE_OPENVPN_PASSWORD:-}" ]] && echo "OPENVPN_PASSWORD=${ARRSUITE_OPENVPN_PASSWORD}" || echo "#OPENVPN_PASSWORD="
  echo ""
  echo "# Port forwarding — enable for better qBittorrent connectivity (ProtonVPN supports this)"
  echo "#VPN_PORT_FORWARDING=on"
  echo "#PORT_FORWARD_ONLY=on"
  echo ""
  echo "# Custom provider only — DO NOT set these for protonvpn/mullvad/nordvpn (will crash)"
  [[ -n "${ARRSUITE_WG_ADDRESSES:-}" ]] && echo "WIREGUARD_ADDRESSES=${ARRSUITE_WG_ADDRESSES}"
  [[ -n "${ARRSUITE_VPN_ENDPOINT_IP:-}" ]] && echo "VPN_ENDPOINT_IP=${ARRSUITE_VPN_ENDPOINT_IP}"
  [[ -n "${ARRSUITE_VPN_ENDPOINT_PORT:-}" ]] && echo "WIREGUARD_ENDPOINT_PORT=${ARRSUITE_VPN_ENDPOINT_PORT}"
  echo ""
  cat <<'STATIC'
# Gluetun internal settings
FIREWALL_ENABLED_DISABLING_IT_SHOOTS_YOU_IN_YOUR_FOOT=on
HTTP_CONTROL_SERVER_ADDRESS=:8000
LOG_LEVEL=info
STORAGE_FILEPATH=/gluetun/servers.json
PUBLICIP_FILE=/gluetun/ip
TZ=UTC
STATIC
} >/opt/gluetun-data/.env
msg_ok "Configured Gluetun"

msg_info "Creating Gluetun Service"
cat <<EOF >/etc/systemd/system/gluetun.service
[Unit]
Description=Gluetun VPN Client
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/gluetun-data
EnvironmentFile=/opt/gluetun-data/.env
UnsetEnvironment=USER
ExecStart=/usr/local/bin/gluetun
Restart=on-failure
RestartSec=5
AmbientCapabilities=CAP_NET_ADMIN

[Install]
WantedBy=multi-user.target
EOF
msg_ok "Created Service"
# =============================================================================
# QBITTORRENT (mandatory)
# =============================================================================

fetch_and_deploy_gh_release "qbittorrent" "userdocs/qbittorrent-nox-static" "singlefile" "latest" "/opt/qbittorrent" "x86_64-qbittorrent-nox"

msg_info "Setup qBittorrent-nox"
mv /opt/qbittorrent/qbittorrent /opt/qbittorrent/qbittorrent-nox
mkdir -p ~/.config/qBittorrent/

QB_PASSWORD_HASH=$(python3 -c "
import hashlib, base64, os
password = '''${ARRSUITE_QB_PASSWORD:-adminadmin}'''
salt = os.urandom(16)
key = hashlib.pbkdf2_hmac('sha512', password.encode(), salt, 100000)
print('@ByteArray(' + base64.b64encode(salt).decode() + ':' + base64.b64encode(key).decode() + ')')
")

cat <<EOF >~/.config/qBittorrent/qBittorrent.conf
[LegalNotice]
Accepted=true

[Preferences]
Connection\Interface=tun0
Connection\InterfaceName=tun0
WebUI\Password_PBKDF2="${QB_PASSWORD_HASH}"
WebUI\Port=8090
WebUI\UseUPnP=false
WebUI\Username=${ARRSUITE_QB_USERNAME:-admin}

[Network]
PortForwardingEnabled=true
EOF
msg_ok "Setup qBittorrent-nox"

msg_info "Creating qBittorrent Service"
cat <<EOF >/etc/systemd/system/qbittorrent-nox.service
[Unit]
Description=qBittorrent client
After=network.target gluetun.service

[Service]
Type=simple
User=root
ExecStart=/opt/qbittorrent/qbittorrent-nox
Restart=always

[Install]
WantedBy=multi-user.target
EOF
msg_ok "Created qBittorrent Service"

# =============================================================================
# PROWLARR
# =============================================================================

if [[ "$INSTALL_PROWLARR" == true ]]; then
  fetch_and_deploy_gh_release "prowlarr" "Prowlarr/Prowlarr" "prebuild" "latest" "/opt/Prowlarr" "Prowlarr.master*linux-core-x64.tar.gz"

  msg_info "Configuring Prowlarr"
  mkdir -p /var/lib/prowlarr/
  chmod 775 /var/lib/prowlarr/ /opt/Prowlarr
  msg_ok "Configured Prowlarr"

  msg_info "Creating Prowlarr Service"
  cat <<EOF >/etc/systemd/system/prowlarr.service
[Unit]
Description=Prowlarr Daemon
After=syslog.target network.target gluetun.service

[Service]
UMask=0002
Type=simple
ExecStart=/opt/Prowlarr/Prowlarr -nobrowser -data=/var/lib/prowlarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  msg_ok "Created Prowlarr Service"
fi

# =============================================================================
# SONARR
# =============================================================================

if [[ "$INSTALL_SONARR" == true ]]; then
  fetch_and_deploy_gh_release "Sonarr" "Sonarr/Sonarr" "prebuild" "latest" "/opt/Sonarr" "Sonarr.main.*.linux-x64.tar.gz"
  mkdir -p /var/lib/sonarr/
  chmod 775 /var/lib/sonarr/

  msg_info "Creating Sonarr Service"
  cat <<EOF >/etc/systemd/system/sonarr.service
[Unit]
Description=Sonarr Daemon
After=syslog.target network.target gluetun.service

[Service]
Type=simple
ExecStart=/opt/Sonarr/Sonarr -nobrowser -data=/var/lib/sonarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  msg_ok "Created Sonarr Service"
fi

# =============================================================================
# RADARR
# =============================================================================

if [[ "$INSTALL_RADARR" == true ]]; then
  fetch_and_deploy_gh_release "Radarr" "Radarr/Radarr" "prebuild" "latest" "/opt/Radarr" "Radarr.master*linux-core-x64.tar.gz"

  msg_info "Configuring Radarr"
  mkdir -p /var/lib/radarr/
  chmod 775 /var/lib/radarr/ /opt/Radarr/
  msg_ok "Configured Radarr"

  msg_info "Creating Radarr Service"
  cat <<EOF >/etc/systemd/system/radarr.service
[Unit]
Description=Radarr Daemon
After=syslog.target network.target gluetun.service

[Service]
UMask=0002
Type=simple
ExecStart=/opt/Radarr/Radarr -nobrowser -data=/var/lib/radarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  msg_ok "Created Radarr Service"
fi

# =============================================================================
# LIDARR
# =============================================================================

if [[ "$INSTALL_LIDARR" == true ]]; then
  msg_info "Installing Lidarr Dependencies"
  $STD apt install -y \
    libchromaprint-tools \
    mediainfo
  msg_ok "Installed Lidarr Dependencies"

  fetch_and_deploy_gh_release "lidarr" "Lidarr/Lidarr" "prebuild" "latest" "/opt/Lidarr" "Lidarr.master*linux-core-x64.tar.gz"

  msg_info "Configuring Lidarr"
  mkdir -p /var/lib/lidarr/
  chmod 775 /var/lib/lidarr/
  chmod 775 /opt/Lidarr
  msg_ok "Configured Lidarr"

  msg_info "Creating Lidarr Service"
  cat <<EOF >/etc/systemd/system/lidarr.service
[Unit]
Description=Lidarr Daemon
After=syslog.target network.target gluetun.service

[Service]
UMask=0002
Type=simple
ExecStart=/opt/Lidarr/Lidarr -nobrowser -data=/var/lib/lidarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  msg_ok "Created Lidarr Service"
fi

# =============================================================================
# FLARESOLVERR
# =============================================================================

if [[ "$INSTALL_FLARESOLVERR" == true ]]; then
  msg_info "Installing FlareSolverr Dependencies"
  $STD apt-get install -y \
    apt-transport-https \
    xvfb
  msg_ok "Installed FlareSolverr Dependencies"

  msg_info "Installing Chrome"
  setup_deb822_repo \
    "google-chrome" \
    "https://dl.google.com/linux/linux_signing_key.pub" \
    "https://dl.google.com/linux/chrome/deb/" \
    "stable"
  $STD apt update
  $STD apt install -y google-chrome-stable
  rm /etc/apt/sources.list.d/google-chrome.list
  msg_ok "Installed Chrome"

  fetch_and_deploy_gh_release "flaresolverr" "FlareSolverr/FlareSolverr" "prebuild" "latest" "/opt/flaresolverr" "flaresolverr_linux_x64.tar.gz"
  
  msg_info "Creating FlareSolverr Service"
  cat <<EOF >/etc/systemd/system/flaresolverr.service
[Unit]
Description=FlareSolverr
After=network.target gluetun.service

[Service]
SyslogIdentifier=flaresolverr
Restart=always
RestartSec=5
Type=simple
Environment="LOG_LEVEL=info"
Environment="CAPTCHA_SOLVER=none"
WorkingDirectory=/opt/flaresolverr
ExecStart=/opt/flaresolverr/flaresolverr
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
  msg_ok "Created FlareSolverr Service"
fi

msg_info "Enabling Services"
systemctl enable -q gluetun qbittorrent-nox
[[ "$INSTALL_PROWLARR" == true ]] && systemctl enable -q  --now prowlarr
[[ "$INSTALL_SONARR" == true ]] && systemctl enable -q  --now sonarr
[[ "$INSTALL_RADARR" == true ]] && systemctl enable -q  --now radarr
[[ "$INSTALL_LIDARR" == true ]] && systemctl enable -q  --now lidarr
[[ "$INSTALL_FLARESOLVERR" == true ]] && systemctl enable -q  --now flaresolverr
msg_ok "Enabled Services"

motd_ssh
customize
cleanup_lxc
