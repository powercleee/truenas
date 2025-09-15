# TrueNAS SCALE Ansible Infrastructure

This Ansible project automates the complete setup of a TrueNAS SCALE infrastructure with 61 services across 11 categories, providing enterprise-grade storage management, user configuration, and automated snapshots.

## Project Overview

This Ansible implementation replaces the original bash scripts with a more maintainable, idempotent, and scalable infrastructure-as-code approach for TrueNAS SCALE 25.10.

### TrueNAS API Integration

**Important**: This project uses the **TrueNAS SCALE Middleware API** instead of direct system commands for:
- User and group management (`/api/v2.0/user`, `/api/v2.0/group`)
- ZFS dataset operations (`/api/v2.0/pool/dataset`)
- File system permissions (`/api/v2.0/filesystem/setperm`)

This ensures compatibility with TrueNAS SCALE's middleware and prevents conflicts with the web interface.

### Dependency Resolution

The 4-phase execution sequence resolves the circular dependency where:
- **Users require datasets** (for home directory paths)
- **Dataset permissions require users** (for ownership assignment)

The solution separates dataset creation from permission assignment, allowing proper sequencing.

### What This Does

- Creates **61 service users** across **11 functional groups**
- Sets up **optimized ZFS datasets** with appropriate record sizes
- Configures **automated snapshot management** with retention policies
- Establishes **proper permissions** for containerized applications
- Provides **comprehensive logging and reporting**

## Quick Start

### Prerequisites

- **Control Machine**: Ansible 2.9+ installed (see [CONTROL_MACHINE_SETUP.md](CONTROL_MACHINE_SETUP.md))
- **TrueNAS System**: Python 3.6+ (included by default)
- **Dedicated User**: `ansible` user with SSH key authentication
- **Storage**: ZFS pool named `tank` (or customize in inventory)

**⚠️ Important:** This project uses a dedicated `ansible` user with admin privileges for API operations. The playbook runs locally and connects via HTTPS API calls instead of SSH.

### Setup Guides

📋 **[CONTROL_MACHINE_SETUP.md](CONTROL_MACHINE_SETUP.md)** - Install Ansible on your laptop/server
📋 **[PRE_BOOTSTRAP_CHECKLIST.md](PRE_BOOTSTRAP_CHECKLIST.md)** - Prepare TrueNAS for automation
📋 **[ANSIBLE_USER_SETUP.md](ANSIBLE_USER_SETUP.md)** - Detailed ansible user configuration

### Installation

1. **Clone and Setup**
   ```bash
   git clone <this-repo>
   cd truenas/ansible

   # Install required collections
   ansible-galaxy install -r requirements.yml
   ```

2. **Prepare TrueNAS** (One-time setup)
   ```bash
   # See PRE_BOOTSTRAP_CHECKLIST.md for TrueNAS configuration
   # Mainly: Enable SSH service and set truenas_admin password
   ```

3. **Create Ansible User** (One-time setup)
   ```bash
   # Generate SSH key pair
   ssh-keygen -t ed25519 -f ~/.ssh/truenas-ansible

   # Update bootstrap inventory with your TrueNAS IP
   nano bootstrap-inventory.yml

   # Create the dedicated ansible user (will prompt for truenas_admin password)
   ansible-playbook -i bootstrap-inventory.yml bootstrap-ansible-user.yml --ask-pass
   ```

4. **Configure Main Inventory**
   ```bash
   # Edit the inventory file with your TrueNAS IP
   nano inventories/hosts.yml

   # Update host-specific variables if needed
   nano host_vars/truenas-server.yml
   ```

5. **Test Connection**
   ```bash
   # Test TrueNAS connectivity and permissions
   ansible-playbook test-connection.yml

   # Should show all green checkmarks ✅
   ```

