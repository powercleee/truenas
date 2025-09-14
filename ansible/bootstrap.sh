#!/bin/bash
# bootstrap.sh - Create ansible user on TrueNAS SCALE
# This script uses the bootstrap-specific ansible.cfg

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "${BLUE}=== $1 ===${NC}"; }

# Check if we're in the right directory
if [[ ! -f "bootstrap-ansible-user.yml" ]]; then
    log_error "bootstrap-ansible-user.yml not found. Please run this from the ansible/ directory."
    exit 1
fi

# Check if SSH key exists
if [[ ! -f "$HOME/.ssh/truenas-ansible" ]]; then
    log_error "SSH key not found at ~/.ssh/truenas-ansible"
    log_info "Please generate it with: ssh-keygen -t ed25519 -f ~/.ssh/truenas-ansible"
    exit 1
fi

# Check if bootstrap inventory exists
if [[ ! -f "bootstrap-inventory.yml" ]]; then
    log_error "bootstrap-inventory.yml not found"
    log_info "Please create it with your TrueNAS IP address"
    exit 1
fi

log_section "TrueNAS SCALE Ansible User Bootstrap"

log_info "Using bootstrap configuration:"
log_info "  Config: bootstrap-ansible.cfg"
log_info "  Inventory: bootstrap-inventory.yml"
log_info "  User: truenas_admin (temporary)"
log_info "  SSH Key: ~/.ssh/truenas-ansible"

echo
log_warn "This will create a dedicated 'ansible' user (UID: 1500) on your TrueNAS system"
log_warn "You will be prompted for the truenas_admin password"
echo

read -p "Continue with bootstrap? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Bootstrap cancelled"
    exit 0
fi

echo
log_section "Running Bootstrap Playbook"

# Run the bootstrap playbook with the bootstrap-specific configuration
export ANSIBLE_CONFIG="./bootstrap-ansible.cfg"

ansible-playbook bootstrap-ansible-user.yml --ask-pass

# Check if bootstrap was successful
if [[ $? -eq 0 ]]; then
    echo
    log_section "Bootstrap Complete!"
    echo
    log_info "✅ Ansible user created successfully"
    log_info "✅ SSH key authentication configured"
    log_info "✅ Sudo access enabled"
    echo
    log_section "Next Steps"
    echo
    log_info "1. Test SSH connection:"
    echo "   ssh -i ~/.ssh/truenas-ansible ansible@$(grep ansible_host bootstrap-inventory.yml | awk '{print $2}')"
    echo
    log_info "2. Test Ansible connection:"
    echo "   ansible-playbook test-connection.yml"
    echo
    log_info "3. Deploy infrastructure:"
    echo "   ansible-playbook site.yml"
    echo
    log_warn "Remember to disable password authentication in TrueNAS Web UI:"
    log_warn "System Settings → Services → SSH → Configure"
    log_warn "Set 'Allow Password Authentication' to DISABLED"
    echo
else
    echo
    log_error "Bootstrap failed! Check the output above for errors"
    log_info "Common issues:"
    log_info "  - Wrong truenas_admin password"
    log_info "  - Network connectivity problems"
    log_info "  - SSH service not enabled on TrueNAS"
    exit 1
fi