# PowerShell script to build, tag, and push ASP.NET image to Azure Container Registry
# Usage: .\build-and-push.ps1

$acrName = "acrdemoeastus2001"
$acrLoginServer = "$acrName.azurecr.io"
$imageName = "windows-aspnet"
$imageTag = "v1.0"
$fullImageName = "${acrLoginServer}/${imageName}:${imageTag}"

Write-Host "Logging in to Azure Container Registry..."
az acr login --name $acrName

# Change to script directory (aspnet-demo)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptDir

Write-Host "Building Docker image..."
docker build -t $imageName .

Write-Host "Tagging image as $fullImageName..."
docker tag $imageName $fullImageName

Write-Host "Pushing image to ACR..."
docker push $fullImageName

Write-Host "Done. Image pushed: $fullImageName"
