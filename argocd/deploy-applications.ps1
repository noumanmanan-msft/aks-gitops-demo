# PowerShell script to deploy ArgoCD applications
param(
    [Parameter(Mandatory=$false)]
    [string]$RepoURL = "https://github.com/noumanmanan-msft/aks-gitops-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$ArgoCDNamespace = "argocd"
)

Write-Host "Deploying ArgoCD applications for GitOps..." -ForegroundColor Green

# Check if ArgoCD is installed
$argoCDPods = kubectl get pods -n $ArgoCDNamespace --selector=app.kubernetes.io/name=argocd-server --ignore-not-found
if (-not $argoCDPods) {
    Write-Error "ArgoCD is not installed. Please run install-argocd.ps1 first."
    exit 1
}

# Update repository URL in application manifests
if ($RepoURL -ne "https://github.com/noumanmanan-msft/aks-gitops-demo") {
    Write-Host "Updating repository URL in application manifests..." -ForegroundColor Yellow
    
    $applications = @(
        "argocd\applications\windows-aspnet-dev.yaml",
        "argocd\applications\windows-aspnet-staging.yaml",
        "argocd\applications\windows-aspnet-production.yaml"
    )
    
    foreach ($app in $applications) {
        if (Test-Path $app) {
            (Get-Content $app) -replace "https://github.com/noumanmanan-msft/aks-gitops-demo", $RepoURL | Set-Content $app
        }
    }
}

try {
    # Apply ArgoCD applications
    Write-Host "Deploying Development environment application..." -ForegroundColor Yellow
    kubectl apply -f argocd\applications\windows-aspnet-dev.yaml
    
    Write-Host "Deploying Staging environment application..." -ForegroundColor Yellow
    kubectl apply -f argocd\applications\windows-aspnet-staging.yaml
    
    Write-Host "Deploying Production environment application..." -ForegroundColor Yellow
    kubectl apply -f argocd\applications\windows-aspnet-production.yaml
    
    # Wait a moment for applications to be created
    Start-Sleep -Seconds 5
    
    # Check application status
    Write-Host "`nArgoCD Applications Status:" -ForegroundColor Cyan
    kubectl get applications -n $ArgoCDNamespace
    
    Write-Host "`nApplication Details:" -ForegroundColor Yellow
    Write-Host "Development: " -ForegroundColor Cyan -NoNewline
    kubectl get application windows-aspnet-dev -n $ArgoCDNamespace -o jsonpath='{.status.sync.status}' 2>$null
    Write-Host ""
    
    Write-Host "Staging: " -ForegroundColor Cyan -NoNewline  
    kubectl get application windows-aspnet-staging -n $ArgoCDNamespace -o jsonpath='{.status.sync.status}' 2>$null
    Write-Host ""
    
    Write-Host "Production: " -ForegroundColor Cyan -NoNewline
    kubectl get application windows-aspnet-production -n $ArgoCDNamespace -o jsonpath='{.status.sync.status}' 2>$null
    Write-Host ""
    
    Write-Host "`nGitOps deployment completed successfully!" -ForegroundColor Green
    Write-Host "`nTo access ArgoCD UI:" -ForegroundColor Cyan
    $argoCDService = kubectl get service argocd-server -n $ArgoCDNamespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    if ($argoCDService) {
        Write-Host "URL: https://$argoCDService" -ForegroundColor White
    } else {
        Write-Host "Get external IP: kubectl get service argocd-server -n $ArgoCDNamespace" -ForegroundColor White
    }
    
    Write-Host "`nManage applications with ArgoCD CLI:" -ForegroundColor Cyan
    Write-Host "argocd app list" -ForegroundColor White
    Write-Host "argocd app sync windows-aspnet-dev" -ForegroundColor White
    Write-Host "argocd app get windows-aspnet-dev" -ForegroundColor White

} catch {
    Write-Error "An error occurred during ArgoCD application deployment: $_"
    exit 1
}