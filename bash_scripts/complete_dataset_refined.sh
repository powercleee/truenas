#!/bin/bash
# complete_dataset_setup.sh - Complete dataset creation with ALL 61 users and groups

# Exit on any error
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "${BLUE}=== $1 ===${NC}"; }

# Set default properties for all datasets
DEFAULT_COMPRESSION="lz4"
DEFAULT_ATIME="off"
DEFAULT_XATTR="sa"

# Function to create dataset with properties
create_dataset() {
    local dataset=$1
    local recordsize=${2:-"128K"}
    local compression=${3:-$DEFAULT_COMPRESSION}

    if zfs list "$dataset" &>/dev/null; then
        log_warn "Dataset $dataset already exists - skipping"
    else
        log_info "Creating $dataset with recordsize=$recordsize"
        zfs create  -o recordsize=$recordsize \
                    -o compression=$compression \
                    -o atime=$DEFAULT_ATIME \
                    -o xattr=$DEFAULT_XATTR \
                    "$dataset"
    fi
}

# ============================
# STEP 1: RUN USER CREATION SCRIPT
# ============================
log_section "Creating Users and Groups"

# Check if user creation script exists and run it
if [ -f "/root/create_all_users_groups.sh" ]; then
    log_info "Running user and group creation script..."
    bash /root/create_all_users_groups.sh
else
    log_warn "User creation script not found at /root/create_all_users_groups.sh"
    log_warn "Please run the user creation script first!"
    exit 1
fi

# ============================
# STEP 2: CREATE ALL DATASETS
# ============================
log_section "Creating ZFS Datasets"

# Create main pool datasets
create_dataset "tank/apps" "128K"
create_dataset "tank/containers" "128K"
create_dataset "tank/media" "1M" "off"
create_dataset "tank/downloads" "128K"
create_dataset "tank/databases" "16K"
create_dataset "tank/backups" "1M"
create_dataset "tank/logs" "128K"
create_dataset "tank/system" "128K"

# Create container runtime datasets
create_dataset "tank/containers/docker" "64K"
create_dataset "tank/containers/docker/volumes" "64K"
create_dataset "tank/containers/docker/overlay2" "64K"
create_dataset "tank/containers/docker/containers" "64K"
create_dataset "tank/containers/docker/builder" "64K"
create_dataset "tank/containers/lxc" "128K"

# Create application datasets for ALL 61 services
log_info "Creating application-specific datasets..."

# Define all applications by category
# Media Services (11)
apps_media=(
    "plex" "tautulli" "overseerr" "radarr" "sonarr"
    "lidarr" "readarr" "prowlarr" "bazarr" "whisparr" "stash"
)

# Download Services (4)
apps_download=(
    "qbittorrent" "sabnzbd" "gluetun" "flaresolverr"
)

# Security Services (9)
apps_security=(
    "authentik" "traefik" "wireguard" "cloudflared" "crowdsec"
    "smallstep" "wazuh" "tarpit" "honeypot"
)

# Web Services (4)
apps_web=(
    "bookstack" "freshrss" "homepage" "homarr"
)

# DevOps Services (3)
apps_devops=(
    "gitlab" "harbor" "awx"
)

# Monitoring Services (12)
apps_monitoring=(
    "prometheus" "grafana" "alertmanager" "librenms" "uptimekuma"
    "gotify" "netdata" "scrutiny" "telegraf" "graylog"
    "nut" "speedtest"
)

# Container Management (2)
apps_containers=(
    "portainer" "watchtower"
)

# Storage Services (4)
apps_storage=(
    "minio" "rclone" "restic" "velero"
)

# Network Services (3)
apps_network=(
    "pihole" "technitium" "chrony"
)

# Automation Services (3)
apps_automation=(
    "homeassistant" "nodered" "n8n"
)

# Create all application datasets
for app in "${apps_media[@]}"; do
    create_dataset "tank/apps/$app" "128K"
done

for app in "${apps_download[@]}"; do
    create_dataset "tank/apps/$app" "128K"
done

for app in "${apps_security[@]}"; do
    create_dataset "tank/apps/$app" "128K"
done

for app in "${apps_web[@]}"; do
    create_dataset "tank/apps/$app" "128K"
done

for app in "${apps_devops[@]}"; do
    create_dataset "tank/apps/$app" "128K"
done

