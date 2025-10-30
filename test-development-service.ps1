# Test Development Environment Service
# PowerShell script to port-forward and test the development ArgoCD deployment

param(
    [string]$Namespace = "development",
    [string]$ServiceName = "windows-aspnet-service", 
    [int]$LocalPort = 8080,
    [int]$ServicePort = 80,
    [string]$TestEndpoint = "/hello"
)

Write-Host "🚀 Development Environment Testing Script" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Function to check if kubectl is available
function Test-Kubectl {
    try {
        kubectl version --client --short | Out-Null
        return $true
    }
    catch {
        Write-Host "❌ kubectl not found or not configured" -ForegroundColor Red
        return $false
    }
}

# Function to check namespace exists
function Test-Namespace {
    param($ns)
    try {
        kubectl get namespace $ns | Out-Null
        return $true
    }
    catch {
        Write-Host "❌ Namespace '$ns' not found" -ForegroundColor Red
        return $false
    }
}

# Function to display environment status
function Show-EnvironmentStatus {
    param($ns)
    
    Write-Host "🔍 Checking $ns environment status..." -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "📦 Pods:" -ForegroundColor Green
    kubectl get pods -n $ns -o wide
    Write-Host ""
    
    Write-Host "🌐 Services:" -ForegroundColor Green
    kubectl get services -n $ns
    Write-Host ""
    
    Write-Host "🚀 ArgoCD Applications:" -ForegroundColor Green
    kubectl get applications -n argocd | Where-Object { $_ -match $ns -or $_ -match "NAME" }
    Write-Host ""
}

# Function to test the service with curl
function Test-Service {
    param($url)
    
    Write-Host "🧪 Testing service at $url..." -ForegroundColor Yellow
    
    try {
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 10
        Write-Host "✅ Success! Response:" -ForegroundColor Green
        Write-Host $response.Content -ForegroundColor White
        Write-Host ""
    }
    catch {
        Write-Host "❌ Failed to reach service: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Make sure port-forward is running in another terminal" -ForegroundColor Yellow
        Write-Host ""
    }
}

# Function to start port-forward
function Start-PortForward {
    param($ns, $service, $localPort, $servicePort)
    
    Write-Host "🌐 Starting port-forward from localhost:$localPort to ${service}:$servicePort in namespace $ns" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📝 Command: kubectl port-forward -n $ns service/$service ${localPort}:$servicePort" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🔗 Test URLs:" -ForegroundColor Cyan
    Write-Host "   • http://localhost:$localPort$TestEndpoint" -ForegroundColor White
    Write-Host "   • http://localhost:$localPort/" -ForegroundColor White
    Write-Host ""
    Write-Host "⚠️  Press Ctrl+C to stop port-forward" -ForegroundColor Yellow
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Start port-forward (this will block until Ctrl+C)
    kubectl port-forward -n $ns "service/$service" "${localPort}:$servicePort"
}

# Main script execution
try {
    # Check prerequisites
    if (-not (Test-Kubectl)) {
        Write-Host "Please install and configure kubectl first." -ForegroundColor Red
        exit 1
    }
    
    if (-not (Test-Namespace $Namespace)) {
        Write-Host "Please ensure the '$Namespace' namespace exists and ArgoCD has deployed the application." -ForegroundColor Red
        exit 1
    }
    
    # Show current status
    Show-EnvironmentStatus $Namespace
    
    # Interactive menu
    Write-Host "🎯 Choose an action:" -ForegroundColor Cyan
    Write-Host "1. Start port-forward and keep running (blocks terminal)" -ForegroundColor White
    Write-Host "2. Test service (assumes port-forward is already running)" -ForegroundColor White
    Write-Host "3. Show detailed pod logs" -ForegroundColor White
    Write-Host "4. Show ArgoCD sync status" -ForegroundColor White
    Write-Host "5. Quick health check" -ForegroundColor White
    Write-Host "0. Exit" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Enter your choice (0-5)"
    
    switch ($choice) {
        "1" {
            # Check if service exists first
            try {
                kubectl get service $ServiceName -n $Namespace | Out-Null
                Start-PortForward $Namespace $ServiceName $LocalPort $ServicePort
            }
            catch {
                Write-Host "❌ Service '$ServiceName' not found in namespace '$Namespace'" -ForegroundColor Red
                Write-Host "Available services:" -ForegroundColor Yellow
                kubectl get services -n $Namespace
            }
        }
        
        "2" {
            Test-Service "http://localhost:$LocalPort$TestEndpoint"
        }
        
        "3" {
            Write-Host "📋 Pod logs for ${Namespace}:" -ForegroundColor Yellow
            kubectl logs -n $Namespace -l app=windows-aspnet-app --tail=50
        }
        
        "4" {
            Write-Host "🎯 ArgoCD Application Status:" -ForegroundColor Yellow
            kubectl get applications -n argocd | Where-Object { $_ -match $Namespace -or $_ -match "NAME" }
            Write-Host ""
            Write-Host "📋 Detailed status:" -ForegroundColor Yellow
            kubectl describe application "windows-aspnet-$Namespace" -n argocd | Select-String -Pattern "(Status:|Health:|Sync:|Message:)" -A 2
        }
        
        "5" {
            Write-Host "🏥 Quick Health Check:" -ForegroundColor Yellow
            Write-Host ""
            
            # Check pods
            $pods = kubectl get pods -n $Namespace -o json | ConvertFrom-Json
            $runningPods = $pods.items | Where-Object { $_.status.phase -eq "Running" }
            
            if ($runningPods.Count -gt 0) {
                Write-Host "✅ $($runningPods.Count) pod(s) running" -ForegroundColor Green
            } else {
                Write-Host "❌ No running pods found" -ForegroundColor Red
            }
            
            # Check service
            try {
                kubectl get service $ServiceName -n $Namespace | Out-Null
                Write-Host "✅ Service '$ServiceName' exists" -ForegroundColor Green
            } catch {
                Write-Host "❌ Service '$ServiceName' not found" -ForegroundColor Red
            }
            
            # Check ArgoCD sync
            try {
                $appStatus = kubectl get application "windows-aspnet-$Namespace" -n argocd -o jsonpath='{.status.sync.status}' 2>$null
                if ($appStatus -eq "Synced") {
                    Write-Host "✅ ArgoCD application is synced" -ForegroundColor Green
                } else {
                    Write-Host "⚠️  ArgoCD application status: $appStatus" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "❌ Could not check ArgoCD application status" -ForegroundColor Red
            }
        }
        
        "0" {
            Write-Host "👋 Goodbye!" -ForegroundColor Green
        }
        
        default {
            Write-Host "❌ Invalid choice. Please run the script again." -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please check your kubectl configuration and cluster connectivity." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Useful Commands:" -ForegroundColor Cyan
Write-Host "kubectl get pods -n development" -ForegroundColor Gray
Write-Host "kubectl get services -n development" -ForegroundColor Gray
Write-Host "kubectl port-forward -n development service/windows-aspnet-service 8080:80" -ForegroundColor Gray
Write-Host "curl http://localhost:8080/hello" -ForegroundColor Gray