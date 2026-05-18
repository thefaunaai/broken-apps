# Gatehouse Infra

Disposable EC2 deployment for running Gatehouse as a cloud-reachable
target.

The goal is narrow: make Gatehouse reachable to one allowed source IP
without exposing SSH, publishing an image, or persisting secrets.

Treat each run as disposable. From a clean state, `terraform apply`
creates a fresh instance; `terraform destroy` removes it. This stack is
not intended for pausing, restarting, or updating a long-lived host.

## Shape

- default VPC and public subnet
- no SSH ingress
- SSM Session Manager enabled
- HTTP ingress only from `allowed_ingress_cidr`
- exact email recipient allowlist through `allowed_email`
- SMTP config managed in Secrets Manager from local Terraform settings
- no ECR; the instance builds the local Dockerfile
- no container restart policy; destroy and apply again for a fresh run

This stack assumes the AWS account has a default VPC with default public
subnets.

## Requirements

- Terraform
- AWS CLI
- AWS credentials allowed to manage EC2, IAM, security groups, SSM, and
  Secrets Manager
- a default VPC with default public subnets

## Local Config

Initialize `terraform.tfvars` from `terraform.tfvars.example`.

Set `allowed_ingress_cidr` to the public IPv4 address that should be
allowed to reach Gatehouse, written as a `/32` CIDR block.

Terraform creates the Secrets Manager secret from `smtp_config` and
deletes it on destroy. The secret name is `gatehouse/smtp`.

## State

Terraform state is local, gitignored, and disposable.
