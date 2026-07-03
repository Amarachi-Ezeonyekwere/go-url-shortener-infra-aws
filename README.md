# go-url-shortener-infra-aws

Terraform infrastructure and automated deployment pipeline for the [go-url-shortener-cicd-aws](https://github.com/Amarachi-Ezeonyekwere/go-url-shortener-cicd-aws) application. This repository provisions all AWS resources needed to run the application and handles deployment via a GitHub Actions pipeline authenticated through OIDC — no credentials stored anywhere.

---

## What This Repository Does

This repo has one responsibility: take a verified, scanned Docker image from AWS ECR and make it accessible to the world on AWS infrastructure.

It does not touch application code. It does not build or test anything. It provisions the cloud environment and deploys the container. That separation is intentional — a developer can update application code without touching infrastructure, and an infrastructure change never triggers an application rebuild.

---

## How the Infrastructure Serves the Application

When a user visits the application URL, here is what happens at the infrastructure level:

```
User's browser → EC2 Public IP (port 80)
                      │
                      ▼
             Docker container (port 8080)
                      │
                      ▼
             Go URL Shortener app
             POST /shorten  → creates short code
             GET  /:code    → redirects to original URL
             GET  /health   → health check
```

Each AWS resource has a specific job:

| Resource | What it does for the app |
|---|---|
| VPC | Private network boundary — isolates all resources from the rest of AWS |
| Public Subnet | Places the EC2 instance in a network segment that can reach the internet |
| Internet Gateway | The door between the VPC and the public internet |
| Route Table | The routing rules — tells traffic destined for the internet to use the IGW |
| Security Group | The firewall — allows port 80 (HTTP) and port 22 (SSH) inbound, all outbound |
| EC2 Instance | The server running the Docker container |
| IAM Role | The identity attached to EC2 — allows it to pull images from ECR without credentials |
| S3 Bucket | Stores Terraform state so the pipeline knows what infrastructure already exists |
| DynamoDB Table | Locks Terraform state during pipeline runs so two runs never conflict |

Without any one of these, the application either cannot run or cannot be reached.

---

## Architecture

```
GitHub Push to main
        │
        ▼
GitHub Actions Pipeline
  ├── Job 1: Terraform Gate
  │     ├── terraform fmt -check    ← enforces consistent formatting
  │     └── terraform validate      ← catches syntax errors before hitting AWS
  │
  ├── Job 2: Terraform Provision
  │     ├── terraform init          ← initialises S3 remote backend
  │     ├── terraform plan          ← previews what will change in AWS
  │     └── terraform apply         ← provisions or updates infrastructure
  │
  └── Job 3: Deploy
        ├── authenticate to ECR via OIDC
        ├── SSH into EC2
        ├── wait for Docker to be ready
        ├── pull latest image from ECR
        └── restart container with updated image
```

---

## Tech Stack

| Layer | Tool |
|---|---|
| Infrastructure as Code | Terraform |
| Cloud Provider | AWS |
| CI/CD | GitHub Actions |
| AWS Authentication | GitHub OIDC (no long-lived keys) |
| Container Registry | AWS ECR (private) |
| State Backend | S3 + DynamoDB locking |
| Compute | EC2 t2.micro — Ubuntu 22.04 LTS |

---

## Project Structure

```
go-url-shortener-infra-aws/
├── main.tf                        # Root — wires all modules together
├── variables.tf                   # All input variable declarations
├── outputs.tf                     # EC2 public IP, app URL, SSH command
├── terraform.tfvars               # Variable values (fill before applying)
├── .gitignore                     # Excludes .tfstate, .terraform/, secrets
└── modules/
    ├── networking/
    │   ├── main.tf                # VPC, subnet, IGW, route table
    │   ├── variables.tf
    │   └── outputs.tf             # vpc_id, public_subnet_id
    ├── security/
    │   ├── main.tf                # Security group — ports 80, 22, all egress
    │   ├── variables.tf
    │   └── outputs.tf             # ec2_sg_id
    ├── iam/
    │   ├── main.tf                # EC2 IAM role, ECR pull policy, instance profile
    │   ├── variables.tf
    │   └── outputs.tf             # ec2_instance_profile_name
    └── compute/
        ├── main.tf                # EC2 instance, AMI lookup, user data script
        ├── variables.tf
        └── outputs.tf             # ec2_public_ip
```

---

## Prerequisites

Before deploying you need:

- An AWS account
- The companion app repo pushed and image available in ECR: [go-url-shortener-cicd-aws](https://github.com/Amarachi-Ezeonyekwere/go-url-shortener-cicd-aws)
- An AWS key pair for SSH access (EC2 → Key Pairs → Create)
- Terraform installed locally (for first-time setup only)

---

## Step-by-Step Deployment Guide

### Step 1 — Create the S3 bucket for Terraform state

In AWS Console → S3 → Create bucket:
- Name: `url-shortener-tf-state-<your-account-id>`
- Region: `us-east-1`
- Enable versioning ✅
- Block all public access ✅
- Enable default encryption ✅

### Step 2 — Create the DynamoDB table for state locking

In AWS Console → DynamoDB → Create table:
- Table name: `url-shortener-tf-locks`
- Partition key: `LockID` (type: String)
- Use default settings

### Step 3 — Create the GitHub OIDC Identity Provider

In AWS Console → IAM → Identity providers → Add provider:
- Provider type: OpenID Connect
- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

This only needs to be done once per AWS account.

### Step 4 — Create the GitHub Actions IAM Role

In AWS Console → IAM → Roles → Create role:
- Trusted entity: Web identity
- Identity provider: `token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`
- GitHub organization: your GitHub username
- GitHub repository: `go-url-shortener-infra-aws`
- GitHub branch: `main`

Attach this inline policy (replace `<ACCOUNT_ID>` with your 12-digit AWS account ID):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EC2andVPC",
      "Effect": "Allow",
      "Action": ["ec2:*"],
      "Resource": "*"
    },
    {
      "Sid": "IAMForEC2Role",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole", "iam:DeleteRole", "iam:GetRole",
        "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
        "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
        "iam:GetInstanceProfile", "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile", "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
        "iam:TagRole", "iam:TagInstanceProfile"
      ],
      "Resource": [
        "arn:aws:iam::<ACCOUNT_ID>:role/ec2-ecr-role",
        "arn:aws:iam::<ACCOUNT_ID>:instance-profile/ec2-profile"
      ]
    },
    {
      "Sid": "PassRoleToEC2Only",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::<ACCOUNT_ID>:role/ec2-ecr-role",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "ec2.amazonaws.com"
        }
      }
    },
    {
      "Sid": "ECRAuth",
      "Effect": "Allow",
      "Action": ["ecr:GetAuthorizationToken"],
      "Resource": "*"
    },
    {
      "Sid": "ECRPull",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchCheckLayerAvailability"
      ],
      "Resource": "arn:aws:ecr:us-east-1:<ACCOUNT_ID>:repository/go-url-shortener-cicd-aws"
    },
    {
      "Sid": "TerraformStateBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetBucketVersioning"],
      "Resource": "arn:aws:s3:::url-shortener-tf-state-<ACCOUNT_ID>"
    },
    {
      "Sid": "TerraformStateObjects",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::url-shortener-tf-state-<ACCOUNT_ID>/*"
    },
    {
      "Sid": "TerraformLocks",
      "Effect": "Allow",
      "Action": ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"],
      "Resource": "arn:aws:dynamodb:us-east-1:<ACCOUNT_ID>:table/url-shortener-tf-locks"
    }
  ]
}
```

Name the role `github-actions-infra-role`. Copy its ARN — you will need it in the next step.

### Step 5 — Add GitHub Actions secrets

In your GitHub repo → Settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | ARN of `github-actions-infra-role` |
| `EC2_SSH_KEY` | Full contents of your `.pem` private key file |
| `ECR_REPOSITORY_URL` | Your full ECR URL e.g. `123456789.dkr.ecr.us-east-1.amazonaws.com/go-url-shortener-cicd-aws` |
| `TF_VAR_KEY_NAME` | Name of your AWS key pair e.g. `linux_key` |

### Step 6 — Update terraform.tfvars

Fill in `terraform.tfvars` with your values:

```hcl
aws_region         = "us-east-1"
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
availability_zone  = "us-east-1a"
instance_type      = "t2.micro"
key_name           = "your-key-pair-name"
ecr_repository_url = "your-account-id.dkr.ecr.us-east-1.amazonaws.com/go-url-shortener-cicd-aws"
```

### Step 7 — Update the backend bucket name in main.tf

```hcl
backend "s3" {
  bucket         = "url-shortener-tf-state-<your-account-id>"
  key            = "infra/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "url-shortener-tf-locks"
  encrypt        = true
}
```

### Step 8 — Push to main

```bash
git add .
git commit -m "feat: initial infrastructure deployment"
git push origin main
```

The pipeline triggers automatically. All three jobs go green. After completion Terraform outputs your EC2 public IP and your app URL.

### Step 9 — Test the application

```bash
# Health check
curl http://<ec2-public-ip>/health

# Shorten a URL
curl -X POST http://<ec2-public-ip>/shorten \
  -H "Content-Type: application/json" \
  -d '{"url": "https://github.com/Amarachi-Ezeonyekwere"}'

# Use the returned short code in your browser
http://<ec2-public-ip>/<short-code>
```

---

## Challenges Encountered and How They Were Solved

### 1. Terraform had no memory between pipeline runs
**Problem:** Without a remote state backend, every pipeline run started fresh. Terraform would try to create resources that already existed, causing `EntityAlreadyExists` errors on IAM roles and instance profiles.

**Fix:** Created an S3 bucket for state storage and a DynamoDB table for state locking. Added the `backend "s3"` block to `main.tf`. From that point forward, every pipeline run reads current state from S3 before planning, and locks the state during apply so concurrent runs never conflict.

### 2. EC2 instance launched without a public IP
**Problem:** The EC2 instance was provisioned but unreachable — no public IP was assigned.

**Root cause:** The subnet was missing `map_public_ip_on_launch = true`. Instances launched into the subnet received no public IP by default.

**Fix:** Added `map_public_ip_on_launch = true` to the subnet resource in the networking module, then force-replaced the EC2 instance using `terraform apply -replace="module.compute.aws_instance.app"`.

### 3. Pipeline deploy step failing with permission denied on Docker socket
**Problem:** The deploy script SSHed into EC2 and ran Docker commands, but received `permission denied while trying to connect to the Docker API`.

**Root cause:** Docker was installed by the root user via the user data script. The `ubuntu` SSH user was not in the `docker` group and could not run Docker commands without `sudo`.

**Fix (immediate):** Added `sudo` to all Docker commands in the deploy script.

**Fix (permanent):** Added `usermod -aG docker ubuntu` to the user data script in the compute module so all future instances automatically add the ubuntu user to the docker group at boot time.

### 4. SSH heredoc causing broken pipe and pipeline failure
**Problem:** The pipeline was succeeding on the server — container was running, deployment was complete — but GitHub Actions marked the step as failed due to a `BrokenPipeError`.

**Root cause:** The SSH heredoc (`<< 'ENDSSH'`) was closing the SSH session before GitHub Actions finished reading stdout, causing a broken pipe.

**Fix:** Changed the SSH command to use `'bash -s'` before the heredoc and added `ServerAliveInterval=30` to keep the connection alive. Added `exit 0` at the end of the heredoc for an explicit clean exit signal.

### 5. IAM policy syntax errors blocking pipeline
**Problem:** JSON policy documents kept failing with syntax errors when edited manually.

**Root cause:** Missing commas between statement objects in the `Statement` array, and mismatched closing brackets.

**Fix:** Adopted a consistent pattern — every statement in the array has a trailing comma except the last one. Validated JSON using the AWS console's built-in policy validator before saving.

---

## Security Design Decisions

**OIDC over access keys** — The GitHub Actions pipeline never holds AWS credentials. GitHub generates a short-lived token per run, AWS validates it against the configured identity provider, and issues temporary credentials that expire when the run ends. Nothing to rotate, nothing to leak.

**Least privilege IAM** — The `github-actions-infra-role` has only the permissions Terraform needs to provision these specific resources. `iam:PassRole` is scoped to a specific role ARN with a `PassedToService` condition so it can only be passed to EC2, not any other AWS service.

**EC2 pulls ECR without credentials** — The EC2 instance has an IAM role attached that grants ECR pull permissions. The Docker ECR login uses `aws ecr get-login-password` which exchanges the instance role for a temporary registry token. No Docker credentials are stored on the server.

**Private ECR** — The container image is not publicly accessible. Only AWS principals with explicit IAM permissions can pull it.

**Remote state with encryption** — Terraform state is stored in an encrypted S3 bucket with versioning enabled. If state becomes corrupted, previous versions are recoverable.

---

## Destroying the Infrastructure

To tear down all provisioned resources:

```bash
# From your local terminal with AWS credentials configured
terraform destroy \
  -var="key_name=your-key-pair-name" \
  -var="ecr_repository_url=your-ecr-url"
```

Type `yes` when prompted. Terraform destroys resources in the correct dependency order automatically.

---

*Part of a DevOps portfolio by Amarachi Ezeonyekwere — Cloud & DevOps Engineer open to remote roles.*
*Companion repo: [go-url-shortener-cicd-aws](https://github.com/Amarachi-Ezeonyekwere/go-url-shortener-cicd-aws)*