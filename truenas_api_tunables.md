# TrueNAS SCALE API Guide for Performance Tunables

## API Authentication Setup

### Getting Your API Key
1. Login to TrueNAS Web UI
2. Navigate to **Settings → API Keys**
3. Click **Add** to create a new API key
4. Give it a name (e.g., "Tunable Automation")
5. Copy the generated key immediately (shown only once)

### API Endpoint
```
https://<your-truenas-ip>/api/v2.0/
```

## Working with Different Tunable Types

### 1. SYSCTL Tunables API

#### List All Sysctls
```bash
curl -X GET \
  -H "Authorization: Bearer YOUR_API_KEY" \
  "https://10.0.2.10/api/v2.0/system/sysctl" \
  -k  # -k for self-signed certificates
```

#### Create a New Sysctl
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  "https://10.0.2.10/api/v2.0/system/sysctl" \
  -d '{
    "var": "vm.swappiness",
    "value": "1",
    "enabled": true,
    "comment": "Minimize swap usage for container performance"
  }' \
  -k
```

#### Update Existing Sysctl
```bash
# First get the ID of the sysctl
curl -X GET \
  -H "Authorization: Bearer YOUR_API_KEY" \
  "https://10.0.2.10/api/v2.0/system/sysctl?var=vm.swappiness" \
  -k

# Then update it (replace {id} with actual ID)
curl -X PUT \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  "https://10.0.2.10/api/v2.0/system/sysctl/{id}" \
  -d '{
    "value": "2",
    "enabled": true
  }' \
  -k
```

#### Delete a Sysctl
```bash
curl -X DELETE \
  -H "Authorization: Bearer YOUR_API_KEY" \
  "https://10.0.2.10/api/v2.0/system/sysctl/{id}" \
  -k
```

### 2. ZFS Module Parameters API

#### List All Tunables
```bash
curl -X GET \
  -H "Authorization: Bearer YOUR_API_KEY" \
  "https://10.0.2.10/api/v2.0/tunable" \
  -k
```

#### Create ZFS Tunable
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  "https://10.0.2.10/api/v2.0/tunable" \
  -d '{
    "type": "ZFS",
    "var": "zfs_arc_max",
    "value": "164987617689",
    "enabled": true,
    "comment": "Set ARC to 153GB (80% of 192GB RAM)"
  }' \
  -k
```

#### Update ZFS Tunable
```bash
curl -X PUT \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  "https://10.0.2.10/api/v2.0/tunable/{id}" \
  -d '{
    "value": "171798691840",
    "comment": "Increased ARC to 160GB"
  }' \
  -k
```

### 3. Init/Shutdown Scripts API (for Block Device Settings)

#### Create Init Script for Block Device Tunables
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  "https://10.0.2.10/api/v2.0/initshutdownscript" \
  -d '{
    "type": "SCRIPT",
    "script": "#!/bin/bash\n# Set read-ahead for all drives\nfor disk in /sys/block/sd*/queue/read_ahead_kb; do\n    echo 1024 > $disk\ndone\n\n# Set scheduler for HDDs\nfor disk in /sys/block/sd*/queue/scheduler; do\n    if [ $(cat ${disk%/*}/rotational) -eq 1 ]; then\n        echo mq-deadline > $disk\n    else\n        echo none > $disk\n    fi\ndone",
    "when": "POSTINIT",
    "enabled": true,
    "timeout": 10,
    "comment": "Configure block device performance settings"
  }' \
  -k
```

## Python Script for Bulk Configuration

```python
#!/usr/bin/env python3
"""
TrueNAS SCALE Performance Tunable Configuration Script
Applies all recommended tunables via API
"""

import requests
import json
import urllib3
from typing import Dict, List, Any

