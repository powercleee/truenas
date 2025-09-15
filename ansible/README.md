# TrueNAS SCALE Ansible Infrastructure

This Ansible project automates the complete setup of a TrueNAS SCALE infrastructure with 61 services across 11 categories, providing enterprise-grade storage management, user configuration, and automated snapshots.

## Project Overview

This Ansible implementation replaces the original bash scripts with a more maintainable, idempotent, and scalable infrastructure-as-code approach for TrueNAS SCALE 25.10.

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

**⚠️ Important:** This project uses a dedicated `ansible` user (UID: 1500) instead of root or truenas_admin for security. See setup guides below for complete instructions.

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

6. **Run the Playbook**
   ```bash
   # Full infrastructure setup
   ansible-playbook site.yml

   # Or run specific components
   ansible-playbook site.yml --tags users
   ansible-playbook site.yml --tags datasets
   ansible-playbook site.yml --tags snapshots
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

### Snapshot Methods

Choose your preferred snapshot method in `group_vars/all.yml`:

#### Option 1: Sanoid (Recommended)
```yaml
snapshot_method: sanoid
```
- Advanced snapshot management with flexible retention policies
- Automated pruning and monitoring
- Cross-platform ZFS snapshot tool

#### Option 2: TrueNAS API Integration
```yaml
snapshot_method: truenas_api
```
- Native TrueNAS SCALE integration
- Generates configuration for manual import
- Requires TrueNAS Web UI or API setup

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
# Check deployment status
ansible-playbook site.yml --check --diff

# Update only users
ansible-playbook site.yml --tags users

# Verify ZFS datasets
ansible truenas -m shell -a "zfs list | grep tank"

# Check service users
ansible truenas -m shell -a "getent passwd | grep 30[0-9][0-9]"

# Snapshot report
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
# Check sanoid status (if using sanoid method)
ansible truenas -m shell -a "systemctl status sanoid.timer"
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

- Sanoid logs: `/var/log/sanoid/`
- Service logs: `/mnt/tank/logs/{service}/`
- Deployment logs: Check Ansible output

## Backup Strategy

The configured snapshot system provides:

- **Critical Data**: 15-minute snapshots, 24-hour retention
- **Application Data**: 4-hour snapshots, 7-day retention
- **Media Content**: Weekly snapshots, 4-week retention
- **Log Data**: Daily snapshots, 7-day retention

For disaster recovery, implement:
1. Off-site replication using `syncoid`
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