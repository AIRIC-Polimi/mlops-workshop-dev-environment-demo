data "aws_ami" "ubuntu22" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "mlops-workshop-demo-ssh-key"
  public_key = tls_private_key.key.public_key_openssh

  provisioner "local-exec" {
    command = <<-EOT
      echo '${tls_private_key.key.private_key_pem}' > ./ssh_private_key.pem
      chmod 400 ./ssh_private_key.pem
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      rm -f ./ssh_private_key.pem
    EOT

    when = destroy
  }
}

resource "aws_instance" "ec2_instance" {
  ami           = data.aws_ami.ubuntu22.id
  instance_type = var.ec2_instance_type

  root_block_device {
    volume_size = var.ec2_instance_volume_size
  }

  user_data = <<-EOF
    #!/bin/bash
    
    if [[ ! -f /home/ubuntu/_build_essential ]]; then
      sudo NEEDRESTART_MODE=a apt-get update -y
      # Git and build essentials (autorestart daemons if needed)
      sudo NEEDRESTART_MODE=a apt-get install -y git build-essential
      touch /home/ubuntu/_build_essential
    fi

    # Docker
    if [[ ! -f /home/ubuntu/_docker ]]; then
      sudo NEEDRESTART_MODE=a apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo NEEDRESTART_MODE=a apt-key add -
      sudo NEEDRESTART_MODE=a add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
      sudo NEEDRESTART_MODE=a apt update
      sudo NEEDRESTART_MODE=a apt install -y docker-ce docker-ce-cli containerd.io
      # Enable for next restart(s)
      sudo NEEDRESTART_MODE=a systemctl enable docker
      sudo NEEDRESTART_MODE=a usermod -a -G docker ubuntu
      touch /home/ubuntu/_docker
    fi

    # Docker-compose
    if [[ ! -f /home/ubuntu/_docker_compose ]]; then
      sudo NEEDRESTART_MODE=a curl -L https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
      sudo NEEDRESTART_MODE=a chmod +x /usr/local/bin/docker-compose
      touch /home/ubuntu/_docker_compose
    fi

    # Install Nvidia drivers
    if [[ ! -f /home/ubuntu/_cuda ]]; then
      BASE_URL=https://us.download.nvidia.com/tesla
      DRIVER_VERSION=535.129.03
      curl -fSsl -O $BASE_URL/$DRIVER_VERSION/NVIDIA-Linux-x86_64-$DRIVER_VERSION.run
      chmod +x NVIDIA-Linux-x86_64-$DRIVER_VERSION.run 
      sudo NEEDRESTART_MODE=a sh NVIDIA-Linux-x86_64-$DRIVER_VERSION.run -qs
      touch /home/ubuntu/_cuda
    fi

    # Nvidia container toolkit
    if [[ ! -f /home/ubuntu/_toolkit ]]; then
      curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo NEEDRESTART_MODE=a gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
      curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo NEEDRESTART_MODE=a tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
      sudo NEEDRESTART_MODE=a apt-get update
      sudo NEEDRESTART_MODE=a apt-get install -y nvidia-container-toolkit
      sudo NEEDRESTART_MODE=a systemctl restart docker
      sudo nvidia-ctk runtime configure --runtime=docker
      sudo systemctl restart docker
      touch /home/ubuntu/_toolkit
    fi

    reboot
  EOF

  vpc_security_group_ids = [
    module.ec2_ssh_security_group.security_group_id,
    module.ec2_internet_access_security_group.security_group_id
  ]

  tags = {
    Name = "mlops-workshop-demo"
  }

  key_name                = aws_key_pair.ssh_key.key_name
  monitoring              = true
  disable_api_termination = false
  ebs_optimized           = true
}
