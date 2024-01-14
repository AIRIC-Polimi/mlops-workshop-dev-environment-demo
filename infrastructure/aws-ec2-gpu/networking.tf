module "ec2_ssh_security_group" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "mlops_workshop_demo_ssh_sg"
  description = "Security group for connecting via SSH to train nanoGPT for the MLOps workshop demo"
  vpc_id      = data.aws_vpc.default.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp"]
}

# NOTE: internet access is necessary to install packages (e.g., docker, git, ...) and clone git repos
module "ec2_internet_access_security_group" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "mlops_workshop_demo_internet_access_sg"
  description = "Security group for egress internet access"
  vpc_id      = data.aws_vpc.default.id

  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["http-80-tcp", "https-443-tcp", "ssh-tcp"]
}
