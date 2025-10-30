# FluxCD Environment Testing Script
# This script tests all FluxCD environments (dev-flux, staging-flux, production-flux)
# and verifies FluxCD GitOps functionality

param(
    [Parameter()]
    [ValidateSet("dev-flux", "staging-flux", "production-flux", "all")]
    [string]$Environment = "all",
    
    [Parameter()]
    [switch]$Detailed,
    
    [Parameter()]
    [switch]$CheckFluxStatus,
    
    [Parameter()]
    [switch]$ShowLogs,
    
    [Parameter()]
    [int]$TimeoutSeconds = 300
)

# ANSI Color codes for PowerShell
$Red = "`e[31m"
$Green = "`e[32m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Magenta = "`e[35m"
$Cyan = "`e[36m"
$Reset = "`e[0m"

function Write-ColorOutput {
    param($Message, $Color = $Reset)
    Write-Host "$Color$Message$Reset"
}

function Test-KubectlConnection {
    Write-ColorOutput "=== Testing Kubernetes Connection ===" $Blue
    
    try {
        $clusterInfo = kubectl cluster-info --request-timeout=10s 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Successfully connected to Kubernetes cluster" $Green
            Write-ColorOutput "Cluster: $($clusterInfo | Select-String 'Kubernetes control plane')" $Cyan
            return $true
        } else {
            Write-ColorOutput "❌ Failed to connect to Kubernetes cluster" $Red
            Write-ColorOutput "Error: $clusterInfo" $Red
            return $false
        }
    } catch {
        Write-ColorOutput "❌ Exception during cluster connection test: $($_.Exception.Message)" $Red
        return $false
    }
}

function Test-FluxCDInstallation {
    Write-ColorOutput "=== Testing FluxCD Installation ===" $Blue
    
    try {
        # Check if FluxCD is installed
        $fluxPods = kubectl get pods -n flux-system -o json 2>&1 | ConvertFrom-Json
        
        if ($LASTEXITCODE -eq 0 -and $fluxPods.items.Count -gt 0) {
            Write-ColorOutput "✅ FluxCD is installed in flux-system namespace" $Green
            
            foreach ($pod in $fluxPods.items) {
                $status = $pod.status.phase
                $podName = $pod.metadata.name
                $statusColor = if ($status -eq "Running") { $Green } else { $Red }
                Write-ColorOutput "  Pod: $podName - Status: $status" $statusColor
            }
            
            if ($CheckFluxStatus) {
                Write-ColorOutput "--- FluxCD System Status ---" $Yellow
                flux check 2>&1
            }
            
            return $true
        } else {
            Write-ColorOutput "❌ FluxCD is not installed or accessible" $Red
            return $false
        }
    } catch {
        Write-ColorOutput "❌ Error checking FluxCD installation: $($_.Exception.Message)" $Red
        return $false
    }
}

