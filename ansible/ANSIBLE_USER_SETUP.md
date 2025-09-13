# TrueNAS SCALE Ansible User Setup

This guide covers creating a dedicated `ansible` user and group for secure automation of TrueNAS SCALE systems. This approach follows security best practices by creating a purpose-built account with minimal privileges instead of using administrative accounts.

## Overview

We'll create:
- **Group**: `ansible` (GID: 1500)
- **User**: `ansible` (UID: 1500)
- **Permissions**: Sudo access for infrastructure management
- **Authentication**: SSH key-based only (no password)

## Quick Start (Automated)

If you prefer automation, use the provided bootstrap playbook:

```bash
# 1. Generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/truenas-ansible

# 2. Update bootstrap inventory with your TrueNAS IP
nano bootstrap-inventory.yml

# 3. Run bootstrap playbook (will prompt for truenas_admin password)
ansible-playbook -i bootstrap-inventory.yml bootstrap-ansible-user.yml --ask-pass

# 4. Test connection
ssh -i ~/.ssh/truenas-ansible ansible@your-truenas-ip
```

Continue to **Step 7** to harden SSH security after bootstrap completes.

## Manual Setup (Detailed)

For a step-by-step manual approach, follow the detailed instructions below:

## Prerequisites

- Administrative access to TrueNAS SCALE Web UI
- SSH access as `truenas_admin` (temporary)
- SSH client on your Ansible control machine

## Step 1: Enable SSH Service

**Via TrueNAS Web UI:**
1. Navigate to **System Settings** → **Services**
2. Find **SSH** service and toggle **ON**
3. Click **Configure** (pencil icon) for SSH service
4. Configure SSH settings:
   - **TCP Port**: 22
   - **Log in as Root with Password**: ❌ **Disabled**
   - **Allow Password Authentication**: ✅ **Enabled** (temporarily)
   - **Allow Kerberos Authentication**: ❌ **Disabled**
5. Click **Save**

## Step 2: Generate SSH Key Pair

On your Ansible control machine:

```bash
# Generate ED25519 key pair (recommended)
ssh-keygen -t ed25519 -f ~/.ssh/truenas-ansible -C "ansible@truenas-automation"

# Set proper permissions
chmod 600 ~/.ssh/truenas-ansible
chmod 644 ~/.ssh/truenas-ansible.pub

# Display public key (you'll need this)
cat ~/.ssh/truenas-ansible.pub
```

## Step 3: Create Ansible User (via truenas_admin)

SSH to your TrueNAS system using the default admin account:

```bash
# SSH as truenas_admin (use your TrueNAS IP)
ssh truenas_admin@your-truenas-ip
```

Now create the dedicated ansible user and group:

```bash
# Create ansible group
sudo groupadd -g 1500 ansible

# Create ansible user
sudo useradd -u 1500 -g 1500 -m -s /bin/bash -c "Ansible Automation User" ansible

# Create .ssh directory for ansible user
sudo mkdir -p /home/ansible/.ssh
sudo chmod 700 /home/ansible/.ssh

# Add your public key to authorized_keys
# Replace the key below with your actual public key from step 2
sudo tee /home/ansible/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx ansible@truenas-automation
EOF

# Set proper ownership and permissions
sudo chown -R ansible:ansible /home/ansible/.ssh
sudo chmod 600 /home/ansible/.ssh/authorized_keys

# Verify the setup
ls -la /home/ansible/.ssh/
```

## Step 4: Configure Sudo Access

The ansible user needs sudo privileges for system administration:

```bash
# Create sudoers file for ansible user
sudo tee /etc/sudoers.d/ansible << 'EOF'
# Ansible user sudo configuration
# Allow ansible user to run all commands without password
ansible ALL=(ALL) NOPASSWD: ALL

# Optional: Restrict to specific commands if desired
# ansible ALL=(ALL) NOPASSWD: /sbin/zfs, /sbin/zpool, /usr/sbin/useradd, /usr/sbin/usermod, /usr/sbin/groupadd, /bin/mkdir, /bin/chown, /bin/chmod, /bin/systemctl
EOF

# Set proper permissions on sudoers file
sudo chmod 440 /etc/sudoers.d/ansible

# Verify sudoers configuration
sudo visudo -c
```

## Step 5: Test SSH Key Authentication

From your Ansible control machine:

