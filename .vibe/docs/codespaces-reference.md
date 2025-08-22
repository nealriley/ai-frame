# GitHub Codespaces Reference Documentation

## Overview
GitHub Codespaces provides cloud-based development environments that enable coding directly in a browser or through VS Code. This document covers configuration and best practices for using Codespaces with the AI Frame project.

## Core Concepts

### What are Codespaces?
- **Cloud-hosted development environments** running in Docker containers
- **Instant setup** with pre-configured tools and dependencies
- **Accessible anywhere** via browser or VS Code
- **Consistent environments** across team members

### Key Benefits
- No local setup required
- Powerful cloud machines (up to 32 cores, 64GB RAM)
- Automatic port forwarding
- Integrated with GitHub workflows
- Supports collaborative development

## Dev Container Configuration

### Basic Structure
```json
// .devcontainer/devcontainer.json
{
  "name": "AI Frame Development",
  "image": "mcr.microsoft.com/devcontainers/python:3.11-node",
  
  // Or use Dockerfile
  "build": {
    "dockerfile": "Dockerfile",
    "context": ".."
  },
  
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/github-cli:1": {}
  }
}
```

### Language-Specific Configurations

#### Python + Node.js (for AI Frame)
```json
{
  "name": "AI Frame Full Stack",
  "image": "mcr.microsoft.com/devcontainers/python:3.11",
  
  "features": {
    "ghcr.io/devcontainers/features/node:1": {
      "version": "18"
    }
  },
  
  "postCreateCommand": "pip install -r requirements.txt && npm install",
  
  "forwardPorts": [3001, 8080, 8443],
  
  "portsAttributes": {
    "3001": {
      "label": "FastAPI Backend",
      "onAutoForward": "notify"
    },
    "8443": {
      "label": "WebXR HTTPS",
      "onAutoForward": "notify",
      "protocol": "https"
    },
    "8080": {
      "label": "Mobile Interface",
      "onAutoForward": "notify"
    }
  }
}
```

### VS Code Extensions
```json
{
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "ms-python.vscode-pylance",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "ms-azuretools.vscode-docker",
        "GitHub.copilot"
      ],
      
      "settings": {
        "python.defaultInterpreterPath": "/usr/local/bin/python",
        "python.linting.enabled": true,
        "python.formatting.provider": "black",
        "editor.formatOnSave": true
      }
    }
  }
}
```

## Port Forwarding

### Automatic Port Detection
Codespaces automatically detects and forwards ports when applications print localhost URLs:
```python
print(f"Server running at http://localhost:3001")  # Auto-forwarded
```

### Manual Port Configuration
```json
{
  "forwardPorts": [3001, 8080, 8443],
  
  "portsAttributes": {
    "3001": {
      "label": "API Server",
      "onAutoForward": "notify",
      "visibility": "public"  // or "private", "org"
    }
  }
}
```

### Port Visibility Settings
- **Private**: Only you can access (default)
- **Organization**: Organization members can access
- **Public**: Anyone with URL can access (careful!)

### Accessing Forwarded Ports

#### URL Format
```
https://CODESPACE-NAME-PORT.app.github.dev
```

#### Programmatic Access
```javascript
// Detect Codespaces environment
const isCodespaces = process.env.CODESPACES === 'true';
const codespaceUrl = process.env.GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN;

if (isCodespaces) {
  const apiUrl = `https://${process.env.CODESPACE_NAME}-3001.${codespaceUrl}`;
}
```

### Authentication for Private Ports
```bash
# Using GITHUB_TOKEN for private ports
curl -H "Authorization: token ${GITHUB_TOKEN}" \
  https://CODESPACE-NAME-3001.app.github.dev/api
```

## Environment Variables and Secrets

### Codespaces Environment Variables
```bash
CODESPACES=true
CODESPACE_NAME=psychic-space-robot-123
GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN=app.github.dev
GITHUB_TOKEN=ghu_xxxxxxxxxxxx
GITHUB_USER=username
```

### Managing Secrets
1. Go to Settings → Codespaces → Secrets
2. Add repository or organization secrets
3. Access in code:
```python
import os
api_key = os.environ.get('API_KEY')  # From Codespaces secrets
```

### Dev Container Environment
```json
{
  "remoteEnv": {
    "NODE_ENV": "development",
    "API_BASE_URL": "http://localhost:3001"
  }
}
```

## Lifecycle Scripts

### Container Creation
```json
{
  "onCreateCommand": "echo 'Container created'",
  "updateContentCommand": "git pull",
  "postCreateCommand": "npm install && pip install -r requirements.txt",
  "postStartCommand": "./start-services.sh",
  "postAttachCommand": "echo 'Welcome to AI Frame Codespace!'"
}
```

### Script Execution Order
1. **onCreateCommand**: Runs once when container is created
2. **updateContentCommand**: Runs after onCreateCommand and when rebuilding
3. **postCreateCommand**: Runs after container is created
4. **postStartCommand**: Runs every time Codespace starts
5. **postAttachCommand**: Runs when VS Code attaches to container

## Performance Optimization

### Machine Types
```json
{
  "hostRequirements": {
    "cpus": 4,
    "memory": "8gb",
    "storage": "32gb"
  }
}
```

Available machine types:
- 2 cores, 8 GB RAM
- 4 cores, 16 GB RAM
- 8 cores, 32 GB RAM
- 16 cores, 64 GB RAM
- 32 cores, 64 GB RAM

### Prebuilding Codespaces
```yaml
# .github/workflows/codespaces-prebuild.yml
name: Codespaces Prebuilds

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  prebuild:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: github/codespaces-prebuild@v1
```

### Optimizing Startup Time
```json
{
  "postCreateCommand": "npm ci --prefer-offline",
  "features": {
    "ghcr.io/devcontainers/features/node:1": {
      "version": "18",
      "installYarnGlobally": false  // Skip if not needed
    }
  }
}
```

## Networking and Services

### Running Multiple Services
```bash
#!/bin/bash
# start-services.sh

