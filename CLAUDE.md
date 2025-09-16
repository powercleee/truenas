# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains TrueNAS SCALE 25.10 setup scripts for comprehensive self-hosted infrastructure management. The project consists of three main bash scripts that automate the complete setup of a TrueNAS server with 61 different services across 11 categories.

## Architecture

The repository implements a three-stage setup process:

### 1. User and Group Management (`create_users_groups_refined.sh`)
- Creates 61 system users across 11 service categories
- Establishes proper group structure with appropriate GIDs/UIDs
- Categories include: Media Services, Download Services, Security Services, Network Services, Database Services, Monitoring Services, Backup Services, Development Services, System Services, Communication Services, and Productivity Services
- Each user gets dedicated home directory under `/mnt/tank/apps/` or `/mnt/tank/databases/`

### 2. Dataset Creation (`complete_dataset_refined.sh`)
- Creates ZFS datasets optimized for different service types
- Implements performance tuning with appropriate recordsizes (16K for databases, 128K for apps, 1M for media)
- Establishes directory structure with proper ownership and permissions
- Creates datasets for: apps, containers, media, downloads, databases, backups, logs, and system files

### 3. Snapshot Configuration (`snapshot_config_refined.sh`)
- Configures automated ZFS snapshots with different retention policies
- Critical services (databases): 15-minute snapshots, 24-hour retention
- Important services (apps): 4-hour snapshots, 7-day retention
- Media/bulk data: 12-hour snapshots, 30-day retention
- Supports both TrueNAS GUI integration and sanoid configurations

## Service Categories and Structure

The scripts manage 61 services organized into:

- **Media Services (11)**: plex, tautulli, overseerr, radarr, sonarr, lidarr, readarr, prowlarr, bazarr, whisparr, stash
- **Download Services (4)**: qbittorrent, sabnzbd, gluetun, flaresolverr
- **Security Services (9)**: authentik, traefik, wireguard, cloudflared, crowdsec, smallstep, wazuh, tarpit, honeypot
- **Network Services (7)**: adguardhome, unifi, nginx, pihole, netbootxyz, technitium, opnsense
- **Database Services (6)**: postgresql, mariadb, redis, influxdb, mongodb, clickhouse
- **Monitoring Services (8)**: grafana, prometheus, uptime-kuma, ntopng, librenms, zabbix, observium, checkmk
- **Backup Services (4)**: duplicati, restic, borgbackup, rclone
- **Development Services (5)**: gitea, jenkins, nexus, portainer, vscode
- **System Services (3)**: homepage, dozzle, watchtower
- **Communication Services (2)**: matrix, jitsi
- **Productivity Services (2)**: nextcloud, onlyoffice

## Common Commands

### Script Execution
```bash
# Run all scripts in sequence (must be executed as root on TrueNAS):
bash bash_scripts/create_users_groups_refined.sh
bash bash_scripts/complete_dataset_refined.sh
bash bash_scripts/snapshot_config_refined.sh
```

### Verification Commands
```bash
# Verify user creation
getent passwd | grep -E "(plex|sonarr|grafana)"

# Check dataset creation
zfs list | grep tank

# Verify snapshots
zfs list -t snapshot
```

## Development Notes

- All scripts include comprehensive error handling with `set -e`
- Color-coded logging system for clear output (INFO, WARN, ERROR)
- Scripts are designed to be idempotent - safe to run multiple times
- Each script validates prerequisites before execution
- Proper ZFS property optimization for different workload types

## File Structure
```
.
├── README.md                                    # Basic project description
├── bash_scripts/
│   ├── create_users_groups_refined.sh          # User/group creation (533 lines)
│   ├── complete_dataset_refined.sh             # Dataset creation (537 lines) 
│   └── snapshot_config_refined.sh              # Snapshot configuration (519 lines)
└── CLAUDE.md                                   # This file
```

The scripts must be executed in order and require root privileges on a TrueNAS SCALE system with ZFS storage pool named "tank".