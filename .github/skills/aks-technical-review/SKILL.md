---
name: aks-technical-review
description: 'AKS technical review checklist for documentation validation. Use for doc-a-thon Eng Reviewer checks, CLI command validation, API version verification, feature status tracking, Kubernetes version support.'
---

# AKS Technical Review

## When to Use
- Eng Reviewer agent validating technical accuracy
- Checking CLI commands, API versions, and feature status
- Verifying Kubernetes version references

## CLI Command Validation

### Current Command Structure
```
az aks {subcommand} [options]
```

Key subcommands to validate:
- `az aks create` / `az aks update` / `az aks delete`
- `az aks get-credentials`
- `az aks get-upgrades` / `az aks upgrade`
- `az aks nodepool add` / `az aks nodepool update` / `az aks nodepool scale`
- `az aks enable-addons` / `az aks disable-addons`

### Validation Method
```bash
# Check if a command exists and get its parameters
az aks {subcommand} --help 2>&1 | head -50

# Check preview extension commands
az extension show --name aks-preview --query version -o tsv
az aks {subcommand} --help  # with aks-preview loaded
```

### Common Deprecated Patterns
| Deprecated | Current | Since |
|-----------|---------|-------|
| `--enable-managed-identity` | Default (no flag needed) | 2023 |
| `--network-plugin azure` (alone) | `--network-plugin azure --network-plugin-mode overlay` | 2024 for overlay |
| `az aks browse` | Removed | 2023 |
| `--enable-pod-identity` | `--enable-workload-identity` | 2024 |
| `--docker-bridge-address` | Removed (Docker removed from AKS) | 2024 |

## API Version Tracking

### Current Stable API Versions
Check against: `https://learn.microsoft.com/en-us/rest/api/aks/`

Format: `YYYY-MM-DD` (GA) or `YYYY-MM-DD-preview` (preview)

### Validation
- API version in REST calls matches a valid published version
- ARM template `apiVersion` field is current
- Bicep examples reference current API version

## Kubernetes Version Support

### AKS Version Policy
- Supports N-2 minor versions from latest GA
- Each minor version supported for ~12 months
- Check current: `az aks get-versions --location eastus -o table`

### Common Issues
- Articles referencing EOL Kubernetes versions (e.g., 1.25, 1.26)
- Feature gates that changed between versions
- API resources that moved between API groups (e.g., `policy/v1beta1` → `policy/v1`)

## Feature Status Tracking

### Validation Sources
1. AKS release notes: `https://github.com/Azure/AKS/releases`
2. AKS roadmap: `https://github.com/Azure/AKS/projects`
3. Azure updates: `https://azure.microsoft.com/en-us/updates/`
4. `az aks` help output (GA commands vs. `aks-preview` extension commands)

### Preview Feature Requirements
Every preview feature article must include:
```markdown
> [!IMPORTANT]
> AKS preview features are available on a self-service, opt-in basis.
> Previews are provided "as is" and "as available," and they're excluded
> from the service-level agreements and limited warranty.
```

## Security Review Points
- No hardcoded secrets, keys, or passwords in examples
- Use `<your-password>` or `$VARIABLE` placeholder syntax
- RBAC examples use least-privilege roles
- Network examples don't expose unnecessary ports
- Certificate examples use proper key sizes (2048+ RSA, P-256+ EC)
