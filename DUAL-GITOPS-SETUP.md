# Dual GitOps Setup: ArgoCD + FluxCD

This repository implements a comprehensive dual GitOps architecture with both ArgoCD and FluxCD running in parallel, allowing for evaluation and comparison of both GitOps tools without any interference.

## Architecture Overview

### GitOps Tool Separation

| Component | ArgoCD | FluxCD |
|-----------|--------|--------|
| **Namespace** | argocd | flux-system |
| **Environments** | development, staging, production | dev-flux, staging-flux, production-flux |
| **Workflow Triggers** | `[skip-fluxcd]` to skip | `[skip-argocd]` to skip |
| **Directory Structure** | `environments/` | `environments/fluxcd/` |
| **Installation Script** | `install-argocd.ps1` | `fluxcd/install-fluxcd.ps1` |
| **Test Script** | `test-development-service.ps1` | `test-fluxcd-environments.ps1` |

### Environment Configurations

#### ArgoCD Environments
- **development**: 2 replicas, ClusterIP service
- **staging**: 3 replicas, LoadBalancer service with HPA
- **production**: 5 replicas, LoadBalancer service with HPA

#### FluxCD Environments  
- **dev-flux**: 2 replicas, ClusterIP service
- **staging-flux**: 3 replicas, LoadBalancer service with HPA
- **production-flux**: 5 replicas, LoadBalancer service with HPA

## Installation Instructions

### Prerequisites
- AKS cluster with Windows node pools
- Azure CLI installed and configured
- kubectl configured for your cluster
- GitHub repository access

### 1. Install ArgoCD (if not already installed)

```powershell
# Run the ArgoCD installation script
.\install-argocd.ps1

# Access ArgoCD UI (after port-forward or external access setup)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Navigate to https://localhost:8080
```

### 2. Install FluxCD

```powershell
# Run the FluxCD installation script
.\fluxcd\install-fluxcd.ps1

# Verify FluxCD installation
flux check
```

### 3. Configure GitHub Repository

Ensure your GitHub repository has the following secrets configured:
- `ACR_USERNAME`: Azure Container Registry username
- `ACR_PASSWORD`: Azure Container Registry password

## Directory Structure

```
aks-gitops-demo/
├── aspnet-demo/                    # ASP.NET Core application
├── argocd/                         # ArgoCD configuration
│   ├── applications/               # ArgoCD Application definitions
│   └── install-argocd.ps1         # ArgoCD installation script
├── fluxcd/                         # FluxCD configuration  
│   ├── clusters/                   # FluxCD cluster config
│   ├── sources/                    # GitRepository sources
│   ├── kustomizations/             # FluxCD Kustomizations
│   └── install-fluxcd.ps1         # FluxCD installation script
├── environments/                   # ArgoCD environments
│   ├── development/
│   ├── staging/
│   ├── production/
│   └── fluxcd/                     # FluxCD environments
│       ├── dev-flux/
│       ├── staging-flux/
│       └── production-flux/
└── .github/workflows/              # CI/CD workflows
    ├── build-and-deploy-dev.yml    # ArgoCD development
    ├── promote-to-staging.yml      # ArgoCD staging
    ├── deploy-production.yml       # ArgoCD production
    ├── fluxcd-dev.yml              # FluxCD development
    ├── fluxcd-staging.yml          # FluxCD staging
    └── fluxcd-production.yml       # FluxCD production
```

## Workflow Architecture

### ArgoCD Workflows
1. **Development**: Triggered on push to main (builds, containerizes, updates development)
2. **Staging**: Auto-triggered after development workflow completes
3. **Production**: Manual trigger with approval required

### FluxCD Workflows
1. **FluxCD Dev**: Triggered on push to main (parallel to ArgoCD, updates dev-flux)
2. **FluxCD Staging**: Auto-triggered after FluxCD dev workflow completes
3. **FluxCD Production**: Manual trigger with approval required

### Workflow Separation
- Use `[skip-argocd]` in commit message to skip ArgoCD workflows
- Use `[skip-fluxcd]` in commit message to skip FluxCD workflows
- Use `[skip-ci]` to skip all workflows

## Testing and Validation

### Test ArgoCD Environments
```powershell
# Test all ArgoCD environments
.\test-development-service.ps1 -Environment all -Detailed

# Test specific environment
.\test-development-service.ps1 -Environment development -ShowLogs
```

### Test FluxCD Environments
```powershell
# Test all FluxCD environments
.\test-fluxcd-environments.ps1 -Environment all -Detailed -CheckFluxStatus

# Test specific environment
.\test-fluxcd-environments.ps1 -Environment dev-flux -ShowLogs
```