```bash
# Test SSH connection with key
ssh -i ~/.ssh/truenas-ansible ansible@your-truenas-ip

# Should log in without password prompt
# Test sudo access
sudo whoami
# Should return 'root' without password prompt

# Test ZFS access
sudo zpool status
sudo zfs list

# Exit back to your control machine
exit
```

## Step 6: Configure SSH Client

Create SSH configuration for easier access:

```bash
# Add to ~/.ssh/config on your Ansible control machine
cat >> ~/.ssh/config << 'EOF'

# TrueNAS Ansible Connection
Host truenas-ansible
    HostName your-truenas-ip
    User ansible
    IdentityFile ~/.ssh/truenas-ansible
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ServerAliveInterval 60
    ServerAliveCountMax 3

EOF
```

Test the SSH config:

```bash
# Connect using SSH config
ssh truenas-ansible

# Should connect automatically with key
sudo zpool status
exit
```

## Step 7: Harden SSH Security

Once SSH keys are working, disable password authentication:

**Via TrueNAS Web UI:**
1. **System Settings** → **Services** → **SSH** → **Configure**
2. **Allow Password Authentication**: ❌ **Disabled**
3. **Allow Root Login**: **No**
4. Click **Save**

**Or via command line:**
```bash
ssh truenas-ansible

# Edit SSH configuration
sudo nano /etc/ssh/sshd_config

# Ensure these settings:
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
PermitRootLogin no
PubkeyAuthentication yes

# Restart SSH service
sudo systemctl restart ssh
exit
```

## Step 8: Create Ansible User Bootstrap Playbook

Create a playbook to automate user creation for future deployments:

```bash
# Create bootstrap playbook on your control machine
cat > bootstrap-ansible-user.yml << 'EOF'
---
- name: Bootstrap Ansible User on TrueNAS SCALE
  hosts: truenas
  remote_user: truenas_admin
  become: true
  vars:
    ansible_user_uid: 1500
    ansible_user_gid: 1500
    ansible_public_key: "{{ lookup('file', '~/.ssh/truenas-ansible.pub') }}"
  
  tasks:
    - name: Create ansible group
      group:
        name: ansible
        gid: "{{ ansible_user_gid }}"
        state: present

    - name: Create ansible user
      user:
        name: ansible
        uid: "{{ ansible_user_uid }}"
        group: ansible
        shell: /bin/bash
        home: /home/ansible
        comment: "Ansible Automation User"
        create_home: true
        state: present

    - name: Set up SSH directory
      file:
        path: /home/ansible/.ssh
        state: directory
        owner: ansible
        group: ansible
        mode: '0700'

    - name: Install SSH public key
      authorized_key:
        user: ansible
        key: "{{ ansible_public_key }}"
        state: present

    - name: Configure sudo access
      copy:
        content: |
          # Ansible user sudo configuration
          ansible ALL=(ALL) NOPASSWD: ALL
        dest: /etc/sudoers.d/ansible
        mode: '0440'
        owner: root
        group: root
        validate: '/usr/sbin/visudo -cf %s'

    - name: Test ansible user sudo access
      command: sudo -u ansible sudo whoami
      register: sudo_test
      changed_when: false

    - name: Display setup results
      debug:
        msg:
          - "✅ Ansible user created successfully"
          - "✅ SSH key authentication configured"
          - "✅ Sudo access verified: {{ sudo_test.stdout }}"
          - "🔑 User: ansible (UID: {{ ansible_user_uid }})"
          - "👥 Group: ansible (GID: {{ ansible_user_gid }})"
          - "📁 Home: /home/ansible"
EOF
```

Run the bootstrap playbook (one-time only):

```bash
# Create temporary inventory for bootstrap
cat > bootstrap-inventory.yml << 'EOF'
all:
  hosts:
    truenas-server:
      ansible_host: your-truenas-ip
      ansible_user: truenas_admin
      ansible_become: true
      ansible_ssh_private_key_file: ~/.ssh/truenas-ansible
EOF

# Run bootstrap (replace with your TrueNAS IP)
ansible-playbook -i bootstrap-inventory.yml bootstrap-ansible-user.yml

# Clean up temporary files
rm bootstrap-inventory.yml bootstrap-ansible-user.yml
```

## Step 9: Update Ansible Configuration

Update your main Ansible configuration to use the new ansible user:

