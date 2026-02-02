# Build and push the supervisor Lambda image.
# Run from repo root. Requires: Docker, AWS CLI, ECR login.
# Replace ACCOUNT and REGION if different.

param(
    [string]$AccountId = "503532613196",
    [string]$Region = "us-east-1",
    [string]$Environment = "sandbox"
)

$ErrorActionPreference = "Stop"
$Repo = "ai-cloud-agent-${Environment}-supervisor"
$Uri = "${AccountId}.dkr.ecr.${Region}.amazonaws.com/${Repo}:latest"

Write-Host "Logging in to ECR..."
aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin "${AccountId}.dkr.ecr.${Region}.amazonaws.com"

Write-Host "Building supervisor image (linux/amd64 for Lambda)..."
docker build --platform linux/amd64 -t $Uri -f src/supervisor/Dockerfile src/supervisor

Write-Host "Pushing $Uri ..."
docker push $Uri

Write-Host "Done. Supervisor image pushed to $Uri"
