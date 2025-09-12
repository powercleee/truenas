#!/bin/bash
# create_all_users_groups.sh - Create ALL users and groups for TrueNAS SCALE services
# Total: 61 users across 11 groups

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "${BLUE}=== $1 ===${NC}"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Function to create group
create_group() {
    local groupname=$1
    local gid=$2
    local description=$3

    if ! getent group "$groupname" &>/dev/null; then
        groupadd -g "$gid" "$groupname"
        log_info "Created group: $groupname (GID: $gid) - $description"
    else
        log_warn "Group $groupname already exists"
    fi
}

# Function to create user
create_user() {
    local username=$1
    local uid=$2
    local gid=$3
    local category=$4
    local description=$5
    local home="/mnt/tank/apps/${username}"
    local shell="/bin/false"

    # Special handling for database users
    if [[ "$category" == "Database" ]]; then
        home="/mnt/tank/databases/${username}"
    fi

    if ! id "$username" &>/dev/null; then
        useradd -u "$uid" -g "$gid" -d "$home" -s "$shell" -c "$description" "$username"
        log_info "Created user: $username (UID: $uid, GID: $gid) - $description"
    else
        log_warn "User $username already exists"
    fi
}

# ============================
# CREATE ALL GROUPS (11 total)
# ============================
log_section "Creating Service Groups"

create_group "media" 2000 "Media services with shared access"
create_group "download" 2001 "Download clients"
create_group "monitor" 2002 "Monitoring and observability"
create_group "devops" 2003 "Development and CI/CD"
create_group "database" 2004 "Database services"
create_group "security" 2005 "Security and authentication"
create_group "storage" 2006 "Storage, backup, and recovery"
create_group "web" 2007 "Web applications"
create_group "containers" 2008 "Docker/LXC container management"
create_group "automation" 2009 "Automation and orchestration"
create_group "networking" 2010 "Network services"

# ============================
# CREATE ALL USERS (61 total)
# ============================
log_section "Creating All Service Users"

# Media Services (11 users)
log_info "Creating Media Service Users..."
create_user "plex" 3000 2000 "Media" "Plex Media Server"
create_user "tautulli" 3001 2000 "Media" "Tautulli Stats"
create_user "overseerr" 3002 2000 "Media" "Overseerr Requests"
create_user "radarr" 3003 2000 "Media" "Radarr Movies"
create_user "sonarr" 3004 2000 "Media" "Sonarr TV Shows"
create_user "lidarr" 3005 2000 "Media" "Lidarr Music"
create_user "readarr" 3006 2000 "Media" "Readarr Books"
create_user "prowlarr" 3007 2000 "Media" "Prowlarr Indexer"
create_user "bazarr" 3008 2000 "Media" "Bazarr Subtitles"
create_user "whisparr" 3009 2000 "Media" "Whisparr Content"
create_user "stash" 3010 2000 "Media" "Stash Media Server"

# Download Services (4 users)
log_info "Creating Download Service Users..."
create_user "qbittorrent" 3100 2001 "Download" "qBittorrent"
create_user "sabnzbd" 3101 2001 "Download" "SABnzbd Usenet"
create_user "gluetun" 3102 2001 "Download" "Gluetun VPN"
create_user "flaresolverr" 3103 2001 "Download" "FlareSolverr"

# Security Services (9 users)
log_info "Creating Security Service Users..."
create_user "authentik" 3200 2005 "Security" "Authentik IdP"
create_user "traefik" 3201 2005 "Security" "Traefik Proxy"
create_user "wireguard" 3202 2005 "Security" "WireGuard VPN"
create_user "cloudflared" 3203 2005 "Security" "Cloudflare Tunnel"
create_user "crowdsec" 3204 2005 "Security" "CrowdSec IPS"
create_user "smallstep" 3205 2005 "Security" "Smallstep CA PKI"
create_user "wazuh" 3206 2005 "Security" "Wazuh SIEM/HIDS"
create_user "tarpit" 3207 2005 "Security" "AI Scraper Tar Pit"
create_user "honeypot" 3208 2005 "Security" "Security Honeypot"

# Web Services (4 users)
log_info "Creating Web Service Users..."
create_user "bookstack" 3300 2007 "Web" "BookStack Wiki"
create_user "freshrss" 3301 2007 "Web" "FreshRSS"
create_user "homepage" 3302 2007 "Web" "Homepage Dashboard"
create_user "homarr" 3303 2007 "Web" "Homarr Dashboard"

