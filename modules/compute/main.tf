data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name
  iam_instance_profile   = var.ec2_instance_profile_name

  user_data_base64 = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Install Docker and AWS CLI
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg awscli

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io

    systemctl enable docker
    systemctl start docker

    # After installing Docker, add ubuntu user to docker group
    usermod -aG docker ubuntu

    # Authenticate to ECR using the instance IAM role — no credentials needed
    aws ecr get-login-password --region ${var.aws_region} | \
      docker login --username AWS --password-stdin ${var.ecr_repository_url}

    # Pull and run the app container
    docker pull ${var.ecr_repository_url}:latest

    docker run -d \
      --name url-shortener \
      --restart unless-stopped \
      -p 80:8080 \
      ${var.ecr_repository_url}:latest
  EOF
  )

  tags = {
    Name = "url-shortener-server"
  }
}