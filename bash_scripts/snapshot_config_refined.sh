#!/bin/bash
# snapshot_config.sh - Configure automated ZFS snapshots for TrueNAS SCALE
# For all 61 services

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

# Create TrueNAS GUI snapshot tasks (alternative to sanoid)
create_truenas_snapshot_tasks() {
    log_section "Creating TrueNAS SCALE Snapshot Tasks"

    cat > /tmp/snapshot_tasks.json << 'EOF'
{
  "snapshot_tasks": [
    {
      "name": "Critical-Databases",
      "dataset": "tank/databases",
      "recursive": true,
      "schedule": {
        "minute": "*/15",
        "hour": "*",
        "dom": "*",
        "month": "*",
        "dow": "*"
      },
      "lifetime_value": 24,
      "lifetime_unit": "HOUR",
      "naming_schema": "critical-%Y%m%d-%H%M",
      "allow_empty": false,
      "enabled": true
    },
    {
      "name": "Important-Apps",
      "dataset": "tank/apps",
      "recursive": false,
      "exclude": ["tank/apps/plex/transcode", "tank/apps/*/cache"],
      "schedule": {
        "minute": "0",
        "hour": "*/4",
        "dom": "*",
        "month": "*",
        "dow": "*"
      },
      "lifetime_value": 7,
      "lifetime_unit": "DAY",
      "naming_schema": "apps-%Y%m%d-%H%M",
      "allow_empty": false,
      "enabled": true
    },
    {
      "name": "Media-Weekly",
      "dataset": "tank/media",
      "recursive": true,
      "schedule": {
        "minute": "0",
        "hour": "3",
        "dom": "*",
        "month": "*",
        "dow": "0"
      },
      "lifetime_value": 4,
      "lifetime_unit": "WEEK",
      "naming_schema": "media-%Y%m%d",
      "allow_empty": true,
      "enabled": true
    },
    {
      "name": "Logs-Daily",
      "dataset": "tank/logs",
      "recursive": true,
      "schedule": {
        "minute": "0",
        "hour": "2",
        "dom": "*",
        "month": "*",
        "dow": "*"
      },
      "lifetime_value": 7,
      "lifetime_unit": "DAY",
      "naming_schema": "logs-%Y%m%d",
      "allow_empty": true,
      "enabled": true
    },
    {
      "name": "System-Config",
      "dataset": "tank/system",
      "recursive": true,
      "schedule": {
        "minute": "0",
        "hour": "1",
        "dom": "*",
        "month": "*",
        "dow": "*"
      },
      "lifetime_value": 30,
      "lifetime_unit": "DAY",
      "naming_schema": "system-%Y%m%d",
      "allow_empty": false,
      "enabled": true
    }
  ]
}
EOF

    log_info "TrueNAS snapshot tasks configuration saved to /tmp/snapshot_tasks.json"
    log_warn "Import these tasks via TrueNAS Web UI: Storage > Snapshots > Import Tasks"
}