# DevOps Services (3 users)
log_info "Creating DevOps Service Users..."
create_user "gitlab" 3400 2003 "DevOps" "GitLab CE"
create_user "harbor" 3401 2003 "DevOps" "Harbor Registry"
create_user "awx" 3402 2003 "DevOps" "AWX Ansible"

# Monitoring Services (12 users)
log_info "Creating Monitoring Service Users..."
create_user "prometheus" 3500 2002 "Monitoring" "Prometheus"
create_user "grafana" 3501 2002 "Monitoring" "Grafana"
create_user "alertmanager" 3502 2002 "Monitoring" "AlertManager"
create_user "librenms" 3503 2002 "Monitoring" "LibreNMS"
create_user "uptimekuma" 3504 2002 "Monitoring" "Uptime Kuma"
create_user "gotify" 3505 2002 "Monitoring" "Gotify Notify"
create_user "netdata" 3506 2002 "Monitoring" "Netdata"
create_user "scrutiny" 3507 2002 "Monitoring" "Scrutiny SMART"
create_user "telegraf" 3508 2002 "Monitoring" "Telegraf Agent"
create_user "graylog" 3509 2002 "Monitoring" "Graylog Logs"
create_user "nut" 3510 2002 "Monitoring" "Network UPS Tools"
create_user "speedtest" 3511 2002 "Monitoring" "Speedtest Tracker"

# Container Management Services (2 users)
log_info "Creating Container Management Users..."
create_user "portainer" 3600 2008 "Containers" "Portainer CE"
create_user "watchtower" 3601 2008 "Containers" "Watchtower"

# Storage Services (4 users)
log_info "Creating Storage Service Users..."
create_user "minio" 3700 2006 "Storage" "MinIO S3"
create_user "rclone" 3701 2006 "Storage" "Rclone"
create_user "restic" 3702 2006 "Storage" "Restic Backup"
create_user "velero" 3703 2006 "Storage" "Velero K8s Backup"

# Network Services (3 users)
log_info "Creating Network Service Users..."
create_user "pihole" 3900 2010 "Network" "Pi-hole DNS"
create_user "technitium" 3901 2010 "Network" "Technitium DNS"
create_user "chrony" 3902 2010 "Network" "Chrony NTP"

# Automation Services (3 users)
log_info "Creating Automation Service Users..."
create_user "homeassistant" 4000 2009 "Automation" "Home Assistant"
create_user "nodered" 4001 2009 "Automation" "Node-RED"
create_user "n8n" 4002 2009 "Automation" "n8n Workflow"

# Database Services (6 users - using standard ports as UIDs)
log_info "Creating Database Service Users..."
create_user "postgres" 5432 2004 "Database" "PostgreSQL DB"
create_user "mariadb" 3306 2004 "Database" "MariaDB"
create_user "redis" 6379 2004 "Database" "Redis Cache"
create_user "mongodb" 27017 2004 "Database" "MongoDB"
create_user "elasticsearch" 9200 2004 "Database" "Elasticsearch"
create_user "influxdb" 8086 2004 "Database" "InfluxDB TSDB"

# ============================
# CONFIGURE GROUP MEMBERSHIPS
# ============================
log_section "Configuring Group Memberships"

# Add users to supplementary groups for cross-functional access
log_info "Adding users to supplementary groups..."

# Media services that need download access
for user in radarr sonarr lidarr readarr bazarr whisparr; do
    usermod -a -G download "$user" 2>/dev/null && log_info "Added $user to download group" || true
done

# Download clients that need media access
for user in qbittorrent sabnzbd; do
    usermod -a -G media "$user" 2>/dev/null && log_info "Added $user to media group" || true
done

# Container management that needs docker access
for user in portainer watchtower; do
    usermod -a -G containers "$user" 2>/dev/null && log_info "Added $user to containers group" || true
done

# Monitoring services that need broad access
for user in prometheus grafana telegraf netdata; do
    usermod -a -G monitor "$user" 2>/dev/null && log_info "Added $user to monitor group" || true
done

# Security services that need monitoring access
for user in wazuh crowdsec; do
    usermod -a -G monitor "$user" 2>/dev/null && log_info "Added $user to monitor group" || true
done

# ============================
# CREATE HELPER FILES
# ============================
log_section "Creating Helper Files"

# Create user/group reference file
cat > /root/users_groups_reference.txt << 'EOF'
# TrueNAS SCALE Users and Groups Reference
# ==========================================
# Generated: $(date)

