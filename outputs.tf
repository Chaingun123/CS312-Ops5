output "minecraft_public_ip" {
  description = "Public IP of the minecraft node: SSH here from your laptop"
  value       = aws_instance.minecraft.public_ip
}

output "ecr_repository_url" {
  description = "ECR repository URL: use this in the GitHub Actions workflow"
  value       = aws_ecr_repository.minecraft.repository_url
}
