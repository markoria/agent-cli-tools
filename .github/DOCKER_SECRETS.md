# GitHub Actions Secrets Required

To enable automated Docker Hub publishing, add these secrets to your GitHub repository:

## Setup Instructions

1. Go to https://github.com/markoria/agent-cli-tools/settings/secrets/actions

2. Click "New repository secret" and add:

### DOCKERHUB_USERNAME
- **Value**: Your Docker Hub username (markoria)

### DOCKERHUB_TOKEN
- **Value**: Your Docker Hub Access Token
- **How to get**:
  1. Login to https://hub.docker.com
  2. Go to Account Settings → Security
  3. Click "New Access Token"
  4. Name: "GitHub Actions"
  5. Permissions: Read, Write, Delete
  6. Copy the token (you won't see it again!)

## What the Workflow Does

- ✅ Builds on every push to `main`
- ✅ Creates multi-platform images (amd64 + arm64)
- ✅ Tags with `latest` for main branch
- ✅ Tags with version numbers for releases (e.g., `v1.0.0`)
- ✅ Updates Docker Hub description from README.md

## Creating a Release

To publish a versioned image:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This will create images tagged as:
- `markoria/agent-cli-tools:latest`
- `markoria/agent-cli-tools:1.0.0`
- `markoria/agent-cli-tools:1.0`
- `markoria/agent-cli-tools:1`