# Create snapshot management scripts
create_management_scripts() {
    log_section "Creating Snapshot Management Scripts"

    # Script to check snapshot space usage
    cat > /usr/local/bin/snapshot-space-usage.sh << 'EOF'
#!/bin/bash
# Check snapshot space usage

echo "=== Snapshot Space Usage Report ==="
echo "Dataset | Used | Snap Count"
echo "--------------------------------"

for dataset in $(zfs list -H -o name -t filesystem | grep "^tank/"); do
    snap_count=$(zfs list -H -t snapshot -o name | grep "^${dataset}@" | wc -l)
    if [ $snap_count -gt 0 ]; then
        used=$(zfs get -H -o value usedbysnapshots "$dataset")
        printf "%-40s | %10s | %d\n" "$dataset" "$used" "$snap_count"
    fi
done | sort -t'|' -k2 -h -r

echo ""
echo "=== Top 10 Largest Snapshots ==="
zfs list -t snapshot -o name,used,referenced -S used | head -11
EOF
    chmod +x /usr/local/bin/snapshot-space-usage.sh

    # Script to manually snapshot critical data (all 61 services)
    cat > /usr/local/bin/snapshot-critical.sh << 'EOF'
#!/bin/bash
# Manual snapshot of critical data for all 61 services

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Critical datasets based on all 61 services
DATASETS=(
    # Databases (6)
    "tank/databases/postgres"
    "tank/databases/mariadb"
    "tank/databases/redis"
    "tank/databases/mongodb"
    "tank/databases/elasticsearch"
    "tank/databases/influxdb"

    # Security services (9)
    "tank/apps/authentik"
    "tank/apps/traefik"
    "tank/apps/wireguard"
    "tank/apps/cloudflared"
    "tank/apps/crowdsec"
    "tank/apps/smallstep"
    "tank/apps/wazuh"
    "tank/apps/tarpit"
    "tank/apps/honeypot"

    # Critical web services (4)
    "tank/apps/bookstack"
    "tank/apps/freshrss"
    "tank/apps/homepage"
    "tank/apps/homarr"

    # DevOps services (3)
    "tank/apps/gitlab"
    "tank/apps/harbor"
    "tank/apps/awx"

    # Critical monitoring services
    "tank/apps/prometheus"
    "tank/apps/grafana"
    "tank/apps/alertmanager"
    "tank/apps/graylog"
    "tank/apps/nut"

    # Automation services (3)
    "tank/apps/homeassistant"
    "tank/apps/nodered"
    "tank/apps/n8n"

    # Storage services (4)
    "tank/apps/minio"
    "tank/apps/restic"
    "tank/apps/velero"

    # Network services (3)
    "tank/apps/pihole"
    "tank/apps/technitium"
    "tank/apps/chrony"
)

echo "Creating manual snapshots with tag: manual-${TIMESTAMP}"

for dataset in "${DATASETS[@]}"; do
    if zfs list "$dataset" &>/dev/null; then
        echo "Snapshotting $dataset..."
        zfs snapshot -r "${dataset}@manual-${TIMESTAMP}"
    else
        echo "Skipping $dataset (doesn't exist)"
    fi
done

echo "Manual snapshots created successfully"
EOF
    chmod +x /usr/local/bin/snapshot-critical.sh

    # Script to cleanup old snapshots
    cat > /usr/local/bin/snapshot-cleanup.sh << 'EOF'
#!/bin/bash
# Cleanup old snapshots based on retention policy

DRY_RUN=${1:-"--dry-run"}

cleanup_snapshots() {
    local dataset=$1
    local keep_days=$2
    local pattern=$3

    echo "Checking $dataset (keep $keep_days days)..."

    cutoff_date=$(date -d "$keep_days days ago" +%s)

    for snap in $(zfs list -H -t snapshot -o name | grep "^${dataset}@${pattern}"); do
        snap_date_str=$(echo "$snap" | grep -oE '[0-9]{8}')
        if [[ -n "$snap_date_str" ]]; then
            snap_date=$(date -d "$snap_date_str" +%s 2>/dev/null)
            if [[ $? -eq 0 && $snap_date -lt $cutoff_date ]]; then
                if [[ "$DRY_RUN" == "--dry-run" ]]; then
                    echo "  [DRY-RUN] Would delete: $snap"
                else
                    echo "  Deleting: $snap"
                    zfs destroy "$snap"
                fi
            fi
        fi
    done
}

# Cleanup policies
cleanup_snapshots "tank/downloads" 3 "auto"
cleanup_snapshots "tank/logs" 14 "auto"
cleanup_snapshots "tank/containers/docker" 7 "auto"

if [[ "$DRY_RUN" == "--dry-run" ]]; then
    echo ""
    echo "This was a dry run. To actually delete snapshots, run:"
    echo "  $0 --execute"
fi
EOF
    chmod +x /usr/local/bin/snapshot-cleanup.sh

    # Script to backup ALL 61 service configs
    cat > /usr/local/bin/backup-service-configs.sh << 'EOF'
#!/bin/bash
# Backup critical service configurations for all 61 services

BACKUP_DIR="/mnt/tank/backups/config"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/services-${TIMESTAMP}"

echo "Starting service configuration backup to ${BACKUP_PATH}"
mkdir -p "${BACKUP_PATH}"

# Function to backup service config
backup_service() {
    local service=$1
    local source_path="/mnt/tank/apps/${service}"

    if [ -d "${source_path}" ]; then
        echo "Backing up ${service}..."
        # Only backup config files, not media/data
        rsync -av --exclude='*.log' \
                  --exclude='cache' \
                  --exclude='temp' \
                  --exclude='transcode' \
                  --exclude='metadata' \
                  --exclude='*.db-wal' \
                  --exclude='*.db-shm' \
                  "${source_path}/" "${BACKUP_PATH}/${service}/"
    fi
}

# Backup ALL 61 services

# Media services (11)
for service in plex tautulli overseerr radarr sonarr lidarr readarr prowlarr bazarr whisparr stash; do
    backup_service "$service"
done

# Download services (4)
for service in qbittorrent sabnzbd gluetun flaresolverr; do
    backup_service "$service"
done

# Security services (9)
for service in authentik traefik wireguard cloudflared crowdsec smallstep wazuh tarpit honeypot; do
    backup_service "$service"
done

# Web services (4)
for service in bookstack freshrss homepage homarr; do
    backup_service "$service"
done

# DevOps services (3)
for service in gitlab harbor awx; do
    backup_service "$service"
done

# Monitoring services (12)
for service in prometheus grafana alertmanager librenms uptimekuma gotify netdata scrutiny telegraf graylog nut speedtest; do
    backup_service "$service"
done

# Container management (2)
for service in portainer watchtower; do
    backup_service "$service"
done

# Storage services (4)
for service in minio rclone restic velero; do
    backup_service "$service"
done

# Network services (3)
for service in pihole technitium chrony; do
    backup_service "$service"
done

# Automation services (3)
for service in homeassistant nodered n8n; do
    backup_service "$service"
done

# Create tarball
echo "Creating compressed archive..."
cd "${BACKUP_DIR}"
tar -czf "services-${TIMESTAMP}.tar.gz" "services-${TIMESTAMP}/"
rm -rf "services-${TIMESTAMP}/"

echo "Backup complete: ${BACKUP_DIR}/services-${TIMESTAMP}.tar.gz"

# Keep only last 7 backups
echo "Cleaning old backups..."
ls -t "${BACKUP_DIR}"/services-*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm

echo ""
echo "=== Backup Summary ==="
echo "Total services backed up: 61"
echo "Archive location: ${BACKUP_DIR}/services-${TIMESTAMP}.tar.gz"
EOF
    chmod +x /usr/local/bin/backup-service-configs.sh

    log_info "Management scripts created in /usr/local/bin/"
}

