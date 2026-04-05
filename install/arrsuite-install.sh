#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: MickLesk (CanbiZ)
# License: MIT | https://github.com/Scalegj/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/qdm12/gluetun

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

APPS=$(whiptail --title "Arrsuite Application Selection" --checklist \
"Choose applications to install:" 15 58 6 \
"qBittorrent" "BitTorrent client" ON \
"Prowlarr" "Indexer manager" ON \
"Sonarr" "TV Show manager" ON \
"Radarr" "Movie manager" ON \
"Lidarr" "Music manager" ON \
"FlareSolverr" "Cloudflare bypass server" ON 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
  echo -e "\e[1;31m✖ Application selection cancelled. Exiting.\e[0m"
  exit 1
fi

INSTALL_QBITTORRENT=0
INSTALL_PROWLARR=0
INSTALL_SONARR=0
INSTALL_RADARR=0
INSTALL_LIDARR=0
INSTALL_FLARESOLVERR=0

for app in $APPS; do
  case $app in
    '"qBittorrent"') INSTALL_QBITTORRENT=1 ;;
    '"Prowlarr"') INSTALL_PROWLARR=1 ;;
    '"Sonarr"') INSTALL_SONARR=1 ;;
    '"Radarr"') INSTALL_RADARR=1 ;;
    '"Lidarr"') INSTALL_LIDARR=1 ;;
    '"FlareSolverr"') INSTALL_FLARESOLVERR=1 ;;
  esac
done

APP_DEPENDENCIES=()

if [ "$INSTALL_PROWLARR" = "1" ] || [ "$INSTALL_SONARR" = "1" ] || [ "$INSTALL_RADARR" = "1" ] || [ "$INSTALL_LIDARR" = "1" ]; then
  APP_DEPENDENCIES+=("sqlite3")
fi

if [ "$INSTALL_LIDARR" = "1" ]; then
  APP_DEPENDENCIES+=("libchromaprint-tools" "mediainfo")
fi

if [ "$INSTALL_FLARESOLVERR" = "1" ]; then
  APP_DEPENDENCIES+=("apt-transport-https" "xvfb")
  setup_deb822_repo \
    "google-chrome" \
    "https://dl.google.com/linux/linux_signing_key.pub" \
    "https://dl.google.com/linux/chrome/deb/" \
    "stable"
  $STD apt-get update
  APP_DEPENDENCIES+=("google-chrome-stable")
fi

