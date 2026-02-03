# AI Cloud Agent

Multi-agent system that monitors an AWS account and sends daily/weekly email reports (cloud hygiene, cost, security) via a supervisor and subordinate agents. Deployed with CloudFormation; Lambdas use zip packages stored in S3.

## Repository and pipeline

- **GitHub**: Create a new repo (e.g. `ai-cloud-agent`) and add this project as the remote (see below).
- **Pipeline**: GitHub Actions builds zip packages, uploads to S3 with `--sse AES256` (SCP compliance), and deploys the CloudFormation stack on push to `main`.

### One-time setup

1. **Create the CloudFormation service role (required for Git sync)**  
   CloudFormation needs an IAM role to assume when creating/updating the stack. Deploy it once:
   - In the **CloudFormation console**: Create stack → Upload a template file → choose `templates/cloudformation-service-role.yaml` from this repo (or paste its contents).
   - Stack name: e.g. `ai-cloud-agent-bootstrap`.
   - Create the stack. When it completes, go to **Outputs** and copy the **RoleArn** (e.g. `arn:aws:iam::123456789012:role/ai-cloud-agent-cloudformation-service-role`).
   - When creating the main stack with **Sync from Git**, under **Permissions** → **IAM role**, choose this role (it appears as `ai-cloud-agent-cloudformation-service-role`).

2. **Create the S3 deployment bucket (required before main stack)**  
   Our org SCP requires explicit server-side encryption on all S3 uploads. Deploy the compliant bucket once:
   - **CloudFormation console** → Create stack → Upload a template file → choose `templates/s3-deployment-bucket.yaml`.
   - Stack name: e.g. `ai-cloud-agent-s3`.
   - Parameters: Environment = `sandbox` (or match your environment).
   - Create the stack. Note the **BucketName** output (e.g. `ai-cloud-agent-sandbox-deployments-503532613196`).

3. **Create the GitHub repo**
   - On GitHub: New repository → name `ai-cloud-agent` (or your choice) → Create (no need to add README; this project has one).

4. **Connect and push**
   ```bash
   git remote add origin https://github.com/YOUR_ORG/ai-cloud-agent.git
   git branch -M main
   git push -u origin main
   ```

5. **Configure AWS credentials for the pipeline**  
   The pipeline needs permissions to upload to S3 (with explicit encryption) and deploy CloudFormation.
   - **Option A (recommended): OIDC**  
     In your AWS account, create an OIDC identity provider for GitHub and an IAM role that trusts it. The role needs `s3:PutObject` on the deployment bucket (uploads must use `--sse AES256`), `cloudformation:*`, `lambda:*`, and related IAM/EventBridge permissions. In the repo: Settings → Secrets and variables → Actions:
     - **Variables**: `USE_OIDC` = `true`
     - **Secrets**: `AWS_ROLE_ARN` (the IAM role ARN), `AWS_REGION` (e.g. `us-east-1`)
   - **Option B: Access keys**  
     In the repo: Settings → Secrets and variables → Actions → Secrets:
     - `AWS_ACCESS_KEY_ID`
     - `AWS_SECRET_ACCESS_KEY`
     - `AWS_REGION` (e.g. `us-east-1`). If omitted, the workflow uses `us-east-1`.

6. **Update the workflow for your stack and bucket**  
   Edit `.github/workflows/deploy.yml` and set `STACK_NAME`, `BUCKET_NAME`, and any parameter-overrides (e.g. SenderEmail, RecipientEmails) to match your environment.

After that, every push to `main` builds the Lambda zips, uploads them to S3 with `--sse AES256`, and deploys/updates the CloudFormation stack.

## Deploying the agent

The main stack (`templates/main.yaml`) creates:

