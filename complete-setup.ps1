# Complete GitOps Setup Script
param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubRepoURL,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$ClusterName,
    
    [Parameter(Mandatory=$false)]
    [string]$ACRName = "acrdemoeastus2001",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipGitSetup = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipArgoCDInstall = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipApplicationDeploy = $false
)

Write-Host "=== Complete GitOps Setup for Windows ASP.NET on AKS ===" -ForegroundColor Green
Write-Host "Repository: $GitHubRepoURL" -ForegroundColor Cyan

# Step 1: Setup Git Repository
if (-not $SkipGitSetup) {
    Write-Host "`n=== Step 1: Setting up Git Repository ===" -ForegroundColor Magenta
    .\setup-git-repo.ps1 -GitHubRepoURL $GitHubRepoURL
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Git setup failed. Exiting."
        exit 1
    }
    
    Write-Host "`nPushing to GitHub..." -ForegroundColor Yellow
    git push -u origin main
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Git push failed. You may need to authenticate or check repository permissions."
        Write-Host "Please run: git push -u origin main" -ForegroundColor Yellow
        Read-Host "Press Enter to continue after pushing to GitHub"
    }
} else {
    Write-Host "`n=== Step 1: Skipped Git Setup ===" -ForegroundColor Yellow
}

# Step 2: Get AKS credentials if cluster info provided
if ($ResourceGroupName -and $ClusterName) {
    Write-Host "`n=== Step 2: Getting AKS Credentials ===" -ForegroundColor Magenta
    Write-Host "Getting credentials for cluster: $ClusterName in resource group: $ResourceGroupName" -ForegroundColor Yellow
    
    az aks get-credentials --resource-group $ResourceGroupName --name $ClusterName --overwrite-existing
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to get AKS credentials. Please check your Azure CLI login and cluster details."
        exit 1
    }
    
    Write-Host "AKS credentials configured successfully!" -ForegroundColor Green
} else {
    Write-Host "`n=== Step 2: Skipped AKS Credentials (no cluster info provided) ===" -ForegroundColor Yellow
    Write-Host "Make sure you have kubectl configured for your AKS cluster" -ForegroundColor Cyan
}

# Step 3: Create ACR Secret if ACR name provided
if ($ACRName) {
    Write-Host "`n=== Step 3: Setting up ACR Secret ===" -ForegroundColor Magenta
    
    # Check if secret already exists
    $existingSecret = kubectl get secret acr-secret --ignore-not-found 2>$null
    
    if (-not $existingSecret) {
        Write-Host "Creating ACR secret for $ACRName..." -ForegroundColor Yellow
        
        $acrLoginServer = "$ACRName.azurecr.io"
        $acrUsername = az acr credential show --name $ACRName --query username --output tsv 2>$null
        $acrPassword = az acr credential show --name $ACRName --query passwords[0].value --output tsv 2>$null
        
        if ($acrUsername -and $acrPassword) {
            kubectl create secret docker-registry acr-secret `
                --docker-server=$acrLoginServer `
                --docker-username=$acrUsername `
                --docker-password=$acrPassword `
                --namespace=default
                
            # Create secret in other namespaces too
            $namespaces = @("development", "staging", "production")
            foreach ($ns in $namespaces) {
                kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f - 2>$null
                kubectl create secret docker-registry acr-secret `
                    --docker-server=$acrLoginServer `
                    --docker-username=$acrUsername `
                    --docker-password=$acrPassword `
                    --namespace=$ns 2>$null
            }
            
            Write-Host "ACR secrets created successfully!" -ForegroundColor Green
        } else {
            Write-Warning "Could not retrieve ACR credentials. You may need to create the ACR secret manually."
        }
    } else {
        Write-Host "ACR secret already exists." -ForegroundColor Green
    }
}

# Step 4: Install ArgoCD
if (-not $SkipArgoCDInstall) {
    Write-Host "`n=== Step 4: Installing ArgoCD ===" -ForegroundColor Magenta
    .\argocd\install-argocd.ps1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "ArgoCD installation failed. Exiting."
        exit 1
    }
} else {
    Write-Host "`n=== Step 4: Skipped ArgoCD Installation ===" -ForegroundColor Yellow
}

# Step 5: Deploy ArgoCD Applications
if (-not $SkipApplicationDeploy) {
    Write-Host "`n=== Step 5: Deploying ArgoCD Applications ===" -ForegroundColor Magenta
    .\argocd\deploy-applications.ps1 -RepoURL $GitHubRepoURL
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "ArgoCD application deployment failed. Exiting."
        exit 1
    }
} else {
    Write-Host "`n=== Step 5: Skipped ArgoCD Application Deployment ===" -ForegroundColor Yellow
}

# Final Status Check
Write-Host "`n=== Setup Complete! ===" -ForegroundColor Green

Write-Host "`nChecking cluster status..." -ForegroundColor Cyan
Write-Host "ArgoCD Status:" -ForegroundColor Yellow
kubectl get pods -n argocd

Write-Host "`nArgoCD Applications:" -ForegroundColor Yellow  
kubectl get applications -n argocd

Write-Host "`nEnvironment Namespaces:" -ForegroundColor Yellow
kubectl get namespaces | Select-String -Pattern "(development|staging|production|argocd)"

# Get ArgoCD URL
Write-Host "`nArgoCD Access Information:" -ForegroundColor Cyan
$argoCDIP = kubectl get service argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null

if ($argoCDIP) {
    Write-Host "ArgoCD URL: https://$argoCDIP" -ForegroundColor White
    Write-Host "Username: admin" -ForegroundColor White
    
    $adminPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>$null
    if ($adminPassword) {
        $decodedPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($adminPassword))
        Write-Host "Password: $decodedPassword" -ForegroundColor White
    }
} else {
    Write-Host "ArgoCD external IP not yet assigned. Check with:" -ForegroundColor Yellow
    Write-Host "kubectl get service argocd-server -n argocd" -ForegroundColor White
}

Write-Host "`nNext Steps:" -ForegroundColor Green
Write-Host "1. Access ArgoCD UI using the URL and credentials above" -ForegroundColor White
Write-Host "2. Verify applications are syncing properly" -ForegroundColor White
Write-Host "3. Test application deployments by updating image tags" -ForegroundColor White
Write-Host "4. Monitor application health in ArgoCD dashboard" -ForegroundColor White

Write-Host "`nUseful Commands:" -ForegroundColor Cyan
Write-Host "# Watch ArgoCD applications" -ForegroundColor Gray
Write-Host "kubectl get applications -n argocd -w" -ForegroundColor White
Write-Host ""
Write-Host "# Check application sync status" -ForegroundColor Gray  
Write-Host "argocd app list" -ForegroundColor White
Write-Host ""
Write-Host "# Manual sync" -ForegroundColor Gray
Write-Host "argocd app sync windows-aspnet-dev" -ForegroundColor White

Write-Host "`nGitOps setup completed successfully! 🚀" -ForegroundColor Green