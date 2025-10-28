#!/bin/bash
# Simple kubectl commands to deploy Windows ASP.NET app to AKS

echo "Deploying Windows ASP.NET application to AKS..."

# Apply the Kubernetes manifests
kubectl apply -f deploy-to-aks.yaml

# Check deployment status
echo "Checking deployment status..."
kubectl rollout status deployment/windows-aspnet-app

# Get service information
echo "Service information:"
kubectl get services windows-aspnet-service

# Get pod information
echo "Pod information:"
kubectl get pods -l app=windows-aspnet-app

# Get external IP (if available)
echo "Getting external IP (may take a few minutes)..."
kubectl get service windows-aspnet-service --watch

echo "Deployment completed!"
echo "Test the application by visiting http://<EXTERNAL-IP>/hello"