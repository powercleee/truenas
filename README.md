# TrueNAS SCALE 25.10 Infrastructure Automation

This project automates the complete setup of a TrueNAS SCALE infrastructure with 61 services across 11 categories, providing enterprise-grade storage management, user configuration, and automated snapshots using both bash scripts and Ansible.

## Project Overview

This repository implements a comprehensive TrueNAS SCALE 25.10 setup using two complementary approaches:

1. **Bash Scripts** - Direct system setup via SSH commands
2. **Ansible Automation** - API-based infrastructure-as-code using TrueNAS middleware

### Architecture

The repository implements a three-stage setup process:

#### 1. User and Group Management
- Creates 61 system users across 11 service categories
- Establishes proper group structure with appropriate GIDs/UIDs
- Categories include: Media Services, Download Services, Security Services, Network Services, Database Services, Monitoring Services, Backup Services, Development Services, System Services, Communication Services, and Productivity Services
- Each user gets dedicated home directory under `/mnt/tank/apps/` or `/mnt/tank/databases/`

#### 2. Dataset Creation
- Creates ZFS datasets optimized for different service types
- Implements optimized recordsizes (16K for databases, 128K for apps, 1M for media)
- Establishes directory structure with proper ownership and permissions
- Creates datasets for: apps, containers, media, downloads, databases, backups, logs, and system files

#### 3. Snapshot Configuration
- Configures automated ZFS snapshots with different retention policies
- Critical services (databases): 15-minute snapshots, 24-hour retention
- Important services (apps): 4-hour snapshots, 7-day retention
- Media/bulk data: 12-hour snapshots, 30-day retention
- Uses TrueNAS API for native snapshot management

#### 4. Performance Tuning
- Applies 75+ system tunables optimized for container workloads
- Memory management tuned for 192GB RAM systems
- Network optimization for 10GbE performance
- ZFS ARC sizing and I/O optimization
- Uses TrueNAS API with job system for reliable configuration

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

## Quick Start Options

### Option 1: Bash Scripts (Direct Setup)

Execute scripts directly on TrueNAS (must be run as root):

```bash
# Run all scripts in sequence
bash bash_scripts/create_users_groups_refined.sh
bash bash_scripts/complete_dataset_refined.sh
bash bash_scripts/snapshot_config_refined.sh
```

### Option 2: Ansible Automation (Recommended)

**Prerequisites:**
- Ansible 2.9+ installed on control machine
- TrueNAS API key configured
- Python 3.6+ on TrueNAS (included by default)

**TrueNAS API Integration:**
This project uses the **TrueNAS SCALE Middleware API** for:
- User and group management (`/api/v2.0/user`, `/api/v2.0/group`)
- ZFS dataset operations (`/api/v2.0/pool/dataset`)
- File system permissions (`/api/v2.0/filesystem/setperm`)
- Snapshot task management (`/api/v2.0/pool/snapshottask`)
- System tunable configuration (`/api/v2.0/tunable`)
- Job monitoring and async operations (`/api/v2.0/core/get_jobs`)

**Setup:**

1. **Generate TrueNAS API Key**
   - Navigate to System > API Keys in TrueNAS Web UI
   - Create new API key and store securely

2. **Configure Ansible Vault**
   ```bash
   cd ansible
   ansible-vault create group_vars/vault.yml
   # Add: vault_truenas_api_key: "your-api-key-here"
   ```

3. **Update Inventory**
   ```bash
   # Edit inventories/hosts.yml with your TrueNAS IP
   nano inventories/hosts.yml
   ```

4. **Test Connection**
   ```bash
   ansible-playbook test-connection.yml --ask-vault-pass
   ```

5. **Execute Deployment**
   ```bash
   ansible-playbook -i inventories/hosts.yml site.yml --ask-vault-pass
   ```

## ZFS Dataset Layout

```
tank/
├── apps/                  # Application data (128K recordsize)
│   ├── plex/
│   ├── grafana/
│   └── [59 other services]/
├── databases/             # Database storage (16K recordsize)
│   ├── postgres/
│   ├── mariadb/
│   └── [4 other databases]/
├── media/                 # Media files (1M recordsize, no compression)
│   ├── movies/
│   ├── tv/
│   └── music/
├── downloads/             # Download staging (128K recordsize)
├── containers/            # Container runtime (64K recordsize)
├── backups/               # Backup storage (1M recordsize)
├── logs/                  # Application logs (128K recordsize)
└── system/                # System configuration (128K recordsize)
```

## Snapshot Management

The system uses **TrueNAS API** for native snapshot management with optimized schedules:

| Dataset | Frequency | Retention | Purpose |
|---------|-----------|-----------|---------|
| **databases** | Every 15 minutes | 24 hours | Critical data protection |
| **apps** | Every 4 hours | 7 days | Application data backup |
| **containers** | Daily | 7 days | Container runtime data |
| **downloads** | Every 6 hours | 3 days | Temporary download staging |
| **logs** | Daily | 7 days | System and application logs |
| **system** | Daily | 30 days | System configuration |
| **media** | Weekly (Sunday) | 4 weeks | Large media files |
| **backups** | Weekly (Monday) | 8 weeks | Backup repositories |

## Performance Tuning

The system applies **75+ performance tunables** optimized for container workloads on TrueNAS SCALE systems with high-end hardware:

### Memory Management
- **VM Optimization**: Minimal swap usage, optimized dirty page handling
- **Shared Memory**: 96GB configured for database containers
- **ZFS ARC**: 153GB (80% of 192GB RAM) with intelligent metadata caching

