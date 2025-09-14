# Pre-Bootstrap Checklist for TrueNAS SCALE

Before running the `bootstrap-ansible-user.yml` playbook, you need to prepare your TrueNAS SCALE system with minimal configuration.

## Required Prerequisites

### 1. Enable SSH Service

**Via TrueNAS Web UI:**
1. Log into TrueNAS Web UI as admin
2. Navigate to **System Settings** → **Services**
3. Find **SSH** service and toggle it **ON**
4. Click the **Configure** (pencil) icon for SSH
5. Configure these settings:
   - ✅ **TCP Port**: 22 (default)
   - ✅ **Allow Password Authentication**: ENABLED (temporarily - will disable later)
   - ❌ **Allow Kerberos Authentication**: DISABLED
6. Click **Save**

### 2. Set truenas_admin Password (If Not Already Set)

The bootstrap playbook connects as `truenas_admin`, so ensure this account has a password:

**Via TrueNAS Web UI:**
1. Navigate to **Credentials** → **Local Users**
2. Find **truenas_admin** user and click **Edit**
3. Set a password if not already configured
4. Click **Save**

### 3. Network Connectivity

Ensure your Ansible control machine can reach TrueNAS:

```bash
# Test basic connectivity (replace with your TrueNAS IP)
ping your-truenas-ip

# Test SSH port is open
nc -zv your-truenas-ip 22
# Should show: Connection succeeded
```

### 4. Test Initial SSH Connection

Verify you can SSH as truenas_admin:

```bash
# Test SSH connection (will prompt for password)
ssh truenas_admin@your-truenas-ip

# You should get a shell prompt
# Type 'exit' to disconnect
```

## That's It!

No additional software installation is required on TrueNAS SCALE. The system comes with:
- ✅ Python 3 (required for Ansible)
- ✅ Standard Linux utilities
- ✅ sudo functionality
- ✅ SSH server capability

## Quick Pre-Bootstrap Test

Run this simple test to verify readiness:

```bash
# Update bootstrap-inventory.yml with your TrueNAS IP
nano bootstrap-inventory.yml

# Test Ansible can reach TrueNAS as truenas_admin
ansible -i bootstrap-inventory.yml all -m ping --ask-pass

# Should prompt for truenas_admin password and return:
# truenas-server | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

## Common Issues and Solutions

### Issue: SSH Connection Refused
```bash
# Check if SSH service is running
ssh truenas_admin@your-truenas-ip
# If connection refused, SSH service is not enabled
```
**Solution:** Enable SSH service via Web UI (Step 1 above)

### Issue: Permission Denied (Password)
```bash
# If SSH connects but password is rejected
ssh truenas_admin@your-truenas-ip
# Permission denied, please try again.
```
**Solution:** Set/reset truenas_admin password via Web UI (Step 2 above)

### Issue: Network Unreachable
```bash
ping your-truenas-ip
# ping: cannot resolve your-truenas-ip: Unknown host
```
**Solution:**
- Verify TrueNAS IP address in Web UI: **Network** → **Interfaces**
- Update your DNS or use IP address directly
- Check network connectivity between Ansible host and TrueNAS

### Issue: Ansible Python Interpreter
```bash
ansible -i bootstrap-inventory.yml all -m ping --ask-pass
# /usr/bin/python: not found
```
**Solution:** TrueNAS SCALE uses python3. This is already configured in the inventory:
```yaml
ansible_python_interpreter: /usr/bin/python3
```

## Security Notes

- **Password authentication is temporarily enabled** only for the bootstrap process
- **After bootstrap completes**, password authentication will be disabled
- **The ansible user will use SSH keys only** - much more secure
- **truenas_admin password** is only used for this one-time setup

## Ready to Bootstrap?

Once you've completed this checklist:

```bash
# 1. Generate SSH key pair
ssh-keygen -t ed25519 -f ~/.ssh/truenas-ansible

# 2. Update bootstrap inventory with your TrueNAS IP
nano bootstrap-inventory.yml

# 3. Run bootstrap playbook
ansible-playbook -i bootstrap-inventory.yml bootstrap-ansible-user.yml --ask-pass

# 4. Test new ansible user
ssh -i ~/.ssh/truenas-ansible ansible@your-truenas-ip
```

The `--ask-pass` flag will prompt for the truenas_admin password once, then the ansible user will be created with SSH key authentication.

---

**Next:** After successful bootstrap, continue with the main README instructions starting from step 4 (Test Connection).