6. **Run the Playbook** (4-Phase Execution)

   ⚠️ **Important**: Due to dependencies between users and datasets, you must run the playbook in the following **4 phases**:

   **Phase 1: Groups + Dataset Structure**
   ```bash
   ansible-playbook -i inventories/hosts.yml site.yml --tags "groups,datasets" --skip-tags "permissions,post_users" --diff
   ```
   *Creates groups and ZFS datasets/directories without setting ownership*

   **Phase 2: Users (with temporary homes)**
   ```bash
   ansible-playbook -i inventories/hosts.yml site.yml --tags "users" --skip-tags "home_directories,post_datasets" --diff
   ```
   *Creates all service users with temporary home directories*

   **Phase 3: Home Directories + Permissions**
   ```bash
   ansible-playbook -i inventories/hosts.yml site.yml --tags "home_directories,permissions,post_users" --diff
   ```
   *Updates user home directories and sets all dataset permissions*

   **Phase 4: Snapshots**
   ```bash
   ansible-playbook -i inventories/hosts.yml site.yml --tags "snapshots" --diff
   ```
   *Configures automated snapshot management*

   **Alternative: All-in-One (Advanced Users)**
   ```bash
   # Only if you understand the dependencies
   ansible-playbook -i inventories/hosts.yml site.yml --diff
   ```

## Architecture

### Directory Structure

```
ansible/
├── ansible.cfg                    # Ansible configuration
├── site.yml                      # Main playbook
├── requirements.yml               # Collection dependencies
├── inventories/
│   └── hosts.yml                 # Inventory configuration
├── group_vars/
│   ├── all.yml                   # Global variables
│   └── truenas.yml               # TrueNAS-specific variables
├── host_vars/
│   └── truenas-server.yml        # Host-specific configuration
├── roles/
│   ├── truenas_users/            # User and group management
│   ├── truenas_datasets/         # ZFS dataset creation
│   └── truenas_snapshots/        # Snapshot configuration
└── templates/
    └── deployment_summary.md.j2  # Deployment documentation
```

### Service Categories

| Category | Users | GID Range | Description |
|----------|-------|-----------|-------------|
| **Media** | 11 | 3000-3010 | Plex, Sonarr, Radarr, etc. |
| **Download** | 4 | 3100-3103 | qBittorrent, SABnzbd, VPN |
| **Security** | 9 | 3200-3208 | Authentik, Traefik, WireGuard |
| **Web** | 4 | 3300-3303 | BookStack, FreshRSS, Dashboards |
| **DevOps** | 3 | 3400-3402 | GitLab, Harbor, AWX |
| **Monitoring** | 12 | 3500-3511 | Grafana, Prometheus, LibreNMS |
| **Containers** | 2 | 3600-3601 | Portainer, Watchtower |
| **Storage** | 4 | 3700-3703 | MinIO, Rclone, Restic |
| **Network** | 3 | 3900-3902 | Pi-hole, DNS, NTP |
| **Automation** | 3 | 4000-4002 | Home Assistant, Node-RED |
| **Database** | 6 | 3306,5432,6379,8086,9200,27017 | PostgreSQL, MariaDB, Redis, etc. |

### ZFS Dataset Layout

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

## Configuration

### Inventory Configuration

Update `inventories/hosts.yml`:

```yaml
all:
  hosts:
    truenas-server:
      ansible_host: 10.0.2.10        # Your TrueNAS IP
      ansible_user: ansible               # Dedicated ansible user (UID: 1500)
      ansible_become: true                # Enable sudo
      ansible_ssh_private_key_file: ~/.ssh/truenas-ansible
      zfs_pool: tank                      # Your ZFS pool name
```

### Snapshot Management

This deployment uses **TrueNAS API** for native snapshot management:

```yaml
snapshot_method: truenas_api
```

**Features:**
- Native TrueNAS SCALE integration via API
- Automated snapshot task creation
- Complete coverage of all main datasets
- Configurable retention policies per dataset type
- Management through TrueNAS Web UI

### Customization

#### Adding Services

1. **Update User Configuration** (`roles/truenas_users/defaults/main.yml`):
   ```yaml
   service_users:
     - { name: newservice, uid: 3999, group: web, category: Web, description: "New Service" }
   ```

2. **Add to Application Categories** (`roles/truenas_datasets/defaults/main.yml`):
   ```yaml
   app_categories:
     web:
       - newservice
   ```

#### Custom ZFS Properties

Override in `group_vars/truenas.yml`:

```yaml
zfs_settings:
  default_compression: zstd
  record_sizes:
    database: "8K"
    application: "64K"
```

## Dataset Cleanup for Service Changes

When you rename or remove services, the playbook can automatically clean up old datasets to prevent confusion and wasted space.

### How to Use Cleanup

