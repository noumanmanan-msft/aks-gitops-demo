# PowerShell script to deploy Windows ASP.NET app to AKS
param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-demo-eastus2-001",
    
    [Parameter(Mandatory=$false)]
    [string]$ClusterName = "aks-tokio-eastus2-002",
    
    [Parameter(Mandatory=$false)]
    [string]$AcrName = "acrdemoeastus2001",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "default"
)

Write-Host "Starting deployment of Windows ASP.NET application to AKS..." -ForegroundColor Green

# Check if kubectl is installed
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error "kubectl is not installed or not in PATH. Please install kubectl first."
    exit 1
}

# Check if Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI is not installed or not in PATH. Please install Azure CLI first."
    exit 1
}

try {
    # Get AKS credentials
    Write-Host "Getting AKS credentials..." -ForegroundColor Yellow
    az aks get-credentials --resource-group $ResourceGroupName --name $ClusterName --overwrite-existing
    
    # Create namespace if it doesn't exist (skip if using default)
    if ($Namespace -ne "default") {
        Write-Host "Creating namespace: $Namespace" -ForegroundColor Yellow
        kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
    }
    
    # Check if ACR secret exists, if not create it
    Write-Host "Checking for ACR secret..." -ForegroundColor Yellow
    $acrSecret = kubectl get secret acr-secret -n $Namespace --ignore-not-found
    
    if (-not $acrSecret) {
        Write-Host "Creating ACR secret..." -ForegroundColor Yellow
        $acrLoginServer = "$AcrName.azurecr.io"
        
        # Get ACR credentials
        $acrUsername = az acr credential show --name $AcrName --query username --output tsv
        $acrPassword = az acr credential show --name $AcrName --query passwords[0].value --output tsv
        
        # Create docker registry secret
        kubectl create secret docker-registry acr-secret `
            --docker-server=$acrLoginServer `
            --docker-username=$acrUsername `
            --docker-password=$acrPassword `
            --namespace=$Namespace
    } else {
        Write-Host "ACR secret already exists." -ForegroundColor Green
    }
    
    # Deploy the application
    Write-Host "Deploying application..." -ForegroundColor Yellow
    kubectl apply -f deploy-to-aks.yaml -n $Namespace
    
    # Wait for deployment to be ready
    Write-Host "Waiting for deployment to be ready..." -ForegroundColor Yellow
    kubectl rollout status deployment/windows-aspnet-app -n $Namespace --timeout=300s
    
    # Get service information
    Write-Host "Getting service information..." -ForegroundColor Yellow
    kubectl get services -n $Namespace -l app=windows-aspnet-app
    
    # Get external IP (may take a few minutes for LoadBalancer)
    Write-Host "`nWaiting for external IP assignment..." -ForegroundColor Yellow
    Write-Host "This may take a few minutes. You can check the status with:" -ForegroundColor Cyan
    Write-Host "kubectl get services -n $Namespace windows-aspnet-service" -ForegroundColor Cyan
    
    # Show pods status
    Write-Host "`nPod status:" -ForegroundColor Yellow
    kubectl get pods -n $Namespace -l app=windows-aspnet-app
    
    # Show logs from one of the pods
    Write-Host "`nRecent logs from application:" -ForegroundColor Yellow
    $podName = kubectl get pods -n $Namespace -l app=windows-aspnet-app -o jsonpath='{.items[0].metadata.name}'
    if ($podName) {
        kubectl logs $podName -n $Namespace --tail=10
    }
    
    Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
    Write-Host "To test the application, get the external IP with:" -ForegroundColor Cyan
    Write-Host "kubectl get service windows-aspnet-service -n $Namespace" -ForegroundColor Cyan
    Write-Host "Then visit http://<EXTERNAL-IP>/hello in your browser." -ForegroundColor Cyan
    
} catch {
    Write-Error "An error occurred during deployment: $_"
    exit 1
}