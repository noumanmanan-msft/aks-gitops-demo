# AKS Windows ASP.NET Deployment

This repository contains Kubernetes manifests and deployment scripts for deploying a Windows ASP.NET application to Azure Kubernetes Service (AKS).

## Files

- `deploy-to-aks.yaml` - Kubernetes manifests (Deployment, Service, HPA)
- `deploy-to-aks.ps1` - PowerShell deployment script with full setup
- `deploy-simple.sh` - Simple bash script for deployment
- `DEPLOYMENT.md` - This documentation

## Prerequisites

1. **Azure CLI** installed and configured
2. **kubectl** installed and configured
3. **AKS cluster** with Windows node pools
4. **Azure Container Registry** access to `crdemoeastus2001.azurecr.io`

## Deployment Options

### Option 1: Using PowerShell Script (Recommended)

```powershell
# Run with default parameters
.\deploy-to-aks.ps1

# Or specify custom parameters
.\deploy-to-aks.ps1 -ResourceGroupName "your-rg" -ClusterName "your-aks" -AcrName "crdemoeastus2001"
```

### Option 2: Manual kubectl Commands

```bash
# 1. Get AKS credentials
az aks get-credentials --resource-group your-resource-group --name your-aks-cluster

# 2. Create ACR secret (if needed)
kubectl create secret docker-registry acr-secret \
  --docker-server=crdemoeastus2001.azurecr.io \
  --docker-username=<acr-username> \
  --docker-password=<acr-password>

# 3. Deploy application
kubectl apply -f deploy-to-aks.yaml

# 4. Check status
kubectl get pods -l app=windows-aspnet-app
kubectl get service windows-aspnet-service
```

### Option 3: Using Simple Script

```bash
chmod +x deploy-simple.sh
./deploy-simple.sh
```

## Application Details

- **Image**: `crdemoeastus2001.azurecr.io/windows-aspnet:v1.0`
- **Port**: 80 (HTTP)
- **Endpoint**: `/hello` - Returns "Hello World from ASP.NET on Windows Container!"
- **Replicas**: 3 (configurable)
- **Node Selector**: Windows nodes only
- **Service Type**: LoadBalancer

## Configuration

### Resource Limits
- **Memory**: 512Mi request, 1Gi limit
- **CPU**: 250m request, 500m limit

### Scaling
- **Min Replicas**: 2
- **Max Replicas**: 10
- **CPU Target**: 70%
- **Memory Target**: 80%

### Health Checks
- **Liveness Probe**: HTTP GET `/hello` every 10s
- **Readiness Probe**: HTTP GET `/hello` every 5s

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -l app=windows-aspnet-app
kubectl describe pod <pod-name>
```

### Check Logs
```bash
kubectl logs -l app=windows-aspnet-app
kubectl logs <pod-name>
```

### Check Service
```bash
kubectl get service windows-aspnet-service
kubectl describe service windows-aspnet-service
```

### Check Events
```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Testing the Application

Once deployed, get the external IP:

```bash
kubectl get service windows-aspnet-service
```

Then visit: `http://<EXTERNAL-IP>/hello`

Expected response: `Hello World from ASP.NET on Windows Container!`

## Cleanup

To remove the deployment:

```bash
kubectl delete -f deploy-to-aks.yaml
kubectl delete secret acr-secret  # if you want to remove the ACR secret too
```

## Notes

- Ensure your AKS cluster has Windows node pools configured
- The LoadBalancer service will provision an Azure Load Balancer with a public IP
- Initial deployment may take a few minutes for the external IP assignment
- Windows containers require Windows nodes in your AKS cluster