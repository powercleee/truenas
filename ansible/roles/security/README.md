# TrueNAS Security Role

This Ansible role implements network and security configurations for TrueNAS SCALE systems using **exclusively** the TrueNAS middleware API. No direct system commands are executed.

## Features

- **SSH Hardening**: Configures secure SSH settings including disabled root login, key-based authentication, and strong ciphers
- **TCP Tuning (API-Managed)**: Optimizes TCP settings for mixed-speed networks (1GbE + 10GbE) using TrueNAS middleware API
- **Network Interface Optimization**: Basic network interface configuration via API
- **Security Reporting**: Generates comprehensive security reports for review and compliance
- **Service Binding**: Configures service-specific network binding for security isolation

## Important Limitations (API-Only Implementation)

⚠️ **Firewall Management**: TrueNAS SCALE does not provide native firewall API endpoints. This role documents recommended firewall rules but cannot implement them directly.

⚠️ **NIC Offloading**: Hardware offloading features (TSO, GSO, LRO, checksum offloading) require direct `ethtool` commands and are not available via TrueNAS API. These must be configured manually or through external automation.

⚠️ **System Commands**: This role exclusively uses TrueNAS API endpoints. No direct system commands, sysctl, or ethtool operations are performed.

## Prerequisites

- TrueNAS SCALE 25.04+ system
- TrueNAS API key with appropriate permissions
- Ansible 2.9+ on control machine
- Network connectivity to TrueNAS system

## API Endpoints Used

- `/api/v2.0/service/id/ssh` - SSH service configuration
- `/api/v2.0/service/restart` - Service restart operations
- `/api/v2.0/interface` - Network interface management
- `/api/v2.0/interface/id/{id}` - Specific interface configuration
- `/api/v2.0/tunable` - System tunable (sysctl) management
- `/api/v2.0/tunable/load` - Apply tunables immediately

## Configuration

### SSH Hardening Settings

```yaml
# Enable/disable SSH hardening
apply_ssh_hardening: true

# SSH security configuration
ssh_allow_root: false          # Disable root login (recommended)
ssh_password_auth: false       # Use key-based authentication only
ssh_tcp_forwarding: false      # Disable TCP forwarding
ssh_compression: false         # Disable compression
ssh_weak_ciphers: false        # Disable weak ciphers
```

### TCP Tuning

```yaml
# Enable/disable TCP tuning via TrueNAS API
apply_tcp_tuning: true

# TCP tuning variables (managed via TrueNAS API)
# Conservative settings for mixed 1GbE/10GbE environment
tcp_tuning_variables:
  "net.core.rmem_max": "67108864"          # 64MB (conservative)
  "net.core.wmem_max": "67108864"          # 64MB (conservative)
  "net.ipv4.tcp_rmem": "4096 87380 67108864"    # 64MB max
  "net.ipv4.tcp_wmem": "4096 65536 67108864"    # 64MB max
  "net.core.netdev_max_backlog": "5000"        # Moderate for mixed speeds
  "net.ipv4.tcp_congestion_control": "htcp"
  "net.ipv4.tcp_mtu_probing": "1"
  "net.ipv4.tcp_window_scaling": "1"
  "net.ipv4.tcp_timestamps": "1"
  "net.ipv4.tcp_sack": "1"
  "net.ipv4.tcp_no_metrics_save": "1"
  "net.core.rmem_default": "262144"
  "net.core.wmem_default": "262144"
  "net.core.netdev_budget": "600"
  "net.core.netdev_budget_usecs": "5000"

# Cleanup existing conflicting tunables (optional)
cleanup_existing_tunables: false

# Basic network interface configuration (API-managed)
network_interfaces:
  - name: "enp0s3"
    description: "Primary Network - Security Optimized"
    mtu: 1500
```

### Service Binding (Security Isolation)

```yaml
service_bindings:
  ssh:
    interfaces: []  # Empty = all interfaces, or specify: ["enp0s3"]
  nfs:
    interfaces: []
  smb:
    interfaces: []
```

## Usage

### Include in Playbook

```yaml
- name: Apply TrueNAS security configurations
  hosts: truenas
  roles:
    - security
  tags:
    - security
```

### Run Security Configuration Only

```bash
# Apply all security configurations
ansible-playbook site.yml --tags "security"

# Apply SSH hardening only
ansible-playbook site.yml --tags "security,ssh"

# Apply network optimization only
ansible-playbook site.yml --tags "security,network"

# Apply TCP tuning via API only
ansible-playbook site.yml --tags "security,optimization,api"
```

### Dry Run (Check Mode)