1. **Add cleanup entries** to `roles/truenas_datasets/defaults/main.yml`:

```yaml
cleanup_old_datasets:
  - old_name: netdata
    reason: "Changed to netdata-monitoring to avoid conflict with built-in TrueNAS user (2025-09-15)"
  - old_name: nut
    reason: "Changed to network-ups-tools to avoid conflict with built-in TrueNAS user (2025-09-15)"
  # Add future changes here:
  - old_name: old_service_name
    reason: "Reason for the change (YYYY-MM-DD)"
```

2. **Run the playbook** normally - cleanup happens automatically:

```bash
# Full deployment with cleanup
ansible-playbook site.yml

# Run only cleanup tasks
ansible-playbook site.yml --tags cleanup

# Skip cleanup if desired
ansible-playbook site.yml --skip-tags cleanup
```

### What Gets Cleaned Up

For each entry in `cleanup_old_datasets`, the playbook will remove:
- `tank/apps/{old_name}` - Application dataset
- `tank/logs/{old_name}` - Log dataset

**Note:** Cleanup tasks use `ignore_errors: true` and accept both 200 (deleted) and 404 (doesn't exist) status codes, making them safe to run multiple times.

## Usage Examples

### Docker Compose Integration

**Using the Generated Environment File:**

The deployment creates `/root/docker_users.env` with all UID/GID mappings:

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
      - /root/docker_users.env
    environment:
      - GF_PATHS_DATA=/var/lib/grafana
      - GF_PATHS_LOGS=/var/log/grafana

  plex:
    image: plexinc/pms-docker
    user: "${PLEX_UID}:${MEDIA_GID}"
    volumes:
      - /mnt/tank/apps/plex:/config
      - /mnt/tank/media:/data:ro
    env_file:
      - /root/docker_users.env
```

**Static UID/GID (without environment file):**

```yaml
version: '3.8'
services:
  grafana:
    image: grafana/grafana
    user: "3501:2002"  # grafana:monitor
    volumes:
      - /mnt/tank/apps/grafana:/var/lib/grafana
      - /mnt/tank/logs/grafana:/var/log/grafana
    environment:
      - GF_PATHS_DATA=/var/lib/grafana
      - GF_PATHS_LOGS=/var/log/grafana
```

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      securityContext:
        runAsUser: 3501    # grafana user
        runAsGroup: 2002   # monitor group
        fsGroup: 2002      # monitor group
      containers:
      - name: grafana
        volumeMounts:
        - name: data
          mountPath: /var/lib/grafana
      volumes:
      - name: data
        hostPath:
          path: /mnt/tank/apps/grafana
```

## Maintenance

### Common Commands

```bash
# Check deployment status (dry-run all phases)
ansible-playbook -i inventories/hosts.yml site.yml --check --diff

# Update specific components (respecting dependencies)
ansible-playbook -i inventories/hosts.yml site.yml --tags "users" --skip-tags "home_directories" --diff
ansible-playbook -i inventories/hosts.yml site.yml --tags "datasets" --skip-tags "permissions" --diff
ansible-playbook -i inventories/hosts.yml site.yml --tags "permissions,post_users" --diff

# Re-run specific phases
ansible-playbook -i inventories/hosts.yml site.yml --tags "groups,datasets" --skip-tags "permissions,post_users" --diff
ansible-playbook -i inventories/hosts.yml site.yml --tags "home_directories,permissions,post_users" --diff

# Verify infrastructure
ansible truenas -m shell -a "zfs list | grep tank"  # Check ZFS datasets
ansible truenas -m shell -a "getent passwd | grep 30[0-9][0-9]"  # Check service users
ansible truenas -m shell -a "getent group | grep 20[0-9][0-9]"   # Check service groups

# Snapshot management
ansible truenas -m shell -a "/usr/local/bin/snapshot_report.sh"
```

### Troubleshooting

#### Permission Issues
```bash
# Fix ownership for specific service
ansible truenas -m file -a "path=/mnt/tank/apps/plex owner=plex group=media mode=0755 recurse=yes"
```

#### ZFS Dataset Issues
```bash
# Verify dataset properties
ansible truenas -m shell -a "zfs get recordsize,compression tank/apps/grafana"
```

#### Snapshot Issues
```bash
# Check TrueNAS snapshot tasks status
ansible truenas -m shell -a "midclt call pool.snapshottask.query"
```

## Security Considerations

- **User Isolation**: Each service runs as a dedicated user with minimal privileges
- **Group-based Access**: Services only have access to their functional group resources
- **ZFS Security**: Datasets use appropriate permissions and can be encrypted
- **SSH Hardening**: Configure SSH key-based authentication
- **Network Security**: Implement firewall rules for service isolation

## Monitoring and Alerting

### Generated Files

After deployment, check `/root/` on your TrueNAS system for:

- `users_groups_reference.txt` - Complete user/group listing
- `docker_users.env` - Environment file with all UID/GID mappings for Docker Compose
- `truenas_deployment_summary.md` - Deployment details and usage examples
- Snapshot management scripts in `/usr/local/bin/`

### Log Locations

- TrueNAS logs: `/var/log/middlewared.log`
- Service logs: `/mnt/tank/logs/{service}/`
- Deployment logs: Check Ansible output

## Backup Strategy

The TrueNAS API snapshot system provides complete coverage with optimized schedules:

| Dataset | Frequency | Retention | Schedule | Purpose |
|---------|-----------|-----------|----------|---------|
| **databases** | Every 15 minutes | 24 hours | `*/15 * * * *` | Critical data protection |
| **apps** | Every 4 hours | 7 days | `0 */4 * * *` | Application data backup |
| **containers** | Daily | 7 days | `0 4 * * *` | Container runtime data |
| **downloads** | Every 6 hours | 3 days | `0 */6 * * *` | Temporary download staging |
| **logs** | Daily | 7 days | `0 2 * * *` | System and application logs |
| **system** | Daily | 30 days | `0 1 * * *` | System configuration |
| **media** | Weekly (Sunday) | 4 weeks | `0 3 * * 0` | Large media files |
| **backups** | Weekly (Monday) | 8 weeks | `0 5 * * 1` | Backup repositories |

**Schedule Design:**
- **High-frequency**: Critical databases (15 min) and downloads (6 hours)
- **Daily**: Apps, containers, logs, system (staggered 1-4 AM)
- **Weekly**: Media and backups (weekend schedule)
- **Retention**: Optimized by data criticality and change frequency

For disaster recovery, implement:
1. Off-site replication using ZFS send/receive
2. Configuration backups to external storage
3. Regular restore testing

## Contributing

To contribute improvements:

1. Test changes in a lab environment
2. Update documentation for new features
3. Follow Ansible best practices
4. Ensure idempotency of all tasks

## Support

For issues specific to this Ansible implementation, check:

1. Ansible execution logs for task failures
2. TrueNAS system logs for ZFS/system issues
3. Service-specific logs in `/mnt/tank/logs/`
4. Generated reference files in `/root/`

Original bash scripts remain available for comparison and fallback if needed.

## Quick Reference: 4-Phase Execution

For quick copy-paste, here are the exact commands for production deployment:

```bash
# Phase 1: Groups + Dataset Structure
ansible-playbook -i inventories/hosts.yml site.yml --tags "groups,datasets" --skip-tags "permissions,post_users" --diff

# Phase 2: Users (with temporary homes)
ansible-playbook -i inventories/hosts.yml site.yml --tags "users" --skip-tags "home_directories,post_datasets" --diff

# Phase 3: Home Directories + Permissions
ansible-playbook -i inventories/hosts.yml site.yml --tags "home_directories,permissions,post_users" --diff

# Phase 4: Snapshots
ansible-playbook -i inventories/hosts.yml site.yml --tags "snapshots" --diff
```

**Verification between phases:**
```bash
# After Phase 1 - Check datasets exist
ansible truenas -m shell -a "zfs list | grep tank"

# After Phase 2 - Check users were created
ansible truenas -m shell -a "getent passwd | grep 30[0-9][0-9]"

# After Phase 3 - Check home directories and permissions
ansible truenas -m shell -a "ls -la /mnt/tank/apps/ | head -10"

# After Phase 4 - Check snapshot tasks
ansible truenas -m shell -a "midclt call pool.snapshottask.query | jq '.[] | {name, dataset, enabled}'"
```

See [README_API_MIGRATION.md](README_API_MIGRATION.md) for detailed technical information about the API integration and dependency resolution.