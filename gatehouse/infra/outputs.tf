output "public_url" {
  description = "HTTPS URL for the Gatehouse login page."
  value       = "https://${local.hostname}/login"
}

output "instance_id" {
  description = "EC2 instance ID for SSM troubleshooting."
  value       = aws_instance.gatehouse.id
}