# Disable SSL warnings for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class TrueNASConfigurator:
    def __init__(self, host: str, api_key: str):
        self.base_url = f"https://{host}/api/v2.0"
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        self.session = requests.Session()
        self.session.headers.update(self.headers)
        self.session.verify = False  # For self-signed certificates
    
    def create_sysctl(self, var: str, value: str, comment: str = "") -> Dict:
        """Create or update a sysctl tunable"""
        # Check if it exists
        response = self.session.get(f"{self.base_url}/system/sysctl")
        existing = [s for s in response.json() if s['var'] == var]
        
        data = {
            "var": var,
            "value": value,
            "enabled": True,
            "comment": comment
        }
        
        if existing:
            # Update existing
            sysctl_id = existing[0]['id']
            response = self.session.put(
                f"{self.base_url}/system/sysctl/{sysctl_id}",
                json=data
            )
        else:
            # Create new
            response = self.session.post(
                f"{self.base_url}/system/sysctl",
                json=data
            )
        
        return response.json()
    
    def create_zfs_tunable(self, var: str, value: str, comment: str = "") -> Dict:
        """Create or update a ZFS tunable"""
        # Check if it exists
        response = self.session.get(f"{self.base_url}/tunable")
        existing = [t for t in response.json() 
                   if t['var'] == var and t['type'] == 'ZFS']
        
        data = {
            "type": "ZFS",
            "var": var,
            "value": value,
            "enabled": True,
            "comment": comment
        }
        
        if existing:
            # Update existing
            tunable_id = existing[0]['id']
            response = self.session.put(
                f"{self.base_url}/tunable/{tunable_id}",
                json=data
            )
        else:
            # Create new
            response = self.session.post(
                f"{self.base_url}/tunable",
                json=data
            )
        
        return response.json()
    
    def create_init_script(self, script: str, comment: str = "") -> Dict:
        """Create a post-init script"""
        data = {
            "type": "SCRIPT",
            "script": script,
            "when": "POSTINIT",
            "enabled": True,
            "timeout": 30,
            "comment": comment
        }
        
        response = self.session.post(
            f"{self.base_url}/initshutdownscript",
            json=data
        )
        
        return response.json()
    
    def apply_all_tunables(self):
        """Apply all recommended tunables"""
        
        # SYSCTL Tunables
        print("Applying SYSCTL tunables...")
        sysctls = {
            "vm.swappiness": ("1", "Minimize swap usage"),
            "vm.vfs_cache_pressure": ("50", "Balanced inode/dentry cache"),
            "vm.dirty_ratio": ("10", "10% dirty pages before forced writes"),
            "vm.dirty_background_ratio": ("5", "5% dirty pages for background writes"),
            "vm.min_free_kbytes": ("1048576", "Reserve 1GB free memory"),
            "kernel.shmmax": ("103079215104", "96GB shared memory max"),
            "kernel.shmall": ("25165824", "Total shared memory pages"),
            "net.core.rmem_max": ("134217728", "128MB max receive buffer"),
            "net.core.wmem_max": ("134217728", "128MB max send buffer"),
            "net.core.netdev_max_backlog": ("30000", "Packet backlog for 10GbE"),
            "net.core.somaxconn": ("8192", "Max socket connections"),
            "net.core.netdev_budget": ("600", "Packet processing budget"),
            "net.core.netdev_budget_usecs": ("8000", "Max packet processing time"),
            "net.ipv4.tcp_rmem": ("4096 87380 134217728", "TCP receive buffer"),
            "net.ipv4.tcp_wmem": ("4096 65536 134217728", "TCP send buffer"),
            "net.ipv4.tcp_congestion_control": ("bbr", "BBR congestion control"),
            "net.ipv4.tcp_mtu_probing": ("1", "Enable MTU probing"),
            "net.ipv4.tcp_adv_win_scale": ("2", "TCP buffer allocation"),
            "fs.file-max": ("2097152", "Max file handles"),
            "fs.aio-max-nr": ("1048576", "Max async I/O operations")
        }
        
        for var, (value, comment) in sysctls.items():
            try:
                result = self.create_sysctl(var, value, comment)
                print(f"  ✓ {var} = {value}")
            except Exception as e:
                print(f"  ✗ {var}: {str(e)}")
        
        # ZFS Tunables
        print("\nApplying ZFS tunables...")
        zfs_tunables = {
            "zfs_arc_max": ("164987617689", "153GB ARC (80% of RAM)"),
            "zfs_arc_min": ("8589934592", "8GB minimum ARC"),
            "zfs_arc_meta_limit": ("82493808844", "76GB metadata limit"),
            "zfs_dirty_data_max": ("8589934592", "8GB dirty data max"),
            "zfs_vdev_async_read_max_active": ("16", "Async reads per vdev"),
            "zfs_vdev_async_write_max_active": ("16", "Async writes per vdev"),
            "zfs_vdev_aggregation_limit": ("1048576", "1MB I/O aggregation"),
            "zfetch_max_distance": ("67108864", "64MB prefetch distance"),
            "metaslab_lba_weighting_enabled": ("1", "Enable LBA weighting"),
            "l2arc_write_max": ("134217728", "128MB/s L2ARC write speed"),
            "zvol_threads": ("32", "ZVOL worker threads")
        }
        
        for var, (value, comment) in zfs_tunables.items():
            try:
                result = self.create_zfs_tunable(var, value, comment)
                print(f"  ✓ {var} = {value}")
            except Exception as e:
                print(f"  ✗ {var}: {str(e)}")
        
        # Block Device Init Script
        print("\nCreating block device init script...")
        block_device_script = """#!/bin/bash
# Block device performance tuning

echo "Configuring block device settings..."

# Set read-ahead based on device type
for disk in /sys/block/sd*/queue/read_ahead_kb; do
    device=$(echo $disk | cut -d'/' -f4)
    rotational=$(cat /sys/block/$device/queue/rotational)
    
    if [ "$rotational" -eq 1 ]; then
        # HDD - 2MB read-ahead
        echo 2048 > $disk
        echo mq-deadline > ${disk%/*}/scheduler
    else
        # SSD - 256KB read-ahead
        echo 256 > $disk
        echo none > ${disk%/*}/scheduler
    fi
done

# NVMe settings
for disk in /sys/block/nvme*/queue/read_ahead_kb; do
    echo 128 > $disk
    echo none > ${disk%/*}/scheduler
done

# Common settings for all disks
for disk in /sys/block/*/queue; do
    [ -f $disk/nr_requests ] && echo 256 > $disk/nr_requests
    [ -f $disk/rq_affinity ] && echo 2 > $disk/rq_affinity
    [ -f $disk/add_random ] && echo 0 > $disk/add_random
    [ -f $disk/nomerges ] && echo 0 > $disk/nomerges
done

echo "Block device configuration complete"
"""
        
        try:
            result = self.create_init_script(
                block_device_script,
                "Configure block device performance settings"
            )
            print("  ✓ Block device init script created")
        except Exception as e:
            print(f"  ✗ Init script: {str(e)}")
        
        print("\nConfiguration complete!")
        print("Note: Some settings may require a reboot to take effect.")

