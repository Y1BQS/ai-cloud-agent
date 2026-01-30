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

## Project layout (planned)

- `templates/` – CloudFormation templates (main stack; Lambdas will reference ECR images).
- `src/` – Lambda source (supervisor, cost agent, security agent); built as Docker images and pushed to ECR by the pipeline.
- `.github/workflows/` – GitHub Actions (deploy CloudFormation, and later build/push images to ECR).

## License

Internal use.
