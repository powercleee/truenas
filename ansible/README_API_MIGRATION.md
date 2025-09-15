# TrueNAS API Migration Guide

This document explains the migration of Ansible roles from direct system commands to TrueNAS API calls and the resolution of dependency conflicts.

## Overview

All three roles have been updated to use the TrueNAS middleware API instead of direct system commands:

- **truenas_users**: Creates users and groups via TrueNAS API (`/api/v2.0/user`, `/api/v2.0/group`)
- **truenas_datasets**: Creates ZFS datasets and sets permissions via TrueNAS API (`/api/v2.0/pool/dataset`, `/api/v2.0/filesystem/setperm`)
- **truenas_snapshots**: Configures snapshot management via TrueNAS API (`/api/v2.0/pool/snapshottask`)

## Critical Dependency Resolution

### The Problem

A circular dependency existed between users and datasets:
1. **Users needed datasets** - Home directory paths required `/mnt/tank/apps/{service}` to exist
2. **Dataset permissions needed users** - Ownership assignment (`chown`) required users to exist first

### The Solution: 4-Phase Execution

**Phase 1: Structure Creation**
```bash
ansible-playbook -i inventories/hosts.yml site.yml --tags "groups,datasets" --skip-tags "permissions,post_users" --diff
```
- Creates all service groups with proper GIDs
- Creates all ZFS datasets and directory structure
- **Skips** permission assignment (no `chown` operations)

**Phase 2: User Creation**
```bash
ansible-playbook -i inventories/hosts.yml site.yml --tags "users" --skip-tags "home_directories,post_datasets" --diff
```
- Creates all service users with UIDs
- Uses temporary home directory (`/nonexistent`)
- **Skips** home directory assignment

**Phase 3: Final Configuration**
```bash
ansible-playbook -i inventories/hosts.yml site.yml --tags "home_directories,permissions,post_users" --diff
```
- Updates user home directories to correct paths
- Sets all dataset ownership and permissions
- Configures supplementary group memberships

**Phase 4: Snapshots**
```bash
ansible-playbook -i inventories/hosts.yml site.yml --tags "snapshots" --diff
```
- Configures automated snapshot management
- **truenas_snapshots**: Configures snapshot tasks via TrueNAS API

## Prerequisites

### 1. TrueNAS API Key

Generate an API key in the TrueNAS Web UI:
1. Navigate to System > API Keys
2. Click "Add" to create a new API key
3. Copy the generated key - you won't be able to see it again
4. Store it securely using ansible-vault

### 2. Ansible Vault Setup

Create an encrypted vault file to store the API key:

```bash
ansible-vault create ansible/group_vars/vault.yml
```

Add this content to the vault file:
```yaml
vault_truenas_api_key: "your-actual-api-key-here"
```

### 3. Configuration File

Copy the example configuration and customize:

```bash
cp ansible/group_vars/truenas.yml.example ansible/group_vars/truenas.yml
```

Edit the file to match your environment:
```yaml
ansible_host: "your-truenas-ip-or-hostname"
vault_truenas_api_key: "{{ vault_truenas_api_key }}"
truenas_validate_certs: true  # Set to false for self-signed certs
```

## API Endpoints Used

### Users Role
- `GET /api/v2.0/group?name={groupname}` - Check existing groups and get database IDs
- `POST /api/v2.0/group` - Create groups
- `GET /api/v2.0/user?username={username}` - Check existing users and get database IDs
- `POST /api/v2.0/user` - Create users (using group database ID, not GID)
- `PUT /api/v2.0/user/id/{user_db_id}` - Update user group memberships (using database IDs)

### Datasets Role
- `POST /api/v2.0/pool/dataset` - Create datasets
- `PUT /api/v2.0/pool/dataset/id/{dataset_id}` - Update dataset properties
- `POST /api/v2.0/filesystem/setperm` - Set filesystem permissions

### Snapshots Role
- `POST /api/v2.0/pool/snapshottask` - Create snapshot tasks

## Benefits of API Migration

1. **No Direct System Access**: Roles no longer require direct SSH access to the TrueNAS system
2. **TrueNAS Integration**: All operations are properly integrated with TrueNAS middleware
3. **Web UI Visibility**: All created resources are visible and manageable through the Web UI
4. **Validation**: TrueNAS API provides built-in validation and error handling
5. **Consistency**: Operations use the same code paths as the Web UI

## Running the Playbook

With vault password prompt:
```bash
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass
```

With vault password file:
```bash
ansible-playbook -i inventory/hosts.yml site.yml --vault-password-file .vault_pass
```

## Verification

After running the playbook, verify the results in the TrueNAS Web UI:

1. **Users**: Accounts > Users & Groups
2. **Datasets**: Storage > Pools > [pool name]
3. **Snapshots**: Data Protection > Periodic Snapshot Tasks

## Error Handling

The roles handle common scenarios:
- **409 Conflict**: Resource already exists (ignored)
- **Authentication**: Invalid API key will cause immediate failure
- **Permissions**: Insufficient API key permissions will be reported

## Migration Notes

- The sanoid-specific tasks have been replaced with native TrueNAS snapshot tasks
- Template files are now generated locally instead of being deployed to the target system
- All file operations that required root access now use API calls
- The roles are now idempotent and can be run multiple times safely
- **Important**: User creation requires group database IDs (not GIDs) - the role automatically looks up and maps these
- Group membership updates use both user and group database IDs for proper API integration

## Troubleshooting

### API Key Issues
- Ensure the API key is correctly stored in the vault file
- Verify the API key has sufficient permissions in TrueNAS
- Check that the ansible_host variable points to the correct TrueNAS system

### SSL Certificate Issues
- For self-signed certificates, set `truenas_validate_certs: false`
- For production environments, use proper SSL certificates

### Network Connectivity
- Ensure Ansible can reach the TrueNAS system on HTTPS (port 443)
- Verify firewall rules allow connection from the Ansible control node