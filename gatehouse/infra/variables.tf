variable "aws_region" {
  description = "AWS region for the disposable Gatehouse instance."
  type        = string
  default     = "us-east-1"
}

variable "source_branch" {
  description = "Git branch to clone for the Gatehouse source."
  type        = string
  default     = "main"

  validation {
    condition     = length(trimspace(var.source_branch)) > 0 && can(regex("^[A-Za-z0-9._/-]+$", var.source_branch))
    error_message = "source_branch must be a branch name using letters, numbers, dot, underscore, slash, or dash."
  }
}

variable "allowed_ingress_cidr" {
  description = "Only this IP can reach Gatehouse over HTTP. Use one IPv4 address as x.x.x.x/32."
  type        = string

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/32$", var.allowed_ingress_cidr)) && can(cidrhost(var.allowed_ingress_cidr, 0))
    error_message = "allowed_ingress_cidr must be one IPv4 address as x.x.x.x/32."
  }
}

variable "allowed_email" {
  description = "Only this recipient can request a Gatehouse verification email."
  type        = string

  validation {
    condition     = length(trimspace(var.allowed_email)) > 0 && can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.allowed_email))
    error_message = "allowed_email must be one concrete email address."
  }
}

variable "smtp_config" {
  description = "Gatehouse SMTP runtime config. Stored in local Terraform state until destroy."
  type = object({
    SMTP_URL  = string
    MAIL_FROM = string
  })
  sensitive = true

  validation {
    condition = (
      length(trimspace(var.smtp_config.SMTP_URL)) > 0 &&
      length(trimspace(var.smtp_config.MAIL_FROM)) > 0
    )
    error_message = "smtp_config must contain SMTP_URL and MAIL_FROM."
  }
}
