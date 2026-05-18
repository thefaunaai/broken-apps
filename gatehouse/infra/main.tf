terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      app = "gatehouse"
    }
  }
}

locals {
  name = "gatehouse-target"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_ssm_parameter" "al2023_x86_64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_secretsmanager_secret" "smtp" {
  name = "gatehouse/smtp"

  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "smtp" {
  secret_id     = aws_secretsmanager_secret.smtp.id
  secret_string = jsonencode(var.smtp_config)
}

resource "aws_security_group" "gatehouse" {
  name        = local.name
  description = "Gatehouse target app"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = local.name
  }
}

resource "aws_vpc_security_group_ingress_rule" "allowed_http" {
  security_group_id = aws_security_group.gatehouse.id
  cidr_ipv4         = var.allowed_ingress_cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from allowed source IP"
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.gatehouse.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS for AWS APIs, packages, git, Docker Hub"
}

resource "aws_vpc_security_group_egress_rule" "smtp" {
  security_group_id = aws_security_group.gatehouse.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 465
  to_port           = 465
  ip_protocol       = "tcp"
  description       = "SMTP delivery"
}

resource "aws_iam_role" "gatehouse" {
  name = local.name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.gatehouse.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "smtp_secret" {
  name = "${local.name}-smtp-secret"
  role = aws_iam_role.gatehouse.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.smtp.arn
    }]
  })
}

resource "aws_iam_instance_profile" "gatehouse" {
  name = local.name
  role = aws_iam_role.gatehouse.name
}

resource "aws_instance" "gatehouse" {
  ami                         = data.aws_ssm_parameter.al2023_x86_64.value
  instance_type               = "t3.small"
  subnet_id                   = sort(data.aws_subnets.default.ids)[0]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.gatehouse.name
  vpc_security_group_ids      = [aws_security_group.gatehouse.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_size = 16
    volume_type = "gp3"
  }

  user_data_base64 = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    allowed_email = var.allowed_email
    aws_region    = var.aws_region
    secret_name   = aws_secretsmanager_secret.smtp.name
    source_branch = var.source_branch
  }))

  tags = {
    Name = local.name
  }

  depends_on = [
    aws_iam_role_policy.smtp_secret,
    aws_iam_role_policy_attachment.ssm,
    aws_secretsmanager_secret_version.smtp,
  ]
}

resource "terraform_data" "gatehouse_ready" {
  triggers_replace = [aws_instance.gatehouse.id]

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/wait-ready.sh ${var.aws_region} ${aws_instance.gatehouse.id}"
  }
}