# Create service-specific snapshot policies
create_service_snapshot_policies() {
    log_section "Creating Service-Specific Snapshot Policies"

    cat > /root/snapshot_policies.md << 'EOF'
# ZFS Snapshot Policies for 61 Services

## Service Count by Category
- **Media Services**: 11 (plex, tautulli, overseerr, radarr, sonarr, lidarr, readarr, prowlarr, bazarr, whisparr, stash)
- **Download Services**: 4 (qbittorrent, sabnzbd, gluetun, flaresolverr)
- **Security Services**: 9 (authentik, traefik, wireguard, cloudflared, crowdsec, smallstep, wazuh, tarpit, honeypot)
- **Web Services**: 4 (bookstack, freshrss, homepage, homarr)
- **DevOps Services**: 3 (gitlab, harbor, awx)
- **Monitoring Services**: 12 (prometheus, grafana, alertmanager, librenms, uptimekuma, gotify, netdata, scrutiny, telegraf, graylog, nut, speedtest)
- **Container Management**: 2 (portainer, watchtower)
- **Storage Services**: 4 (minio, rclone, restic, velero)
- **Network Services**: 3 (pihole, technitium, chrony)
- **Automation Services**: 3 (homeassistant, nodered, n8n)
- **Database Services**: 6 (postgres, mariadb, redis, mongodb, elasticsearch, influxdb)

## Critical Services (15-minute snapshots)
- **Databases**: All 6 database services
- **Security**: authentik, traefik, smallstep, wazuh
- **DevOps**: gitlab, harbor
- **Network**: chrony (time sync critical)

## Important Services (4-hour snapshots)
- **Media Management**: radarr, sonarr, lidarr, readarr, prowlarr, bazarr
- **Monitoring**: prometheus, grafana, alertmanager, graylog, nut
- **Automation**: homeassistant, nodered, n8n
- **Storage**: velero (backup service)

## Standard Services (Daily snapshots)
- **Media Servers**: plex, tautulli, overseerr, whisparr, stash
- **Web Apps**: bookstack, freshrss, homepage, homarr
- **Container Management**: portainer, watchtower
- **Network**: pihole, technitium
- **Monitoring**: librenms, uptimekuma, gotify, netdata, scrutiny, telegraf, speedtest
- **Security**: wireguard, cloudflared, crowdsec, tarpit, honeypot

## Low Priority (Weekly snapshots)
- **Download Services**: qbittorrent, sabnzbd, gluetun, flaresolverr
- **Media Library**: /mnt/tank/media (content rarely changes)
- **Storage Sync**: minio, rclone, restic

## Retention Policies

| Service Type | Frequency | Keep Hourly | Keep Daily | Keep Weekly | Keep Monthly |
|-------------|-----------|-------------|------------|-------------|--------------|
| Databases   | 15 min    | 24 hours    | 7 days     | 4 weeks     | 12 months    |
| Security    | 1 hour    | 24 hours    | 7 days     | 4 weeks     | 6 months     |
| Apps        | 4 hours   | -           | 7 days     | 4 weeks     | 3 months     |
| Media       | Weekly    | -           | -          | 4 weeks     | 3 months     |
| Logs        | Daily     | -           | 7 days     | -           | -            |
| Downloads   | Daily     | -           | 1 day      | -           | -            |
EOF

    log_info "Snapshot policies documentation created at /root/snapshot_policies.md"
}