function Test-FluxCDEnvironment {
    param(
        [string]$EnvironmentName,
        [hashtable]$ExpectedConfig
    )
    
    Write-ColorOutput "=== Testing FluxCD Environment: $EnvironmentName ===" $Blue
    
    $testResults = @{
        Namespace = $false
        Deployment = $false
        Service = $false
        Pods = $false
        ServiceEndpoint = $false
        FluxResources = $false
    }
    
    try {
        # Test namespace
        kubectl get namespace $EnvironmentName -o json 2>/dev/null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Namespace '$EnvironmentName' exists" $Green
            $testResults.Namespace = $true
        } else {
            Write-ColorOutput "❌ Namespace '$EnvironmentName' not found" $Red
        }
        
        # Test FluxCD Kustomization resources
        $kustomizations = kubectl get kustomizations -n flux-system -o json 2>/dev/null | ConvertFrom-Json
        if ($LASTEXITCODE -eq 0) {
            $envKustomization = $kustomizations.items | Where-Object { $_.metadata.name -like "*$EnvironmentName*" }
            if ($envKustomization) {
                Write-ColorOutput "✅ FluxCD Kustomization found for $EnvironmentName" $Green
                Write-ColorOutput "  Status: $($envKustomization.status.conditions | Where-Object { $_.type -eq 'Ready' } | Select-Object -ExpandProperty status)" $Cyan
                $testResults.FluxResources = $true
            } else {
                Write-ColorOutput "⚠️  No FluxCD Kustomization found for $EnvironmentName" $Yellow
            }
        }
        
        # Test deployment
        $deployment = kubectl get deployment windows-aspnet-app -n $EnvironmentName -o json 2>/dev/null
        if ($LASTEXITCODE -eq 0) {
            $deploymentObj = $deployment | ConvertFrom-Json
            $availableReplicas = if ($deploymentObj.status.availableReplicas) { $deploymentObj.status.availableReplicas } else { 0 }
            $desiredReplicas = $deploymentObj.spec.replicas
            
            Write-ColorOutput "✅ Deployment 'windows-aspnet-app' found in $EnvironmentName" $Green
            Write-ColorOutput "  Desired Replicas: $desiredReplicas, Available: $availableReplicas" $Cyan
            
            # Check if deployment has FluxCD labels
            $labels = $deploymentObj.metadata.labels
            if ($labels.'gitops-tool' -eq 'fluxcd') {
                Write-ColorOutput "✅ Deployment has correct FluxCD GitOps labels" $Green
            } else {
                Write-ColorOutput "⚠️  Deployment missing FluxCD GitOps labels" $Yellow
            }
            
            if ($availableReplicas -eq $desiredReplicas) {
                $testResults.Deployment = $true
            }
        } else {
            Write-ColorOutput "❌ Deployment 'windows-aspnet-app' not found in $EnvironmentName" $Red
        }
        
        # Test service
        $service = kubectl get service windows-aspnet-service -n $EnvironmentName -o json 2>/dev/null
        if ($LASTEXITCODE -eq 0) {
            $serviceObj = $service | ConvertFrom-Json
            $serviceType = $serviceObj.spec.type
            Write-ColorOutput "✅ Service 'windows-aspnet-service' found in $EnvironmentName" $Green
            Write-ColorOutput "  Type: $serviceType" $Cyan
            $testResults.Service = $true
            
            # Check for LoadBalancer external IP
            if ($serviceType -eq "LoadBalancer") {
                $externalIP = $serviceObj.status.loadBalancer.ingress[0].ip
                if ($externalIP) {
                    Write-ColorOutput "  External IP: $externalIP" $Cyan
                    $testResults.ServiceEndpoint = $true
                } else {
                    Write-ColorOutput "  External IP: Pending..." $Yellow
                }
            }
        } else {
            Write-ColorOutput "❌ Service 'windows-aspnet-service' not found in $EnvironmentName" $Red
        }
        
        # Test pods
        $pods = kubectl get pods -n $EnvironmentName -l app=windows-aspnet-app -o json 2>/dev/null
        if ($LASTEXITCODE -eq 0) {
            $podsObj = $pods | ConvertFrom-Json
            $runningPods = ($podsObj.items | Where-Object { $_.status.phase -eq "Running" }).Count
            $totalPods = $podsObj.items.Count
            
            Write-ColorOutput "✅ Found $totalPods pod(s), $runningPods running" $Green
            
            if ($Detailed) {
                foreach ($pod in $podsObj.items) {
                    $podName = $pod.metadata.name
                    $podStatus = $pod.status.phase
                    $nodeType = $pod.spec.nodeSelector.'kubernetes.io/os'
                    $statusColor = if ($podStatus -eq "Running") { $Green } else { $Red }
                    Write-ColorOutput "  Pod: $podName - Status: $podStatus - Node OS: $nodeType" $statusColor
                }
            }
            
            if ($runningPods -eq $totalPods -and $totalPods -gt 0) {
                $testResults.Pods = $true
            }
        } else {
            Write-ColorOutput "❌ No pods found for windows-aspnet-app in $EnvironmentName" $Red
        }
        
        # Show environment-specific information
        if ($Detailed) {
            Write-ColorOutput "--- Environment Details ---" $Yellow
            Write-ColorOutput "Expected Replicas: $($ExpectedConfig.Replicas)" $Cyan
            Write-ColorOutput "Service Type: $($ExpectedConfig.ServiceType)" $Cyan
            Write-ColorOutput "GitOps Tool: FluxCD" $Cyan
            Write-ColorOutput "Namespace: $EnvironmentName" $Cyan
        }
        
        # Show logs if requested
        if ($ShowLogs) {
            Write-ColorOutput "--- Recent Pod Logs (last 5 lines) ---" $Yellow
            kubectl logs -n $EnvironmentName -l app=windows-aspnet-app --tail=5 2>/dev/null
        }
        
    } catch {
        Write-ColorOutput "❌ Error testing environment $EnvironmentName`: $($_.Exception.Message)" $Red
    }
    
    return $testResults
}

