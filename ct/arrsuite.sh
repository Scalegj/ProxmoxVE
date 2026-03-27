#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/Scalegj/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Scalegj
# License: MIT | https://github.com/Scalegj/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/qdm12/gluetun | https://www.qbittorrent.org/ | https://prowlarr.com/ | https://sonarr.tv/ | https://radarr.video/ | https://lidarr.audio/ | https://github.com/FlareSolverr/FlareSolverr

APP="ArrSuite"
var_tags="${var_tags:-arr;torrent;vpn}"
var_cpu="${var_cpu:-4}"
var_ram="${var_ram:-8192}"
var_disk="${var_disk:-20}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"
var_tun="${var_tun:-yes}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /usr/local/bin/gluetun ]] || [[ ! -f /etc/systemd/system/qbittorrent-nox.service ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  # Update Gluetun
  if [[ -f /usr/local/bin/gluetun ]]; then
    if check_for_gh_release "gluetun" "qdm12/gluetun"; then
      msg_info "Stopping Gluetun"
      systemctl stop gluetun
      msg_ok "Stopped Gluetun"

      CLEAN_INSTALL=1 fetch_and_deploy_gh_release "gluetun" "qdm12/gluetun" "tarball"

      msg_info "Building Gluetun"
      cd /opt/gluetun
      $STD go mod download
      CGO_ENABLED=0 $STD go build -trimpath -ldflags="-s -w" -o /usr/local/bin/gluetun ./cmd/gluetun/
      msg_ok "Built Gluetun"

      msg_info "Starting Gluetun"
      systemctl start gluetun
      msg_ok "Started Gluetun"
      msg_ok "Updated Gluetun successfully!"
    fi
  fi

  # Update qBittorrent
  if [[ -f /etc/systemd/system/qbittorrent-nox.service ]]; then
    if check_for_gh_release "qbittorrent" "userdocs/qbittorrent-nox-static"; then
      msg_info "Stopping qBittorrent"
      systemctl stop qbittorrent-nox
      msg_ok "Stopped qBittorrent"

      rm -f /opt/qbittorrent/qbittorrent-nox
      fetch_and_deploy_gh_release "qbittorrent" "userdocs/qbittorrent-nox-static" "singlefile" "latest" "/opt/qbittorrent" "x86_64-qbittorrent-nox"
      mv /opt/qbittorrent/qbittorrent /opt/qbittorrent/qbittorrent-nox

      msg_info "Starting qBittorrent"
      systemctl start qbittorrent-nox
      msg_ok "Started qBittorrent"
      msg_ok "Updated qBittorrent successfully!"
    fi
  fi

  # Update Prowlarr
  if [[ -d /var/lib/prowlarr ]]; then
    if check_for_gh_release "prowlarr" "Prowlarr/Prowlarr"; then
      msg_info "Stopping Prowlarr"
      systemctl stop prowlarr
      msg_ok "Stopped Prowlarr"

      rm -rf /opt/Prowlarr
      fetch_and_deploy_gh_release "prowlarr" "Prowlarr/Prowlarr" "prebuild" "latest" "/opt/Prowlarr" "Prowlarr.master*linux-core-x64.tar.gz"
      chmod 775 /opt/Prowlarr

      msg_info "Starting Prowlarr"
      systemctl start prowlarr
      msg_ok "Started Prowlarr"
      msg_ok "Updated Prowlarr successfully!"
    fi
  fi

  # Update Sonarr
  if [[ -d /var/lib/sonarr ]]; then
    msg_info "Stopping Sonarr"
    systemctl stop sonarr
    msg_ok "Stopped Sonarr"

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "Sonarr" "Sonarr/Sonarr" "prebuild" "latest" "/opt/Sonarr" "Sonarr.main.*.linux-x64.tar.gz"

    msg_info "Starting Sonarr"
    systemctl start sonarr
    msg_ok "Started Sonarr"
    msg_ok "Updated Sonarr successfully!"
  fi

  # Update Radarr
  if [[ -d /var/lib/radarr ]]; then
    if check_for_gh_release "Radarr" "Radarr/Radarr"; then
      msg_info "Stopping Radarr"
      systemctl stop radarr
      msg_ok "Stopped Radarr"

      rm -rf /opt/Radarr
      fetch_and_deploy_gh_release "Radarr" "Radarr/Radarr" "prebuild" "latest" "/opt/Radarr" "Radarr.master*linux-core-x64.tar.gz"
      chmod 775 /opt/Radarr

      msg_info "Starting Radarr"
      systemctl start radarr
      msg_ok "Started Radarr"
      msg_ok "Updated Radarr successfully!"
    fi
  fi

  # Update Lidarr
  if [[ -d /var/lib/lidarr ]]; then
    if check_for_gh_release "lidarr" "Lidarr/Lidarr"; then
      msg_info "Stopping Lidarr"
      systemctl stop lidarr
      msg_ok "Stopped Lidarr"

      fetch_and_deploy_gh_release "lidarr" "Lidarr/Lidarr" "prebuild" "latest" "/opt/Lidarr" "Lidarr.master*linux-core-x64.tar.gz"
      chmod 775 /opt/Lidarr

      msg_info "Starting Lidarr"
      systemctl start lidarr
      msg_ok "Started Lidarr"
      msg_ok "Updated Lidarr successfully!"
    fi
  fi

  # Update FlareSolverr
  if [[ -f /etc/systemd/system/flaresolverr.service ]]; then
    if check_for_gh_release "flaresolverr" "FlareSolverr/FlareSolverr"; then
      msg_info "Stopping FlareSolverr"
      systemctl stop flaresolverr
      msg_ok "Stopped FlareSolverr"

      rm -rf /opt/flaresolverr
      fetch_and_deploy_gh_release "flaresolverr" "FlareSolverr/FlareSolverr" "prebuild" "latest" "/opt/flaresolverr" "flaresolverr_linux_x64.tar.gz"

      msg_info "Starting FlareSolverr"
      systemctl start flaresolverr
      msg_ok "Started FlareSolverr"
      msg_ok "Updated FlareSolverr successfully!"
    fi
  fi

  exit
}