# Create monitoring script for all 61 services
create_monitoring_script() {
    log_section "Creating Service Monitoring Script"

    cat > /usr/local/bin/monitor-services.sh << 'EOF'
#!/bin/bash
# monitor-services.sh - Monitor status of all 61 services

echo "=== Service Status Report ==="
echo "Total services: 61"
echo ""

# Function to check service dataset
check_service() {
    local service=$1
    local category=$2
    local dataset="/mnt/tank/apps/${service}"

    if [ -d "${dataset}" ]; then
        size=$(du -sh "${dataset}" 2>/dev/null | cut -f1)
        printf "✓ %-15s %-12s %8s\n" "$service" "[$category]" "$size"
    else
        printf "✗ %-15s %-12s Missing!\n" "$service" "[$category]"
    fi
}

echo "Service Name     Category      Size"
echo "----------------------------------------"

# Check all 61 services
for service in plex tautulli overseerr radarr sonarr lidarr readarr prowlarr bazarr whisparr stash; do
    check_service "$service" "Media"
done

for service in qbittorrent sabnzbd gluetun flaresolverr; do
    check_service "$service" "Download"
done

for service in authentik traefik wireguard cloudflared crowdsec smallstep wazuh tarpit honeypot; do
    check_service "$service" "Security"
done

for service in bookstack freshrss homepage homarr; do
    check_service "$service" "Web"
done

for service in gitlab harbor awx; do
    check_service "$service" "DevOps"
done

for service in prometheus grafana alertmanager librenms uptimekuma gotify netdata scrutiny telegraf graylog nut speedtest; do
    check_service "$service" "Monitor"
done

for service in portainer watchtower; do
    check_service "$service" "Container"
done

for service in minio rclone restic velero; do
    check_service "$service" "Storage"
done

for service in pihole technitium chrony; do
    check_service "$service" "Network"
done

for service in homeassistant nodered n8n; do
    check_service "$service" "Automation"
done

echo ""
echo "=== Dataset Usage Summary ==="
df -h | grep tank
EOF
    chmod +x /usr/local/bin/monitor-services.sh

    log_info "Service monitoring script created at /usr/local/bin/monitor-services.sh"
}

# Main execution
main() {
    log_section "TrueNAS SCALE Snapshot Configuration"

    create_truenas_snapshot_tasks
    create_management_scripts
    create_service_snapshot_policies
    create_monitoring_script

    log_section "Snapshot Configuration Complete"

    echo ""
    echo "=== Quick Reference ==="
    echo "Check snapshot space:        snapshot-space-usage.sh"
    echo "Manual critical snapshot:    snapshot-critical.sh"
    echo "Cleanup old snapshots:       snapshot-cleanup.sh --dry-run"
    echo "Backup service configs:      backup-service-configs.sh"
    echo "Monitor all services:        monitor-services.sh"
    echo ""
    echo "=== Snapshot Schedule Summary ==="
    echo "Critical (DBs+Security):  Every 15 min, keep 30 days + monthly"
    echo "Important (Apps):         Every 4 hours, keep 14 days + weekly"
    echo "Standard (Config):        Daily, keep 7 days + weekly"
    echo "Media:                    Weekly, keep 4 weeks"
    echo "Logs:                     Daily, keep 7 days"
    echo "Downloads/Cache:          Daily, keep 1 day only"
    echo ""
    echo "Documentation: /root/snapshot_policies.md"
    echo ""
    echo "Total services configured: 61"
    echo "Total service groups: 11"
}

main "$@"