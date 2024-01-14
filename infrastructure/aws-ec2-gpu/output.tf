output "ssh_private_key" {
  value     = tls_private_key.key.private_key_pem
  sensitive = true
}

output "ec2_instance_ip" {
  value = aws_instance.ec2_instance.public_dns
}

output "ssh_command" {
  value = "ssh -i ssh_private_key.pem ec2-user@${aws_instance.ec2_instance.public_dns}"
}
