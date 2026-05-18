output "public_url" {
  description = "Public URL."
  value       = "http://${aws_instance.gatehouse.public_ip}/login"
}