for app in "${apps_monitoring[@]}"; do
    create_dataset "tank/apps/$app" "128K"
done

for app in "${apps_containers[@]}"; do
    create_dataset "tank/apps/$app" "128K"
done

for app in "${apps_storage[@]}"; do
    create_dataset "tank/apps/$app" "128K"
done

for app in "${apps_network[@]}"; do
    create_dataset "tank/apps/$app" "128K"
done

for app in "${apps_automation[@]}"; do
    create_dataset "tank/apps/$app" "128K"
done

# MinIO needs larger recordsize for object storage
zfs set recordsize=1M tank/apps/minio 2>/dev/null || true

# Create media subdatasets
for dir in movies tv music books audiobooks podcasts; do
    create_dataset "tank/media/$dir" "1M" "off"
done

# Create download subdatasets
create_dataset "tank/downloads/incomplete" "128K"
create_dataset "tank/downloads/complete" "128K"
create_dataset "tank/downloads/torrents" "128K"
create_dataset "tank/downloads/usenet" "128K"

# Create database datasets with optimized recordsize
create_dataset "tank/databases/postgres" "16K"
create_dataset "tank/databases/mariadb" "16K"
create_dataset "tank/databases/redis" "8K"
create_dataset "tank/databases/mongodb" "16K"
create_dataset "tank/databases/elasticsearch" "16K"
create_dataset "tank/databases/influxdb" "128K"

# Create backup subdatasets
create_dataset "tank/backups/config" "1M"
create_dataset "tank/backups/database" "1M"
create_dataset "tank/backups/snapshots" "1M"
create_dataset "tank/backups/timemachine" "1M"

# Create log subdatasets for ALL 61 services
log_dirs=(
    # Media services (11)
    "plex" "tautulli" "overseerr" "radarr" "sonarr"
    "lidarr" "readarr" "prowlarr" "bazarr" "whisparr" "stash"
    # Download services (4)
    "qbittorrent" "sabnzbd" "gluetun" "flaresolverr"
    # Security services (9)
    "authentik" "traefik" "wireguard" "cloudflared" "crowdsec"
    "smallstep" "wazuh" "tarpit" "honeypot"
    # Web services (4)
    "bookstack" "freshrss" "homepage" "homarr"
    # DevOps services (3)
    "gitlab" "harbor" "awx"
    # Monitoring services (12)
    "prometheus" "grafana" "alertmanager" "librenms" "uptimekuma"
    "gotify" "netdata" "scrutiny" "telegraf" "graylog"
    "nut" "speedtest"
    # Container management (2)
    "portainer" "watchtower"
    # Storage services (4)
    "minio" "rclone" "restic" "velero"
    # Network services (3)
    "pihole" "technitium" "chrony"
    # Automation services (3)
    "homeassistant" "nodered" "n8n"
    # System logs
    "docker" "system" "audit"
)

for dir in "${log_dirs[@]}"; do
    create_dataset "tank/logs/$dir" "128K"
done

# Create system dataset
create_dataset "tank/system/truenas" "128K"
create_dataset "tank/system/ca" "128K"

# ============================
# STEP 3: SET GRANULAR PERMISSIONS
# ============================
log_section "Setting Granular Permissions"

# Function to set permissions safely
set_permissions() {
    local path=$1
    local owner=$2
    local group=$3
    local perms=$4

    if [ -d "$path" ]; then
        chown -R "${owner}:${group}" "$path" 2>/dev/null || log_warn "Could not set ownership on $path"
        chmod -R "$perms" "$path" 2>/dev/null || log_warn "Could not set permissions on $path"
    else
        log_warn "Path $path does not exist"
    fi
}

log_info "Setting permissions for all application directories..."

# Media Services - 750 permissions
for app in "${apps_media[@]}"; do
    set_permissions "/mnt/tank/apps/$app" "$app" "media" "750"
done

# Download Services - 750 permissions
for app in "${apps_download[@]}"; do
    set_permissions "/mnt/tank/apps/$app" "$app" "download" "750"
done

# Security Services - 700 permissions (more restrictive)
for app in "${apps_security[@]}"; do
    set_permissions "/mnt/tank/apps/$app" "$app" "security" "700"
done

# Web Services - 750 permissions
for app in "${apps_web[@]}"; do
    set_permissions "/mnt/tank/apps/$app" "$app" "web" "750"
