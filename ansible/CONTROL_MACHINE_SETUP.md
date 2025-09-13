# Ansible Control Machine Setup

This guide covers setting up your Ansible control machine (laptop, desktop, or server) to manage TrueNAS SCALE infrastructure.

## System Requirements

### Minimum Requirements
- **OS**: Linux, macOS, or Windows (with WSL2)
- **RAM**: 2GB available
- **Storage**: 1GB free space
- **Network**: Internet access + connectivity to TrueNAS

### Recommended
- **OS**: Linux (Ubuntu 22.04+) or macOS
- **RAM**: 4GB+ available
- **Storage**: 5GB+ free space
- **Network**: Stable connection to TrueNAS management network

## Installation by Operating System

### Ubuntu/Debian Linux

```bash
# Update package manager
sudo apt update && sudo apt upgrade -y

# Install Python 3 and pip
sudo apt install -y python3 python3-pip python3-venv

# Install system dependencies
sudo apt install -y curl wget git openssh-client sshpass

# Install Ansible via pip (recommended for latest version)
python3 -m pip install --user ansible

# Or install via apt (older version but more stable)
# sudo apt install -y ansible

# Install additional Ansible collections
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix

# Verify installation
ansible --version
python3 --version
```

### RHEL/CentOS/Fedora

```bash
# RHEL/CentOS 8+
sudo dnf update -y
sudo dnf install -y python3 python3-pip git openssh-clients

# Fedora
sudo dnf install -y ansible python3 python3-pip git openssh-clients

# CentOS 7 (use EPEL)
sudo yum install -y epel-release
sudo yum install -y ansible python3 python3-pip git openssh-clients

# Install Ansible via pip (if not using package manager)
python3 -m pip install --user ansible

# Install collections
ansible-galaxy collection install community.general ansible.posix

# Verify
ansible --version
```

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

### Windows (WSL2)

```bash
# First, install WSL2 with Ubuntu
# https://docs.microsoft.com/en-us/windows/wsl/install

# Inside WSL2 Ubuntu, follow Ubuntu instructions above
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv curl wget git openssh-client
python3 -m pip install --user ansible
ansible-galaxy collection install community.general ansible.posix
```

## Project Setup

### 1. Clone the Repository

```bash
# Clone the TrueNAS infrastructure repository
git clone https://github.com/your-username/truenas-infrastructure.git
cd truenas-infrastructure/ansible

# Or if you're setting up locally
mkdir -p ~/truenas-automation
cd ~/truenas-automation
# Copy the ansible directory contents here
```

### 2. Python Virtual Environment (Recommended)

```bash
# Create virtual environment
python3 -m venv ansible-env

# Activate virtual environment
source ansible-env/bin/activate  # Linux/macOS
# ansible-env\Scripts\activate     # Windows

# Install Ansible in virtual environment
pip install ansible

# Install requirements
pip install -r requirements.txt  # if requirements.txt exists
```

### 3. Install Ansible Collections

```bash
# Install required collections
ansible-galaxy install -r requirements.yml

# Or manually install key collections
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix
```

### 4. SSH Configuration

```bash
# Create SSH directory if it doesn't exist
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Generate SSH key for TrueNAS (if not already done)
ssh-keygen -t ed25519 -f ~/.ssh/truenas-ansible -C "ansible@$(hostname)"

# Set proper permissions
chmod 600 ~/.ssh/truenas-ansible
chmod 644 ~/.ssh/truenas-ansible.pub

# Optional: Add to SSH agent
ssh-add ~/.ssh/truenas-ansible
```

### 5. Configure Ansible

```bash
# Create Ansible configuration directory
mkdir -p ~/.ansible

# Set environment variables (add to ~/.bashrc or ~/.zshrc)
export ANSIBLE_CONFIG=~/truenas-automation/ansible/ansible.cfg
export ANSIBLE_INVENTORY=~/truenas-automation/ansible/inventories/hosts.yml
export ANSIBLE_PRIVATE_KEY_FILE=~/.ssh/truenas-ansible

# Or create global Ansible config
cat > ~/.ansible.cfg << 'EOF'
[defaults]
host_key_checking = False
timeout = 30
retry_files_enabled = False
stdout_callback = yaml

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
EOF
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

## IDE/Editor Setup (Optional)

### VS Code with Ansible Extension

```bash
# Install VS Code extensions
code --install-extension redhat.ansible
code --install-extension ms-python.python
code --install-extension timonwong.shellcheck

# Configure VS Code for Ansible
mkdir -p .vscode
cat > .vscode/settings.json << 'EOF'
{
    "ansible.python.interpreterPath": "python3",
    "ansible.validation.enabled": true,
    "ansible.validation.lint.enabled": true,
    "files.associations": {
        "*.yml": "ansible",
        "*.yaml": "ansible"
    }
}
EOF
```

### Vim/Neovim with Ansible Plugin

```bash
# Install vim-ansible plugin
git clone https://github.com/pearofducks/ansible-vim ~/.vim/pack/ansible/start/ansible-vim

# Or for Neovim with vim-plug
# Add to ~/.config/nvim/init.vim:
# Plug 'pearofducks/ansible-vim'
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
ssh-agent bash
ssh-add ~/.ssh/truenas-ansible

# Configure SSH client
cat >> ~/.ssh/config << 'EOF'
Host truenas-*
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ControlMaster auto
    ControlPath ~/.ssh/control-%r@%h:%p
    ControlPersist 600
EOF
```

### 2. Ansible Vault

```bash
# Create vault password file
echo "your-secure-vault-password" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass

# Create encrypted variables file
ansible-vault create secrets.yml
# Or encrypt existing file
ansible-vault encrypt secrets.yml
```

### 3. Network Security

```bash
# Consider using VPN for remote access
# Configure firewall to restrict SSH access
# Use non-standard SSH ports if needed
```

## Performance Optimization

### 1. SSH Multiplexing

Already configured in SSH config above - reuses connections for better performance.

### 2. Ansible Configuration

```bash
# Add to ansible.cfg for better performance
cat >> ansible.cfg << 'EOF'
[defaults]
forks = 20
poll_interval = 15
gathering = smart
fact_caching = jsonfile
fact_caching_connection = ./cache/facts
fact_caching_timeout = 86400

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
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