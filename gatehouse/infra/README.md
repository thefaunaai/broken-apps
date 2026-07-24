# Gatehouse Infra

Disposable AWS deployment for running Gatehouse as a cloud-reachable
target.

The stack gives Gatehouse a temporary HTTPS endpoint restricted to one
source CIDR. It uses SSM instead of SSH, builds the image on the
instance, and stores SMTP configuration in Secrets Manager.

Treat each run as disposable. From a clean state, `terraform apply`
creates a fresh instance; `terraform destroy` removes it. This stack is
not intended for pausing, restarting, or updating a long-lived host.

## Architecture

- one EC2 instance in the default VPC
- an internet-facing Application Load Balancer in two default public
  subnets
- an ACM certificate validated with Route 53 DNS records
- HTTPS ingress to the load balancer only from
  `allowed_ingress_cidr`
- Gatehouse port 3000 ingress only from the load balancer security
  group
- a Route 53 alias from `hostname` to the load balancer
- no SSH ingress
- SSM Session Manager enabled
- exact email recipient allowlist through `allowed_email`
- SMTP configuration managed in Secrets Manager from local Terraform
  settings
- no ECR; the instance builds the local Dockerfile
- no container restart policy; destroy and apply again for a fresh run

This stack assumes the AWS account has a default VPC with default public
subnets in at least two Availability Zones and an existing public
Route 53 hosted zone for `hosted_zone_name`.

## Requirements

- Terraform
- AWS CLI
- AWS credentials allowed to manage ACM, EC2, Elastic Load Balancing,
  IAM, Route 53 records, security groups, SSM, and Secrets Manager
- a default VPC with default public subnets in at least two Availability
  Zones
- an existing public Route 53 hosted zone for the chosen hostname

## Local Config

Initialize `terraform.tfvars` from `terraform.tfvars.example`.

Set `hosted_zone_name` to the public Route 53 zone in the deploying AWS
account. Set `hostname` to the full Gatehouse hostname within that zone.

Set `allowed_ingress_cidr` to the public IPv4 address allowed to reach
Gatehouse, written as a `/32` CIDR block.

Terraform creates the Secrets Manager secret from `smtp_config` and
deletes it on destroy. The secret name is `gatehouse/smtp`.

## State

Terraform state is local, gitignored, and disposable.
