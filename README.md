# AKS GitOps Demo with Windows ASP.NET

This repository demonstrates GitOps deployment of a Windows ASP.NET application on Azure Kubernetes Service (AKS) using ArgoCD.

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Git Repository│    │     ArgoCD       │    │    AKS Cluster      │
│                 │    │                  │    │                     │
│  ├─ environments│───▶│  ├─ Applications │───▶│  ├─ development     │
│     ├─ dev      │    │     ├─ dev-app   │    │     ├─ staging       │
│     ├─ staging  │    │     ├─ stg-app   │    │     ├─ production    │
│     └─ prod     │    │     └─ prd-app   │    │     └─ argocd        │
│                 │    │                  │    │                     │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
```

## 📁 Repository Structure

```
├── 📂 aspnet-demo/              # ASP.NET application source
│   ├── Controllers/
│   ├── Dockerfile
│   └── aspnet-demo.csproj
├── 📂 argocd/                   # ArgoCD configurations
│   ├── install-argocd.ps1
│   ├── deploy-applications.ps1
│   ├── project.yaml
│   └── 📂 applications/
├── 📂 environments/             # Environment-specific configs
│   ├── 📂 development/
│   ├── 📂 staging/
│   └── 📂 production/
├── complete-setup.ps1           # Complete setup script
├── setup-git-repo.ps1          # Git repository setup
└── GITOPS-GUIDE.md             # Detailed GitOps guide
```

## 🚀 Quick Start

### Prerequisites

- Azure CLI installed and logged in
- kubectl installed and configured
- Git installed
- PowerShell (Windows) or PowerShell Core (cross-platform)
- Access to an AKS cluster with Windows node pools
- Azure Container Registry with the Windows ASP.NET image

### Option 1: Complete Automated Setup

```powershell
# Run the complete setup script
.\complete-setup.ps1 -GitHubRepoURL "https://github.com/noumanmanan-msft/aks-gitops-demo" -ResourceGroupName "your-rg" -ClusterName "your-aks-cluster"
```

### Option 2: Step-by-Step Setup

#### 1. Setup Git Repository
```powershell
# Initialize git repo and commit files
.\setup-git-repo.ps1 -GitHubRepoURL "https://github.com/noumanmanan-msft/aks-gitops-demo"

# Push to GitHub
git push -u origin main
```

#### 2. Get AKS Credentials
```powershell
az aks get-credentials --resource-group your-resource-group --name your-aks-cluster
```

#### 3. Install ArgoCD
```powershell
.\argocd\install-argocd.ps1
```

#### 4. Deploy ArgoCD Applications
```powershell
.\argocd\deploy-applications.ps1 -RepoURL "https://github.com/noumanmanan-msft/aks-gitops-demo"
```

## 🌍 Environments

| Environment | Namespace | Replicas | Service Type | Sync Policy | Resources |
|-------------|-----------|----------|--------------|-------------|-----------|
| Development | `development` | 2 | ClusterIP | Auto + Self-Heal | 256Mi/100m |
| Staging | `staging` | 3 | LoadBalancer | Auto (no self-heal) | 512Mi/250m |
| Production | `production` | 5 | LoadBalancer | Manual Only | 1Gi/500m |

## 🔧 Managing the Application

### Access ArgoCD UI
```powershell
# Get ArgoCD URL and credentials
kubectl get service argocd-server -n argocd
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Update Application Images
```bash
# Update development environment
cd environments/development
kustomize edit set image acrdemoeastus2001.azurecr.io/windows-aspnet:v1.1
git add . && git commit -m "Update dev to v1.1" && git push

# Update staging environment  
cd environments/staging
kustomize edit set image acrdemoeastus2001.azurecr.io/windows-aspnet:v1.1
git add . && git commit -m "Update staging to v1.1" && git push

# Production requires manual sync in ArgoCD UI
```

### ArgoCD CLI Commands
```bash
# Install ArgoCD CLI (if not already installed)
# Download from: https://github.com/argoproj/argo-cd/releases

# Login to ArgoCD
argocd login <ARGOCD-SERVER-IP> --username admin --password <PASSWORD> --insecure

# List applications
argocd app list

# Get application details
argocd app get windows-aspnet-dev

# Sync application
argocd app sync windows-aspnet-dev

# Watch application status
argocd app wait windows-aspnet-dev
```

## 🔍 Monitoring and Troubleshooting

### Check Application Status
```bash
# ArgoCD applications
kubectl get applications -n argocd

# Application pods
kubectl get pods -n development
kubectl get pods -n staging  
kubectl get pods -n production

# Services and external IPs
kubectl get services -n staging
kubectl get services -n production
```

### View Logs
```bash
# Application logs
kubectl logs -l app=windows-aspnet-app -n development

# ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller
```

### Common Issues

#### Application Not Syncing
```bash
# Check repository access
argocd repo list

# Refresh application
argocd app get windows-aspnet-dev --refresh

# Force sync
argocd app sync windows-aspnet-dev --force
```

#### Image Pull Errors
```bash
# Check ACR secret
kubectl get secret acr-secret -n development

# Recreate ACR secret if needed
kubectl create secret docker-registry acr-secret \
  --docker-server=acrdemoeastus2001.azurecr.io \
  --docker-username=<username> \
  --docker-password=<password> \
  --namespace=development
```

## 📊 Testing the Application

### Development Environment (Internal)
```bash
# Port forward to test
kubectl port-forward service/windows-aspnet-service 8080:80 -n development
# Visit: http://localhost:8080/hello
```

### Staging/Production Environment (External)
```bash
# Get external IP
kubectl get service windows-aspnet-service -n staging
# Visit: http://<EXTERNAL-IP>/hello
```

## 🔒 Security Best Practices

- Store ACR credentials in Azure Key Vault
- Use Azure AD integration for ArgoCD authentication
- Implement network policies for namespace isolation
- Use pod security policies/standards
- Regular security scanning of container images

## 📈 Scaling and Performance

### Manual Scaling
```bash
# Scale deployment
kubectl scale deployment windows-aspnet-app --replicas=10 -n production
```

### Auto Scaling (HPA configured for staging/production)
```bash
# Check HPA status
kubectl get hpa -n production

# View HPA details
kubectl describe hpa windows-aspnet-hpa -n production
```

## 🔄 CI/CD Integration

This GitOps setup can be integrated with:
- **Azure DevOps Pipelines**
- **GitHub Actions**
- **Jenkins**
- **Tekton Pipelines**

Example GitHub Action for updating image tags:
```yaml
name: Deploy to Development
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Update image tag
      run: |
        cd environments/development
        kustomize edit set image acrdemoeastus2001.azurecr.io/windows-aspnet:${{ github.sha }}
        git config user.email "action@github.com"
        git config user.name "GitHub Action"
        git add .
        git commit -m "Update dev image to ${{ github.sha }}"
        git push
```

## 📚 Additional Resources

- [Complete GitOps Guide](GITOPS-GUIDE.md) - Detailed documentation
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test in development environment
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Happy GitOps-ing! 🚀**