**`inventories/hosts.yml`:**
```yaml
all:
  hosts:
    truenas-server:
      ansible_host: your-truenas-ip
      ansible_user: ansible  # Our dedicated user
      ansible_ssh_private_key_file: ~/.ssh/truenas-ansible
      ansible_python_interpreter: /usr/bin/python3
      ansible_become: true
      ansible_become_method: sudo
      ansible_become_user: root
      zfs_pool: tank
  children:
    truenas:
      hosts:
        truenas-server:
      vars:
        ansible_connection: ssh
        ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
```

**`ansible.cfg`:**
```ini
[defaults]
inventory = inventories/hosts.yml
remote_user = ansible
private_key_file = ~/.ssh/truenas-ansible
host_key_checking = False

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
```

## Step 10: Validation

Test the complete setup:

```bash
# Test connection
ansible truenas-server -m ping

# Test privilege escalation
ansible truenas-server -m shell -a "whoami" --become

# Test ZFS access
ansible truenas-server -m shell -a "zpool status" --become

# Run full connection test
ansible-playbook test-connection.yml
```

## Security Considerations

### Advantages of Dedicated Ansible User

✅ **Principle of Least Privilege**: Purpose-built account with only necessary permissions  
✅ **Audit Trail**: Clear separation of automated vs manual administrative actions  
✅ **Account Isolation**: No impact on other administrative accounts  
✅ **SSH Key Only**: No password authentication risk  
✅ **Centralized Management**: Easy to disable/rotate without affecting other services  

### Optional: Restrict Sudo Commands

For even tighter security, you can limit sudo commands:

```bash
# Edit /etc/sudoers.d/ansible
sudo visudo /etc/sudoers.d/ansible

# Replace with restricted command list:
ansible ALL=(ALL) NOPASSWD: /sbin/zfs, /sbin/zpool, /usr/sbin/useradd, /usr/sbin/usermod, /usr/sbin/groupadd, /bin/mkdir, /bin/chown, /bin/chmod, /bin/systemctl, /usr/bin/apt, /usr/bin/git, /bin/cp, /bin/mv, /bin/rm, /bin/ln, /usr/bin/tee, /bin/cat
```

### SSH Key Rotation

To rotate SSH keys:

```bash
# Generate new key pair
ssh-keygen -t ed25519 -f ~/.ssh/truenas-ansible-new

# Update authorized_keys on TrueNAS
ssh truenas-ansible
sudo nano /home/ansible/.ssh/authorized_keys
# Replace old key with new key content

# Update Ansible configuration
mv ~/.ssh/truenas-ansible-new ~/.ssh/truenas-ansible
mv ~/.ssh/truenas-ansible-new.pub ~/.ssh/truenas-ansible.pub
```

## Troubleshooting

### SSH Connection Issues

```bash
# Debug SSH connection
ssh -vvv -i ~/.ssh/truenas-ansible ansible@your-truenas-ip

# Check SSH key permissions
ls -la ~/.ssh/truenas-ansible*
chmod 600 ~/.ssh/truenas-ansible
chmod 644 ~/.ssh/truenas-ansible.pub

# Verify key is in ssh-agent
ssh-add ~/.ssh/truenas-ansible
ssh-add -l
```

### Sudo Issues

```bash
# Test sudo configuration
ssh truenas-ansible "sudo -l"

# Check sudoers file
ssh truenas-ansible "sudo visudo -c"

# Verify ansible user groups
ssh truenas-ansible "groups ansible"
```

### Ansible Connection Issues

```bash
# Test with verbose output
ansible truenas-server -m ping -vvv

# Check Ansible configuration
ansible-config dump --only-changed

# Verify inventory
ansible-inventory --list
```

## Maintenance

### Regular Tasks

1. **Monitor SSH logs**: Review `/var/log/auth.log` for ansible user activity
2. **Rotate SSH keys**: Update keys quarterly or after security incidents  
3. **Review sudo logs**: Check `/var/log/sudo.log` for privilege escalation
4. **Update sudoers**: Adjust permissions as automation requirements change

### Backup ansible User Configuration

```bash
# Backup user configuration
ssh truenas-ansible "sudo tar -czf /tmp/ansible-user-backup.tar.gz /home/ansible /etc/sudoers.d/ansible"
scp truenas-ansible:/tmp/ansible-user-backup.tar.gz ./ansible-user-backup-$(date +%Y%m%d).tar.gz
ssh truenas-ansible "sudo rm /tmp/ansible-user-backup.tar.gz"
```

---

**Next Steps:** After completing this setup, your TrueNAS SCALE system will have a dedicated, secure `ansible` user account ready for automation with SSH key authentication and appropriate sudo privileges.