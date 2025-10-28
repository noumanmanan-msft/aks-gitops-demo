# PowerShell script to initialize Git repository and commit GitOps files
param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubRepoURL,
    
    [Parameter(Mandatory=$false)]
    [string]$BranchName = "main",
    
    [Parameter(Mandatory=$false)]
    [string]$CommitMessage = "Initial GitOps setup with ArgoCD for Windows ASP.NET app"
)

Write-Host "Setting up Git repository for GitOps..." -ForegroundColor Green

# Check if git is installed
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed or not in PATH. Please install Git first."
    exit 1
}

try {
    # Check if we're already in a git repository
    $isGitRepo = git rev-parse --is-inside-work-tree 2>$null
    
    if (-not $isGitRepo) {
        Write-Host "Initializing Git repository..." -ForegroundColor Yellow
        git init
        
        # Set default branch name
        git config --local init.defaultBranch $BranchName
        git checkout -b $BranchName 2>$null
    } else {
        Write-Host "Git repository already exists." -ForegroundColor Green
    }
    
    # Create .gitignore file
    Write-Host "Creating .gitignore file..." -ForegroundColor Yellow
    $gitignoreContent = @"
# Build outputs
bin/
obj/
*.dll
*.exe
*.pdb

# Visual Studio / VS Code
.vs/
.vscode/
*.user
*.suo
*.userosscache
*.sln.docstates

# NuGet
packages/
*.nupkg

# Temporary files
*.tmp
*.temp
*~

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Docker
.dockerignore

# Kubernetes secrets (if any)
*secret*.yaml
*-secret.yaml

# Personal notes
notes.txt
TODO.md

# Logs
*.log
"@
    $gitignoreContent | Out-File -FilePath ".gitignore" -Encoding UTF8
    
    # Add remote origin if provided and not already set
    $remoteUrl = git remote get-url origin 2>$null
    if (-not $remoteUrl -and $GitHubRepoURL) {
        Write-Host "Adding remote origin: $GitHubRepoURL" -ForegroundColor Yellow
        git remote add origin $GitHubRepoURL
    } elseif ($remoteUrl -ne $GitHubRepoURL -and $GitHubRepoURL) {
        Write-Host "Updating remote origin to: $GitHubRepoURL" -ForegroundColor Yellow
        git remote set-url origin $GitHubRepoURL
    }
    
    # Update ArgoCD application manifests with correct repo URL
    Write-Host "Updating ArgoCD applications with repository URL..." -ForegroundColor Yellow
    $applications = @(
        "argocd\applications\windows-aspnet-dev.yaml",
        "argocd\applications\windows-aspnet-staging.yaml", 
        "argocd\applications\windows-aspnet-production.yaml"
    )
    
    foreach ($app in $applications) {
        if (Test-Path $app) {
            (Get-Content $app) -replace "https://github.com/noumanmanan-msft/aks-gitops-demo", $GitHubRepoURL | Set-Content $app -Encoding UTF8
            Write-Host "Updated $app" -ForegroundColor Gray
        }
    }
    
    # Update ArgoCD project.yaml with correct repo URL
    if (Test-Path "argocd\project.yaml") {
        (Get-Content "argocd\project.yaml") -replace "https://github.com/noumanmanan-msft/aks-gitops-demo", $GitHubRepoURL | Set-Content "argocd\project.yaml" -Encoding UTF8
        Write-Host "Updated argocd\project.yaml" -ForegroundColor Gray
    }
    
    # Stage all files
    Write-Host "Staging files for commit..." -ForegroundColor Yellow
    git add .
    
    # Show what will be committed
    Write-Host "`nFiles to be committed:" -ForegroundColor Cyan
    git status --porcelain
    
    # Commit the changes
    Write-Host "`nCommitting changes..." -ForegroundColor Yellow
    git commit -m $CommitMessage
    
    # Show repository status
    Write-Host "`nRepository Status:" -ForegroundColor Cyan
    git status
    
    Write-Host "`nBranch Information:" -ForegroundColor Cyan
    git branch -v
    
    Write-Host "`nRemote Information:" -ForegroundColor Cyan
    git remote -v
    
    Write-Host "`nNext Steps:" -ForegroundColor Green
    Write-Host "1. Push to GitHub:" -ForegroundColor Yellow
    Write-Host "   git push -u origin $BranchName" -ForegroundColor White
    Write-Host ""
    Write-Host "2. Install ArgoCD:" -ForegroundColor Yellow
    Write-Host "   .\argocd\install-argocd.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Deploy ArgoCD Applications:" -ForegroundColor Yellow
    Write-Host "   .\argocd\deploy-applications.ps1 -RepoURL `"$GitHubRepoURL`"" -ForegroundColor White
    
    Write-Host "`nGit repository setup completed successfully!" -ForegroundColor Green

} catch {
    Write-Error "An error occurred during Git setup: $_"
    exit 1
}