# Usage
if __name__ == "__main__":
    # Configuration
    TRUENAS_HOST = "10.0.2.10"  # Your TrueNAS IP
    API_KEY = "YOUR_API_KEY_HERE"  # Replace with your API key
    
    # Create configurator and apply tunables
    config = TrueNASConfigurator(TRUENAS_HOST, API_KEY)
    config.apply_all_tunables()
```

## WebSocket API for Real-time Monitoring

```python
#!/usr/bin/env python3
"""
Monitor tunable changes in real-time via WebSocket
"""

import asyncio
import websockets
import json

async def monitor_tunables(host: str, api_key: str):
    uri = f"wss://{host}/websocket"
    
    async with websockets.connect(uri, ssl=False) as websocket:
        # Authenticate
        auth_msg = {
            "msg": "connect",
            "version": "1",
            "support": ["1"],
            "token": api_key
        }
        await websocket.send(json.dumps(auth_msg))
        
        # Subscribe to tunable changes
        subscribe_msg = {
            "id": "1",
            "name": "tunable.query",
            "msg": "method"
        }
        await websocket.send(json.dumps(subscribe_msg))
        
        # Listen for changes
        async for message in websocket:
            data = json.loads(message)
            print(f"Tunable change: {data}")

# Run: asyncio.run(monitor_tunables("10.0.2.10", "YOUR_API_KEY"))
```

## REST API vs CLI Commands Comparison

| Operation | REST API | CLI (via SSH) |
|-----------|----------|---------------|
| List sysctls | `GET /api/v2.0/system/sysctl` | `midclt call system.sysctl.query` |
| Create sysctl | `POST /api/v2.0/system/sysctl` | `midclt call system.sysctl.create '{"var":"vm.swappiness","value":"1"}'` |
| List tunables | `GET /api/v2.0/tunable` | `midclt call tunable.query` |
| Create tunable | `POST /api/v2.0/tunable` | `midclt call tunable.create '{"type":"ZFS","var":"zfs_arc_max","value":"164987617689"}'` |
| Create init script | `POST /api/v2.0/initshutdownscript` | `midclt call initshutdownscript.create` |

## Ansible Playbook for Automation

```yaml
---
- name: Configure TrueNAS SCALE Performance Tunables
  hosts: localhost
  vars:
    truenas_host: "10.0.2.10"
    api_key: "{{ vault_truenas_api_key }}"
    
  tasks:
    - name: Configure SYSCTL tunables
      uri:
        url: "https://{{ truenas_host }}/api/v2.0/system/sysctl"
        method: POST
        headers:
          Authorization: "Bearer {{ api_key }}"
        body_format: json
        body:
          var: "{{ item.var }}"
          value: "{{ item.value }}"
          enabled: true
          comment: "{{ item.comment }}"
        validate_certs: no
      loop:
        - { var: "vm.swappiness", value: "1", comment: "Minimize swap" }
        - { var: "vm.dirty_ratio", value: "10", comment: "Dirty page ratio" }
        - { var: "net.core.rmem_max", value: "134217728", comment: "Max receive buffer" }
        # Add more sysctls as needed
      
    - name: Configure ZFS tunables
      uri:
        url: "https://{{ truenas_host }}/api/v2.0/tunable"
        method: POST
        headers:
          Authorization: "Bearer {{ api_key }}"
        body_format: json
        body:
          type: "ZFS"
          var: "{{ item.var }}"
          value: "{{ item.value }}"
          enabled: true
          comment: "{{ item.comment }}"
        validate_certs: no
      loop:
        - { var: "zfs_arc_max", value: "164987617689", comment: "153GB ARC" }
        - { var: "zfs_arc_min", value: "8589934592", comment: "8GB min ARC" }
        # Add more ZFS tunables as needed