# Start backend
cd server && python api_server.py &

# Start frontend dev server
npm run dev &

# Start HTTPS server for WebXR
npx http-server -S -p 8443 &

echo "All services started"
```

### Docker Compose in Codespaces
```json
{
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {}
  },
  
  "postStartCommand": "docker-compose up -d"
}
```

### Connecting to Private Networks
```json
{
  "features": {
    "ghcr.io/devcontainers/features/sshd:1": {}
  }
}
```

## File System and Storage

### Workspace Structure
```
/workspaces/
├── your-repo/          # Your repository
├── .codespaces/        # Codespaces config
└── .vscode-remote/     # VS Code server files
```

### Persistent Storage
- **/workspaces**: Persists across Codespace sessions
- **/tmp**: Cleared on restart
- **~/.config**: User configuration persists

### Large File Handling
```json
{
  "postCreateCommand": "git lfs pull",
  
  "features": {
    "ghcr.io/devcontainers/features/git-lfs:1": {}
  }
}
```

## Debugging and Development

### Launch Configuration
```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Python: FastAPI",
      "type": "python",
      "request": "launch",
      "module": "uvicorn",
      "args": ["main:app", "--reload", "--port", "3001"],
      "jinja": true
    },
    {
      "name": "Node: Debug",
      "type": "node",
      "request": "launch",
      "program": "${workspaceFolder}/index.js",
      "skipFiles": ["<node_internals>/**"]
    }
  ]
}
```

### Tasks Configuration
```json
// .vscode/tasks.json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Start All Services",
      "type": "shell",
      "command": "./run-services.sh",
      "group": {
        "kind": "build",
        "isDefault": true
      }
    }
  ]
}
```

## GitHub CLI Integration

### Available Commands
```bash
# Create pull request
gh pr create --title "Feature" --body "Description"

# View issues
gh issue list

# Create Codespace
gh codespace create --repo owner/repo

# List Codespaces
gh codespace list

# Forward ports
gh codespace ports forward 3001:3001
```

### Codespace Management
```bash
# SSH into Codespace
gh codespace ssh

# Copy files to/from Codespace
gh codespace cp local.txt remote:/workspaces/

# View logs
gh codespace logs
```

## Security Best Practices

### Port Visibility
```json
{
  "portsAttributes": {
    "3001": {
      "visibility": "org",  // Not "public" for sensitive APIs
      "requireLocalPort": true
    }
  }
}
```

### Secrets Management
- Never commit secrets to repository
- Use Codespaces secrets for sensitive data
- Rotate tokens regularly
- Use least privilege principle

### Network Security
```json
{
  "remoteUser": "vscode",  // Non-root user
  
  "features": {
    "ghcr.io/devcontainers/features/common-utils:2": {
      "installZsh": true,
      "username": "vscode",
      "userGid": "1000",
      "userUid": "1000"
    }
  }
}
```

## Troubleshooting

### Common Issues

#### Port Already in Use
```bash
# Find process using port
lsof -i :3001
# Kill process
kill -9 <PID>
```

#### Codespace Won't Start
1. Check dev container configuration
2. Review creation logs
3. Try rebuilding container

#### Slow Performance
- Upgrade to larger machine type
- Enable prebuilds
- Optimize startup scripts
- Use `npm ci` instead of `npm install`

### Debug Commands
```bash
# View Codespace info
echo $CODESPACE_NAME
echo $GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN

# Check forwarded ports
gh codespace ports

# View container logs
docker logs $(docker ps -q)
```

## AI Frame Specific Configuration

### Complete devcontainer.json
```json
{
  "name": "AI Frame WebXR Development",
  "image": "mcr.microsoft.com/devcontainers/python:3.11",
  
  "features": {
    "ghcr.io/devcontainers/features/node:1": {
      "version": "18"
    },
    "ghcr.io/devcontainers/features/docker-in-docker:2": {}
  },
  
  "forwardPorts": [3001, 8080, 8443],
  
  "portsAttributes": {
    "3001": {
      "label": "FastAPI Backend",
      "onAutoForward": "notify",
      "visibility": "public"
    },
    "8443": {
      "label": "WebXR HTTPS",
      "onAutoForward": "notify",
      "protocol": "https",
      "visibility": "public"
    },
    "8080": {
      "label": "Mobile Interface",
      "onAutoForward": "notify",
      "visibility": "public"
    }
  },
  
  "postCreateCommand": "cd first-attempt && npm install && cd server && pip install -r requirements.txt",
  
  "postStartCommand": "cd first-attempt && ./run-services.sh",
  
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode"
      ]
    }
  },
  
  "remoteEnv": {
    "CODESPACES": "true"
  }
}
```

### Auto-detect Codespaces URLs
```javascript
// JavaScript
const isCodespaces = process.env.CODESPACES === 'true';
if (isCodespaces) {
  const baseUrl = `https://${process.env.CODESPACE_NAME}-3001.${process.env.GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}`;
}
```

```python
# Python
import os

is_codespaces = os.environ.get('CODESPACES') == 'true'
if is_codespaces:
    codespace_name = os.environ.get('CODESPACE_NAME')
    domain = os.environ.get('GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN')
    base_url = f"https://{codespace_name}-3001.{domain}"
```