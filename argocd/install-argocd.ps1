# PowerShell script to install and configure ArgoCD on AKS
param(
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "argocd",
    
    [Parameter(Mandatory=$false)]
    [string]$Version = "v2.8.4",
    
    [Parameter(Mandatory=$false)]
    [string]$AdminPassword = $null
)

Write-Host "Installing ArgoCD on AKS cluster..." -ForegroundColor Green

# Check prerequisites
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error "kubectl is not installed or not in PATH."
    exit 1
}

try {
    # Create ArgoCD namespace
    Write-Host "Creating ArgoCD namespace..." -ForegroundColor Yellow
    kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -

    # Install ArgoCD
    Write-Host "Installing ArgoCD $Version..." -ForegroundColor Yellow
    kubectl apply -n $Namespace -f "https://raw.githubusercontent.com/argoproj/argo-cd/$Version/manifests/install.yaml"

    # Wait for ArgoCD to be ready
    Write-Host "Waiting for ArgoCD to be ready..." -ForegroundColor Yellow
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n $Namespace

    # Patch ArgoCD server service to use LoadBalancer
    Write-Host "Configuring ArgoCD server service..." -ForegroundColor Yellow
    kubectl patch svc argocd-server -n $Namespace -p '{"spec": {"type": "LoadBalancer"}}'

    # Get initial admin password
    Write-Host "Getting ArgoCD admin password..." -ForegroundColor Yellow
    $initialPassword = kubectl -n $Namespace get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

    # Set custom password if provided
    if ($AdminPassword) {
        Write-Host "Setting custom admin password..." -ForegroundColor Yellow
        # Hash the password
        $hashedPassword = & kubectl exec -n $Namespace deployment/argocd-server -- argocd admin bcrypt --password $AdminPassword
        
        # Update the secret
        kubectl -n $Namespace patch secret argocd-secret -p @"
{
  "data": {
    "admin.password": "$([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($hashedPassword)))",
    "admin.passwordMtime": "$([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString())))"
  }
}
"@
        $finalPassword = $AdminPassword
    } else {
        $finalPassword = $initialPassword
    }

    # Wait for external IP
    Write-Host "Waiting for external IP assignment..." -ForegroundColor Yellow
    $externalIP = $null
    $attempts = 0
    while (-not $externalIP -and $attempts -lt 30) {
        Start-Sleep -Seconds 10
        $externalIP = kubectl get service argocd-server -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
        $attempts++
        Write-Host "." -NoNewline
    }

    if ($externalIP) {
        Write-Host "`nArgoCD installation completed successfully!" -ForegroundColor Green
        Write-Host "`nArgoCD UI Access:" -ForegroundColor Cyan
        Write-Host "URL: https://$externalIP" -ForegroundColor White
        Write-Host "Username: admin" -ForegroundColor White
        Write-Host "Password: $finalPassword" -ForegroundColor White
        
        Write-Host "`nArgoCD CLI Login:" -ForegroundColor Cyan
        Write-Host "argocd login $externalIP --username admin --password $finalPassword --insecure" -ForegroundColor White
    } else {
        Write-Host "`nArgoCD installation completed, but external IP not yet assigned." -ForegroundColor Yellow
        Write-Host "Check external IP with: kubectl get service argocd-server -n $Namespace" -ForegroundColor Cyan
        Write-Host "Username: admin" -ForegroundColor White
        Write-Host "Password: $finalPassword" -ForegroundColor White
    }

    # Show ArgoCD resources
    Write-Host "`nArgoCD Resources:" -ForegroundColor Yellow
    kubectl get all -n $Namespace

} catch {
    Write-Error "An error occurred during ArgoCD installation: $_"
    exit 1
}