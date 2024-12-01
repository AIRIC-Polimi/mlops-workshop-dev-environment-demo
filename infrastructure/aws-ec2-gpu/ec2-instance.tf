data "aws_ami" "ubuntu22" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-*"]
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


data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "s3_dvc_rw_access" {
  statement {
    actions = ["s3:*"]

    resources = ["arn:aws:s3:::mlops-workshop-demo"]
  }
}

resource "aws_iam_role" "ec2_iam_role" {
  name_prefix = "mlops-workshop-demo-iam-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy" "join_policy" {
  role       = aws_iam_role.ec2_iam_role.name
  policy = data.aws_iam_policy_document.s3_dvc_rw_access.json
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name_prefix = "mlops-workshop-demo-iam-role-instance-profile"
  role = aws_iam_role.ec2_iam_role.name
}

resource "aws_instance" "ec2_instance" {
  ami           = data.aws_ami.ubuntu22.id
  instance_type = var.ec2_instance_type

  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  root_block_device {
    volume_size = var.ec2_instance_volume_size
  }

  user_data = <<-EOF
    #!/bin/bash -e

    if [[ ! -f /home/ubuntu/_build_essential ]]; then
      echo "[USER] Installing build essentials"
      sudo NEEDRESTART_MODE=a apt-get update -y
      # Git and build essentials (autorestart daemons if needed)
      sudo NEEDRESTART_MODE=a apt-get install -y git build-essential ubuntu-drivers-common
      touch /home/ubuntu/_build_essential
    fi

    # Docker
    if [[ ! -f /home/ubuntu/_docker ]]; then
      echo "[USER] Installing docker"
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
      echo "[USER] Installing docker-compose"
      sudo NEEDRESTART_MODE=a curl -L https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
      sudo NEEDRESTART_MODE=a chmod +x /usr/local/bin/docker-compose
      touch /home/ubuntu/_docker_compose
    fi

    # Install Nvidia drivers
    if [[ ! -f /home/ubuntu/_cuda ]]; then
      echo "[USER] Installing nvidia drivers"
      sudo apt install -y linux-modules-nvidia-550-server-open-6.8.0-49-generic
      sudo apt install -y nvidia-utils-550-server
      sudo apt install -y nvidia-driver-550 nvidia-dkms-550
      touch /home/ubuntu/_cuda
    fi

    # Nvidia container toolkit
    if [[ ! -f /home/ubuntu/_toolkit ]]; then
      echo "[USER] Installing nvidia container toolkit"
      curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo NEEDRESTART_MODE=a gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
      curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo NEEDRESTART_MODE=a tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
      sudo NEEDRESTART_MODE=a apt-get update
      sudo NEEDRESTART_MODE=a apt-get install -y nvidia-container-toolkit
      sudo NEEDRESTART_MODE=a systemctl restart docker
      sudo nvidia-ctk runtime configure --runtime=docker
      sudo systemctl restart docker
      touch /home/ubuntu/_toolkit
    fi

    # Setting up repository
    if [[ ! -f /home/ubuntu/_repo ]]; then
      echo "[USER] Setting up repo"
      git clone https://github.com/AIRIC-Polimi/mlops-workshop-dev-environment-demo.git /home/ubuntu/mlops-workshop-dev-environment-demo
      cd /home/ubuntu/mlops-workshop-dev-environment-demo
      docker run -it --rm -v `realpath .`:/workspace --workdir /workspace python:3.12-slim bash -c 'pip install dvc[s3] && dvc pull'
      touch /home/ubuntu/_repo
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

resource "null_resource" "append_ssh_config" {
  provisioner "local-exec" {
    command = <<-EOT
      identity_file_abspath=`realpath .`
      host="mlops-devenv-demo"

      grep "Host $host" ~/.ssh/config 2>&1 > /dev/null
      if [ $? -eq 0 ]; then
          sed -i --follow-symlinks "/Host $host/,/HostName/ s/HostName .*/HostName ${aws_instance.ec2_instance.public_dns}/" ~/.ssh/config
          sed -i --follow-symlinks "/Host $host/,/IdentityFile/ s~IdentityFile .*~IdentityFile $identity_file_abspath/ssh_private_key.pem~" ~/.ssh/config
      else
          ssh_config=$(cat <<END

      Host $host
          HostName ${aws_instance.ec2_instance.public_dns}
          User ubuntu
          IdentityFile "$identity_file_abspath/ssh_private_key.pem"
          ForwardAgent yes
      END
      )

          echo "$ssh_config" >> ~/.ssh/config
      fi

      # This is to append to known_hosts file the fingerprints of the new server
      ssh-keyscan ${aws_instance.ec2_instance.public_dns} >> $HOME/.ssh/known_hosts
    EOT
  }
}