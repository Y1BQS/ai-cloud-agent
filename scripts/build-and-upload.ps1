# Build Lambda zip packages and upload to S3 with --sse AES256 (SCP compliance).
# Run from repo root. Requires: AWS CLI. Deploy s3-deployment-bucket stack first.

param(
    [string]$BucketName,
    [string]$AccountId = "503532613196",
    [string]$Region = "us-east-1",
    [string]$Environment = "sandbox"
)

if (-not $BucketName) {
    $BucketName = "ai-cloud-agent-$Environment-deployments-$AccountId"
}

$ErrorActionPreference = "Stop"
$RepoRoot = (Get-Location).Path
$BuildDir = Join-Path $RepoRoot "build"
$Prefix = "ai-cloud-agent/$Environment"

# Ensure build dir exists and is clean
if (Test-Path $BuildDir) { Remove-Item -Recurse -Force $BuildDir }
New-Item -ItemType Directory -Path $BuildDir | Out-Null

function New-LambdaZip {
    param([string]$SourceDir, [string]$OutputZip)
    $zipPath = Join-Path $BuildDir $OutputZip
    Push-Location (Join-Path $RepoRoot $SourceDir)
    try {
        Compress-Archive -Path *.py -DestinationPath $zipPath -Force
    } finally {
        Pop-Location
    }
    Write-Host "Created $zipPath"
}

Write-Host "Building Lambda packages..."
New-LambdaZip -SourceDir "src/supervisor" -OutputZip "supervisor.zip"
New-LambdaZip -SourceDir "src/agents/cost" -OutputZip "cost-agent.zip"
New-LambdaZip -SourceDir "src/agents/security" -OutputZip "security-agent.zip"

$Keys = @{
    SupervisorS3Key = "$Prefix/supervisor.zip"
    CostAgentS3Key = "$Prefix/cost-agent.zip"
    SecurityAgentS3Key = "$Prefix/security-agent.zip"
}

Write-Host "Uploading to s3://$BucketName (--sse AES256 for SCP compliance)..."
foreach ($name in @("supervisor", "cost-agent", "security-agent")) {
    $zipFile = Join-Path $BuildDir "$name.zip"
    if (-not (Test-Path $zipFile)) { throw "Build failed: $zipFile not found" }
    $s3Key = "$Prefix/$name.zip"
    aws s3 cp $zipFile "s3://$BucketName/$s3Key" --sse AES256 --region $Region
    Write-Host "Uploaded $s3Key"
}

Write-Host ""
Write-Host "Done. Use these parameters for CloudFormation deploy:"
Write-Host "  DeploymentBucketName: $BucketName"
Write-Host "  SupervisorS3Key: $($Keys.SupervisorS3Key)"
Write-Host "  CostAgentS3Key: $($Keys.CostAgentS3Key)"
Write-Host "  SecurityAgentS3Key: $($Keys.SecurityAgentS3Key)"
