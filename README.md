# AI Cloud Agent

Multi-agent system that monitors an AWS account and sends daily/weekly email reports (cloud hygiene, cost, security) via a supervisor and subordinate agents. Deployed with CloudFormation; Lambdas use container images (ECR).

## Repository and pipeline

- **GitHub**: Create a new repo (e.g. `ai-cloud-agent`) and add this project as the remote (see below).
- **Pipeline**: GitHub Actions deploys the CloudFormation stack on push to `main`. No S3 uploads; Lambdas will use ECR when added.

### One-time setup

1. **Create the CloudFormation service role (required for Git sync)**  
   CloudFormation needs an IAM role to assume when creating/updating the stack. Deploy it once:
   - In the **CloudFormation console**: Create stack → Upload a template file → choose `templates/cloudformation-service-role.yaml` from this repo (or paste its contents).
   - Stack name: e.g. `ai-cloud-agent-bootstrap`.
   - Create the stack. When it completes, go to **Outputs** and copy the **RoleArn** (e.g. `arn:aws:iam::123456789012:role/ai-cloud-agent-cloudformation-service-role`).
   - When creating the main stack with **Sync from Git**, under **Permissions** → **IAM role**, choose this role (it appears as `ai-cloud-agent-cloudformation-service-role`).

2. **Create the GitHub repo**
   - On GitHub: New repository → name `ai-cloud-agent` (or your choice) → Create (no need to add README; this project has one).

3. **Connect and push**
   ```bash
   git remote add origin https://github.com/YOUR_ORG/ai-cloud-agent.git
   git branch -M main
   git push -u origin main
   ```

4. **Configure AWS credentials for the pipeline**
   - **Option A (recommended): OIDC**  
     In your AWS account, create an OIDC identity provider for GitHub and an IAM role that trusts it and has `cloudformation:*` (and later `ecr:*`, `lambda:*`). In the repo: Settings → Secrets and variables → Actions:
     - **Variables**: `USE_OIDC` = `true`
     - **Secrets**: `AWS_ROLE_ARN` (the IAM role ARN), `AWS_REGION` (e.g. `us-east-1`)
   - **Option B: Access keys**  
     In the repo: Settings → Secrets and variables → Actions → Secrets:
     - `AWS_ACCESS_KEY_ID`
     - `AWS_SECRET_ACCESS_KEY`
     - `AWS_REGION` (e.g. `us-east-1`). If omitted, the workflow uses `us-east-1`.

5. **Update the workflow for your stack name**  
   Edit `.github/workflows/deploy.yml` and set `stack-name` (and `region` if not using a secret) to match your environment (e.g. `ai-cloud-agent-sandbox`).

After that, every push to `main` runs the workflow and deploys/updates the CloudFormation stack.

## Deploying the agent

The main stack (`templates/main.yaml`) creates:

- **Supervisor Lambda** – invokes subordinate Lambdas, calls Bedrock to synthesize the report, sends email via SES.
- **Cost agent Lambda** – Cost Explorer + Bedrock; returns a short cost/optimization report.
- **Security agent Lambda** – Security Hub / EC2 / S3 checks + Bedrock; returns a short security report.
- **EventBridge** – daily (08:00 UTC) and weekly (Monday 08:00 UTC) rules that trigger the supervisor with `schedule_type: daily` or `weekly`.
- **ECR repositories** – one per Lambda; push your container images here.
- **SSM parameters** – recipients and account alias (used by the supervisor at runtime).

### Required stack parameters

When you create or update the stack (Sync from Git or console), set:

| Parameter | Description |
|-----------|-------------|
| **SenderEmail** | Verified SES sender (e.g. `noreply@yourdomain.com`). Verify this identity in SES before deploying. |
| **RecipientEmails** | Comma-separated emails that receive the reports (e.g. `engineer@company.com,team@company.com`). |
| **AccountAlias** | Label in the email subject (e.g. `sandbox`, `prod`). Default: `sandbox`. |
| **BedrockModelId** | Model for Converse API (default: `anthropic.claude-3-5-sonnet-v2:0`). Enable this model in Bedrock in your account/region. |

**SupervisorImageUri**, **CostAgentImageUri**, **SecurityAgentImageUri** – Required. Lambda **cannot** use images from public ECR; images must be in a **private ECR repository** in your account and region. Push the base image (or your custom image) to the stack’s ECR repos, then set these parameters to those image URIs (see below).

### Fix: "Source image ... is not valid" / CREATE_FAILED

Lambda rejects `public.ecr.aws/lambda/python:3.12` because it only accepts images from **private** ECR in the same account/region. Do this:

1. **Create the ECR repos** (if you see *"The repository with name 'ai-cloud-agent-sandbox-...' does not exist"* when pushing):  
   Deploy the ECR-only template once so the repos exist:
   - **CloudFormation console** → Create stack → Upload a template file → choose `templates/ecr-only.yaml`.
   - Stack name: e.g. `ai-cloud-agent-ecr`.
   - Create the stack. When it completes, the three repos exist and you can push images.

