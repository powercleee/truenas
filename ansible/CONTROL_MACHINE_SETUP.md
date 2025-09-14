# Ansible Control Machine Setup

This guide covers setting up the Ansible control machine to manage TrueNAS SCALE infrastructure.

## Installation

### macOS

**Option 1: Using Homebrew (Recommended)**
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Ansible and dependencies
brew install ansible python3 git openssh

# Install collections
ansible-galaxy collection install community.general ansible.posix

# Verify
ansible --version
```

**Option 2: Using Python pip**
```bash
# Install Python 3 if not already installed
brew install python3

# Install Ansible
python3 -m pip install --user ansible

# Install collections
ansible-galaxy collection install community.general ansible.posix
```

## Project Setup

### 1. Clone the Repository

```bash
# Clone the TrueNAS infrastructure repository
git clone https://github.com/powercleee/truenas.git
cd truenas/ansible
```

### 2. Install Ansible Collections

```bash
# Install required collections
ansible-galaxy install -r requirements.yml
```

### 3. SSH Configuration

```bash
# Create SSH directory if it doesn't exist
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Generate SSH key for TrueNAS (if not already done)
ssh-keygen -t ed25519 -f ~/.ssh/truenas-ansible

# Set proper permissions
chmod 600 ~/.ssh/truenas-ansible
chmod 644 ~/.ssh/truenas-ansible.pub

# Optional: Add to SSH agent
ssh-add ~/.ssh/truenas-ansible
```

### 4. Configure Ansible

```bash
# Set environment variables (add to ~/.bashrc or ~/.zshrc)
export ANSIBLE_CONFIG=~/Documents/GitHub/powercleee/truenas/ansible/ansible.cfg
export ANSIBLE_INVENTORY=~/Documents/GitHub/powercleee/truenas/ansible/inventories/hosts.yml
export ANSIBLE_PRIVATE_KEY_FILE=~/.ssh/truenas-ansible
```

## Verification Tests

### 1. Ansible Installation Test

```bash
# Check Ansible version
ansible --version
# Should show Ansible 2.9+ with Python 3.6+

# Check available modules
ansible-doc -l | grep -i zfs
# Should show ZFS-related modules

# List installed collections
ansible-galaxy collection list
# Should show community.general and ansible.posix
```

### 2. SSH Key Test

```bash
# Verify SSH key was created
ls -la ~/.ssh/truenas-ansible*
# Should show both private key (600) and public key (644)

# Display public key (you'll need this for TrueNAS)
cat ~/.ssh/truenas-ansible.pub
```

### 3. Network Connectivity Test

```bash
# Test basic connectivity to TrueNAS (replace with your IP)
ping -c 3 your-truenas-ip

# Test SSH port
nc -zv your-truenas-ip 22
# Should show: Connection to your-truenas-ip port 22 [tcp/ssh] succeeded!
```

## Troubleshooting

### Common Issues

**1. Ansible Command Not Found**
```bash
# Check PATH
echo $PATH | grep -o '[^:]*bin'

# Add to PATH (add to ~/.bashrc)
export PATH="$HOME/.local/bin:$PATH"
source ~/.bashrc
```

**2. Python Version Issues**
```bash
# Check Python version
python3 --version
ansible --version | grep python

# Ensure Ansible uses Python 3
ansible-config dump | grep interpreter
```

**3. SSH Key Permissions**
```bash
# Fix SSH key permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/truenas-ansible
chmod 644 ~/.ssh/truenas-ansible.pub
```

**4. Collection Installation Issues**
```bash
# Clear Ansible cache
ansible-galaxy collection list
rm -rf ~/.ansible/collections/ansible_collections

# Reinstall collections
ansible-galaxy collection install community.general --force
ansible-galaxy collection install ansible.posix --force
```

**5. Network/Firewall Issues**
```bash
# Test connectivity
telnet your-truenas-ip 22

# Check DNS resolution
nslookup your-truenas-ip

# Test with different SSH options
ssh -v truenas_admin@your-truenas-ip
```

## Security Best Practices

### 1. SSH Security

```bash
# Use SSH agent for key management
ssh-agent zsh
ssh-add ~/.ssh/truenas-ansible

# Configure SSH client
cat >> ~/.ssh/config << 'EOF'
Host 10.0.2.10
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ControlMaster auto
    ControlPath ~/.ssh/control-%r@%h:%p
    ControlPersist 600
EOF
```



## Ready to Proceed!

Once you've completed this setup:

1. ✅ **Ansible installed** and working
2. ✅ **SSH keys generated**
3. ✅ **Network connectivity** verified
4. ✅ **Collections installed**
5. ✅ **Environment configured**

You're ready to proceed with the TrueNAS bootstrap process:

```bash
# Next steps:
1. Configure TrueNAS (see PRE_BOOTSTRAP_CHECKLIST.md)
2. Run bootstrap playbook
3. Deploy infrastructure
```

---

**Note:** Keep your control machine updated and maintain your SSH keys securely. Consider backing up your Ansible configuration and SSH keys to a secure location.