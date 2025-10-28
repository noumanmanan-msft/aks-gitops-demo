# PowerShell script to setup GitHub Actions secrets for ACR
param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubRepo = "noumanmanan-msft/aks-gitops-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$ACRName = "acrdemoeastus2001"
)

Write-Host "Setting up GitHub Actions secrets for Azure Container Registry..." -ForegroundColor Green

# Check if GitHub CLI is installed
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) is not installed. Please install it first:"
    Write-Host "winget install GitHub.cli" -ForegroundColor Yellow
    exit 1
}

# Check if Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI is not installed. Please install it first."
    exit 1
}

try {
    # Check GitHub authentication
    Write-Host "Checking GitHub authentication..." -ForegroundColor Yellow
    $ghAuth = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Please login to GitHub first:" -ForegroundColor Yellow
        Write-Host "gh auth login" -ForegroundColor White
        exit 1
    }
    Write-Host "✅ GitHub authentication OK" -ForegroundColor Green

    # Get ACR credentials
    Write-Host "Getting Azure Container Registry credentials..." -ForegroundColor Yellow
    
    # Enable admin user on ACR if not already enabled
    $acrInfo = az acr show --name $ACRName --query "adminUserEnabled" --output tsv
    if ($acrInfo -eq "false") {
        Write-Host "Enabling admin user on ACR..." -ForegroundColor Yellow
        az acr update --name $ACRName --admin-enabled true
    }
    
    # Get ACR credentials
    $acrCreds = az acr credential show --name $ACRName --output json | ConvertFrom-Json
    
    if (-not $acrCreds) {
        Write-Error "Failed to get ACR credentials. Please check ACR name and permissions."
        exit 1
    }

    $acrUsername = $acrCreds.username
    $acrPassword = $acrCreds.passwords[0].value

    Write-Host "✅ ACR credentials retrieved" -ForegroundColor Green

    # Set GitHub secrets
    Write-Host "Setting GitHub repository secrets..." -ForegroundColor Yellow

    # Set ACR_USERNAME secret
    Write-Host "Setting ACR_USERNAME secret..." -ForegroundColor Gray
    echo $acrUsername | gh secret set ACR_USERNAME --repo $GitHubRepo
    
    # Set ACR_PASSWORD secret  
    Write-Host "Setting ACR_PASSWORD secret..." -ForegroundColor Gray
    echo $acrPassword | gh secret set ACR_PASSWORD --repo $GitHubRepo

    Write-Host "✅ GitHub secrets configured successfully!" -ForegroundColor Green

    # Verify secrets were set
    Write-Host "`nVerifying secrets..." -ForegroundColor Yellow
    $secrets = gh secret list --repo $GitHubRepo --json name | ConvertFrom-Json
    
    $acrUsernameExists = $secrets | Where-Object { $_.name -eq "ACR_USERNAME" }
    $acrPasswordExists = $secrets | Where-Object { $_.name -eq "ACR_PASSWORD" }

    if ($acrUsernameExists -and $acrPasswordExists) {
        Write-Host "✅ All required secrets are configured" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Some secrets may not have been set correctly" -ForegroundColor Yellow
    }

    # Display summary
    Write-Host "`n📋 Setup Summary:" -ForegroundColor Cyan
    Write-Host "Repository: $GitHubRepo" -ForegroundColor White
    Write-Host "ACR Name: $ACRName" -ForegroundColor White
    Write-Host "ACR Username: $acrUsername" -ForegroundColor White
    Write-Host "Secrets configured: ACR_USERNAME, ACR_PASSWORD" -ForegroundColor White

    Write-Host "`n🚀 Next Steps:" -ForegroundColor Green
    Write-Host "1. Push code changes to trigger the workflow:" -ForegroundColor White
    Write-Host "   git add ." -ForegroundColor Gray
    Write-Host "   git commit -m 'Add GitHub Actions CI/CD'" -ForegroundColor Gray
    Write-Host "   git push origin main" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Monitor the workflow in GitHub Actions:" -ForegroundColor White
    Write-Host "   https://github.com/$GitHubRepo/actions" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Check ArgoCD for automatic deployment:" -ForegroundColor White
    Write-Host "   https://172.193.108.166" -ForegroundColor Gray

} catch {
    Write-Error "An error occurred during setup: $_"
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Ensure you have permissions to the ACR: $ACRName" -ForegroundColor White
    Write-Host "2. Verify GitHub CLI authentication: gh auth status" -ForegroundColor White
    Write-Host "3. Check Azure CLI login: az account show" -ForegroundColor White
    exit 1
}