start

# Component selection
COMPONENTS=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
  --title "ArrSuite - Optional Components" \
  --checklist "\nSelect optional components to install:\n" 18 70 5 \
  "prowlarr" "Prowlarr  - Indexer Manager" ON \
  "sonarr" "Sonarr    - TV Series" OFF \
  "radarr" "Radarr    - Movies" OFF \
  "lidarr" "Lidarr    - Music" OFF \
  "flaresolverr" "FlareSolverr - Cloudflare Bypass (~300MB)" OFF \
  3>&1 1>&2 2>&3) || exit
if [[ "$COMPONENTS" == *"prowlarr"* ]]; then export INSTALL_PROWLARR=true; else export INSTALL_PROWLARR=false; fi
if [[ "$COMPONENTS" == *"sonarr"* ]]; then export INSTALL_SONARR=true; else export INSTALL_SONARR=false; fi
if [[ "$COMPONENTS" == *"radarr"* ]]; then export INSTALL_RADARR=true; else export INSTALL_RADARR=false; fi
if [[ "$COMPONENTS" == *"lidarr"* ]]; then export INSTALL_LIDARR=true; else export INSTALL_LIDARR=false; fi
if [[ "$COMPONENTS" == *"flaresolverr"* ]]; then export INSTALL_FLARESOLVERR=true; else export INSTALL_FLARESOLVERR=false; fi

# VPN configuration
ARRSUITE_VPN_PROVIDER=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
  --title "ArrSuite - VPN Provider" \
  --radiolist "\nSelect VPN Provider (credentials can be set later via Proxmox GUI):\n" 16 70 4 \
  "protonvpn" "ProtonVPN (recommended)" ON \
  "mullvad" "Mullvad" OFF \
  "nordvpn" "NordVPN" OFF \
  "custom" "Custom WireGuard / OpenVPN" OFF \
  3>&1 1>&2 2>&3) || exit

ARRSUITE_VPN_TYPE=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
  --title "ArrSuite - VPN Protocol" \
  --radiolist "\nSelect VPN Protocol:\n" 12 60 2 \
  "wireguard" "WireGuard (recommended)" ON \
  "openvpn" "OpenVPN" OFF \
  3>&1 1>&2 2>&3) || exit

ARRSUITE_SERVER_COUNTRIES=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
  --title "ArrSuite - VPN Country" \
  --inputbox "\nPreferred country for auto server selection (leave empty for automatic).\nExamples: Netherlands, Sweden, Switzerland, United States, Canada, Japan, Germany, United Kingdom" 12 70 "" \
  3>&1 1>&2 2>&3) || exit

ARRSUITE_WG_PRIVATE_KEY=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
  --title "ArrSuite - WireGuard Private Key" \
  --inputbox "\nWireGuard Private Key:\n(leave empty to configure later in Proxmox GUI → Container → Options → Environment)" 12 70 "" \
  3>&1 1>&2 2>&3) || exit

if [[ "$ARRSUITE_VPN_PROVIDER" == "custom" ]]; then
  ARRSUITE_WG_ADDRESSES=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
    --title "ArrSuite - WireGuard Addresses" \
    --inputbox "\nWireGuard Addresses (e.g. 10.8.0.2/32):" 10 70 "" \
    3>&1 1>&2 2>&3) || exit
  ARRSUITE_VPN_ENDPOINT_IP=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
    --title "ArrSuite - VPN Endpoint IP" \
    --inputbox "\nVPN Endpoint IP:" 10 70 "" \
    3>&1 1>&2 2>&3) || exit
  ARRSUITE_VPN_ENDPOINT_PORT=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
    --title "ArrSuite - VPN Endpoint Port" \
    --inputbox "\nVPN Endpoint Port:" 10 70 "51820" \
    3>&1 1>&2 2>&3) || exit
