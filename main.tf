terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  # If you configured a named profile above, add: profile = "cs312"
}

# Use the default VPC instead of creating a new one
data "aws_vpc" "default" {
  default = true
}

# Security Group for the control node: SSH access from your laptop
resource "aws_security_group" "minecraft" {
  name        = "cs312-minecraft-sg"
  description = "K3 node with ssh and minecraft ports enabled"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.devip]
  }

  ingress {
    description = "Minecraft"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cs312-tf-minecraft-sg"
  }
}

#bucket logic
resource "aws_s3_bucket" "backups" {
  bucket = var.backup_name

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name    = var.backup_name
    Project = "cs312-minecraft"
    Purpose = "minecraft-backups"
  }
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

#security rules per assignment
resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#k3 node
resource "aws_instance" "minecraft" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.minecraft.id]
  iam_instance_profile   = "LabInstanceProfile"
  #user data to install k3 configs and k3. credential-provider-config
  #was taken from the example on the kubernetes website.
  #claude was used to research how to statically set kubelet args
  user_data = <<-EOF
  #cloud-config
  package_update: true
  package_upgrade: false
  packages:
    - jq
    - awscli

  write_files:
    - path: /etc/kubernetes/credential-provider-config.yaml
      permissions: '0644'
      content: |
        apiVersion: kubelet.config.k8s.io/v1
        kind: CredentialProviderConfig
        providers:
          - name: ecr-credential-provider
            matchImages:
              - "*.dkr.ecr.*.amazonaws.com"
            defaultCacheDuration: "12h"
            apiVersion: credentialprovider.kubelet.k8s.io/v1

    - path: /etc/rancher/k3s/config.yaml
      permissions: '0600'
      content: |
        kubelet-arg:
          - "image-credential-provider-config=/etc/kubernetes/credential-provider-config.yaml"
          - "image-credential-provider-bin-dir=/usr/local/bin"

  runcmd:
    - curl -L -o /usr/local/bin/ecr-credential-provider https://github.com/dntosas/ecr-credential-provider/releases/download/v1.2.0/ecr-credential-provider-linux-amd64
    - chmod 0755 /usr/local/bin/ecr-credential-provider
    - curl -sfL https://get.k3s.io | sh -
    - git clone https://github.com/Chaingun123/CS312-Ops4.git /opt/ops4/
    - sleep 5
    - cp /opt/ops4/manifests/*.yaml /var/lib/rancher/k3s/server/manifests

  EOF

  root_block_device {
    volume_size           = 30
    delete_on_termination = true
  }

  tags = {
    Name = "cs312-minecraft-k3"
  }
}

# ECR repository for the CI/CD pipeline
resource "aws_ecr_repository" "minecraft" {
  name                 = "cs312-minecraft"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