## Service Groups (11 groups)
- media (2000): Media services with shared access
- download (2001): Download clients
- monitor (2002): Monitoring and observability
- devops (2003): Development and CI/CD
- database (2004): Database services
- security (2005): Security and authentication
- storage (2006): Storage, backup, and recovery
- web (2007): Web applications
- containers (2008): Docker/LXC container management
- automation (2009): Automation and orchestration
- networking (2010): Network services

## Service Users by Category (61 users total)

### Media Services (11 users)
- plex (3000): Plex Media Server
- tautulli (3001): Tautulli Stats
- overseerr (3002): Overseerr Requests
- radarr (3003): Radarr Movies
- sonarr (3004): Sonarr TV Shows
- lidarr (3005): Lidarr Music
- readarr (3006): Readarr Books
- prowlarr (3007): Prowlarr Indexer
- bazarr (3008): Bazarr Subtitles
- whisparr (3009): Whisparr Content
- stash (3010): Stash Media Server

### Download Services (4 users)
- qbittorrent (3100): qBittorrent
- sabnzbd (3101): SABnzbd Usenet
- gluetun (3102): Gluetun VPN
- flaresolverr (3103): FlareSolverr

### Security Services (9 users)
- authentik (3200): Authentik IdP
- traefik (3201): Traefik Proxy
- wireguard (3202): WireGuard VPN
- cloudflared (3203): Cloudflare Tunnel
- crowdsec (3204): CrowdSec IPS
- smallstep (3205): Smallstep CA PKI
- wazuh (3206): Wazuh SIEM/HIDS
- tarpit (3207): AI Scraper Tar Pit
- honeypot (3208): Security Honeypot

### Web Services (4 users)
- bookstack (3300): BookStack Wiki
- freshrss (3301): FreshRSS
- homepage (3302): Homepage Dashboard
- homarr (3303): Homarr Dashboard

### DevOps Services (3 users)
- gitlab (3400): GitLab CE
- harbor (3401): Harbor Registry
- awx (3402): AWX Ansible

### Monitoring Services (12 users)
- prometheus (3500): Prometheus
- grafana (3501): Grafana
- alertmanager (3502): AlertManager
- librenms (3503): LibreNMS
- uptimekuma (3504): Uptime Kuma
- gotify (3505): Gotify Notify
- netdata (3506): Netdata
- scrutiny (3507): Scrutiny SMART
- telegraf (3508): Telegraf Agent
- graylog (3509): Graylog Logs
- nut (3510): Network UPS Tools
- speedtest (3511): Speedtest Tracker

### Container Management (2 users)
- portainer (3600): Portainer CE
- watchtower (3601): Watchtower

### Storage Services (4 users)
- minio (3700): MinIO S3
- rclone (3701): Rclone
- restic (3702): Restic Backup
- velero (3703): Velero K8s Backup

### Network Services (3 users)
- pihole (3900): Pi-hole DNS
- technitium (3901): Technitium DNS
- chrony (3902): Chrony NTP

### Automation Services (3 users)
- homeassistant (4000): Home Assistant
- nodered (4001): Node-RED
- n8n (4002): n8n Workflow

### Database Services (6 users)
- postgres (5432): PostgreSQL DB
- mariadb (3306): MariaDB
- redis (6379): Redis Cache
- mongodb (27017): MongoDB
- elasticsearch (9200): Elasticsearch
- influxdb (8086): InfluxDB TSDB
EOF

# Create Docker environment file
cat > /root/docker_users.env << 'EOF'
# Docker Compose User/Group Environment Variables
# Source this in your .env file or docker-compose.yml

# Media Services
PLEX_UID=3000
PLEX_GID=2000
TAUTULLI_UID=3001
TAUTULLI_GID=2000
OVERSEERR_UID=3002
OVERSEERR_GID=2000
RADARR_UID=3003
RADARR_GID=2000
SONARR_UID=3004
SONARR_GID=2000
LIDARR_UID=3005
LIDARR_GID=2000
READARR_UID=3006
READARR_GID=2000
PROWLARR_UID=3007
PROWLARR_GID=2000
BAZARR_UID=3008
BAZARR_GID=2000
WHISPARR_UID=3009
WHISPARR_GID=2000
STASH_UID=3010
STASH_GID=2000

# Download Services
QBITTORRENT_UID=3100
QBITTORRENT_GID=2001
SABNZBD_UID=3101
SABNZBD_GID=2001
GLUETUN_UID=3102
GLUETUN_GID=2001
FLARESOLVERR_UID=3103
FLARESOLVERR_GID=2001