if [ ${#APP_DEPENDENCIES[@]} -gt 0 ]; then
  msg_info "Installing App Dependencies"
  $STD apt-get install -y "${APP_DEPENDENCIES[@]}"
  msg_ok "Installed App Dependencies"
fi

msg_info "Installing Base Dependencies"
$STD apt install -y \
  openvpn \
  wireguard-tools \
  iptables
msg_ok "Installed Base Dependencies"

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
touch /etc/alpine-release
ln -sf /opt/gluetun-data /gluetun
cat <<EOF >/opt/gluetun-data/.env
VPN_SERVICE_PROVIDER=custom
VPN_TYPE=openvpn
OPENVPN_CUSTOM_CONFIG=/opt/gluetun-data/custom.ovpn
OPENVPN_USER=
OPENVPN_PASSWORD=
OPENVPN_PROCESS_USER=root
PUID=0
PGID=0
HTTP_CONTROL_SERVER_ADDRESS=:8000
HTTPPROXY=off
SHADOWSOCKS=off
PPROF_ENABLED=no
PPROF_BLOCK_PROFILE_RATE=0
PPROF_MUTEX_PROFILE_RATE=0
PPROF_HTTP_SERVER_ADDRESS=:6060
FIREWALL_ENABLED_DISABLING_IT_SHOOTS_YOU_IN_YOUR_FOOT=on
HEALTH_SERVER_ADDRESS=127.0.0.1:9999
DNS_UPSTREAM_RESOLVERS=cloudflare
LOG_LEVEL=info
STORAGE_FILEPATH=/gluetun/servers.json
PUBLICIP_FILE=/gluetun/ip
VPN_PORT_FORWARDING_STATUS_FILE=/gluetun/forwarded_port
TZ=UTC
EOF
msg_ok "Configured Gluetun"

msg_info "Creating Service"
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
ExecStartPre=/bin/sh -c 'rm -f /etc/openvpn/target.ovpn'
ExecStart=/usr/local/bin/gluetun
Restart=on-failure
RestartSec=5
AmbientCapabilities=CAP_NET_ADMIN

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now gluetun
msg_ok "Created Service"

if [ "$INSTALL_QBITTORRENT" == "1" ]; then
fetch_and_deploy_gh_release "qbittorrent" "userdocs/qbittorrent-nox-static" "singlefile" "latest" "/opt/qbittorrent" "x86_64-qbittorrent-nox"

msg_info "Setup qBittorrent-nox"
mv /opt/qbittorrent/qbittorrent /opt/qbittorrent/qbittorrent-nox
mkdir -p ~/.config/qBittorrent/
cat <<EOF >~/.config/qBittorrent/qBittorrent.conf
[LegalNotice]
Accepted=true

[Preferences]
WebUI\Password_PBKDF2="@ByteArray(amjeuVrF3xRbgzqWQmes5A==:XK3/Ra9jUmqUc4RwzCtrhrkQIcYczBl90DJw2rT8DFVTss4nxpoRhvyxhCf87ahVE3SzD8K9lyPdpyUCfmVsUg==)"
WebUI\Port=8090
WebUI\UseUPnP=false
WebUI\Username=admin

[Network]
PortForwardingEnabled=false
EOF
msg_ok "Setup qBittorrent-nox"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/qbittorrent-nox.service
[Unit]
Description=qBittorrent client
After=network.target gluetun.service
BindsTo=gluetun.service

[Service]
Type=simple
User=root
ExecStart=/opt/qbittorrent/qbittorrent-nox
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now qbittorrent-nox
msg_ok "Created Service"
fi

if [ "$INSTALL_FLARESOLVERR" == "1" ]; then
fetch_and_deploy_gh_release "flaresolverr" "FlareSolverr/FlareSolverr" "prebuild" "latest" "/opt/flaresolverr" "flaresolverr_linux_x64.tar.gz"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/flaresolverr.service
[Unit]
Description=FlareSolverr
After=network.target gluetun.service
BindsTo=gluetun.service
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
systemctl enable -q --now flaresolverr
msg_ok "Created Service"
fi

if [ "$INSTALL_PROWLARR" == "1" ]; then
fetch_and_deploy_gh_release "prowlarr" "Prowlarr/Prowlarr" "prebuild" "latest" "/opt/Prowlarr" "Prowlarr.master*linux-core-x64.tar.gz"

msg_info "Configuring Prowlarr"
mkdir -p /var/lib/prowlarr/
chmod 775 /var/lib/prowlarr/ /opt/Prowlarr
msg_ok "Configured Prowlarr"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/prowlarr.service
[Unit]
Description=Prowlarr Daemon
After=syslog.target network.target gluetun.service
BindsTo=gluetun.service

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
systemctl enable -q --now prowlarr
msg_ok "Created Service"
fi

if [ "$INSTALL_SONARR" == "1" ]; then
fetch_and_deploy_gh_release "Sonarr" "Sonarr/Sonarr" "prebuild" "latest" "/opt/Sonarr" "Sonarr.main.*.linux-x64.tar.gz"
mkdir -p /var/lib/sonarr/
chmod 775 /var/lib/sonarr/

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/sonarr.service
[Unit]
Description=Sonarr Daemon
After=syslog.target network.target gluetun.service
BindsTo=gluetun.service

[Service]
Type=simple
ExecStart=/opt/Sonarr/Sonarr -nobrowser -data=/var/lib/sonarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now sonarr
msg_ok "Created Service"
fi

if [ "$INSTALL_RADARR" == "1" ]; then
fetch_and_deploy_gh_release "Radarr" "Radarr/Radarr" "prebuild" "latest" "/opt/Radarr" "Radarr.master*linux-core-x64.tar.gz"

msg_info "Configuring Radarr"
mkdir -p /var/lib/radarr/
chmod 775 /var/lib/radarr/ /opt/Radarr/
msg_ok "Configured Radarr"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/radarr.service
[Unit]
Description=Radarr Daemon
After=syslog.target network.target gluetun.service
BindsTo=gluetun.service

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
systemctl enable -q --now radarr
msg_ok "Created Service"
fi

if [ "$INSTALL_LIDARR" == "1" ]; then
fetch_and_deploy_gh_release "lidarr" "Lidarr/Lidarr" "prebuild" "latest" "/opt/Lidarr" "Lidarr.master*linux-core-x64.tar.gz"

msg_info "Configuring Lidarr"
mkdir -p /var/lib/lidarr/
chmod 775 /var/lib/lidarr/
chmod 775 /opt/Lidarr
msg_ok "Configured Lidarr"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/lidarr.service
[Unit]
Description=Lidarr Daemon
After=syslog.target network.target gluetun.service
BindsTo=gluetun.service

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
systemctl enable -q --now lidarr
msg_ok "Created Service"
fi

motd_ssh
customize
cleanup_lxc
