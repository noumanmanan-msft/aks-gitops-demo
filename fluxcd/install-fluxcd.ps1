# FluxCD v2 Installation Script for AKS
# This script installs FluxCD v2 alongside existing ArgoCD installation
# Completely separate namespaces and configurations

param(
    [string]$ClusterName = "aks-tokio-eastus2-002",
    [string]$ResourceGroup = "rg-demo-eastus2-001",
    [string]$GitRepository = "https://github.com/noumanmanan-msft/aks-gitops-demo",
    [string]$GitBranch = "main",
    [string]$GitPath = "./fluxcd/clusters/aks-tokio",
    [string]$FluxNamespace = "flux-system"
)

Write-Host "🚀 FluxCD v2 Installation for AKS GitOps" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Function to check prerequisites
function Test-Prerequisites {
    Write-Host "🔍 Checking prerequisites..." -ForegroundColor Yellow
    
    # Check kubectl
    try {
        kubectl version --client --short | Out-Null
        Write-Host "✅ kubectl is available" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ kubectl not found. Please install kubectl." -ForegroundColor Red
        return $false
    }
    
    # Check flux CLI
    try {
        flux version --client | Out-Null
        Write-Host "✅ Flux CLI is available" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️  Flux CLI not found. Installing..." -ForegroundColor Yellow
        Install-FluxCLI
    }
    
    # Check Azure CLI
    try {
        az version | Out-Null
        Write-Host "✅ Azure CLI is available" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Azure CLI not found. Please install Azure CLI." -ForegroundColor Red
        return $false
    }
    
    # Check cluster connectivity
    try {
        kubectl get nodes | Out-Null
        Write-Host "✅ Connected to Kubernetes cluster" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Cannot connect to Kubernetes cluster" -ForegroundColor Red
        Write-Host "Please ensure you're connected to: $ClusterName" -ForegroundColor Yellow
        return $false
    }
    
    return $true
}