## GitOps Tool Comparison

### ArgoCD
**Pros:**
- Rich UI dashboard for visualization
- Comprehensive RBAC and multi-tenancy
- Excellent application health monitoring
- Mature ecosystem and community
- Built-in SSO integration

**Cons:**
- Heavier resource footprint
- More complex initial setup
- Requires additional components (Redis, Dex)

### FluxCD v2
**Pros:**
- Lightweight and Kubernetes-native
- Strong GitOps security model
- Excellent Helm integration
- Progressive delivery capabilities
- Multi-tenancy through namespaces

**Cons:**
- Limited UI (requires external tools like Weave GitOps)
- Steeper learning curve for complex scenarios
- Less mature monitoring tools

### Feature Comparison Matrix

| Feature | ArgoCD | FluxCD v2 |
|---------|--------|-----------|
| **UI Dashboard** | ✅ Built-in rich UI | ❌ CLI-based (external UI available) |
| **GitOps Security** | ✅ Good | ✅ Excellent |
| **Resource Usage** | ❌ Higher | ✅ Lower |
| **Helm Support** | ✅ Good | ✅ Excellent |
| **Multi-tenancy** | ✅ RBAC-based | ✅ Namespace-based |
| **Progressive Delivery** | ❌ Limited | ✅ Built-in |
| **Community** | ✅ Large | ✅ Growing |
| **Learning Curve** | ✅ Easier | ❌ Steeper |

## Operational Procedures

### Deploying to Development
Both ArgoCD and FluxCD development environments are automatically updated when you push to the main branch:

```bash
git add .
git commit -m "Update application feature"
git push origin main
```

### Promoting to Staging
Staging environments for both tools are automatically promoted after successful development deployments.

### Deploying to Production

#### ArgoCD Production
```powershell
# Manually trigger ArgoCD production workflow
# Go to GitHub Actions > Deploy Production > Run workflow
```

#### FluxCD Production
```powershell
# Manually trigger FluxCD production workflow  
# Go to GitHub Actions > FluxCD Production Environment > Run workflow
```

### Monitoring Deployments

#### ArgoCD
- Access UI: `kubectl port-forward svc/argocd-server -n argocd 8080:443`
- CLI: `argocd app list` and `argocd app get <app-name>`

#### FluxCD
- CLI: `flux get all` and `flux logs`
- Status: `kubectl get gitrepositories,kustomizations -A`

### Troubleshooting

#### Common Issues

1. **Image Pull Errors**
   ```powershell
   # Check ACR credentials
   kubectl get secret acr-credentials -n <namespace> -o yaml
   ```

2. **FluxCD Reconciliation Issues**
   ```powershell
   # Force reconciliation
   flux reconcile kustomization <kustomization-name>
   flux reconcile source git <source-name>
   ```

3. **ArgoCD Sync Issues**
   ```powershell
   # Force refresh and sync
   argocd app sync <app-name> --force
   ```

#### Health Checks

```powershell
# ArgoCD health
kubectl get pods -n argocd
argocd app list

# FluxCD health  
kubectl get pods -n flux-system
flux check
```

## Security Considerations

### ArgoCD Security
- Uses dedicated service accounts
- RBAC policies limit access to specific namespaces
- TLS encryption for all communications

### FluxCD Security
- Kubernetes-native security model
- No additional attack surface (no API server)
- GitOps-native secret management

### Best Practices
1. Use separate namespaces for complete isolation
2. Implement proper RBAC policies
3. Regularly rotate ACR credentials
4. Monitor both GitOps tools for security updates
5. Use environment-specific service accounts

## Migration Considerations

### From ArgoCD to FluxCD
1. Export ArgoCD applications: `argocd app list -o yaml`
2. Convert to FluxCD Kustomizations
3. Test in parallel environments first
4. Gradually migrate applications

### From FluxCD to ArgoCD
1. Export FluxCD resources: `flux export kustomization --all`
2. Convert to ArgoCD Applications
3. Test in parallel environments first
4. Gradually migrate applications

## Conclusion

This dual GitOps setup provides a comprehensive platform for evaluating both ArgoCD and FluxCD in a real-world Windows container environment. The complete separation ensures no interference while allowing direct comparison of features, performance, and operational characteristics.

Choose the GitOps tool that best fits your organization's requirements:
- **ArgoCD** for teams wanting rich UI and mature ecosystem
- **FluxCD** for teams preferring lightweight, Kubernetes-native solutions

Both tools are production-ready and provide excellent GitOps capabilities for modern Kubernetes deployments.