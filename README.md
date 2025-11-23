# Terraform Lab

Hands-on Terraform scenarios that grow from the absolute basics to a full VPC + ALB + EC2 workload, demonstrating how to structure infrastructure as code with reusable modules and remote state.

## Skills Covered
- Initializing Terraform, pinning providers, and producing outputs (00-basics)
- Authoring AWS resources: S3 buckets, VPCs, subnets, internet gateways, route tables, NAT gateways, Elastic IPs
- Managing remote state with an S3 backend and DynamoDB locking (`backend/`)
- Working with input variables/`terraform.tfvars` and passing structured data into modules
- Designing reusable modules (`modules/vpc`) that expose outputs for downstream stacks
- Building environment-specific stacks (environments/dev) featuring ACM certificates, ALB/target groups/listeners, security groups, IAM roles/profiles, Systems Manager Session Manager, and EC2 user-data automation that installs Docker + nginx
- Operating Terraform safely: `plan`, `apply`, and `destroy`, plus cleaning up cloud resources when labs are finished

## Repository Layout
| Path | Purpose |
| --- | --- |
| `00-basics/` | Minimal root module that provisions a single S3 bucket and prints its name.
| `backend/` | Creates an S3 bucket + DynamoDB table suitable for Terraform remote state and configures the backend block.
| `01-vpc/` | Builds a manually defined public VPC (two subnets, IGW, route tables) to practice core networking resources.
| `modules/vpc/` | Parameterized VPC module with public/private subnets, NAT gateway, and routing associations.
| `environments/dev/` | Complete reference environment that consumes the VPC module and adds certificates, an ALB, listeners, target groups, IAM/SSM access, and a Docker-based EC2 instance behind HTTPS.
| `environments/dev/session-manager-plugin.rpm` | Offline installer for the AWS Session Manager Plugin (needed if you want SSM port-forwarding into the private instance).

## Prerequisites
- Terraform CLI 1.5+ and AWS CLI v2.
- An AWS account with permissions for IAM, EC2, ACM, Route 53, and VPC resources.
- AWS credentials exported locally (for example `AWS_PROFILE=terraform-lab`).
- Optional: install the AWS Session Manager Plugin (binary included under `environments/dev/`).

## Working Through the Labs
Each directory is an independent Terraform root module. Run commands from inside the folder you are exploring.

### 00-basics — Provider Warm-up
1. `cd 00-basics`
2. `terraform init`
3. `terraform plan`
4. `terraform apply`

What you learn: declaring providers, configuring regions, creating an `aws_s3_bucket`, and exposing values via `output` blocks. Destroy the bucket when finished (`terraform destroy`).

### backend — Remote State Bucket + Locks
1. `cd backend`
2. Customize bucket/table names in `main.tf` if they are not globally unique.
3. `terraform init && terraform apply`

Resources: versioned + encrypted S3 bucket for state, DynamoDB table for state locks, plus outputs that can be copied into other backends. Once provisioned you can copy the backend stanza into future root modules (`bucket`, `key`, `region`, `dynamodb_table`).

### 01-vpc — Hand-built Network
1. `cd 01-vpc`
2. Review `variables.tf` / `terraform.tfvars` to adjust CIDRs or regions.
3. `terraform init`, `plan`, and `apply`.

Resources: VPC, two public subnets, internet gateway, public route table, and associations. Outputs expose IDs for validation or reuse. Skills practiced: iterating on variables, referencing attributes, and tagging resources consistently.

### modules/vpc — Reusable Networking Module
This directory is a Terraform module meant to be called from other stacks. It demonstrates:
- Accepting lists for public/private subnets and looping with `count` to create symmetric resources.
- Surfacing key identifiers via outputs so downstream stacks can attach security groups, ALBs, NAT gateways, etc.
- Using data sources (`aws_availability_zones`) to stay AZ-aware.

You can test the module quickly by calling it from a scratch root module or by reviewing how `environments/dev` consumes it.

### environments/dev — End-to-end Environment
1. `cd environments/dev`
2. Update `terraform.tfvars`:
   - `project`, `region`, and CIDRs as needed.
   - `domain_name` and `hosted_zone_id` must reference a Route 53 public hosted zone you control for ACM DNS validation.
   - Optionally set `my_ip_cidr` if you uncomment the SSH ingress rule.
3. Initialize Terraform. If you want to reuse the remote state bucket created earlier, add a `backend` block mirroring the values from `backend/main.tf` or run `terraform init -backend-config="bucket=..." ...`.
4. `terraform plan` and `apply`.

Resources/skills:
- Consuming the `modules/vpc` outputs for multi-AZ public & private subnets plus a NAT gateway.
- ACM certificate with DNS validation (records returned via `acm_dns_validation_records`).
- Application Load Balancer with dedicated security group, listeners, and target group forwarding to EC2.
- Private EC2 instance (Amazon Linux 2023) launched without a public IP, configured through user data to install Docker, docker-compose, and run nginx in a container.
- IAM role + instance profile granting SSM access; connect through AWS Systems Manager Session Manager instead of SSH.
- Outputs exposing ALB DNS name and EC2 metadata for verification.

### Cleanup
Terraform only manages resources that were created via these configs. When you finish a lab, run `terraform destroy` from the same directory to avoid ongoing AWS charges. Destroy the `environments/dev` stack before deleting shared resources like the remote state bucket.

## Suggested Workflow
1. Run `00-basics` to confirm credentials.
2. Provision the remote state infrastructure under `backend/`.
3. Practice networking with `01-vpc` and review the `modules/vpc` implementation.
4. Deploy `environments/dev` to experience a full stack, then iterate by adjusting variables, security groups, or user data.

Happy Terraforming!