```bash
# Review changes before applying
ansible-playbook site.yml --tags "security" --check --diff
```

## Generated Reports

The role generates security reports in `/tmp/`:

- **SSH Security Report**: `/tmp/ssh_security_report.txt`
  - SSH service configuration details
  - Security recommendations
  - Connection testing instructions

- **Network Security Report**: `/tmp/network_security_report.txt`
  - Network interface configurations
  - Firewall rule recommendations
  - Security hardening checklist

## Security Best Practices Implemented

### SSH Hardening

✅ **Root login disabled** - Prevents direct root access
✅ **Password authentication disabled** - Forces key-based authentication
✅ **TCP forwarding disabled** - Prevents tunneling abuse
✅ **Compression disabled** - Prevents compression-based attacks
✅ **Weak ciphers disabled** - Uses only strong encryption
✅ **Connection limits** - Limits concurrent sessions
✅ **Strong algorithms** - Modern cipher suites and key exchange

### Network Security

✅ **TCP tuning** - Mixed-speed network optimization (1GbE + 10GbE) via TrueNAS API
✅ **Interface configuration** - Basic MTU and description settings
✅ **Service binding** - Restrict services to specific interfaces
✅ **Security reporting** - Comprehensive configuration documentation
✅ **Web UI integration** - All settings visible in TrueNAS interface
❌ **NIC offloading** - Requires direct ethtool commands (not available)
❌ **Advanced networking** - Limited to API-exposed features only

## Firewall Implementation

Since TrueNAS SCALE lacks native firewall API, implement these external solutions:

### Option 1: External Firewall Appliance
- pfSense/OPNsense
- Cisco ASA
- SonicWall
- Fortinet FortiGate

### Option 2: Host-based Firewall
```bash
# Example iptables rules (implement manually or via configuration management)
iptables -A INPUT -p tcp --dport 22 -s trusted_network -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -s management_network -j ACCEPT
iptables -A INPUT -j DROP
```

### Option 3: Network Infrastructure
- Switch ACLs
- Router filtering rules
- VLAN segmentation

## Monitoring and Compliance

### Log Monitoring
- SSH authentication logs: `/var/log/auth.log`
- System logs: `/var/log/messages`
- TrueNAS middleware logs: `/var/log/middlewared.log`

### Security Auditing
```bash
# Check SSH configuration
sshd -T | grep -E "(PasswordAuthentication|PermitRootLogin|Protocol)"

# Review active network connections
ss -tuln

# Check interface configuration
ip addr show
```

### Compliance Frameworks
This role helps implement security controls for:
- CIS Benchmarks
- NIST Cybersecurity Framework
- ISO 27001 controls
- SOC 2 requirements

## Troubleshooting

### SSH Access Issues
1. Verify SSH service is running: `systemctl status ssh`
2. Check SSH configuration: `sshd -T`
3. Review SSH logs: `tail -f /var/log/auth.log`
4. Test from client: `ssh -vvv user@truenas-host`

### Network Configuration Issues
1. Check interface status: `ip addr show`
2. Verify routing: `ip route show`
3. Test connectivity: `ping gateway_ip`
4. Review network logs: `journalctl -u networkd`

### API Access Issues
1. Verify API key permissions
2. Check TrueNAS API service status
3. Test API endpoint directly: `curl -H "Authorization: Bearer $API_KEY" https://truenas-ip/api/v2.0/system/info`

## Security Considerations

### API Key Management
- Store API keys securely using Ansible Vault
- Rotate API keys regularly
- Limit API key permissions to minimum required
- Monitor API key usage

### Network Security
- Use dedicated management network for TrueNAS
- Implement network segmentation
- Monitor network traffic for anomalies
- Regular security assessments

### System Hardening
- Keep TrueNAS system updated
- Disable unused services
- Implement proper backup strategies
- Regular security configuration reviews

## Contributing

When contributing to this role:

1. Test changes in lab environment
2. Update documentation for new features
3. Follow Ansible best practices
4. Ensure idempotency of all tasks
5. Add appropriate tags to tasks
6. Update security reports if configuration options change

## Support

For issues with this security role:

1. Check generated security reports
2. Review TrueNAS API logs
3. Verify API key permissions
4. Test individual API endpoints
5. Review network connectivity

## Related Documentation

- [TrueNAS SCALE Security Guide](https://www.truenas.com/docs/scale/gettingstarted/configure/)
- [SSH Hardening Guide](https://www.ssh.com/academy/ssh/sshd_config)
- [Network Security Best Practices](https://www.nist.gov/cybersecurity)
- [TrueNAS API Documentation](https://www.truenas.com/docs/api/)