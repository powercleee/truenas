#!/bin/bash
# bootstrap-api.sh - Create ansible user via TrueNAS API
# This script uses the TrueNAS middleware API instead of SSH

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
if [[ ! -f "bootstrap-api-user.yml" ]]; then
    log_error "bootstrap-api-user.yml not found. Please run this from the ansible/ directory."
    exit 1
fi

# Check if API inventory exists
if [[ ! -f "bootstrap-api-inventory.yml" ]]; then
    log_error "bootstrap-api-inventory.yml not found"
    log_info "Please create it with your TrueNAS IP address"
    exit 1
fi

log_section "TrueNAS SCALE API-Based User Bootstrap"

log_info "Using API bootstrap configuration:"
log_info "  Config: bootstrap-api.cfg"
log_info "  Inventory: bootstrap-api-inventory.yml"
log_info "  Method: TrueNAS middleware API"
log_info "  Access: API-only service account"

echo
log_warn "This will create a dedicated 'ansible' user via TrueNAS API"
log_warn "User will be visible in TrueNAS Web UI"
log_warn "You will need a TrueNAS API key"
echo

# Check if API key is provided
if [[ -z "${TRUENAS_API_KEY:-}" ]]; then
    log_error "TrueNAS API key required"
    echo
    log_info "Generate an API key in TrueNAS Web UI:"
    log_info "  1. Go to Account (top right) → My API Keys"
    log_info "  2. Click 'Add' to create new key"
    log_info "  3. Set this environment variable:"
    echo "     export TRUENAS_API_KEY='your-api-key-here'"
    echo
    log_info "Then run: $0"
    exit 1
fi

read -p "Continue with API bootstrap? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Bootstrap cancelled"
    exit 0
fi

echo
log_section "Running API Bootstrap Playbook"

# Run the API bootstrap playbook
export ANSIBLE_CONFIG="./bootstrap-api.cfg"

ansible-playbook bootstrap-api-user.yml -e "truenas_api_key=${TRUENAS_API_KEY}"

# Check if bootstrap was successful
if [[ $? -eq 0 ]]; then
    echo
    log_section "API Bootstrap Complete!"
    echo
    log_info "✅ Ansible user created via TrueNAS middleware"
    log_info "✅ User visible in TrueNAS Web UI"
    log_info "✅ SSH key authentication configured"
    log_info "✅ Sudo access enabled"
    echo
    log_section "Next Steps"
    echo
    log_info "1. Verify user in TrueNAS Web UI:"
    echo "   Credentials → Local Users → ansible"
    echo
    log_info "2. Test Ansible connection:"
    echo "   ansible all -m ping"
    echo
    log_info "3. Deploy infrastructure:"
    echo "   ansible-playbook site.yml"
    echo
else
    echo
    log_error "API Bootstrap failed! Check the output above for errors"
    log_info "Common issues:"
    log_info "  - Invalid API key"
    log_info "  - Network connectivity problems"
    log_info "  - TrueNAS API version mismatch"
    exit 1
fi