### Network Performance
- **10GbE Optimization**: 128MB TCP buffers, BBR congestion control
- **Container Networking**: Expanded port ranges, optimized ARP caches
- **High-throughput**: Increased network device backlogs and socket queues

### ZFS Optimization
- **ARC Tuning**: Intelligent memory allocation with 8GB minimum
- **I/O Scheduling**: Optimized async/sync operations per vdev
- **Transaction Groups**: Reduced timeout for better responsiveness
- **Prefetch**: Configured for sequential workload performance

### Container Support
- **File Handles**: Increased limits for containerized services
- **Async I/O**: Expanded operations for database performance
- **File Monitoring**: Enhanced inotify for container file systems

**Configuration Management:**
- Uses delete-and-recreate strategy for idempotency
- Leverages TrueNAS job system for reliable async operations
- Generates performance report with validation commands
- Separate SYSCTL (immediate) and ZFS (reboot required) tunables


## Verification Commands

```bash
# Verify user creation
getent passwd | grep -E "(plex|sonarr|grafana)"

# Check dataset creation
zfs list | grep tank

# Verify snapshots
zfs list -t snapshot

# Check TrueNAS API snapshot tasks
curl -H "Authorization: Bearer $API_KEY" https://truenas-ip/api/v2.0/pool/snapshottask

# Verify performance tunables
curl -H "Authorization: Bearer $API_KEY" https://truenas-ip/api/v2.0/tunable

# Check current SYSCTL values
sysctl vm.swappiness vm.dirty_ratio net.core.rmem_max

# Monitor ZFS ARC usage
arc_summary

```

## Docker Compose Integration

The deployment creates environment files for easy container deployment:

```yaml
version: '3.8'
services:
  grafana:
    image: grafana/grafana
    user: "${GRAFANA_UID}:${GRAFANA_GID}"
    volumes:
      - /mnt/tank/apps/grafana:/var/lib/grafana
      - /mnt/tank/logs/grafana:/var/log/grafana
    env_file:
      - /tmp/docker_users.env
```

## API Endpoints Used

### Users and Groups
- `GET /api/v2.0/group` - List existing groups
- `POST /api/v2.0/group` - Create groups
- `GET /api/v2.0/user` - List existing users
- `POST /api/v2.0/user` - Create users
- `PUT /api/v2.0/user/id/{id}` - Update user properties

### Datasets and Permissions
- `POST /api/v2.0/pool/dataset` - Create datasets
- `PUT /api/v2.0/pool/dataset/id/{id}` - Update dataset properties
- `POST /api/v2.0/filesystem/setperm` - Set filesystem permissions

### Snapshots
- `GET /api/v2.0/pool/snapshottask` - List snapshot tasks
- `POST /api/v2.0/pool/snapshottask` - Create snapshot tasks
- `PUT /api/v2.0/pool/snapshottask/id/{id}` - Update snapshot tasks

### Performance Tunables
- `GET /api/v2.0/tunable` - List system tunables
- `POST /api/v2.0/tunable` - Create system tunables
- `DELETE /api/v2.0/tunable/id/{id}` - Delete tunables
- `POST /api/v2.0/core/get_jobs` - Monitor async job completion

## Benefits of API Integration

1. **No Direct System Access**: Operations use HTTPS API calls instead of SSH
2. **TrueNAS Integration**: All resources visible and manageable through Web UI
3. **Built-in Validation**: TrueNAS API provides error handling and validation
4. **Consistency**: Uses same code paths as the Web UI
5. **Idempotency**: Safe to run multiple times without conflicts

## Security Considerations

- **User Isolation**: Each service runs as dedicated user with minimal privileges
- **Group-based Access**: Services only access their functional group resources
- **ZFS Security**: Datasets use appropriate permissions and can be encrypted
- **API Security**: All operations authenticated via API key over HTTPS
- **Network Security**: API calls over encrypted HTTPS connections

## File Structure

```
.
├── README.md                                    # This file
├── CLAUDE.md                                   # Claude Code guidance
├── bash_scripts/
│   ├── create_users_groups_refined.sh          # User/group creation (533 lines)
│   ├── complete_dataset_refined.sh             # Dataset creation (537 lines)
│   └── snapshot_config_refined.sh              # Snapshot configuration (519 lines)
└── ansible/
    ├── site.yml                               # Main Ansible playbook
    ├── inventories/hosts.yml                  # Inventory configuration
    ├── group_vars/                            # Global variables
    ├── roles/
    │   ├── users/                             # User management via API
    │   ├── datasets/                          # Dataset creation via API
    │   ├── snapshots/                         # Snapshot configuration via API
    │   ├── security/                          # Security hardening via API
    │   └── performance/                       # Performance tuning via API
    └── templates/                             # Deployment documentation
```

## Development Notes

- All scripts include comprehensive error handling with `set -e`
- Color-coded logging system for clear output (INFO, WARN, ERROR)
- Scripts are idempotent - safe to run multiple times
- Each script validates prerequisites before execution
- Ansible roles use TrueNAS API for all operations
- Generated reference files for Docker Compose integration

## Support

For issues:
1. Check TrueNAS system logs: `/var/log/middlewared.log`
2. Verify API connectivity and authentication
3. Review generated reference files in `/tmp/`
4. Test with individual API endpoints

The scripts must be executed in order and require appropriate privileges (root for bash scripts, API key for Ansible) on a TrueNAS SCALE system with ZFS storage pool named "tank".