done

# DevOps Services - 750 permissions
for app in "${apps_devops[@]}"; do
    set_permissions "/mnt/tank/apps/$app" "$app" "devops" "750"
done

# Monitoring Services - 750 permissions
for app in "${apps_monitoring[@]}"; do
    set_permissions "/mnt/tank/apps/$app" "$app" "monitor" "750"
done

# Container Management - 750 permissions
for app in "${apps_containers[@]}"; do
    set_permissions "/mnt/tank/apps/$app" "$app" "containers" "750"
done

# Storage Services - 750 permissions
for app in "${apps_storage[@]}"; do
    set_permissions "/mnt/tank/apps/$app" "$app" "storage" "750"
done

# Network Services - 750 permissions
for app in "${apps_network[@]}"; do
    set_permissions "/mnt/tank/apps/$app" "$app" "networking" "750"
done

# Automation Services - 750 permissions
for app in "${apps_automation[@]}"; do
    set_permissions "/mnt/tank/apps/$app" "$app" "automation" "750"
done

# Set permissions for shared directories
set_permissions "/mnt/tank/media" "plex" "media" "2775"  # SGID bit
set_permissions "/mnt/tank/downloads" "qbittorrent" "download" "2775"  # SGID bit

# Database permissions - very restrictive
set_permissions "/mnt/tank/databases/postgres" "postgres" "database" "700"
set_permissions "/mnt/tank/databases/mariadb" "mariadb" "database" "700"
set_permissions "/mnt/tank/databases/redis" "redis" "database" "700"
set_permissions "/mnt/tank/databases/mongodb" "mongodb" "database" "700"
set_permissions "/mnt/tank/databases/elasticsearch" "elasticsearch" "database" "700"
set_permissions "/mnt/tank/databases/influxdb" "influxdb" "database" "700"

# Backup permissions
set_permissions "/mnt/tank/backups" "root" "storage" "750"

# Container runtime permissions
set_permissions "/mnt/tank/containers/docker" "root" "containers" "710"

# System permissions
set_permissions "/mnt/tank/system" "root" "root" "700"

# Log permissions - special handling for write-only
log_info "Setting write-only permissions for log directories..."
chown root:monitor "/mnt/tank/logs"
chmod 755 "/mnt/tank/logs"

for dir in "${log_dirs[@]}"; do
    if [ -d "/mnt/tank/logs/$dir" ]; then
        chown root:monitor "/mnt/tank/logs/$dir"
        chmod 733 "/mnt/tank/logs/$dir"  # Write-only for services
    fi
done

# System and audit logs - special permissions
chown root:monitor "/mnt/tank/logs/system" 2>/dev/null || true
chmod 750 "/mnt/tank/logs/system" 2>/dev/null || true
chown root:security "/mnt/tank/logs/audit" 2>/dev/null || true
chmod 700 "/mnt/tank/logs/audit" 2>/dev/null || true

# Set ACLs for cross-group access if available
if command -v setfacl &>/dev/null; then
    log_info "Setting ACLs for cross-group access..."
    # Allow media group to read/write downloads
    setfacl -R -m g:media:rwx /mnt/tank/downloads 2>/dev/null || true
    setfacl -R -d -m g:media:rwx /mnt/tank/downloads 2>/dev/null || true

    # Allow download group to read media (for hardlinks)
    setfacl -R -m g:download:rx /mnt/tank/media 2>/dev/null || true
    setfacl -R -d -m g:download:rx /mnt/tank/media 2>/dev/null || true
fi

# ============================
# STEP 4: CREATE DOCKER CONFIG
# ============================
log_section "Creating Docker Configuration"

if command -v docker &>/dev/null; then
    # Create Docker daemon configuration
    cat > /etc/docker/daemon.json << 'EOF'
{
  "data-root": "/mnt/tank/containers/docker",
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false
}
EOF

    log_info "Docker configuration created"
    log_warn "Restart Docker daemon to apply changes: systemctl restart docker"
fi

# ============================
# CREATE SUPPLEMENTARY SCRIPTS
# ============================
log_section "Creating Supplementary Scripts"

# Create a permissions verification script
cat > /root/verify_permissions.sh << 'EOF'
#!/bin/bash
# verify_permissions.sh - Verify dataset permissions

echo "=== Dataset Permissions Verification ==="
echo ""