function Get-FluxCDEnvironmentSummary {
    param([hashtable]$AllResults)
    
    Write-ColorOutput "=== FluxCD Environment Summary ===" $Magenta
    
    foreach ($env in $AllResults.Keys) {
        $results = $AllResults[$env]
        $successCount = ($results.Values | Where-Object { $_ -eq $true }).Count
        $totalTests = $results.Count
        $percentage = [math]::Round(($successCount / $totalTests) * 100, 1)
        
        $statusColor = switch ($percentage) {
            {$_ -ge 80} { $Green }
            {$_ -ge 60} { $Yellow }
            default { $Red }
        }
        
        Write-ColorOutput "Environment: $env - $successCount/$totalTests tests passed ($percentage%)" $statusColor
        
        if ($Detailed) {
            foreach ($test in $results.Keys) {
                $status = if ($results[$test]) { "✅ PASS" } else { "❌ FAIL" }
                $color = if ($results[$test]) { $Green } else { $Red }
                Write-ColorOutput "  $test`: $status" $color
            }
        }
    }
}

# Main execution
Write-ColorOutput "🚀 FluxCD Environment Testing Script" $Magenta
Write-ColorOutput "Testing Environment(s): $Environment" $Cyan
Write-ColorOutput "Timeout: $TimeoutSeconds seconds" $Cyan

# Test basic connectivity
if (-not (Test-KubectlConnection)) {
    Write-ColorOutput "❌ Cannot proceed without Kubernetes connectivity" $Red
    exit 1
}

# Test FluxCD installation
if (-not (Test-FluxCDInstallation)) {
    Write-ColorOutput "❌ FluxCD is not properly installed - some tests may fail" $Red
}

# Define environment configurations
$environmentConfigs = @{
    "dev-flux" = @{
        Replicas = 2
        ServiceType = "ClusterIP"
    }
    "staging-flux" = @{
        Replicas = 3
        ServiceType = "LoadBalancer"
    }
    "production-flux" = @{
        Replicas = 5
        ServiceType = "LoadBalancer"
    }
}

# Test environments
$allResults = @{}

if ($Environment -eq "all") {
    $environmentsToTest = @("dev-flux", "staging-flux", "production-flux")
} else {
    $environmentsToTest = @($Environment)
}

foreach ($env in $environmentsToTest) {
    if ($environmentConfigs.ContainsKey($env)) {
        $results = Test-FluxCDEnvironment -EnvironmentName $env -ExpectedConfig $environmentConfigs[$env]
        $allResults[$env] = $results
        Write-ColorOutput "" # Empty line for readability
    } else {
        Write-ColorOutput "❌ Unknown environment: $env" $Red
    }
}

# Show summary
Get-FluxCDEnvironmentSummary -AllResults $allResults

# Final status
$allTestsPassed = $true
foreach ($envResults in $allResults.Values) {
    foreach ($testResult in $envResults.Values) {
        if (-not $testResult) {
            $allTestsPassed = $false
            break
        }
    }
    if (-not $allTestsPassed) { break }
}

Write-ColorOutput "=== Final Result ===" $Magenta
if ($allTestsPassed) {
    Write-ColorOutput "🎉 All FluxCD environments are healthy!" $Green
    exit 0
} else {
    Write-ColorOutput "⚠️  Some FluxCD environment tests failed - check details above" $Yellow
    exit 1
}