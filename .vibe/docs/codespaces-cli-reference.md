# GitHub Codespaces CLI Reference

## Overview
The GitHub CLI (`gh`) provides comprehensive command-line access to manage GitHub Codespaces. This document covers all available commands, practical examples, and automation patterns for Codespaces management.

## Table of Contents
1. [Installation and Setup](#installation-and-setup)
2. [Core Commands](#core-commands)
3. [Codespace Management](#codespace-management)
4. [Port Forwarding](#port-forwarding)
5. [Environment Configuration](#environment-configuration)
6. [Advanced Operations](#advanced-operations)
7. [Automation and Scripting](#automation-and-scripting)
8. [Troubleshooting](#troubleshooting)

## Installation and Setup

### Installing GitHub CLI
```bash
# macOS
brew install gh

# Ubuntu/Debian
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# Windows (with Scoop)
scoop install gh

# Windows (with Chocolatey)
choco install gh
```

### Authentication
```bash
# Authenticate with GitHub
gh auth login

# Check authentication status
gh auth status

# Authenticate with specific scopes
gh auth login --scopes "codespace,repo"

# Use token authentication
echo $GITHUB_TOKEN | gh auth login --with-token

# Switch between accounts
gh auth switch
```

## Core Commands

### Basic Codespace Operations
```bash
# List all your codespaces
gh codespace list

# List with details
gh codespace list --json name,state,repository,machine,createdAt

# List codespaces for specific repo
gh codespace list --repo owner/repository

# View codespace details
gh codespace view --codespace CODESPACE_NAME
```

### Creating Codespaces
```bash
# Create a new codespace (interactive)
gh codespace create

# Create with specific parameters
gh codespace create \
  --repo owner/repository \
  --branch main \
  --machine standardLinux \
  --retention-period 7d \
  --display-name "My Dev Environment"

# Create with specific machine type
gh codespace create \
  --repo owner/repository \
  --machine premiumLinux \
  --location WestUs2

# Create from current directory
gh codespace create --repo .

# Create with dev container configuration
gh codespace create \
  --repo owner/repository \
  --devcontainer-path .devcontainer/backend/devcontainer.json
```

### Machine Types
```bash
# Available machine types:
# - basicLinux: 2 cores, 4GB RAM, 32GB storage
# - standardLinux: 4 cores, 8GB RAM, 32GB storage  
# - premiumLinux: 8 cores, 16GB RAM, 64GB storage
# - largePremiumLinux: 16 cores, 32GB RAM, 128GB storage

# List available machine types for a repository
gh api repos/owner/repository/codespaces/machines
```

### Connecting to Codespaces
```bash
# Connect via SSH
gh codespace ssh

# SSH to specific codespace
gh codespace ssh --codespace CODESPACE_NAME

# SSH with command
gh codespace ssh --codespace CODESPACE_NAME -- ls -la

# Open in VS Code
gh codespace code

# Open specific codespace in VS Code
gh codespace code --codespace CODESPACE_NAME

# Open in browser (VS Code Web)
gh codespace code --web

# Open with JupyterLab
gh codespace jupyter

# Connect with custom SSH config
gh codespace ssh --config ~/.ssh/custom_config
```

## Codespace Management

### Lifecycle Management
```bash
# Start a stopped codespace
gh codespace start --codespace CODESPACE_NAME

# Stop a running codespace
gh codespace stop --codespace CODESPACE_NAME

# Restart a codespace
gh codespace restart --codespace CODESPACE_NAME

# Delete a codespace
gh codespace delete --codespace CODESPACE_NAME

# Delete all codespaces for a repo
gh codespace delete --all --repo owner/repository

# Delete codespaces older than N days
gh codespace list --json name,createdAt | \
  jq -r '.[] | select(.createdAt | fromdateiso8601 < (now - 86400 * 7)) | .name' | \
  xargs -I {} gh codespace delete --codespace {}
```

### Rebuilding Codespaces
```bash
# Rebuild container (preserves user data)
gh codespace rebuild

# Rebuild specific codespace
gh codespace rebuild --codespace CODESPACE_NAME

# Full rebuild (recreates container)
gh codespace rebuild --full
```

### Codespace Logs
```bash
# View codespace logs
gh codespace logs

# View logs for specific codespace
gh codespace logs --codespace CODESPACE_NAME

# Follow logs (tail -f style)
gh codespace logs --follow

# View creation logs
gh codespace logs --codespace CODESPACE_NAME --creation
```

## Port Forwarding

### Managing Ports
```bash
# List forwarded ports
gh codespace ports

# List ports for specific codespace
gh codespace ports --codespace CODESPACE_NAME

# List ports in JSON format
gh codespace ports --json sourcePort,label,visibility,browseUrl

# Forward a port
gh codespace ports forward 3000:3000

# Forward with specific codespace
gh codespace ports forward 3000:3000 --codespace CODESPACE_NAME

# Forward multiple ports
gh codespace ports forward 3000:3000 8080:8080 5432:5432
```

### Port Visibility
```bash
# Set port visibility (private, org, public)
gh codespace ports visibility 3000:public

# Set multiple ports to public
gh codespace ports visibility 3000:public 8080:public 3001:public

# Set organization visibility
gh codespace ports visibility 3000:org

# Make port private
gh codespace ports visibility 3000:private

# Set visibility with specific codespace
gh codespace ports visibility 3000:public --codespace CODESPACE_NAME
```

### Port Labels and Protocols
```bash
# The GitHub CLI doesn't directly support setting labels/protocols
# Use the API instead:

# Set port attributes via API
gh api \
  --method PATCH \
  -H "Accept: application/vnd.github+json" \
  /user/codespaces/CODESPACE_NAME \
  --field ports='[
    {
      "number": 3000,
      "label": "Frontend",
      "visibility": "public",
      "protocol": "https"
    },
    {
      "number": 3001,
      "label": "API",
      "visibility": "public",
      "protocol": "http"
    }
  ]'
```

## Environment Configuration

### Secrets Management
```bash
# List codespace secrets
gh secret list --env codespace

# Set a codespace secret for user
gh secret set MY_SECRET --env codespace

# Set secret with value
echo "secret-value" | gh secret set MY_SECRET --env codespace

# Set repository codespace secret
gh secret set MY_SECRET --env codespace --repo owner/repository

# Set organization codespace secret
gh secret set MY_SECRET --env codespace --org organization

# Delete a secret
gh secret delete MY_SECRET --env codespace

# Set secret from file
gh secret set MY_SECRET --env codespace < secret.txt
```

### Environment Variables
```bash
# Codespaces automatically provides these environment variables:
# CODESPACES=true
# CODESPACE_NAME=<unique-name>
# GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN=app.github.dev
# GITHUB_USER=<username>
# GITHUB_TOKEN=<token>
# GITHUB_REPOSITORY=owner/repo
# GITHUB_REPOSITORY_OWNER=owner

# Access in codespace
gh codespace ssh -- printenv | grep CODESPACE

# Set custom environment variables in devcontainer.json
cat > .devcontainer/devcontainer.json <<EOF
{
  "remoteEnv": {
    "MY_CUSTOM_VAR": "value",
    "API_ENDPOINT": "https://api.example.com"
  }
}
EOF
```

## Advanced Operations

### File Operations
```bash
# Copy files to codespace
gh codespace cp local-file.txt remote:/workspaces/project/

# Copy from codespace
gh codespace cp remote:/workspaces/project/output.txt ./local-output.txt

# Copy directory
gh codespace cp -r ./local-dir remote:/workspaces/project/

# Copy with specific codespace
gh codespace cp --codespace CODESPACE_NAME local.txt remote:/tmp/

# Sync directories (requires rsync)
rsync -avz -e "gh codespace ssh --" ./local/ :~/remote/
```

### Running Commands
```bash
# Execute command in codespace
gh codespace ssh -- ls -la

# Run complex commands
gh codespace ssh -- "cd /workspaces/project && npm install && npm test"

# Run interactive commands
gh codespace ssh -- bash

# Execute script
gh codespace ssh -- bash < local-script.sh

# Run command and capture output
OUTPUT=$(gh codespace ssh -- cat /workspaces/project/version.txt)
echo "Version: $OUTPUT"
```

### Codespace Configuration
```bash
# Edit codespace configuration
gh codespace edit --codespace CODESPACE_NAME \
  --machine premiumLinux \
  --display-name "Production Debug"

# Update retention period
gh codespace edit --codespace CODESPACE_NAME \
  --retention-period 30d

# Change default editor
gh config set editor "code --wait"

# Set default codespace settings
gh config set codespace.default_permissions "write"
```

## Automation and Scripting

### Bash Script Examples
```bash
#!/bin/bash
# codespace-manager.sh - Automated codespace management

# Function to create and setup codespace
create_dev_environment() {
    local REPO=$1
    local BRANCH=${2:-main}
    
    echo "Creating codespace for $REPO on branch $BRANCH..."
    
    # Create codespace
    CODESPACE_NAME=$(gh codespace create \
        --repo "$REPO" \
        --branch "$BRANCH" \
        --machine standardLinux \
        --json name \
        -q .name)
    
    echo "Created codespace: $CODESPACE_NAME"
    
    # Wait for codespace to be ready
    while true; do
        STATE=$(gh codespace list --json name,state \
            | jq -r ".[] | select(.name==\"$CODESPACE_NAME\") | .state")
        
        if [ "$STATE" = "Available" ]; then
            break
        fi
        
        echo "Waiting for codespace to be ready... (current state: $STATE)"
        sleep 10
    done
    
    # Set up ports
    echo "Configuring ports..."
    gh codespace ports visibility 3000:public --codespace "$CODESPACE_NAME"
    gh codespace ports visibility 3001:public --codespace "$CODESPACE_NAME"
    
    # Run setup commands
    echo "Running setup..."
    gh codespace ssh --codespace "$CODESPACE_NAME" -- "
        cd /workspaces/* &&
        npm install &&
        npm run setup
    "
    
    echo "Codespace ready: $CODESPACE_NAME"
    return 0
}

# Function to backup codespace
backup_codespace() {
    local CODESPACE_NAME=$1
    local BACKUP_DIR="./backups/$(date +%Y%m%d-%H%M%S)"
    
    mkdir -p "$BACKUP_DIR"
    
    echo "Backing up $CODESPACE_NAME to $BACKUP_DIR..."
    
    # Copy important files
    gh codespace cp -r \
        "remote:/workspaces/*/src" \
        "$BACKUP_DIR/" \
        --codespace "$CODESPACE_NAME"
    
    # Export environment
    gh codespace ssh --codespace "$CODESPACE_NAME" -- printenv \
        > "$BACKUP_DIR/environment.txt"
    
    # Save codespace info
    gh codespace view --codespace "$CODESPACE_NAME" --json \
        > "$BACKUP_DIR/codespace-info.json"
    
    echo "Backup complete: $BACKUP_DIR"
}

# Function to cleanup old codespaces
cleanup_old_codespaces() {
    local DAYS=${1:-7}
    
    echo "Cleaning up codespaces older than $DAYS days..."
    
    local CUTOFF=$(date -d "$DAYS days ago" +%s)
    
    gh codespace list --json name,createdAt | jq -r '.[]' | while read -r codespace; do
        NAME=$(echo "$codespace" | jq -r .name)
        CREATED=$(echo "$codespace" | jq -r .createdAt)
        CREATED_TS=$(date -d "$CREATED" +%s)
        
        if [ "$CREATED_TS" -lt "$CUTOFF" ]; then
            echo "Deleting old codespace: $NAME (created: $CREATED)"
            gh codespace delete --codespace "$NAME" --force
        fi
    done
}

# Main menu
case "$1" in
    create)
        create_dev_environment "$2" "$3"
        ;;
    backup)
        backup_codespace "$2"
        ;;
    cleanup)
        cleanup_old_codespaces "$2"
        ;;
    *)
        echo "Usage: $0 {create|backup|cleanup} [args]"
        exit 1
        ;;
esac
```

### Python Automation
```python
#!/usr/bin/env python3
# codespace_automation.py - Python automation for Codespaces

import subprocess
import json
import time
from datetime import datetime, timedelta
from typing import List, Dict, Optional

class CodespaceManager:
    def __init__(self):
        self.gh_cmd = "gh"
    
    def run_command(self, args: List[str]) -> str:
        """Execute gh command and return output"""
        cmd = [self.gh_cmd] + args
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    
    def list_codespaces(self, repo: Optional[str] = None) -> List[Dict]:
        """List all codespaces"""
        args = ["codespace", "list", "--json", 
                "name,state,repository,machine,createdAt"]
        
        if repo:
            args.extend(["--repo", repo])
        
        output = self.run_command(args)
        return json.loads(output) if output else []
    
    def create_codespace(
        self,
        repo: str,
        branch: str = "main",
        machine: str = "standardLinux"
    ) -> str:
        """Create a new codespace"""
        args = [
            "codespace", "create",
            "--repo", repo,
            "--branch", branch,
            "--machine", machine,
            "--json", "name"
        ]
        
        output = self.run_command(args)
        data = json.loads(output)
        return data["name"]
    
    def setup_ports(
        self,
        codespace_name: str,
        ports: Dict[int, str]
    ):
        """Configure port visibility"""
        for port, visibility in ports.items():
            args = [
                "codespace", "ports", "visibility",
                f"{port}:{visibility}",
                "--codespace", codespace_name
            ]
            self.run_command(args)
    
    def execute_command(
        self,
        codespace_name: str,
        command: str
    ) -> str:
        """Execute command in codespace"""
        args = [
            "codespace", "ssh",
            "--codespace", codespace_name,
            "--", command
        ]
        return self.run_command(args)
    
    def monitor_codespaces(self):
        """Monitor codespace health and usage"""
        codespaces = self.list_codespaces()
        
        print(f"Total codespaces: {len(codespaces)}")
        print("-" * 50)
        
        for cs in codespaces:
            name = cs["name"]
            state = cs["state"]
            created = datetime.fromisoformat(
                cs["createdAt"].replace("Z", "+00:00")
            )
            age = datetime.now(created.tzinfo) - created
            
            print(f"Name: {name}")
            print(f"State: {state}")
            print(f"Repository: {cs['repository']}")
            print(f"Machine: {cs['machine']}")
            print(f"Age: {age.days} days, {age.seconds // 3600} hours")
            
            if state == "Available":
                # Check port configuration
                try:
                    ports_output = self.run_command([
                        "codespace", "ports",
                        "--codespace", name,
                        "--json", "sourcePort,visibility"
                    ])
                    ports = json.loads(ports_output) if ports_output else []
                    print(f"Ports: {ports}")
                except:
                    print("Ports: Unable to fetch")
            
            print("-" * 50)
    
    def cleanup_old_codespaces(self, days: int = 7):
        """Delete codespaces older than specified days"""
        codespaces = self.list_codespaces()
        cutoff = datetime.now() - timedelta(days=days)
        
        for cs in codespaces:
            created = datetime.fromisoformat(
                cs["createdAt"].replace("Z", "+00:00")
            )
            created = created.replace(tzinfo=None)
            
            if created < cutoff:
                print(f"Deleting old codespace: {cs['name']}")
                self.run_command([
                    "codespace", "delete",
                    "--codespace", cs["name"],
                    "--force"
                ])
    
    def create_development_environment(
        self,
        repo: str,
        setup_script: str = None
    ):
        """Create and configure a complete development environment"""
        print(f"Creating development environment for {repo}...")
        
        # Create codespace
        codespace_name = self.create_codespace(repo)
        print(f"Created codespace: {codespace_name}")
        
        # Wait for it to be ready
        print("Waiting for codespace to be ready...")
        while True:
            codespaces = self.list_codespaces()
            cs = next(
                (c for c in codespaces if c["name"] == codespace_name),
                None
            )
            
            if cs and cs["state"] == "Available":
                break
            
            time.sleep(10)
        
        # Configure ports
        print("Configuring ports...")
        self.setup_ports(codespace_name, {
            3000: "public",
            3001: "public",
            8080: "public"
        })
        
        # Run setup script if provided
        if setup_script:
            print("Running setup script...")
            output = self.execute_command(codespace_name, setup_script)
            print(output)
        
        print(f"Environment ready: {codespace_name}")
        return codespace_name

# Example usage
if __name__ == "__main__":
    import sys
    
    manager = CodespaceManager()
    
    if len(sys.argv) < 2:
        print("Usage: python codespace_automation.py [command]")
        print("Commands: list, create, monitor, cleanup")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "list":
        codespaces = manager.list_codespaces()
        for cs in codespaces:
            print(f"{cs['name']}: {cs['state']} ({cs['repository']})")
    
    elif command == "create":
        if len(sys.argv) < 3:
            print("Usage: python codespace_automation.py create <repo>")
            sys.exit(1)
        repo = sys.argv[2]
        manager.create_development_environment(repo)
    
    elif command == "monitor":
        manager.monitor_codespaces()
    
    elif command == "cleanup":
        days = int(sys.argv[2]) if len(sys.argv) > 2 else 7
        manager.cleanup_old_codespaces(days)
```

### GitHub Actions Integration
```yaml
# .github/workflows/codespace-management.yml
name: Codespace Management

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday
  workflow_dispatch:
    inputs:
      action:
        description: 'Action to perform'
        required: true
        default: 'cleanup'
        type: choice
        options:
          - cleanup
          - create
          - list

jobs:
  manage-codespaces:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup GitHub CLI
        run: |
          gh auth setup-git
          gh auth status
      
      - name: List Codespaces
        if: github.event.inputs.action == 'list' || github.event_name == 'schedule'
        run: |
          echo "Current Codespaces:"
          gh codespace list --json name,state,repository,createdAt \
            | jq -r '.[] | "\(.name) - \(.state) - \(.repository) - \(.createdAt)"'
      
      - name: Cleanup Old Codespaces
        if: github.event.inputs.action == 'cleanup' || github.event_name == 'schedule'
        run: |
          echo "Cleaning up codespaces older than 7 days..."
          
          CUTOFF=$(date -d "7 days ago" --iso-8601)
          
          gh codespace list --json name,createdAt | \
            jq -r --arg cutoff "$CUTOFF" \
            '.[] | select(.createdAt < $cutoff) | .name' | \
            while read -r name; do
              echo "Deleting: $name"
              gh codespace delete --codespace "$name" --force
            done
      
      - name: Create Development Codespace
        if: github.event.inputs.action == 'create'
        run: |
          CODESPACE_NAME=$(gh codespace create \
            --repo ${{ github.repository }} \
            --branch main \
            --machine standardLinux \
            --json name -q .name)
          
          echo "Created codespace: $CODESPACE_NAME"
          echo "codespace_name=$CODESPACE_NAME" >> $GITHUB_OUTPUT
```

## API Access

### Using GitHub API for Codespaces
```bash
# Get codespace details via API
gh api /user/codespaces

# Get specific codespace
gh api /user/codespaces/CODESPACE_NAME

# Update codespace configuration
gh api \
  --method PATCH \
  /user/codespaces/CODESPACE_NAME \
  --field machine=premiumLinux \
  --field display_name="Production Debug"

# Get available machines for repository
gh api /repos/owner/repository/codespaces/machines

# Get codespace secrets
gh api /user/codespaces/secrets

# Create codespace via API
gh api \
  --method POST \
  /repos/owner/repository/codespaces \
  --field ref=main \
  --field machine=standardLinux

# Export codespace
gh api \
  --method POST \
  /user/codespaces/CODESPACE_NAME/exports

# Get organization codespaces
gh api /orgs/ORGANIZATION/codespaces

# Get billing information
gh api /user/codespaces/billing
```

### Advanced API Operations
```bash
# Get prebuild configurations
gh api /repos/owner/repository/codespaces/devcontainers

# Trigger prebuild
gh api \
  --method POST \
  /repos/owner/repository/codespaces/prebuilds \
  --field devcontainer_path=.devcontainer/devcontainer.json

# Get codespace usage metrics
gh api /user/codespaces/CODESPACE_NAME/metrics

# Set repository secrets for codespaces
gh api \
  --method PUT \
  /repos/owner/repository/codespaces/secrets/SECRET_NAME \
  --field encrypted_value="..." \
  --field key_id="..."
```

## Troubleshooting

### Common Issues and Solutions

#### Codespace Won't Start
```bash
# Check creation logs
gh codespace logs --codespace CODESPACE_NAME --creation

# Rebuild container
gh codespace rebuild --codespace CODESPACE_NAME

# Delete and recreate
gh codespace delete --codespace CODESPACE_NAME --force
gh codespace create --repo owner/repository
```

#### Port Forwarding Issues
```bash
# Check current port configuration
gh codespace ports --codespace CODESPACE_NAME

# Reset port forwarding
gh codespace ports visibility 3000:private
gh codespace ports visibility 3000:public

# Verify port is listening inside codespace
gh codespace ssh --codespace CODESPACE_NAME -- "lsof -i :3000"
```

#### SSH Connection Problems
```bash
# Test SSH connection
gh codespace ssh --codespace CODESPACE_NAME -- echo "Connected"

# Check SSH configuration
gh codespace ssh --codespace CODESPACE_NAME --debug

# Reset SSH keys
gh auth refresh

# Use alternative connection method
gh codespace code --codespace CODESPACE_NAME
```

#### Performance Issues
```bash
# Check resource usage
gh codespace ssh --codespace CODESPACE_NAME -- "
  echo 'CPU Usage:' && top -bn1 | head -5
  echo 'Memory Usage:' && free -h
  echo 'Disk Usage:' && df -h
"

# Upgrade machine type
gh codespace edit --codespace CODESPACE_NAME --machine premiumLinux

# Clear caches and temporary files
gh codespace ssh --codespace CODESPACE_NAME -- "
  rm -rf /tmp/*
  npm cache clean --force
  pip cache purge
"
```

### Debug Commands
```bash
# Enable debug output
export GH_DEBUG=1
gh codespace list

# Check gh configuration
gh config list

# Verify authentication
gh auth status

# Test API access
gh api /user

# Check rate limits
gh api /rate_limit
```

## Best Practices

### Security
1. **Use secrets** for sensitive data, never hardcode
2. **Set appropriate port visibility** (prefer private/org over public)
3. **Rotate tokens regularly** using `gh auth refresh`
4. **Clean up unused codespaces** to reduce attack surface
5. **Use organization policies** to enforce security settings

### Performance
1. **Choose appropriate machine types** for workload
2. **Use prebuilds** to speed up creation time
3. **Cache dependencies** in Docker layers
4. **Clean up regularly** to free resources
5. **Monitor resource usage** and upgrade when needed

### Cost Management
1. **Set retention periods** appropriately
2. **Stop codespaces** when not in use
3. **Delete old codespaces** automatically
4. **Use smaller machines** for light tasks
5. **Monitor billing** regularly via API

### Automation
1. **Script common operations** for consistency
2. **Use GitHub Actions** for scheduled maintenance
3. **Implement health checks** for critical codespaces
4. **Automate backups** of important work
5. **Create templates** for common configurations

## Quick Reference

### Essential Commands
```bash
# Create
gh codespace create --repo owner/repo

# List
gh codespace list

# Connect
gh codespace ssh
gh codespace code

# Stop/Start
gh codespace stop
gh codespace start

# Delete
gh codespace delete

# Ports
gh codespace ports
gh codespace ports visibility 3000:public

# Logs
gh codespace logs

# Copy files
gh codespace cp local.txt remote:/path/
```

### Environment Variables in Codespaces
```bash
CODESPACES=true
CODESPACE_NAME=<name>
GITHUB_USER=<username>
GITHUB_TOKEN=<token>
GITHUB_REPOSITORY=owner/repo
GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN=app.github.dev
```

### Useful Aliases
```bash
# Add to ~/.bashrc or ~/.zshrc
alias csl="gh codespace list"
alias csc="gh codespace create"
alias css="gh codespace ssh"
alias cscode="gh codespace code"
alias csstop="gh codespace stop"
alias csdelete="gh codespace delete"
alias csports="gh codespace ports"

# Functions for common operations
cs-public() {
  gh codespace ports visibility "$1:public"
}

cs-cleanup() {
  gh codespace list --json name,createdAt | \
    jq -r '.[] | select(.createdAt | fromdateiso8601 < (now - 86400 * 7)) | .name' | \
    xargs -I {} gh codespace delete --codespace {} --force
}
```

## References
- [GitHub CLI Documentation](https://cli.github.com/manual/)
- [Codespaces Documentation](https://docs.github.com/en/codespaces)
- [GitHub REST API - Codespaces](https://docs.github.com/en/rest/codespaces)
- [Codespaces Billing](https://docs.github.com/en/billing/managing-billing-for-github-codespaces)
- [Dev Containers Specification](https://containers.dev/)