echo "App Directories:"
echo "----------------"
for app in /mnt/tank/apps/*; do
    if [ -d "$app" ]; then
        stat -c "%n: %U:%G %a" "$app"
    fi
done | sort

echo ""
echo "Database Directories:"
echo "--------------------"
for db in /mnt/tank/databases/*; do
    if [ -d "$db" ]; then
        stat -c "%n: %U:%G %a" "$db"
    fi
done | sort

echo ""
echo "Shared Directories:"
echo "------------------"
stat -c "%n: %U:%G %a" /mnt/tank/media
stat -c "%n: %U:%G %a" /mnt/tank/downloads
stat -c "%n: %U:%G %a" /mnt/tank/backups

echo ""
echo "ZFS Dataset Count:"
echo "-----------------"
echo "Total datasets: $(zfs list -H -o name | grep -c '^tank/')"
echo "App datasets: $(zfs list -H -o name | grep -c '^tank/apps/')"
echo "Database datasets: $(zfs list -H -o name | grep -c '^tank/databases/')"
EOF
chmod +x /root/verify_permissions.sh

# Create a service health check script
cat > /root/check_services.sh << 'EOF'
#!/bin/bash
# check_services.sh - Check if services can write to their directories

echo "=== Service Write Permission Check ==="
echo ""

test_write() {
    local user=$1
    local dir=$2

    if su -s /bin/sh -c "touch $dir/.test_write 2>/dev/null && rm $dir/.test_write 2>/dev/null" "$user"; then
        echo "✓ $user can write to $dir"
    else
        echo "✗ $user CANNOT write to $dir"
    fi
}

# Test media services
echo "Media Services:"
for app in plex tautulli overseerr radarr sonarr; do
    if id "$app" &>/dev/null && [ -d "/mnt/tank/apps/$app" ]; then
        test_write "$app" "/mnt/tank/apps/$app"
    fi
done

echo ""
echo "Security Services:"
for app in authentik traefik wireguard crowdsec wazuh; do
    if id "$app" &>/dev/null && [ -d "/mnt/tank/apps/$app" ]; then
        test_write "$app" "/mnt/tank/apps/$app"
    fi
done

echo ""
echo "Download Services:"
for app in qbittorrent sabnzbd; do
    if id "$app" &>/dev/null && [ -d "/mnt/tank/apps/$app" ]; then
        test_write "$app" "/mnt/tank/apps/$app"
    fi
done

echo ""
echo "Cross-permissions (media/download):"
if id "radarr" &>/dev/null; then
    test_write "radarr" "/mnt/tank/downloads/complete"
fi
if id "qbittorrent" &>/dev/null; then
    echo -n "qbittorrent read test on /mnt/tank/media: "
    if su -s /bin/sh -c "ls /mnt/tank/media >/dev/null 2>&1" "qbittorrent"; then
        echo "✓ Can read"
    else
        echo "✗ Cannot read"
    fi
fi
EOF
chmod +x /root/check_services.sh

# ============================
# SUMMARY
# ============================
log_section "Setup Complete!"

echo ""
echo "================================================"
echo "Dataset and User Creation Summary"
echo "================================================"
echo "Datasets created: $(zfs list -H -o name | grep -c '^tank/')"
echo "Users configured: 61"
echo "Groups configured: 11"
echo "================================================"
echo ""
echo "Service Categories:"
echo "  Media Services: 11 users"
echo "  Download Services: 4 users"
echo "  Security Services: 9 users"
echo "  Web Services: 4 users"
echo "  DevOps Services: 3 users"
echo "  Monitoring Services: 12 users"
echo "  Container Management: 2 users"
echo "  Storage Services: 4 users"
echo "  Network Services: 3 users"
echo "  Automation Services: 3 users"
echo "  Database Services: 6 users"
echo ""
echo "Helper files available:"
echo "  - /root/users_groups_reference.txt"
echo "  - /root/docker_users.env"
echo "  - /root/verify_permissions.sh"
echo "  - /root/check_services.sh"
echo ""
echo "Next steps:"
echo "1. Review permissions: /root/verify_permissions.sh"
echo "2. Test service access: /root/check_services.sh"
echo "3. Configure your Docker containers with appropriate UIDs/GIDs"
echo "4. Set up snapshots with: /root/snapshot_config.sh"
echo ""
log_info "Script execution completed successfully!"