2. **Get your ECR repo URIs**  
   From the CloudFormation stack **Outputs** (or Resources): `SupervisorRepoUri`, `CostAgentRepoUri`, `SecurityAgentRepoUri`. If the stack is CREATE_FAILED, the ECR repos may still exist – check the ECR console for `ai-cloud-agent-sandbox-supervisor`, `-cost-agent`, `-security-agent`. The image URI format is: `ACCOUNT.dkr.ecr.REGION.amazonaws.com/ai-cloud-agent-sandbox-supervisor:latest` (replace ACCOUNT and REGION).

3. **Push the base image to each repo** – run these commands **one at a time** in PowerShell or a terminal (no script needed). Replace `ACCOUNT` and `REGION` with your AWS account ID and region (e.g. `503532613196`, `us-east-1`):

   ```powershell
   aws ecr get-login-password --region REGION | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.REGION.amazonaws.com
   ```
   ```powershell
   docker pull public.ecr.aws/lambda/python:3.12
   ```
   ```powershell
   docker tag public.ecr.aws/lambda/python:3.12 ACCOUNT.dkr.ecr.REGION.amazonaws.com/ai-cloud-agent-sandbox-supervisor:latest
   docker push ACCOUNT.dkr.ecr.REGION.amazonaws.com/ai-cloud-agent-sandbox-supervisor:latest
   ```
   ```powershell
   docker tag public.ecr.aws/lambda/python:3.12 ACCOUNT.dkr.ecr.REGION.amazonaws.com/ai-cloud-agent-sandbox-cost-agent:latest
   docker push ACCOUNT.dkr.ecr.REGION.amazonaws.com/ai-cloud-agent-sandbox-cost-agent:latest
   ```
   ```powershell
   docker tag public.ecr.aws/lambda/python:3.12 ACCOUNT.dkr.ecr.REGION.amazonaws.com/ai-cloud-agent-sandbox-security-agent:latest
   docker push ACCOUNT.dkr.ecr.REGION.amazonaws.com/ai-cloud-agent-sandbox-security-agent:latest
   ```

   Example for account `503532613196` and region `us-east-1`: use `503532613196` for ACCOUNT and `us-east-1` for REGION in every command above.

4. **Set the image parameters**  
   In `templates/sandbox-deployment.yaml`, replace `ACCOUNT` and `REGION` in **SupervisorImageUri**, **CostAgentImageUri**, and **SecurityAgentImageUri** with your real account ID and region (e.g. `123456789012`, `us-east-1`).

5. **Commit and push**  
   Git sync will run again; the stack update will use the new image URIs and Lambda creation should succeed. If the stack was CREATE_FAILED, the update retries the failed resources.

### First deploy (with base images)

1. Verify the **sender email** in Amazon SES (SES console → Verified identities).
2. Push the base image to your ECR repos (step 2 above). If the stack doesn’t exist yet, create the ECR repos first by deploying the stack once (it will fail on Lambda; ECR repos will exist), then push images and set the three image URIs in the deployment file, then push again.
3. Ensure **SupervisorImageUri**, **CostAgentImageUri**, and **SecurityAgentImageUri** in the deployment file use your private ECR URIs (step 3 above), then create the stack (Sync from Git or console).

### Building and pushing your images

After you add Lambda code under `src/supervisor/`, `src/agents/cost/`, and `src/agents/security/` (each with a `Dockerfile`):

1. **Log in to ECR** (replace region and account as needed):
   ```bash
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
   ```
2. **Build and push** each image to the ECR URIs shown in the stack **Outputs** (e.g. `SupervisorRepoUri`, `CostAgentRepoUri`, `SecurityAgentRepoUri`). Tag as `latest` (or the tag you use in the Outputs).
3. **Update the stack** with the new image URIs: set parameters **SupervisorImageUri**, **CostAgentImageUri**, **SecurityAgentImageUri** to the full ECR image URIs (e.g. `123456789012.dkr.ecr.us-east-1.amazonaws.com/ai-cloud-agent-sandbox-supervisor:latest`). If you use Git sync, update the stack deployment file parameters and commit; otherwise update the stack in the console.

### Testing the supervisor

Invoke the supervisor Lambda from the console or CLI with a test event to trigger a report without waiting for EventBridge:

```json
{"schedule_type": "daily"}
```

Check CloudWatch Logs for the supervisor and agents, and ensure the recipient inbox receives the email (and that SES is out of sandbox if sending to unverified addresses).

## Project layout

- **`templates/`** – CloudFormation: `main.yaml` (agent stack), `cloudformation-service-role.yaml` (bootstrap IAM role for Git sync).
- **`src/`** – Lambda source: `supervisor/`, `agents/cost/`, `agents/security/` (each with a Dockerfile; add these when implementing the agents).
- **`.github/workflows/`** – GitHub Actions (optional deploy; use Git sync for deployment if you prefer).

## License

Internal use.