```

## Terraform Provider for Infrastructure as Code

```hcl
terraform {
  required_providers {
    truenas = {
      source = "dariusbakunas/truenas"
      version = "0.11.0"
    }
  }
}

provider "truenas" {
  api_key  = var.truenas_api_key
  base_url = "https://10.0.2.10/api/v2.0"
}

resource "truenas_sysctl" "vm_swappiness" {
  var     = "vm.swappiness"
  value   = "1"
  enabled = true
  comment = "Minimize swap usage"
}

resource "truenas_tunable" "arc_max" {
  type    = "ZFS"
  var     = "zfs_arc_max"
  value   = "164987617689"
  enabled = true
  comment = "Set ARC to 153GB"
}
```

## Best Practices for API Usage

1. **Always use HTTPS** even with self-signed certificates
2. **Store API keys securely** (environment variables, vaults)
3. **Implement error handling** for network issues
4. **Use idempotent operations** - check before create/update
5. **Rate limit your requests** to avoid overwhelming the system
6. **Test in non-production** first
7. **Keep audit logs** of configuration changes
8. **Version control** your configuration scripts

## Validation After API Configuration

```bash
# Verify sysctls were applied
curl -X GET \
  -H "Authorization: Bearer YOUR_API_KEY" \
  "https://10.0.2.10/api/v2.0/system/sysctl" \
  -k | jq '.[] | select(.enabled==true) | {var: .var, value: .value}'

# Verify ZFS tunables
curl -X GET \
  -H "Authorization: Bearer YOUR_API_KEY" \
  "https://10.0.2.10/api/v2.0/tunable" \
  -k | jq '.[] | select(.type=="ZFS" and .enabled==true) | {var: .var, value: .value}'

# Check system performance metrics
curl -X GET \
  -H "Authorization: Bearer YOUR_API_KEY" \
  "https://10.0.2.10/api/v2.0/reporting/graphs" \
  -k
```