- **Supervisor Lambda** – invokes subordinate Lambdas, calls Bedrock to synthesize the report, sends email via SES.
- **Cost agent Lambda** – Cost Explorer + Bedrock; returns a short cost/optimization report.
- **Security agent Lambda** – Security Hub / EC2 / S3 checks + Bedrock; returns a short security report.
- **EventBridge** – daily (08:00 UTC) and weekly (Monday 08:00 UTC) rules that trigger the supervisor with `schedule_type: daily` or `weekly`.
- **SSM parameters** – recipients and account alias (used by the supervisor at runtime).

### Required stack parameters

When you create or update the stack (Sync from Git or console), set:

| Parameter | Description |
|-----------|-------------|
| **SenderEmail** | Verified SES sender (e.g. `noreply@yourdomain.com`). Verify this identity in SES before deploying. |
| **RecipientEmails** | Comma-separated emails that receive the reports (e.g. `engineer@company.com,team@company.com`). |
| **AccountAlias** | Label in the email subject (e.g. `sandbox`, `prod`). Default: `sandbox`. |
| **BedrockModelId** | Model for Converse API (default: `anthropic.claude-3-5-sonnet-v2:0`). Enable this model in Bedrock in your account/region. |
| **DeploymentBucketName** | S3 bucket for Lambda zips (from `s3-deployment-bucket` stack). |
| **SupervisorS3Key** | S3 key for supervisor zip (e.g. `ai-cloud-agent/sandbox/supervisor.zip`). |
| **CostAgentS3Key** | S3 key for cost agent zip. |
| **SecurityAgentS3Key** | S3 key for security agent zip. |

### S3 and SCP compliance

Our AWS Organization enforces SCPs that **deny all s3:PutObject calls unless server-side encryption is explicitly used**. Therefore:

- The deployment bucket is created with default SSE-S3 (AES256) encryption and public access blocked.
- **All uploads must specify `--sse AES256`** (e.g. `aws s3 cp file.zip s3://bucket/key --sse AES256`).
- The build-and-upload script and GitHub Actions workflow use `--sse AES256` for all uploads.

### Local build and upload

To build zip packages and upload to S3 manually (e.g. before a Git Sync deploy):

```powershell
# Deploy the S3 bucket first if not already done.
# Then run (from repo root):
.\scripts\build-and-upload.ps1 -Environment sandbox -AccountId 503532613196

# Or with explicit bucket name:
.\scripts\build-and-upload.ps1 -BucketName ai-cloud-agent-sandbox-deployments-503532613196
```

Update `templates/sandbox-deployment.yaml` (or your deployment file) with the S3 keys output by the script, then commit and push for Git Sync.

### First deploy

1. Verify the **sender email** in Amazon SES (SES console → Verified identities).
2. Deploy `templates/s3-deployment-bucket.yaml` once.
3. Run `scripts/build-and-upload.ps1` to upload Lambda zips (or let the GitHub Actions workflow do it on push).
4. Ensure **DeploymentBucketName**, **SupervisorS3Key**, **CostAgentS3Key**, and **SecurityAgentS3Key** in the deployment file match your bucket and keys, then create the stack (Sync from Git or console).

### Testing the supervisor

Invoke the supervisor Lambda from the console or CLI with a test event to trigger a report without waiting for EventBridge:

```json
{"schedule_type": "daily"}
```

Check CloudWatch Logs for the supervisor and agents, and ensure the recipient inbox receives the email (and that SES is out of sandbox if sending to unverified addresses).

## Project layout

- **`templates/`** – CloudFormation: `main.yaml` (agent stack), `s3-deployment-bucket.yaml` (S3 bucket for Lambda zips), `cloudformation-service-role.yaml` (bootstrap IAM role for Git sync).
- **`src/`** – Lambda source: `supervisor/`, `agents/cost/`, `agents/security/` (each with `app.py` handler).
- **`scripts/build-and-upload.ps1`** – Builds zip packages and uploads to S3 with `--sse AES256`.
- **`.github/workflows/`** – GitHub Actions (build, upload, deploy).

## License

Internal use.