# Security Services
AUTHENTIK_UID=3200
AUTHENTIK_GID=2005
TRAEFIK_UID=3201
TRAEFIK_GID=2005
WIREGUARD_UID=3202
WIREGUARD_GID=2005
CLOUDFLARED_UID=3203
CLOUDFLARED_GID=2005
CROWDSEC_UID=3204
CROWDSEC_GID=2005
SMALLSTEP_UID=3205
SMALLSTEP_GID=2005
WAZUH_UID=3206
WAZUH_GID=2005
TARPIT_UID=3207
TARPIT_GID=2005
HONEYPOT_UID=3208
HONEYPOT_GID=2005

# Web Services
BOOKSTACK_UID=3300
BOOKSTACK_GID=2007
FRESHRSS_UID=3301
FRESHRSS_GID=2007
HOMEPAGE_UID=3302
HOMEPAGE_GID=2007
HOMARR_UID=3303
HOMARR_GID=2007

# DevOps Services
GITLAB_UID=3400
GITLAB_GID=2003
HARBOR_UID=3401
HARBOR_GID=2003
AWX_UID=3402
AWX_GID=2003

# Monitoring Services
PROMETHEUS_UID=3500
PROMETHEUS_GID=2002
GRAFANA_UID=3501
GRAFANA_GID=2002
ALERTMANAGER_UID=3502
ALERTMANAGER_GID=2002
LIBRENMS_UID=3503
LIBRENMS_GID=2002
UPTIMEKUMA_UID=3504
UPTIMEKUMA_GID=2002
GOTIFY_UID=3505
GOTIFY_GID=2002
NETDATA_UID=3506
NETDATA_GID=2002
SCRUTINY_UID=3507
SCRUTINY_GID=2002
TELEGRAF_UID=3508
TELEGRAF_GID=2002
GRAYLOG_UID=3509
GRAYLOG_GID=2002
NUT_UID=3510
NUT_GID=2002
SPEEDTEST_UID=3511
SPEEDTEST_GID=2002

# Container Management
PORTAINER_UID=3600
PORTAINER_GID=2008
WATCHTOWER_UID=3601
WATCHTOWER_GID=2008

# Storage Services
MINIO_UID=3700
MINIO_GID=2006
RCLONE_UID=3701
RCLONE_GID=2006
RESTIC_UID=3702
RESTIC_GID=2006
VELERO_UID=3703
VELERO_GID=2006

# Network Services
PIHOLE_UID=3900
PIHOLE_GID=2010
TECHNITIUM_UID=3901
TECHNITIUM_GID=2010
CHRONY_UID=3902
CHRONY_GID=2010

# Automation Services
HOMEASSISTANT_UID=4000
HOMEASSISTANT_GID=2009
NODERED_UID=4001
NODERED_GID=2009
N8N_UID=4002
N8N_GID=2009

# Database Services
POSTGRES_UID=5432
POSTGRES_GID=2004
MARIADB_UID=3306
MARIADB_GID=2004
REDIS_UID=6379
REDIS_GID=2004
MONGODB_UID=27017
MONGODB_GID=2004
ELASTICSEARCH_UID=9200
ELASTICSEARCH_GID=2004
INFLUXDB_UID=8086
INFLUXDB_GID=2004

# Common Group IDs
MEDIA_GID=2000
DOWNLOAD_GID=2001
MONITOR_GID=2002
DEVOPS_GID=2003
DATABASE_GID=2004
SECURITY_GID=2005
STORAGE_GID=2006
WEB_GID=2007
CONTAINERS_GID=2008
AUTOMATION_GID=2009
NETWORKING_GID=2010
EOF

log_info "Helper files created:"
log_info "  - /root/users_groups_reference.txt"
log_info "  - /root/docker_users.env"

# ============================
# SUMMARY
# ============================
log_section "User and Group Creation Complete!"

# Count results
GROUP_COUNT=$(getent group | grep -E '^(media|download|monitor|devops|database|security|storage|web|containers|automation|networking):' | wc -l)
USER_COUNT=$(getent passwd | grep -E '/mnt/tank/(apps|databases)/' | wc -l)

echo ""
echo "================================================"
echo "              Creation Summary"
echo "================================================"
echo "Groups created/verified: $GROUP_COUNT (expected: 11)"
echo "Users created/verified: $USER_COUNT (expected: 61)"
echo "Helper files created: 2"
echo "================================================"
echo ""
echo "You can verify with:"
echo "  getent group | sort"
echo "  getent passwd | sort"
echo ""
log_info "All users and groups have been created successfully!"