fi

if [[ "$ARRSUITE_VPN_TYPE" == "openvpn" ]]; then
  ARRSUITE_OPENVPN_USER=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
    --title "ArrSuite - OpenVPN Username" \
    --inputbox "\nOpenVPN Username:" 10 70 "" \
    3>&1 1>&2 2>&3) || exit
  ARRSUITE_OPENVPN_PASSWORD=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
    --title "ArrSuite - OpenVPN Password" \
    --passwordbox "\nOpenVPN Password:" 10 70 "" \
    3>&1 1>&2 2>&3) || exit
fi

ARRSUITE_QB_USERNAME=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
  --title "ArrSuite - qBittorrent Username" \
  --inputbox "\nSet a username for the qBittorrent WebUI:" 10 70 "admin" \
  3>&1 1>&2 2>&3) || exit

ARRSUITE_QB_PASSWORD=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
  --title "ArrSuite - qBittorrent Password" \
  --passwordbox "\nSet a password for the qBittorrent WebUI:" 10 70 "" \
  3>&1 1>&2 2>&3) || exit

export ARRSUITE_VPN_PROVIDER ARRSUITE_VPN_TYPE ARRSUITE_SERVER_COUNTRIES \
  ARRSUITE_WG_PRIVATE_KEY ARRSUITE_WG_ADDRESSES \
  ARRSUITE_VPN_ENDPOINT_IP ARRSUITE_VPN_ENDPOINT_PORT \
  ARRSUITE_OPENVPN_USER ARRSUITE_OPENVPN_PASSWORD \
  ARRSUITE_QB_USERNAME ARRSUITE_QB_PASSWORD

build_container
description

# Store VPN settings as LXC environment variables (visible/editable in Proxmox GUI)
{
  echo "lxc.environment: VPN_SERVICE_PROVIDER=${ARRSUITE_VPN_PROVIDER:-protonvpn}"
  echo "lxc.environment: VPN_TYPE=${ARRSUITE_VPN_TYPE:-wireguard}"
  echo "lxc.environment: SERVER_COUNTRIES=${ARRSUITE_SERVER_COUNTRIES:-}"
  echo "lxc.environment: WIREGUARD_PRIVATE_KEY=${ARRSUITE_WG_PRIVATE_KEY:-}"
  echo "lxc.environment: WIREGUARD_ADDRESSES=${ARRSUITE_WG_ADDRESSES:-}"
  echo "lxc.environment: VPN_ENDPOINT_IP=${ARRSUITE_VPN_ENDPOINT_IP:-}"
  echo "lxc.environment: VPN_ENDPOINT_PORT=${ARRSUITE_VPN_ENDPOINT_PORT:-51820}"
  echo "lxc.environment: OPENVPN_USER=${ARRSUITE_OPENVPN_USER:-}"
  echo "lxc.environment: OPENVPN_PASSWORD=${ARRSUITE_OPENVPN_PASSWORD:-}"
} >> "/etc/pve/lxc/${CTID}.conf"
pct reboot "$CTID"

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} VPN config is stored at:${CL}"
echo -e "${TAB}${BGN}/opt/gluetun-data/.env${CL}${YW} inside the container${CL}"
echo -e "${TAB}${YW}Edit it with: ${BGN}pct exec ${CTID} -- nano /opt/gluetun-data/.env${CL}"
echo -e "${TAB}${YW}Then restart Gluetun: ${BGN}pct exec ${CTID} -- systemctl restart gluetun${CL}"
echo -e "${INFO}${YW} Service ports:${CL}"
echo -e "${TAB}${YW}Gluetun control:  ${BGN}http://${IP}:8000${CL}"
echo -e "${TAB}${YW}qBittorrent:      ${BGN}http://${IP}:8090${CL} (${ARRSUITE_QB_USERNAME:-admin} / your chosen password)"
echo -e "${TAB}${YW}Prowlarr:         ${BGN}http://${IP}:9696${CL}"
echo -e "${TAB}${YW}Sonarr:           ${BGN}http://${IP}:8989${CL}"
echo -e "${TAB}${YW}Radarr:           ${BGN}http://${IP}:7878${CL}"
echo -e "${TAB}${YW}Lidarr:           ${BGN}http://${IP}:8686${CL}"
echo -e "${TAB}${YW}FlareSolverr:     ${BGN}http://${IP}:8191${CL}"

