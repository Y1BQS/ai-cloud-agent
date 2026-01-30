# Push the Lambda Python 3.12 base image to all three ECR repos.
# Run from repo root. Requires: Docker, AWS CLI, and ECR repos to exist (stack creates them).
# Replace ACCOUNT and REGION if different from below.

param(
    [string]$AccountId = "503532613196",
    [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"
$BaseImage = "public.ecr.aws/lambda/python:3.12"
$Registry = "$AccountId.dkr.ecr.$Region.amazonaws.com"

Write-Host "Logging in to ECR..."
aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $Registry

Write-Host "Pulling base image..."
docker pull $BaseImage

$Repos = @(
    "ai-cloud-agent-sandbox-supervisor",
    "ai-cloud-agent-sandbox-cost-agent",
    "ai-cloud-agent-sandbox-security-agent"
)

foreach ($Repo in $Repos) {
    $Uri = "${Registry}/${Repo}:latest"
    Write-Host "Tagging and pushing $Uri ..."
    docker tag ${BaseImage}:latest $Uri
    docker push $Uri
}

Write-Host "Done. All three images pushed to $Registry"