# Function to install Flux CLI
function Install-FluxCLI {
    Write-Host "📥 Installing Flux CLI..." -ForegroundColor Yellow
    
    try {
        # Download and install flux CLI for Windows
        $fluxVersion = "v2.1.2"
        $downloadUrl = "https://github.com/fluxcd/flux2/releases/download/$fluxVersion/flux_$($fluxVersion)_windows_amd64.zip"
        
        # Create temp directory
        $tempDir = "$env:TEMP\flux-install"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        # Download flux
        Invoke-WebRequest -Uri $downloadUrl -OutFile "$tempDir\flux.zip"
        
        # Extract
        Expand-Archive -Path "$tempDir\flux.zip" -DestinationPath $tempDir -Force
        
        # Move to a directory in PATH (or create one)
        $fluxDir = "$env:USERPROFILE\.local\bin"
        New-Item -ItemType Directory -Path $fluxDir -Force | Out-Null
        Move-Item -Path "$tempDir\flux.exe" -Destination "$fluxDir\flux.exe" -Force
        
        # Add to PATH if not already there
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($currentPath -notlike "*$fluxDir*") {
            [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$fluxDir", "User")
            $env:PATH += ";$fluxDir"
        }
        
        Write-Host "✅ Flux CLI installed successfully" -ForegroundColor Green
        
        # Cleanup
        Remove-Item -Path $tempDir -Recurse -Force
    }
    catch {
        Write-Host "❌ Failed to install Flux CLI: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please install manually: https://fluxcd.io/flux/installation/" -ForegroundColor Yellow
        throw
    }
}

# Function to check if FluxCD is already installed
function Test-FluxCDInstalled {
    try {
        kubectl get namespace $FluxNamespace | Out-Null
        $fluxPods = kubectl get pods -n $FluxNamespace --no-headers 2>$null
        if ($fluxPods) {
            Write-Host "⚠️  FluxCD appears to be already installed in namespace '$FluxNamespace'" -ForegroundColor Yellow
            Write-Host "Existing pods:" -ForegroundColor Gray
            kubectl get pods -n $FluxNamespace
            Write-Host ""
            
            $response = Read-Host "Do you want to continue anyway? This will update the existing installation. (y/N)"
            return ($response -eq 'y' -or $response -eq 'Y')
        }
        return $true
    }
    catch {
        return $true
    }
}

# Function to install FluxCD
function Install-FluxCD {
    Write-Host "🔧 Installing FluxCD v2..." -ForegroundColor Yellow
    Write-Host ""
    
    # Pre-check cluster requirements
    Write-Host "📋 Running FluxCD pre-flight checks..." -ForegroundColor Cyan
    $precheck = flux check --pre 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Pre-flight checks passed" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  Pre-flight check warnings:" -ForegroundColor Yellow
        Write-Host $precheck -ForegroundColor Gray
        Write-Host ""
    }
    
    # Bootstrap FluxCD
    Write-Host "🚀 Bootstrapping FluxCD..." -ForegroundColor Cyan
    Write-Host "Repository: $GitRepository" -ForegroundColor Gray
    Write-Host "Branch: $GitBranch" -ForegroundColor Gray
    Write-Host "Path: $GitPath" -ForegroundColor Gray
    Write-Host "Namespace: $FluxNamespace" -ForegroundColor Gray
    Write-Host ""
    
    # Create the cluster directory structure first
    $clusterPath = "fluxcd/clusters/aks-tokio"
    if (-not (Test-Path $clusterPath)) {
        New-Item -ItemType Directory -Path $clusterPath -Force | Out-Null
        Write-Host "📁 Created cluster directory: $clusterPath" -ForegroundColor Green
    }
    
    # Install FluxCD components
    Write-Host "Installing FluxCD components..." -ForegroundColor Yellow
    
    try {
        # Install FluxCD using kubectl (more reliable than flux bootstrap for existing repos)
        flux install --namespace=$FluxNamespace --network-policy=false
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ FluxCD components installed successfully" -ForegroundColor Green
        }
        else {
            throw "FluxCD installation failed"
        }
        
        # Wait for FluxCD to be ready
        Write-Host "⏳ Waiting for FluxCD to be ready..." -ForegroundColor Yellow
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=flux -n $FluxNamespace --timeout=300s
        
        Write-Host "✅ FluxCD is ready!" -ForegroundColor Green
        
    }
    catch {
        Write-Host "❌ FluxCD installation failed: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Function to create GitRepository source
function Create-GitRepository {
    Write-Host "📚 Creating Git repository source..." -ForegroundColor Yellow
    
    $gitRepoManifest = @"
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: aks-gitops-demo
  namespace: $FluxNamespace
spec:
  interval: 1m
  ref:
    branch: $GitBranch
  url: $GitRepository
  ignore: |
    # Ignore ArgoCD directory to avoid conflicts
    /argocd/
    # Ignore non-FluxCD environments
    /environments/development/
    /environments/staging/
    /environments/production/
"@

    $gitRepoPath = "fluxcd/sources/git-repository.yaml"
    Set-Content -Path $gitRepoPath -Value $gitRepoManifest -Encoding UTF8
    
    # Apply the GitRepository
    kubectl apply -f $gitRepoPath
    
    Write-Host "✅ GitRepository source created" -ForegroundColor Green
}

# Function to create basic Kustomizations
function Create-Kustomizations {
    Write-Host "🔧 Creating Kustomizations..." -ForegroundColor Yellow
    
    # Infrastructure Kustomization
    $infraKustomization = @"
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-infrastructure
  namespace: $FluxNamespace
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: aks-gitops-demo
  path: "./fluxcd/infrastructure"
  prune: true
  wait: true
  timeout: 5m
"@
    
    # Applications Kustomization  
    $appsKustomization = @"
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-applications
  namespace: $FluxNamespace
spec:
  interval: 2m
  sourceRef:
    kind: GitRepository
    name: aks-gitops-demo
  path: "./environments/fluxcd"
  prune: true
  wait: false
  timeout: 5m
  dependsOn:
    - name: flux-infrastructure
"@
    
    # Save kustomizations
    $infraPath = "fluxcd/kustomizations/infrastructure.yaml"
    $appsPath = "fluxcd/kustomizations/applications.yaml"
    
    Set-Content -Path $infraPath -Value $infraKustomization -Encoding UTF8
    Set-Content -Path $appsPath -Value $appsKustomization -Encoding UTF8
    
    Write-Host "✅ Kustomizations created" -ForegroundColor Green
}

# Function to display status
function Show-FluxCDStatus {
    Write-Host ""
    Write-Host "🎯 FluxCD Installation Summary" -ForegroundColor Cyan
    Write-Host "===============================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "📦 FluxCD Pods:" -ForegroundColor Green
    kubectl get pods -n $FluxNamespace
    Write-Host ""
    
    Write-Host "📚 Git Sources:" -ForegroundColor Green
    kubectl get gitrepositories -n $FluxNamespace
    Write-Host ""
    
    Write-Host "🔧 Kustomizations:" -ForegroundColor Green
    kubectl get kustomizations -n $FluxNamespace
    Write-Host ""
    
    Write-Host "🌐 FluxCD API Resources:" -ForegroundColor Green
    kubectl api-resources --api-group=source.toolkit.fluxcd.io
    Write-Host ""
    
    Write-Host "✅ FluxCD v2 Installation Complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Create FluxCD environment manifests" -ForegroundColor White
    Write-Host "2. Set up FluxCD GitHub Actions workflows" -ForegroundColor White  
    Write-Host "3. Configure image automation (optional)" -ForegroundColor White
    Write-Host "4. Test FluxCD deployments" -ForegroundColor White
    Write-Host ""
    Write-Host "🔗 Useful Commands:" -ForegroundColor Cyan
    Write-Host "   flux get all" -ForegroundColor Gray
    Write-Host "   kubectl get all -n $FluxNamespace" -ForegroundColor Gray
    Write-Host "   flux logs --follow --tail=10" -ForegroundColor Gray
}

# Main execution
try {
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    Write-Host ""
    Write-Host "🎯 Installation Configuration:" -ForegroundColor Cyan
    Write-Host "Cluster: $ClusterName" -ForegroundColor White
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor White
    Write-Host "Git Repository: $GitRepository" -ForegroundColor White
    Write-Host "Git Branch: $GitBranch" -ForegroundColor White
    Write-Host "FluxCD Namespace: $FluxNamespace" -ForegroundColor White
    Write-Host ""
    
    # Confirm installation
    $confirm = Read-Host "Proceed with FluxCD installation? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    # Check if already installed
    if (-not (Test-FluxCDInstalled)) {
        Write-Host "Installation cancelled by user." -ForegroundColor Yellow
        exit 0
    }
    
    # Install FluxCD
    Install-FluxCD
    
    # Create Git repository source
    Create-GitRepository
    
    # Create basic kustomizations
    Create-Kustomizations
    
    # Show status
    Show-FluxCDStatus
    
    Write-Host "🎉 FluxCD installation completed successfully!" -ForegroundColor Green
    Write-Host "FluxCD is now running alongside ArgoCD in separate namespaces." -ForegroundColor White
}
catch {
    Write-Host ""
    Write-Host "❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please check the error above and try again." -ForegroundColor Yellow
    exit 1
}